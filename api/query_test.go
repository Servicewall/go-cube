package api

import (
	"context"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"

	"github.com/Servicewall/go-cube/model"
)

// testCube builds a minimal Cube fixture for unit tests.
func testCube() *model.Cube {
	return &model.Cube{
		Name:     "AccessView",
		SQLTable: "default.access",
		Dimensions: map[string]model.Dimension{
			"id": {SQL: "id", Type: "string"},
			"ts": {SQL: "ts", Type: "time"},
			"ip": {SQL: "ip", Type: "string"},
		},
		Measures: map[string]model.Measure{
			"count": {SQL: "count()", Type: "number"},
		},
		Segments: map[string]model.Segment{
			"org":   {SQL: "org = '1'"},
			"black": {SQL: "black = 1"},
		},
	}
}

func TestBuildQuery_DimensionsOnly(t *testing.T) {
	req := &QueryRequest{
		Dimensions: []string{"AccessView.id", "AccessView.ts"},
		Limit:      10,
	}

	sql, params, err := BuildQuery(req, testCube())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(params) != 0 {
		t.Errorf("expected no params, got %v", params)
	}

	for _, substr := range []string{`id AS "AccessView.id"`, `ts AS "AccessView.ts"`, "default.access", "LIMIT 10"} {
		if !contains(sql, substr) {
			t.Errorf("expected SQL to contain %q, got: %s", substr, sql)
		}
	}
}

func TestBuildQuery_MeasuresWithGroupBy(t *testing.T) {
	req := &QueryRequest{
		Dimensions: []string{"AccessView.ip"},
		Measures:   []string{"AccessView.count"},
		Limit:      5,
	}

	sql, _, err := BuildQuery(req, testCube())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	for _, substr := range []string{"GROUP BY", "count()", "ip"} {
		if !contains(sql, substr) {
			t.Errorf("expected SQL to contain %q, got: %s", substr, sql)
		}
	}
}

func TestBuildQuery_FilterEquals(t *testing.T) {
	req := &QueryRequest{
		Dimensions: []string{"AccessView.id"},
		Filters: []Filter{
			{Member: "AccessView.ip", Operator: "equals", Values: []interface{}{"1.2.3.4"}},
		},
	}

	sql, params, err := BuildQuery(req, testCube())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !contains(sql, "ip IN (?)") {
		t.Errorf("expected IN clause, got: %s", sql)
	}
	if len(params) != 1 || params[0] != "1.2.3.4" {
		t.Errorf("unexpected params: %v", params)
	}
}

func TestBuildQuery_FilterContains(t *testing.T) {
	req := &QueryRequest{
		Dimensions: []string{"AccessView.id"},
		Filters: []Filter{
			{Member: "AccessView.ip", Operator: "contains", Values: []interface{}{"192"}},
		},
	}

	sql, params, err := BuildQuery(req, testCube())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !contains(sql, "LIKE") {
		t.Errorf("expected LIKE clause, got: %s", sql)
	}
	if len(params) != 1 || params[0] != "%192%" {
		t.Errorf("expected wildcard param, got: %v", params)
	}
}

func TestBuildQuery_FilterSet(t *testing.T) {
	req := &QueryRequest{
		Dimensions: []string{"AccessView.id"},
		Filters: []Filter{
			{Member: "AccessView.ip", Operator: "set"},
		},
	}

	sql, params, err := BuildQuery(req, testCube())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !contains(sql, "notEmpty(ip)") {
		t.Errorf("expected notEmpty(), got: %s", sql)
	}
	if len(params) != 0 {
		t.Errorf("expected no params for 'set' operator, got: %v", params)
	}
}

func TestBuildQuery_OrderBy(t *testing.T) {
	req := &QueryRequest{
		Dimensions: []string{"AccessView.ts"},
		Order:      OrderMap{"AccessView.ts": "desc"},
	}

	sql, _, err := BuildQuery(req, testCube())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !contains(sql, "ORDER BY") || !contains(sql, "DESC") {
		t.Errorf("expected ORDER BY ts DESC, got: %s", sql)
	}
}

