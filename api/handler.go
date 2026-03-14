package api

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/Servicewall/go-cube/config"
	"github.com/Servicewall/go-cube/model"
	"github.com/Servicewall/go-cube/sql"
)

type Handler struct {
	modelLoader *model.Loader
	chClient    *sql.Client
}

// New 使用 ClickHouse 配置和内置模型创建 Handler，是最常见场景的便利构造函数。
func New(cfg *config.ClickHouseConfig) (*Handler, error) {
	chClient, err := sql.NewClient(cfg)
	if err != nil {
		return nil, err
	}
	return NewHandler(model.NewLoader(model.InternalFS), chClient), nil
}

// NewHandler 使用外部提供的 modelLoader 和 chClient 创建 Handler，适合自定义模型或测试场景。
func NewHandler(modelLoader *model.Loader, chClient *sql.Client) *Handler {
	return &Handler{modelLoader: modelLoader, chClient: chClient}
}

// Query 执行一次 cube 查询，接受结构体，是库调用的首选入口。
func (h *Handler) Query(ctx context.Context, req *QueryRequest) (*QueryResponse, error) {
	if err := validateQuery(req); err != nil {
		return nil, err
	}

	modelName := extractModelNameFromRequest(req)
	if modelName == "" {
		return nil, errorf("无法从查询中确定模型")
	}

	m, err := h.modelLoader.Load(modelName)
	if err != nil {
		return nil, err
	}

	query, params, err := BuildQuery(req, m)
	if err != nil {
		return nil, err
	}
	log.Printf("SQL: %s %v", query, params)

	data, err := h.chClient.Query(ctx, query, params...)
	if err != nil {
		return nil, err
	}

	return &QueryResponse{
		QueryType: "regularQuery",
		Results:   []QueryResult{{Query: *req, Data: data}},
	}, nil
}

// HandleLoad 是 HTTP 入口，供注册到路由器使用。
func (h *Handler) HandleLoad(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 30*time.Second)
	defer cancel()

	var body []byte
	if r.Method == http.MethodPost {
		body, _ = io.ReadAll(r.Body)
	} else {
		body = []byte(r.URL.Query().Get("query"))
	}

	req, err := parseQueryRequest(body)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}

	resp, err := h.Query(ctx, req)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

func (h *Handler) HealthCheck(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	if err := h.chClient.Ping(ctx); err != nil {
		http.Error(w, err.Error(), http.StatusServiceUnavailable)
		return
	}
	writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
}

// parseQueryRequest 从 JSON 字节解析出 QueryRequest。
// 支持两种格式：直接的 QueryRequest JSON，或包含 "query" 键的包装对象。
func parseQueryRequest(body []byte) (*QueryRequest, error) {
	if m := map[string]json.RawMessage{}; json.Unmarshal(body, &m) == nil && m["query"] != nil {
		body = m["query"]
	}
	var req QueryRequest
	if err := json.Unmarshal(body, &req); err != nil {
		return nil, err
	}
	return &req, nil
}

func extractModelNameFromRequest(req *QueryRequest) string {
	if len(req.Dimensions) > 0 {
		return extractModelName(req.Dimensions[0])
	}
	if len(req.Measures) > 0 {
		return extractModelName(req.Measures[0])
	}
	if len(req.Filters) > 0 {
		return extractModelName(filterMember(req.Filters[0]))
	}
	return ""
}

func extractModelName(field string) string {
	name, _, _ := strings.Cut(field, ".")
	return name
}

// filterMember 返回 filter 的 Member 字段；
// 若为 OR 复合条件则遍历子条件，返回第一个非空的 Member。
func filterMember(f Filter) string {
	if f.Member != "" {
		return f.Member
	}
	for _, sub := range f.Or {
		if m := filterMember(sub); m != "" {
			return m
		}
	}
	return ""
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(v)
}

func errorf(format string, args ...any) error {
	return fmt.Errorf(format, args...)
}
