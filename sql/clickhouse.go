package sql

import (
	"bufio"
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
	url  string
	user string
	key  string
	http *http.Client
}

func NewClient(cfg *config.ClickHouseConfig) (*Client, error) {
	addr := cfg.Hosts[0]
	if !strings.HasPrefix(addr, "http") {
		addr = "http://" + addr
	}
	queryTimeout := cfg.QueryTimeout
	if queryTimeout == 0 {
		queryTimeout = 60 * time.Second
	}
	return &Client{
		url:  addr + "?default_format=JSON&database=" + cfg.Database,
		user: cfg.Username,
		key:  cfg.Password,
		http: &http.Client{Timeout: queryTimeout},
	}, nil
}

func (c *Client) urlFor(host string, stream bool) string {
	u := c.url
	if stream {
		u = strings.Replace(u, "default_format=JSON", "default_format=JSONEachRow", 1)
	}
	if host != "" {
		if !strings.Contains(host, ":") {
			host = host + ":8123"
		}
		u = "http://" + host + u[strings.Index(u, "?"):]
	}
	return u
}

// doRequest 发送 ClickHouse HTTP 请求，处理认证和错误检查。
func (c *Client) doRequest(ctx context.Context, host, body string, stream bool) (*http.Response, error) {
	req, err := http.NewRequestWithContext(ctx, "POST", c.urlFor(host, stream), strings.NewReader(body))
	if err != nil {
		return nil, fmt.Errorf("create request: %w", err)
	}
	if c.user != "" {
		req.Header.Set("X-ClickHouse-User", c.user)
		req.Header.Set("X-ClickHouse-Key", c.key)
	}
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, err
	}
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		resp.Body.Close()
		return nil, fmt.Errorf("clickhouse error (HTTP %d): %s", resp.StatusCode, strings.TrimSpace(string(body)))
	}
	return resp, nil
}

func (c *Client) Query(ctx context.Context, host, query string) ([]map[string]interface{}, error) {
	resp, err := c.doRequest(ctx, host, query, false)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	var res struct{ Data []map[string]interface{} }
	return res.Data, json.NewDecoder(resp.Body).Decode(&res)
}

func (c *Client) Ping(ctx context.Context) error {
	_, err := c.Query(ctx, "", "SELECT 1")
	return err
}

func (c *Client) Exec(ctx context.Context, host, query string) error {
	resp, err := c.doRequest(ctx, host, query, false)
	if err != nil {
		return err
	}
	resp.Body.Close()
	return nil
}

// QueryStream 使用 JSONEachRow 格式执行流式查询，每读出一行即回调 fn。
func (c *Client) QueryStream(ctx context.Context, host, query string, fn func(row map[string]interface{}) error) (int, error) {
	resp, err := c.doRequest(ctx, host, query, true)
	if err != nil {
		return 0, err
	}
	defer resp.Body.Close()
	scanner := bufio.NewScanner(resp.Body)
	scanner.Buffer(make([]byte, 0, 256*1024), 1*1024*1024)
	count := 0
	for scanner.Scan() {
		line := scanner.Text()
		if line == "" {
			continue
		}
		var row map[string]interface{}
		if err := json.Unmarshal([]byte(line), &row); err != nil {
			return count, fmt.Errorf("ndjson: %w", err)
		}
		count++
		if err := fn(row); err != nil {
			return count, err
		}
	}
	return count, scanner.Err()
}