func TestBuildQuery_TimeDimensionRange(t *testing.T) {
	req := &QueryRequest{
		Dimensions: []string{"AccessView.ts"},
		TimeDimensions: []TimeDimension{
			{
				Dimension: "AccessView.ts",
				DateRange: DateRange{V: []string{"2024-01-01", "2024-01-31"}},
			},
		},
	}

	sql, params, err := BuildQuery(req, testCube())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !contains(sql, "ts >= ?") || !contains(sql, "ts <= ?") {
		t.Errorf("expected date range WHERE clause, got: %s", sql)
	}
	if len(params) != 2 {
		t.Errorf("expected 2 date params, got: %v", params)
	}
}

func TestBuildQuery_TimeDimensionRelative(t *testing.T) {
	req := &QueryRequest{
		Dimensions: []string{"AccessView.ts"},
		TimeDimensions: []TimeDimension{
			{
				Dimension: "AccessView.ts",
				DateRange: DateRange{V: "from 15 minutes ago to now"},
			},
		},
	}

	sql, params, err := BuildQuery(req, testCube())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !contains(sql, "now()") {
		t.Errorf("expected ClickHouse now() expr, got: %s", sql)
	}
	if len(params) != 0 {
		t.Errorf("expected no bind params for relative time, got: %v", params)
	}
}

func TestBuildQuery_TimeDimensionThisMonth(t *testing.T) {
	req := &QueryRequest{
		Dimensions: []string{"AccessView.ts"},
		TimeDimensions: []TimeDimension{
			{
				Dimension: "AccessView.ts",
				DateRange: DateRange{V: "this month"},
			},
		},
	}

	sql, params, err := BuildQuery(req, testCube())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !contains(sql, "toStartOfMonth(now())") {
		t.Errorf("expected toStartOfMonth(now()) in SQL, got: %s", sql)
	}
	if len(params) != 0 {
		t.Errorf("expected no bind params, got: %v", params)
	}
}

func TestBuildQuery_TimeDimensionLastMonth(t *testing.T) {
	req := &QueryRequest{
		Dimensions: []string{"AccessView.ts"},
		TimeDimensions: []TimeDimension{
			{
				Dimension: "AccessView.ts",
				DateRange: DateRange{V: "last month"},
			},
		},
	}

	sql, params, err := BuildQuery(req, testCube())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !contains(sql, "toStartOfMonth(now() - INTERVAL 1 MONTH)") {
		t.Errorf("expected toStartOfMonth(now() - INTERVAL 1 MONTH) in SQL, got: %s", sql)
	}
	if !contains(sql, ">=") || !contains(sql, "<=") {
		t.Errorf("expected >= and <= for range, got: %s", sql)
	}
	if len(params) != 0 {
		t.Errorf("expected no bind params, got: %v", params)
	}
}

func TestBuildQuery_Segments(t *testing.T) {
	req := &QueryRequest{
		Dimensions: []string{"AccessView.id"},
		Segments:   []string{"AccessView.org", "AccessView.black"},
	}

	sql, params, err := BuildQuery(req, testCube())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(params) != 0 {
		t.Errorf("expected no params, got %v", params)
	}
	if !contains(sql, "org = '1'") {
		t.Errorf("expected org segment SQL, got: %s", sql)
	}
	if !contains(sql, "black = 1") {
		t.Errorf("expected black segment SQL, got: %s", sql)
	}
}

func TestBuildQuery_UnknownFilterSkipped(t *testing.T) {
	// 字段不在模型中，应直接跳过，不拼入 SQL
	req := &QueryRequest{
		Dimensions: []string{"AccessView.id"},
		Filters: []Filter{
			{Member: "AccessView.notExist", Operator: "equals", Values: []interface{}{"x"}},
		},
	}

	sql, params, err := BuildQuery(req, testCube())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if contains(sql, "notExist") || contains(sql, "AccessView.notExist") {
		t.Errorf("unknown filter field should not appear in SQL, got: %s", sql)
	}
	if contains(sql, "WHERE") {
		t.Errorf("no WHERE clause expected when all filters skipped, got: %s", sql)
	}
	if len(params) != 0 {
		t.Errorf("expected no params, got %v", params)
	}
}

