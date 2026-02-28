package api

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/Servicewall/go-cube/config"
	"github.com/Servicewall/go-cube/model"
	"github.com/Servicewall/go-cube/sql"
)

// customKeyPattern 只允许字母、数字、下划线、连字符
var customKeyPattern = regexp.MustCompile(`^[a-zA-Z0-9_-]+$`)

// customKeyDelimiter 是 Custom-Key 请求头中参数名在 SQL 模板中使用的分隔符，
// 与 AccessView.yaml customData 维度的 splitByString 分隔符保持一致
const customKeyDelimiter = "|-|"

type Config struct {
	Server struct {
		Port int
	}
	ClickHouse config.ClickHouseConfig
}

var handler *Handler
var modelLoader *model.Loader

func Init(cfg *Config) error {
	chClient, err := sql.NewClient(&cfg.ClickHouse)
	if err != nil {
		return err
	}
	modelLoader = model.NewLoader(model.InternalFS)
	if _, err = modelLoader.LoadAll(); err != nil {
		log.Printf("加载模型失败: %v", err)
	}
	handler = NewHandler(modelLoader, chClient)
	return nil
}

// Load 执行 cube 查询，queryJSON 与 /load?query=... 接口的 JSON 格式相同
func Load(ctx context.Context, queryJSON string) (*QueryResponse, error) {
	if handler == nil {
		return nil, fmt.Errorf("go-cube 未初始化，请先调用 Init")
	}
	var req QueryRequest
	if err := json.Unmarshal([]byte(queryJSON), &req); err != nil {
		return nil, err
	}
	return handler.load(ctx, &req)
}

func RegisterHandler() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("/load", handler.HandleLoad)
	mux.HandleFunc("/health", handler.HealthCheck)
	return mux
}

type Handler struct {
	modelLoader *model.Loader
	chClient    *sql.Client
}

func NewHandler(modelLoader *model.Loader, chClient *sql.Client) *Handler {
	return &Handler{modelLoader: modelLoader, chClient: chClient}
}

func (h *Handler) HandleLoad(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 30*time.Second)
	defer cancel()

	var body []byte
	if r.Method == http.MethodPost {
		body, _ = io.ReadAll(r.Body)
	} else {
		body = []byte(r.URL.Query().Get("query"))
	}

	var req QueryRequest
	if err := json.Unmarshal(body, &req); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	resp, err := h.load(ctx, &req)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(resp)
}

func (h *Handler) load(ctx context.Context, req *QueryRequest) (*QueryResponse, error) {
	if err := validateQuery(req); err != nil {
		return nil, err
	}

	modelName := ""
	if len(req.Dimensions) > 0 {
		modelName = extractModelName(req.Dimensions[0])
	} else if len(req.Measures) > 0 {
		modelName = extractModelName(req.Measures[0])
	} else if len(req.Filters) > 0 {
		modelName = extractModelName(req.Filters[0].Member)
	}
	if modelName == "" {
		return nil, fmt.Errorf("无法从查询中确定模型")
	}

	m, err := h.modelLoader.Load(modelName)
	if err != nil {
		return nil, err
	}

	// 构建编译上下文：从 Custom-Key 请求头中获取自定义参数名
	compileContext := map[string]string{}
	if customKey := r.Header.Get("Custom-Key"); customKey != "" {
		// 验证 Custom-Key 只含字母、数字、下划线、连字符，防止 SQL 注入
		if !customKeyPattern.MatchString(customKey) {
			h.writeError(w, http.StatusBadRequest, "invalid_custom_key", "Custom-Key header contains invalid characters")
			return
		}
		// Custom-Key 头以 - 分隔参数名，SQL 模板使用 customKeyDelimiter 作为分隔符
		compileContext["custom-key"] = strings.ReplaceAll(customKey, "-", customKeyDelimiter)
	}

	// 构建SQL
	query, params, err := BuildQuery(&queryReq, m, compileContext)
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

func extractModelName(field string) string {
	for i, ch := range field {
		if ch == '.' {
			return field[:i]
		}
	}
	return field
}

func (h *Handler) HealthCheck(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()
	if err := h.chClient.Ping(ctx); err != nil {
		http.Error(w, err.Error(), http.StatusServiceUnavailable)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "ok"})
}
