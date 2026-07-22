package api

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/Servicewall/go-cube/model"
	"github.com/Servicewall/go-cube/sql"
)

// PrintSQL 控制是否打印生成的 SQL 语句，默认关闭。
var PrintSQL bool

type Handler struct {
	modelLoader  *model.Loader
	chClient     *sql.Client
	queryTimeout time.Duration
}

// NewHandler 使用外部提供的 modelLoader 和 chClient 创建 Handler，适合自定义模型或测试场景。
func NewHandler(modelLoader *model.Loader, chClient *sql.Client) *Handler {
	return &Handler{modelLoader: modelLoader, chClient: chClient}
}

func (h *Handler) query(ctx context.Context, host string, req *QueryRequest) (*QueryResponse, error) {
	m, query, err := h.setupQuery(req)
	if err != nil {
		return nil, err
	}
	var start time.Time
	if PrintSQL {
		start = time.Now()
	}
	data, err := h.chClient.Query(ctx, host, query)
	if PrintSQL {
		log.Printf("SQL execution time: %s | query: %s", time.Since(start), query)
	}
	if err != nil {
		log.Printf("SQL error: %v | query: %s", err, query)
		return nil, err
	}

	for _, td := range req.TimeDimensions {
		if td.Granularity == "" {
			continue
		}
		granKey := td.Dimension + "." + td.Granularity
		for _, row := range data {
			if v, ok := row[granKey]; ok {
				row[td.Dimension] = v
			}
		}
	}

	return &QueryResponse{
		QueryType: "regularQuery",
		Results:   []QueryResult{{Query: *req, Data: data, Annotation: buildAnnotation(req, m)}},
	}, nil
}

// setupQuery 验证请求、加载模型、构建 SQL，query 和 handleLoadStream 共用。
func (h *Handler) setupQuery(req *QueryRequest) (*model.Cube, string, error) {
	if err := validateQuery(req); err != nil {
		return nil, "", err
	}
	modelName := extractModelNameFromRequest(req)
	if modelName == "" {
		return nil, "", fmt.Errorf("无法从查询中确定模型")
	}
	m, err := h.modelLoader.Load(modelName)
	if err != nil {
		return nil, "", err
	}
	if m.Name == "AccessView" {
		if targets, ok := req.Vars["search_target"]; ok && len(targets) > 0 && targets[0] == "offline" {
			m = m.Clone()
			m.SQLTable = "default.access_offline_local"
		}
	}
	query, err := buildQuery(req, m)
	if err != nil {
		return nil, "", err
	}
	return m, query, nil
}

// HandleLoad 是 HTTP 入口，供注册到路由器使用。
// 从 request header 读取所有业务变量注入查询：
//   - X-Sw-Node:      目标 ClickHouse 节点地址
//   - X-Auth-Mask:    数据脱敏开关
//   - X-Sw-Org:       org 模板变量
//   - X-Sw-Api-Exact: api_exact 模板变量（逗号分隔多值）
//   - X-Sw-Api-Regex: api_regex 模板变量（逗号分隔多值）
//   - X-Sw-Api-Filter-Min-Count:      api_filter_min_count 数值模板变量
//   - X-Sw-Api-Lifecycle-Active-Days: api_lifecycle_active_days 数值模板变量
//   - X-Sw-Api-Lifecycle-New-Days:    api_lifecycle_new_days 数值模板变量
func (h *Handler) HandleLoad(w http.ResponseWriter, r *http.Request) {
	timeout := h.queryTimeout
	if timeout == 0 {
		timeout = 60 * time.Second
	}
	ctx, cancel := context.WithTimeout(r.Context(), timeout)
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

	req.Mask = r.Header.Get("X-Auth-Mask") == "true"
	// api_exact/api_regex 始终注入，未传时 Split("", ",") 返回 [""]，SQL 中条件短路无影响
	req.Vars = map[string][]any{
		"org":       {r.Header.Get("X-Sw-Org")},
		"api_exact": stringVars(strings.Split(r.Header.Get("X-Sw-Api-Exact"), ",")),
		"api_regex": stringVars(strings.Split(r.Header.Get("X-Sw-Api-Regex"), ",")),
	}
	for key, header := range map[string]string{
		varFilterMinCount:      "X-Sw-Api-Filter-Min-Count",
		varLifecycleActiveDays: "X-Sw-Api-Lifecycle-Active-Days",
		varLifecycleNewDays:    "X-Sw-Api-Lifecycle-New-Days",
	} {
		v := strings.TrimSpace(r.Header.Get(header))
		if v == "" {
			continue
		}
		n, err := strconv.Atoi(v)
		if err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
			return
		}
		req.Vars[key] = []any{n}
	}
	if v := r.Header.Get("Search-Target"); v != "" {
		req.Vars["search_target"] = []any{v}
	}

	if req.Ungrouped && len(req.Measures) == 0 &&
		strings.Contains(r.Header.Get("Accept"), "application/x-ndjson") {
		h.handleLoadStream(ctx, w, r.Header.Get("X-Sw-Node"), req)
		return
	}

	resp, err := h.query(ctx, r.Header.Get("X-Sw-Node"), req)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}
	writeJSON(w, http.StatusOK, resp)
}

func stringVars(vals []string) []any {
	out := make([]any, len(vals))
	for i, v := range vals {
		out[i] = v
	}
	return out
}

// handleLoadStream 流式处理 ungrouped 查询，使用 NDJSON 逐行返回。
func (h *Handler) handleLoadStream(ctx context.Context, w http.ResponseWriter, node string, req *QueryRequest) {
	_, query, err := h.setupQuery(req)
	if err != nil {
		writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		return
	}

	type granPatch struct{ dim, key string }
	var patches []granPatch
	for _, td := range req.TimeDimensions {
		if td.Granularity != "" {
			patches = append(patches, granPatch{td.Dimension, td.Dimension + "." + td.Granularity})
		}
	}

	w.Header().Set("Content-Type", "application/x-ndjson")
	w.Header().Set("X-Content-Type-Options", "nosniff")
	flusher, _ := w.(http.Flusher)

	var wrote bool
	_, err = h.chClient.QueryStream(ctx, node, query, func(row map[string]interface{}) error {
		for _, p := range patches {
			if v, ok := row[p.key]; ok {
				row[p.dim] = v
			}
		}
		buf, err := json.Marshal(row)
		if err != nil {
			return err
		}
		if _, err := w.Write(buf); err != nil {
			return err
		}
		if _, err := w.Write([]byte("\n")); err != nil {
			return err
		}
		if flusher != nil {
			flusher.Flush()
		}
		wrote = true
		return ctx.Err()
	})
	if err != nil {
		if !wrote {
			writeJSON(w, http.StatusInternalServerError, map[string]string{"error": err.Error()})
		} else {
			fmt.Fprintf(w, `{"error":%q}`+"\n", err.Error())
		}
	}
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