func TestBuildQuery_FilterTagUsesSchemaSQL(t *testing.T) {
	// riskFilterTag 是 array 类型，单值用 has()
	cube := testCube()
	cube.Dimensions["riskFilterTag"] = model.Dimension{
		SQL:  "arrayConcat(req_risk, res_risk)",
		Type: "array",
	}
	req := &QueryRequest{
		Dimensions: []string{"AccessView.id"},
		Filters: []Filter{
			{Member: "AccessView.riskFilterTag", Operator: "equals", Values: []interface{}{"SQL注入"}},
		},
	}

	sql, params, err := BuildQuery(req, cube)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !contains(sql, "has(arrayConcat(req_risk, res_risk), ?)") {
		t.Errorf("expected has() for array equals, got: %s", sql)
	}
	if len(params) != 1 || params[0] != "SQL注入" {
		t.Errorf("unexpected params: %v", params)
	}
}

func TestBuildQuery_FilterTagMultiValue(t *testing.T) {
	// equals 多值 -> hasAll(arr, [?,?])
	cube := testCube()
	cube.Dimensions["riskFilterTag"] = model.Dimension{
		SQL:  "arrayConcat(req_risk, res_risk)",
		Type: "array",
	}
	req := &QueryRequest{
		Dimensions: []string{"AccessView.id"},
		Filters: []Filter{
			{Member: "AccessView.riskFilterTag", Operator: "equals", Values: []interface{}{"SQL注入", "XSS"}},
		},
	}

	sql, params, err := BuildQuery(req, cube)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !contains(sql, "hasAll(arrayConcat(req_risk, res_risk), [?,?])") {
		t.Errorf("expected hasAll() for array equals multi-value, got: %s", sql)
	}
	if len(params) != 2 {
		t.Errorf("expected 2 params, got: %v", params)
	}
}

func TestBuildQuery_FilterTagContains(t *testing.T) {
	// contains 多值 -> hasAny(arr, [?,?])
	cube := testCube()
	cube.Dimensions["riskFilterTag"] = model.Dimension{
		SQL:  "arrayConcat(req_risk, res_risk)",
		Type: "array",
	}
	req := &QueryRequest{
		Dimensions: []string{"AccessView.id"},
		Filters: []Filter{
			{Member: "AccessView.riskFilterTag", Operator: "contains", Values: []interface{}{"SQL注入", "XSS"}},
		},
	}

	sql, params, err := BuildQuery(req, cube)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !contains(sql, "hasAny(arrayConcat(req_risk, res_risk), [?,?])") {
		t.Errorf("expected hasAny() for array contains, got: %s", sql)
	}
	if len(params) != 2 {
		t.Errorf("expected 2 params, got: %v", params)
	}
}

func TestBuildQuery_FilterTagNotEquals(t *testing.T) {
	// notEquals 用 NOT has()
	cube := testCube()
	cube.Dimensions["riskFilterTag"] = model.Dimension{
		SQL:  "arrayConcat(req_risk, res_risk)",
		Type: "array",
	}
	req := &QueryRequest{
		Dimensions: []string{"AccessView.id"},
		Filters: []Filter{
			{Member: "AccessView.riskFilterTag", Operator: "notEquals", Values: []interface{}{"SQL注入"}},
		},
	}

	sql, params, err := BuildQuery(req, cube)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !contains(sql, "NOT has(arrayConcat(req_risk, res_risk), ?)") {
		t.Errorf("expected NOT has() for array notEquals, got: %s", sql)
	}
	if len(params) != 1 {
		t.Errorf("expected 1 param, got: %v", params)
	}
}

