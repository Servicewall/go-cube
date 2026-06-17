package api

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/Servicewall/go-cube/config"
	"github.com/Servicewall/go-cube/model"
	"github.com/Servicewall/go-cube/sql"
)

var defaultHandler *Handler

// Init initializes the global Handler with the given ClickHouse connection parameters.
// An optional queryTimeout can be provided; defaults to 60s if zero or omitted.
func Init(hosts []string, database, username, password string, queryTimeout ...time.Duration) error {
	cfg := &config.ClickHouseConfig{
		Hosts:    hosts,
		Database: database,
		Username: username,
		Password: password,
	}
	qt := 60 * time.Second
	if len(queryTimeout) > 0 && queryTimeout[0] > 0 {
		qt = queryTimeout[0]
	}
	cfg.QueryTimeout = qt
	chClient, err := sql.NewClient(cfg)
	if err != nil {
		return err
	}
	loader, err := model.NewLoaderFromFS(model.InternalFS)
	if err != nil {
		return fmt.Errorf("load embedded models: %w", err)
	}
	h := NewHandler(loader, chClient)
	h.queryTimeout = qt
	defaultHandler = h
	return nil
}

// PutCube parses yamlData and hot-loads it into the global model cache.
func PutCube(name string, yamlData []byte) error {
	if defaultHandler == nil {
		panic("go-cube: call Init before PutCube")
	}
	return defaultHandler.modelLoader.PutCube(name, yamlData)
}

// HTTPHandler 返回全局 Handler 作为 http.Handler，供注册到外部路由器使用。
func HTTPHandler() http.Handler {
	if defaultHandler == nil {
		panic("go-cube: call Init before HTTPHandler")
	}
	return http.HandlerFunc(defaultHandler.HandleLoad)
}

// OfflineTrace 离线溯源：根据 queryJSON 生成数据 SQL，插入 access_offline_local 表。
//   - taskID:         任务标识
//   - org:            组织标识（注入 segment 变量）
//   - mask:           数据脱敏开关
//   - clickhouseNode: 目标 ClickHouse 节点地址（空则使用 Init 配置的默认地址）
//   - apiExact:       精确匹配的 API 列表（逗号分隔）
//   - apiRegex:       正则匹配的 API 列表（逗号分隔）
//   - queryJSON:      标准 cube query 的 JSON 字节（必须基于 AccessView）
func OfflineTrace(ctx context.Context, taskID, org string, mask bool, clickhouseNode, apiExact, apiRegex string, queryJSON []byte) error {
	if defaultHandler == nil {
		return fmt.Errorf("go-cube: call Init before OfflineTrace")
	}
	h := defaultHandler

	req, err := parseQueryRequest(queryJSON)
	if err != nil {
		return fmt.Errorf("parse query: %w", err)
	}

	req.Mask = mask
	req.Vars = map[string][]string{
		"org":       {org},
		"api_exact": strings.Split(apiExact, ","),
		"api_regex": strings.Split(apiRegex, ","),
	}

	if err := validateQuery(req); err != nil {
		return fmt.Errorf("validate query: %w", err)
	}

	m, err := h.modelLoader.Load("AccessView")
	if err != nil {
		return fmt.Errorf("load model: %w", err)
	}

	// 确保 CubeSQL 中包含 id 和 ts 列（用于数据源 SQL 的关联条件）
	ensureDim := func(dim string) {
		for _, d := range req.Dimensions {
			if d == dim {
				return
			}
		}
		req.Dimensions = append(req.Dimensions, dim)
	}
	ensureDim("AccessView.id")
	ensureDim("AccessView.ts")

	dataSQL, err := buildQuery(req, m)
	if err != nil {
		return fmt.Errorf("build query: %w", err)
	}

	// 获取 access 表列名
	colRows, err := h.chClient.Query(ctx, clickhouseNode,
		"SELECT name FROM system.columns WHERE database = currentDatabase() AND table = 'access' ORDER BY position")
	if err != nil {
		return fmt.Errorf("fetch columns: %w", err)
	}
	var cols []string
	for _, row := range colRows {
		if name, ok := row["name"].(string); ok {
			cols = append(cols, name)
		}
	}
	if len(cols) == 0 {
		return fmt.Errorf("no columns found for access table")
	}

	sourceColumns := strings.Join(cols, ",")
	colStr := "task_id,task_ts," + sourceColumns
	taskIDEscaped := strings.ReplaceAll(taskID, "'", "''")

	// 数据源 SQL：从 access 全表中根据 CubeSQL 结果过滤
	cubeSQL := dataSQL
	insertDataSQL := fmt.Sprintf(
		`SELECT '%s' AS task_id, now() AS task_ts, %s FROM access WHERE `+
			`ts BETWEEN (SELECT min("AccessView.ts") FROM (%s)) AND (SELECT max("AccessView.ts") FROM (%s)) `+
			`AND id || ts GLOBAL IN (SELECT "AccessView.id" || "AccessView.ts" FROM (%s))`,
		taskIDEscaped, sourceColumns, cubeSQL, cubeSQL, cubeSQL)

	insertSQL := "INSERT INTO access_offline_local (" + colStr + ") " + insertDataSQL

	log.Printf("OfflineTrace SQL: %s", insertSQL)

	return h.chClient.Exec(ctx, clickhouseNode, insertSQL)
}
