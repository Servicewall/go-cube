package api

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"github.com/Servicewall/go-cube/config"
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
	if len(queryTimeout) > 0 && queryTimeout[0] > 0 {
		cfg.QueryTimeout = queryTimeout[0]
	}
	h, err := New(cfg)
	if err != nil {
		return err
	}
	defaultHandler = h
	return nil
}

// Load executes a query using the global Handler. query is a JSON string.
func Load(ctx context.Context, query string) (*QueryResponse, error) {
	if defaultHandler == nil {
		return nil, fmt.Errorf("go-cube: call Init before Load")
	}
	req, err := parseQueryRequest([]byte(query))
	if err != nil {
		return nil, err
	}
	return defaultHandler.Query(ctx, req)
}

// HTTPHandler returns the global Handler as an http.Handler.
func HTTPHandler() http.Handler {
	if defaultHandler == nil {
		panic("go-cube: call Init before HTTPHandler")
	}
	return http.HandlerFunc(defaultHandler.HandleLoad)
}
