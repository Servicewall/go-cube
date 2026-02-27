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
var chClient *sql.Client

func Init(cfg *Config) error {
	chClient, err := sql.NewClient(&cfg.ClickHouse)
	if err != nil {
		return err
	}

	modelLoader = model.NewLoader(model.InternalFS)
	if _, err = modelLoader.LoadAll(); err != nil {
		log.Printf("Warning: load models: %v", err)
	}

	handler = NewHandler(modelLoader, chClient)
	return nil
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
	return &Handler{
		modelLoader: modelLoader,
		chClient:    chClient,
	}
}

func (h *Handler) HandleLoad(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 30*time.Second)
	defer cancel()

	// 解析查询：GET 从 ?query= 读取，POST 从 body 读取，格式相同
	var body []byte
	if r.Method == http.MethodPost {
		var err error
		body, err = io.ReadAll(r.Body)
		if err != nil {
			h.writeError(w, http.StatusBadRequest, "body_read_failed", fmt.Sprintf("Failed to read request body: %v", err))
			return
		}
		defer r.Body.Close()
	} else {
		body = []byte(r.URL.Query().Get("query"))
	}
	if len(body) == 0 {
		h.writeError(w, http.StatusBadRequest, "query_required", "Query is required")
		return
	}

	var queryReq QueryRequest
	if err := json.Unmarshal(body, &queryReq); err != nil {
		h.writeError(w, http.StatusBadRequest, "invalid_query_format", fmt.Sprintf("Invalid query format: %v", err))
		return
	}

	// 验证查询
	if err := validateQuery(&queryReq); err != nil {
		h.writeError(w, http.StatusBadRequest, "invalid_query", fmt.Sprintf("Invalid query: %v", err))
		return
	}

	// 获取模型（从 dimensions、measures 或 filters 中提取）
	modelName := ""
	if len(queryReq.Dimensions) > 0 {
		modelName = extractModelName(queryReq.Dimensions[0])
	} else if len(queryReq.Measures) > 0 {
		modelName = extractModelName(queryReq.Measures[0])
	} else if len(queryReq.Filters) > 0 {
		// 从 filters 中提取模型名
		modelName = extractModelName(queryReq.Filters[0].Member)
	}

	if modelName == "" {
		h.writeError(w, http.StatusBadRequest, "model_not_determined", "Cannot determine model from query")
		return
	}

	// 加载模型
	m, err := h.modelLoader.Load(modelName)
	if err != nil {
		h.writeError(w, http.StatusNotFound, "model_not_found", fmt.Sprintf("Model '%s' not found: %v", modelName, err))
		return
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
		h.writeError(w, http.StatusBadRequest, "query_build_failed", fmt.Sprintf("Failed to build query: %v", err))
		return
	}

	// 打印生成的SQL（调试用）
	log.Printf("Generated SQL: %s", query)
	log.Printf("Params: %v", params)

	// 执行查询
	data, err := h.chClient.Query(ctx, query, params...)
	if err != nil {
		h.writeError(w, http.StatusInternalServerError, "query_execution_failed", fmt.Sprintf("Query execution failed: %v", err))
		return
	}

	// 构建响应
	response := QueryResponse{
		QueryType: "regularQuery",
		Results: []QueryResult{
			{
				Query: queryReq,
				Data:  data,
			},
		},
	}

	// 返回JSON响应
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(response); err != nil {
		http.Error(w, fmt.Sprintf("encode response: %v", err), http.StatusInternalServerError)
		return
	}
}

func extractModelName(field string) string {
	// 简化：假设字段名格式为 "ModelName.fieldName"
	// 例如: "AccessView.id" -> "AccessView"
	for i, ch := range field {
		if ch == '.' {
			return field[:i]
		}
	}
	return field
}

func (h *Handler) writeError(w http.ResponseWriter, status int, errorType, message string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	json.NewEncoder(w).Encode(map[string]interface{}{
		"error":   errorType,
		"message": message,
		"status":  status,
	})
}

func (h *Handler) HealthCheck(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
	defer cancel()

	if err := h.chClient.Ping(ctx); err != nil {
		http.Error(w, fmt.Sprintf("clickhouse ping failed: %v", err), http.StatusServiceUnavailable)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"status": "ok",
	})
}
