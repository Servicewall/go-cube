package sql

import (
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/Servicewall/go-cube/config"
)

type Client struct {
	url          string
	user         string
	key          string
	http         *http.Client
	queryTimeout time.Duration
}

func NewClient(cfg *config.ClickHouseConfig) (*Client, error) {
	addr := cfg.Hosts[0]
	if !strings.HasPrefix(addr, "http") {
		addr = "http://" + addr
	}
	queryTimeout := cfg.QueryTimeout
	if queryTimeout == 0 {
		queryTimeout = 30 * time.Second
	}
	return &Client{
		url:          addr + "?default_format=JSON" + "&max_bytes_before_external_group_by=8000000000" + "&database=" + cfg.Database,
		user:         cfg.Username,
		key:          cfg.Password,
		http:         &http.Client{Timeout: queryTimeout},
		queryTimeout: queryTimeout,
	}, nil
}

// Query 执行 SQL。host 为空时使用默认地址；非空时替换目标节点，
// host 可为纯 IP（默认追加 :8123）或 IP:port 格式。
func (c *Client) Query(ctx context.Context, host, query string, args ...interface{}) ([]map[string]interface{}, error) {
	targetURL := c.url
	if host != "" {
		if !strings.Contains(host, ":") {
			host = host + ":8123"
		}
		targetURL = "http://" + host + c.url[strings.Index(c.url, "?"):]
	}
	for _, arg := range args {
		val := fmt.Sprintf("%v", arg)
		if s, ok := arg.(string); ok {
			val = "'" + strings.ReplaceAll(s, "'", "''") + "'"
		}
		query = strings.Replace(query, "?", val, 1)
	}
	req, _ := http.NewRequestWithContext(ctx, "POST", targetURL, strings.NewReader(query))
	if c.user != "" {
		req.Header.Set("X-ClickHouse-User", c.user)
		req.Header.Set("X-ClickHouse-Key", c.key)
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return nil, fmt.Errorf("clickhouse error (HTTP %d): %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}
	var res struct{ Data []map[string]interface{} }
	return res.Data, json.NewDecoder(resp.Body).Decode(&res)
}

func (c *Client) Ping(ctx context.Context) error {
	_, err := c.Query(ctx, "", "SELECT 1")
	return err
}