func TestBuildQuery_OrFilter(t *testing.T) {
	// OR 复合条件：两个维度 LIKE 查询，用 OR 连接
	req := &QueryRequest{
		Dimensions: []string{"AccessView.id"},
		Filters: []Filter{
			{Or: []Filter{
				{Member: "AccessView.ip", Operator: "contains", Values: []interface{}{"192"}},
				{Member: "AccessView.id", Operator: "contains", Values: []interface{}{"192"}},
			}},
		},
	}

	sql, params, err := BuildQuery(req, testCube())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !contains(sql, "ip LIKE ?") {
		t.Errorf("expected ip LIKE clause in OR, got: %s", sql)
	}
	if !contains(sql, "id LIKE ?") {
		t.Errorf("expected id LIKE clause in OR, got: %s", sql)
	}
	if !contains(sql, " OR ") {
		t.Errorf("expected OR keyword, got: %s", sql)
	}
	// OR 条件应被括号包裹
	if !contains(sql, "(") || !contains(sql, ")") {
		t.Errorf("expected parentheses around OR clause, got: %s", sql)
	}
	if len(params) != 2 {
		t.Errorf("expected 2 params, got: %v", params)
	}
	for _, p := range params {
		if p != "%192%" {
			t.Errorf("expected wildcard param %%192%%, got: %v", p)
		}
	}
}

func TestBuildQuery_OrFilterSkipsUnknown(t *testing.T) {
	// OR 中若某个维度不存在，应跳过，不影响其他子条件
	req := &QueryRequest{
		Dimensions: []string{"AccessView.id"},
		Filters: []Filter{
			{Or: []Filter{
				{Member: "AccessView.ip", Operator: "contains", Values: []interface{}{"test"}},
				{Member: "AccessView.notExist", Operator: "contains", Values: []interface{}{"test"}},
			}},
		},
	}

	sql, params, err := BuildQuery(req, testCube())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if contains(sql, "notExist") {
		t.Errorf("unknown field should not appear in SQL, got: %s", sql)
	}
	// 只有一个有效子条件，不应出现 OR
	if contains(sql, " OR ") {
		t.Errorf("should not have OR when only one valid condition, got: %s", sql)
	}
	if !contains(sql, "ip LIKE ?") {
		t.Errorf("expected ip LIKE clause, got: %s", sql)
	}
	if len(params) != 1 {
		t.Errorf("expected 1 param, got: %v", params)
	}
}

func TestBuildQuery_OrFilterAllUnknown(t *testing.T) {
	// OR 中所有维度都不存在，不应添加任何 WHERE 条件
	req := &QueryRequest{
		Dimensions: []string{"AccessView.id"},
		Filters: []Filter{
			{Or: []Filter{
				{Member: "AccessView.notExist1", Operator: "contains", Values: []interface{}{"x"}},
				{Member: "AccessView.notExist2", Operator: "contains", Values: []interface{}{"x"}},
			}},
		},
	}

	sql, params, err := BuildQuery(req, testCube())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if contains(sql, "WHERE") {
		t.Errorf("no WHERE clause expected when all or-filters skipped, got: %s", sql)
	}
	if len(params) != 0 {
		t.Errorf("expected no params, got %v", params)
	}
}

func TestBuildQuery_OrFilterMutualExclusion(t *testing.T) {
	// or 与普通条件字段不能同时存在，应返回错误
	req := &QueryRequest{
		Dimensions: []string{"AccessView.id"},
		Filters: []Filter{
			{
				Member:   "AccessView.ip",
				Operator: "contains",
				Values:   []interface{}{"192"},
				Or: []Filter{
					{Member: "AccessView.id", Operator: "contains", Values: []interface{}{"192"}},
				},
			},
		},
	}

	_, _, err := BuildQuery(req, testCube())
	if err == nil {
		t.Error("expected error when or and member/operator/values are both set")
	}
}

func TestValidateQuery_Valid(t *testing.T) {
	req := &QueryRequest{Dimensions: []string{"AccessView.id"}}
	if err := validateQuery(req); err != nil {
		t.Errorf("unexpected error for valid query: %v", err)
	}
}

