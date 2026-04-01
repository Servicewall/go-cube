package api

import (
	"net/http"
	"time"

	"github.com/Servicewall/go-cube/config"
	"github.com/Servicewall/go-cube/model"
	"github.com/Servicewall/go-cube/sql"
)

var defaultHandler *Handler

// Init initializes the global Handler with the given ClickHouse connection parameters.
// An optional queryTimeout can be provided; defaults to 30s if zero or omitted.
func Init(hosts []string, database, username, password string, queryTimeout ...time.Duration) error {
	cfg := &config.ClickHouseConfig{
		Hosts:    hosts,
		Database: database,
		Username: username,
		Password: password,
	}
	qt := 30 * time.Second
	if len(queryTimeout) > 0 && queryTimeout[0] > 0 {
		qt = queryTimeout[0]
	}
	chClient, err := sql.NewClient(cfg)
	if err != nil {
		return err
	}
	h := NewHandler(model.NewLoader(model.InternalFS), chClient)
	h.queryTimeout = qt
	defaultHandler = h
	return nil
}

// HTTPHandler 返回全局 Handler 作为 http.Handler，供注册到外部路由器使用。
func HTTPHandler() http.Handler {
	if defaultHandler == nil {
		panic("go-cube: call Init before HTTPHandler")
	}
	return http.HandlerFunc(defaultHandler.HandleLoad)
}
