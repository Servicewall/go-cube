package api

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"time"

	"github.com/Servicewall/go-cube/config"
	"github.com/Servicewall/go-cube/model"
	"github.com/Servicewall/go-cube/sql"
)

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
		log.Printf("Warning: load models: %v", err)
	}

	handler = NewHandler(modelLoader, chClient)
	return nil
}

// Load executes a cube query and returns the result.
// queryJSON 与 /load?query=... 接口的 JSON 格式相同。
// Init must be called before using this function.
func Load(ctx context.Context, queryJSON string) (*QueryResponse, error) {
	if handler == nil {
		return nil, fmt.Errorf("go-cube not initialized: call Init first")
	}
	var req QueryRequest
	if err := json.Unmarshal([]byte(queryJSON), &req); err != nil {
		return nil, fmt.Errorf("invalid query JSON: %w", err)
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

	response, err := h.load(ctx, &queryReq)
	if err != nil {
		var cubeErr *QueryError
		if errors.As(err, &cubeErr) {
			h.writeError(w, cubeErr.Status, cubeErr.Type, cubeErr.Message)
		} else {
			h.writeError(w, http.StatusInternalServerError, "internal_error", err.Error())
		}
		return
	}

	// 返回JSON响应
	w.Header().Set("Content-Type", "application/json")
	if err := json.NewEncoder(w).Encode(response); err != nil {
		http.Error(w, fmt.Sprintf("encode response: %v", err), http.StatusInternalServerError)
		return
	}
}

// QueryError represents a structured query error with an HTTP status code.
// It is returned by load and can be inspected by HTTP handlers to map errors
// to appropriate HTTP responses via errors.As.
type QueryError struct {
	// Status is the suggested HTTP status code for this error.
	Status int
	// Type is a machine-readable error identifier.
	Type string
	// Message is a human-readable description of the error.
	Message string
}

func (e *QueryError) Error() string {
	return fmt.Sprintf("%s: %s", e.Type, e.Message)
}

func (h *Handler) load(ctx context.Context, req *QueryRequest) (*QueryResponse, error) {
	// 验证查询
	if err := validateQuery(req); err != nil {
		return nil, &QueryError{http.StatusBadRequest, "invalid_query", fmt.Sprintf("Invalid query: %v", err)}
	}

	// 获取模型（从 dimensions、measures 或 filters 中提取）
	modelName := ""
	if len(req.Dimensions) > 0 {
		modelName = extractModelName(req.Dimensions[0])
	} else if len(req.Measures) > 0 {
		modelName = extractModelName(req.Measures[0])
	} else if len(req.Filters) > 0 {
		// 从 filters 中提取模型名
		modelName = extractModelName(req.Filters[0].Member)
	}

	if modelName == "" {
		return nil, &QueryError{http.StatusBadRequest, "model_not_determined", "Cannot determine model from query"}
	}

	// 加载模型
	m, err := h.modelLoader.Load(modelName)
	if err != nil {
		return nil, &QueryError{http.StatusNotFound, "model_not_found", fmt.Sprintf("Model '%s' not found: %v", modelName, err)}
	}

	// 构建SQL
	query, params, err := BuildQuery(req, m)
	if err != nil {
		return nil, &QueryError{http.StatusBadRequest, "query_build_failed", fmt.Sprintf("Failed to build query: %v", err)}
	}

	// 打印生成的SQL（调试用）
	log.Printf("Generated SQL: %s", query)
	log.Printf("Params: %v", params)

	// 执行查询
	data, err := h.chClient.Query(ctx, query, params...)
	if err != nil {
		return nil, &QueryError{http.StatusInternalServerError, "query_execution_failed", fmt.Sprintf("Query execution failed: %v", err)}
	}

	return &QueryResponse{
		QueryType: "regularQuery",
		Results: []QueryResult{
			{
				Query: *req,
				Data:  data,
			},
		},
	}, nil
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