func TestValidateQuery_Empty(t *testing.T) {
	req := &QueryRequest{}
	if err := validateQuery(req); err == nil {
		t.Error("expected error for empty query")
	}
}

func TestValidateQuery_NegativeLimit(t *testing.T) {
	req := &QueryRequest{Dimensions: []string{"AccessView.id"}, Limit: -1}
	if err := validateQuery(req); err == nil {
		t.Error("expected error for negative limit")
	}
}

func TestSplitMemberName(t *testing.T) {
	cases := []struct {
		in         string
		wantCube   string
		wantField  string
		wantSubKey string
	}{
		{"AccessView.id", "AccessView", "id", ""},
		{"AccessView.ts", "AccessView", "ts", ""},
		{"id", "id", "", ""},
		{"AccessView.customData.UserToken", "AccessView", "customData", "UserToken"},
	}
	for _, c := range cases {
		cube, field, subKey := splitMemberName(c.in)
		if cube != c.wantCube || field != c.wantField || subKey != c.wantSubKey {
			t.Errorf("splitMemberName(%q) = (%q, %q, %q), want (%q, %q, %q)",
				c.in, cube, field, subKey, c.wantCube, c.wantField, c.wantSubKey)
		}
	}
}

func TestParseRelativeTimeRange(t *testing.T) {
	cases := []struct {
		input       string
		wantStart   string
		wantEnd     string
		wantIsRange bool
	}{
		{"from 15 minutes ago to now", "now() - INTERVAL 15 MINUTE", "now()", true},
		{"from 1 hour ago to now", "now() - INTERVAL 1 HOUR", "now()", true},
		{"from 7 days ago to now", "now() - INTERVAL 7 DAY", "now()", true},
		{"today", "", "", false},
	}
	for _, c := range cases {
		start, end, isRange := parseRelativeTimeRange(c.input)
		if isRange != c.wantIsRange {
			t.Errorf("parseRelativeTimeRange(%q) isRange=%v, want %v", c.input, isRange, c.wantIsRange)
			continue
		}
		if isRange {
			if start != c.wantStart {
				t.Errorf("parseRelativeTimeRange(%q) start=%q, want %q", c.input, start, c.wantStart)
			}
			if end != c.wantEnd {
				t.Errorf("parseRelativeTimeRange(%q) end=%q, want %q", c.input, end, c.wantEnd)
			}
		}
	}
}

func TestConvertToClickHouseTimeExpr(t *testing.T) {
	cases := []struct{ in, want string }{
		{"now", "now()"},
		{"today", "today()"},
		{"yesterday", "yesterday()"},
		{"15 minutes ago", "now() - INTERVAL 15 MINUTE"},
		{"1 hour ago", "now() - INTERVAL 1 HOUR"},
		{"15 minutes from now", "now() + INTERVAL 15 MINUTE"},
	}
	for _, c := range cases {
		if got := convertToClickHouseTimeExpr(c.in); got != c.want {
			t.Errorf("convertToClickHouseTimeExpr(%q) = %q, want %q", c.in, got, c.want)
		}
	}
}

func TestBuildQuery_CustomDataSubKey(t *testing.T) {
	cube := testCube()
	cube.Dimensions["customData"] = model.Dimension{
		SQL:  "data[indexOf(key, '{key}')]",
		Type: "string",
	}
	req := &QueryRequest{
		Dimensions: []string{"AccessView.customData.UserToken"},
	}

	sql, params, err := BuildQuery(req, cube)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !contains(sql, `data[indexOf(key, 'UserToken')]`) {
		t.Errorf("expected subKey substitution in SQL, got: %s", sql)
	}
	if !contains(sql, `"AccessView.customData.UserToken"`) {
		t.Errorf("expected full alias in SQL, got: %s", sql)
	}
	if len(params) != 0 {
		t.Errorf("expected no params, got %v", params)
	}
}

