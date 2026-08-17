//go:build integration

package api

import (
	"context"
	"net/http"
	"testing"
	"time"

	"github.com/Servicewall/go-cube/config"
	"github.com/Servicewall/go-cube/model"
	"github.com/Servicewall/go-cube/sql"
)

// 用于集成调试【创建离线溯源】功能
// go test ./api/ -tags integration -run TestOfflineTrace_Integration -v -count=1
func TestOfflineTrace_Integration(t *testing.T) {
	// ClickHouse 连接信息
	chHost := "127.0.0.1:8123"
	chDatabase := "default"
	chUsername := "default"
	chPassword := ""

	// 任务参数
	taskID := "test-task-001"

	// 查询 JSON（基于 AccessView）
	queryJSON := []byte(`{
		"dimensions": ["AccessView.id", "AccessView.ts", "AccessView.ip"],
		"filters": [
			{"member": "AccessView.ip", "operator": "equals", "values": ["127.0.0.1"]}
		],
		"timeDimensions": [
			{"dimension": "AccessView.ts", "dateRange": ["today"]}
		],
		"limit": 10
	}`)

	// 初始化 ClickHouse client
	chClient, err := sql.NewClient(&config.ClickHouseConfig{
		Hosts:        []string{chHost},
		Database:     chDatabase,
		Username:     chUsername,
		Password:     chPassword,
		QueryTimeout: 30 * time.Second,
	})
	if err != nil {
		t.Fatalf("create clickhouse client: %v", err)
	}

	// 初始化 handler
	defaultHandler = &Handler{
		modelLoader:  model.NewLoader(model.InternalFS),
		chClient:     chClient,
		queryTimeout: 30 * time.Second,
	}

	ctx := context.Background()
	err = OfflineTrace(ctx, taskID, http.Header{"X-Sw-Org": {"test-org"}}, queryJSON)
	if err != nil {
		t.Fatalf("OfflineTrace failed: %v", err)
	}

	t.Log("OfflineTrace executed successfully")
}
