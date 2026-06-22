package main

import (
	"bufio"
	"crypto/tls"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"time"

	"gopkg.in/yaml.v3"
)

type ClickHouseConfig struct {
	Hosts    []string `yaml:"hosts"`
	Database string   `yaml:"database"`
	Username string   `yaml:"username"`
	Password string   `yaml:"password"`
}

type Config struct {
	ClickHouse ClickHouseConfig `yaml:"clickhouse"`
}

func main() {
	cfg := loadConfig("../../config.yaml")
	baseURL := norm(cfg.ClickHouse.Hosts[0])
	user, pass := cfg.ClickHouse.Username, cfg.ClickHouse.Password

	fmt.Println("=== ClickHouse HTTP Streaming Test ===")
	fmt.Printf("Target: %s | Rows in access_local: %d\n\n", baseURL,
		queryCount(cfg, baseURL, user, pass, "SELECT count() FROM access_local"))

	query := "SELECT id, ts, ip, uid, host, url, method, status, channel, result, ua, req, res FROM access_local WHERE channel = 'web' LIMIT 500000"

	// === STREAMING ===
	fmt.Println("━━━ Streaming (wait_end_of_query=0) ━━━")
	run(cfg, baseURL, user, pass, query, false)

	// === BUFFERED ===
	fmt.Println("\n━━━ Buffered  (wait_end_of_query=1) ━━━")
	run(cfg, baseURL, user, pass, query, true)

	// === AGGREGATION ===
	fmt.Println("\n━━━ Aggregation (GROUP BY — cannot stream) ━━━")
	agg(cfg, baseURL, user, pass,
		"SELECT channel, count() AS cnt FROM access_local GROUP BY channel ORDER BY cnt DESC FORMAT JSONEachRow")

	fmt.Println("\n=== Summary ===")
	fmt.Println("| Mode      | First row | Last row  | Rows  |")
	fmt.Println("|-----------|-----------|-----------|-------|")
	fmt.Println("| Streaming | see above | see above |       |")
	fmt.Println("| Buffered  | see above | see above |       |")
	fmt.Println()
	fmt.Println("Key: Streaming delivers rows AS they are found (边查边传).")
	fmt.Println("     Buffered waits for ALL data before sending (查完再传).")
	fmt.Println("     Aggregation (GROUP BY) MUST collect all data first.")
}

func norm(addr string) string {
	if !strings.HasPrefix(addr, "http") {
		return "http://" + addr
	}
	return addr
}

func run(cfg *Config, baseURL, user, pass, query string, buffered bool) {
	waitVal := "0"
	mode := "stream"
	if buffered {
		waitVal = "1"
		mode = "buffer"
	}
	url := fmt.Sprintf("%s?database=%s&default_format=JSONEachRow&wait_end_of_query=%s&max_block_size=8192",
		baseURL, cfg.ClickHouse.Database, waitVal)

	req, _ := http.NewRequest("POST", url, strings.NewReader(query))
	if user != "" {
		req.Header.Set("X-ClickHouse-User", user)
		req.Header.Set("X-ClickHouse-Key", pass)
	}

	client := &http.Client{
		Timeout: 120 * time.Second,
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
		},
	}

	t0 := time.Now()
	resp, err := client.Do(req)
	if err != nil {
		fmt.Printf("  ERROR: %v\n", err)
		return
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		fmt.Printf("  ERROR: HTTP %d: %s\n", resp.StatusCode, strings.TrimSpace(string(body)))
		return
	}

	firstRowSet := false
	firstAt := time.Duration(0)
	totalRows := 0
	lastReport := time.Now()

	// Also collect sample
	samples := make([]string, 0, 3)

	scanner := bufio.NewScanner(resp.Body)
	scanner.Buffer(make([]byte, 0, 256*1024), 256*1024)

	for scanner.Scan() {
		line := scanner.Text()
		if line == "" {
			continue
		}
		totalRows++
		if !firstRowSet {
			firstAt = time.Since(t0)
			firstRowSet = true
		}

		// Report every 500ms
		if time.Since(lastReport) >= 500*time.Millisecond {
			fmt.Printf("  %s progress: %d rows @ %.2fs\n", mode, totalRows, time.Since(t0).Seconds())
			lastReport = time.Now()
		}

		if totalRows <= 3 {
			samples = append(samples, line)
		}
	}

	totalTime := time.Since(t0)

	if totalRows == 0 {
		fmt.Printf("  %-10s: no results\n", mode)
	} else {
		fmt.Printf("  %-10s: first row @ %.3fs | %d rows total @ %.3fs\n",
			mode, firstAt.Seconds(), totalRows, totalTime.Seconds())
		if len(samples) > 0 {
			fmt.Println("  sample:")
			for i, s := range samples {
				fmt.Printf("    [%d] %s\n", i+1, truncate(s, 160))
			}
		}
	}
}

func agg(cfg *Config, baseURL, user, pass, query string) {
	url := fmt.Sprintf("%s?database=%s&default_format=JSONEachRow", baseURL, cfg.ClickHouse.Database)

	req, _ := http.NewRequest("POST", url, strings.NewReader(query))
	if user != "" {
		req.Header.Set("X-ClickHouse-User", user)
		req.Header.Set("X-ClickHouse-Key", pass)
	}

	client := &http.Client{
		Timeout: 30 * time.Second,
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
		},
	}

	t0 := time.Now()
	resp, _ := client.Do(req)
	defer resp.Body.Close()
	body, _ := io.ReadAll(resp.Body)

	lines := strings.Split(strings.TrimSpace(string(body)), "\n")
	for _, line := range lines {
		if line == "" {
			continue
		}
		var row map[string]interface{}
		if json.Unmarshal([]byte(line), &row) == nil {
			fmt.Printf("  channel=%-16s count=%.0f\n", row["channel"], row["cnt"])
		}
	}
	fmt.Printf("  Total: %.3fs (all data collected before output)\n", time.Since(t0).Seconds())
}

func queryCount(cfg *Config, baseURL, user, pass, sql string) int {
	url := fmt.Sprintf("%s?database=%s&default_format=JSON", baseURL, cfg.ClickHouse.Database)
	req, _ := http.NewRequest("POST", url, strings.NewReader(sql))
	if user != "" {
		req.Header.Set("X-ClickHouse-User", user)
		req.Header.Set("X-ClickHouse-Key", pass)
	}
	client := &http.Client{Timeout: 30 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return -1
	}
	defer resp.Body.Close()
	var result struct{ Data []map[string]interface{} }
	json.NewDecoder(resp.Body).Decode(&result)
	if len(result.Data) > 0 {
		for _, v := range result.Data[0] {
			switch n := v.(type) {
			case float64:
				return int(n)
			case uint64:
				return int(n)
			}
		}
	}
	return -1
}

func loadConfig(path string) *Config {
	data, _ := os.ReadFile(path)
	var cfg Config
	yaml.Unmarshal(data, &cfg)
	return &cfg
}

func truncate(s string, n int) string {
	if len(s) <= n {
		return s
	}
	return s[:n] + "..."
}