func TestBuildQuery_CustomDataSubKeyFilter(t *testing.T) {
	cube := testCube()
	cube.Dimensions["customData"] = model.Dimension{
		SQL:  "data[indexOf(key, '{key}')]",
		Type: "string",
	}
	req := &QueryRequest{
		Dimensions: []string{"AccessView.id"},
		Filters: []Filter{
			{Member: "AccessView.customData.UserToken", Operator: "equals", Values: []interface{}{"abc"}},
		},
	}

	sql, params, err := BuildQuery(req, cube)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !contains(sql, `data[indexOf(key, 'UserToken')] IN (?)`) {
		t.Errorf("expected filter with subKey substitution, got: %s", sql)
	}
	if len(params) != 1 || params[0] != "abc" {
		t.Errorf("unexpected params: %v", params)
	}
}

func TestBuildQuery_CustomDataSubKeyOrderBy(t *testing.T) {
	cube := testCube()
	cube.Dimensions["customData"] = model.Dimension{
		SQL:  "data[indexOf(key, '{key}')]",
		Type: "string",
	}
	req := &QueryRequest{
		Dimensions: []string{"AccessView.customData.UserToken"},
		Order:      OrderMap{"AccessView.customData.UserToken": "desc"},
	}

	sql, _, err := BuildQuery(req, cube)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !contains(sql, `data[indexOf(key, 'UserToken')] DESC`) {
		t.Errorf("expected subKey substitution in ORDER BY, got: %s", sql)
	}
}

func TestBuildQuery_CustomDataSubKeyGroupBy(t *testing.T) {
	cube := testCube()
	cube.Dimensions["customData"] = model.Dimension{
		SQL:  "data[indexOf(key, '{key}')]",
		Type: "string",
	}
	req := &QueryRequest{
		Dimensions: []string{"AccessView.customData.UserToken"},
		Measures:   []string{"AccessView.count"},
	}

	sql, _, err := BuildQuery(req, cube)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// GROUP BY 应出现两次（SELECT 和 GROUP BY 各一次）
	if !contains(sql, "GROUP BY") {
		t.Errorf("expected GROUP BY clause, got: %s", sql)
	}
	if !contains(sql, `data[indexOf(key, 'UserToken')]`) {
		t.Errorf("expected subKey substitution in GROUP BY, got: %s", sql)
	}
}

func TestLoadNotInitialized(t *testing.T) {
	// Reset global handler to ensure it's nil
	origHandler := handler
	handler = nil
	defer func() { handler = origHandler }()

	_, err := Load(context.Background(), `{"dimensions":["AccessView.id"]}`)
	if err == nil {
		t.Error("expected error when Load called without Init")
	}
}

// TestHandleLoad_PostWrapped 验证 POST {"query":{...},"queryType":"multi"} 的 unwrap 逻辑。
func TestHandleLoad_PostWrapped(t *testing.T) {
	defer func() { recover() }() // chClient=nil 会 panic，属预期，忽略
	body := `{"query":{"dimensions":["AccessView.id"],"limit":1},"queryType":"multi"}`
	req := httptest.NewRequest(http.MethodPost, "/load", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rr := httptest.NewRecorder()

	h := &Handler{modelLoader: model.NewLoader(model.InternalFS), chClient: nil}
	h.HandleLoad(rr, req)

	if rr.Code == http.StatusBadRequest {
		t.Errorf("wrapped POST body should parse OK, got 400: %s", rr.Body.String())
	}
}

// TestHandleLoad_GetQuery 验证 GET ?query=... 格式正常解析。
func TestHandleLoad_GetQuery(t *testing.T) {
	defer func() { recover() }()
	q := url.QueryEscape(`{"dimensions":["AccessView.id"],"limit":1}`)
	req := httptest.NewRequest(http.MethodGet, "/load?query="+q, nil)
	rr := httptest.NewRecorder()

	h := &Handler{modelLoader: model.NewLoader(model.InternalFS), chClient: nil}
	h.HandleLoad(rr, req)

	if rr.Code == http.StatusBadRequest {
		t.Errorf("GET ?query= should parse OK, got 400: %s", rr.Body.String())
	}
}

// contains reports whether s contains substr.
func contains(s, substr string) bool {
	return strings.Contains(s, substr)
}
