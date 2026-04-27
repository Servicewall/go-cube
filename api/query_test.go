package api

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"strings"
	"testing"
	"testing/fstest"
	"time"

	"github.com/Servicewall/go-cube/config"
	"github.com/Servicewall/go-cube/model"
	"github.com/Servicewall/go-cube/sql"
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
			"org":   {SQL: []string{"org = {vars.org}"}},
			"black": {SQL: []string{"concat(host, url) NOT IN ({vars.api_exact})", "NOT multiMatchAny(concat(host, url), [{vars.api_regex}])"}},
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

func TestBuildQuery_MeasuresOnlyNoGroupBy(t *testing.T) {
	// measures only, no dimensions, no timeDimensions — full-table aggregate
	// GROUP BY must NOT be present (ClickHouse syntax error on empty GROUP BY)
	req := &QueryRequest{
		Measures: []string{"AccessView.count"},
	}

	sql, _, err := BuildQuery(req, testCube())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if contains(sql, "GROUP BY") {
		t.Errorf("expected no GROUP BY for measures-only query, got: %s", sql)
	}
	if !contains(sql, "count()") {
		t.Errorf("expected count() in SELECT, got: %s", sql)
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

func testApiCube() *model.Cube {
	return &model.Cube{
		Name:     "ApiView",
		SQLTable: "default.api",
		Dimensions: map[string]model.Dimension{
			"id":          {SQL: "id", Type: "string"},
			"sidebarType": {SQL: "arrayStringConcat(arrayFilter(x->x!='',sidebar_arr), ',')", Type: "string"},
		},
		Measures: map[string]model.Measure{
			"count": {SQL: "count()", Type: "number"},
		},
	}
}

func TestBuildQuery_FilterContainsMultiValue(t *testing.T) {
	req := &QueryRequest{
		Dimensions: []string{"ApiView.id"},
		Filters: []Filter{
			{Member: "ApiView.sidebarType", Operator: "contains", Values: []interface{}{"已发现->", "已梳理->"}},
		},
	}

	sql, params, err := BuildQuery(req, testApiCube())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !contains(sql, "OR") {
		t.Errorf("expected OR clause for multi-value contains, got: %s", sql)
	}
	if len(params) != 2 {
		t.Fatalf("expected 2 params, got %d: %v", len(params), params)
	}
	if params[0] != "%已发现->%" || params[1] != "%已梳理->%" {
		t.Errorf("expected wildcard params, got: %v", params)
	}
}

func TestBuildQuery_FilterNotContainsMultiValue(t *testing.T) {
	req := &QueryRequest{
		Dimensions: []string{"ApiView.id"},
		Filters: []Filter{
			{Member: "ApiView.sidebarType", Operator: "notContains", Values: []interface{}{"已发现->", "已梳理->"}},
		},
	}

	sql, params, err := BuildQuery(req, testApiCube())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !contains(sql, "NOT LIKE") {
		t.Errorf("expected NOT LIKE clause, got: %s", sql)
	}
	// notContains 多值用 AND
	if !contains(sql, "AND") {
		t.Errorf("expected AND clause for multi-value notContains, got: %s", sql)
	}
	if len(params) != 2 {
		t.Fatalf("expected 2 params, got %d: %v", len(params), params)
	}
	if params[0] != "%已发现->%" || params[1] != "%已梳理->%" {
		t.Errorf("expected wildcard params, got: %v", params)
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
		Order:      OrderList{{Member: "AccessView.ts", Direction: "desc"}},
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
	if !contains(sql, "ts >= '2024-01-01'") || !contains(sql, "ts <= '2024-01-31'") {
		t.Errorf("expected date range WHERE clause, got: %s", sql)
	}
	if len(params) != 0 {
		t.Errorf("expected 0 date params (inlined), got: %v", params)
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
	if !contains(sql, "toStartOfMonth(addMonths(now(), -1))") {
		t.Errorf("expected toStartOfMonth(addMonths(now(), -1)) in SQL, got: %s", sql)
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
		Segments:   []string{"AccessView.org"},
		Vars:       map[string][]string{"org": {"tenant_abc"}},
	}

	sql, params, err := BuildQuery(req, testCube())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if len(params) != 0 {
		t.Errorf("expected no params, got %v", params)
	}
	if !contains(sql, "WHERE") {
		t.Errorf("expected WHERE clause, got: %s", sql)
	}
	if !contains(sql, "org = 'tenant_abc'") {
		t.Errorf("expected org segment in WHERE with var substituted, got: %s", sql)
	}
}

func TestBuildQuery_BlackSegment(t *testing.T) {
	req := &QueryRequest{
		Dimensions: []string{"AccessView.id"},
		Segments:   []string{"AccessView.black"},
		Vars: map[string][]string{
			"api_exact": {"host1/api/v1", "host2/api/v2"},
			"api_regex": {"\\.php$", "^/admin/.*"},
		},
	}

	sql, _, err := BuildQuery(req, testCube())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !contains(sql, "WHERE") {
		t.Errorf("expected WHERE clause, got: %s", sql)
	}
	if !contains(sql, "concat(host, url) NOT IN ('host1/api/v1','host2/api/v2')") {
		t.Errorf("expected exact list quoted in NOT IN, got: %s", sql)
	}
	if !contains(sql, "multiMatchAny(concat(host, url), ['\\.php$','^/admin/.*'])") {
		t.Errorf("expected regex list quoted in multiMatchAny, got: %s", sql)
	}
}

func TestBuildQuery_BlackSegmentEmpty(t *testing.T) {
	// 空 slice 时整体跳过该 segment，不产生自动 WHERE 条件
	req := &QueryRequest{
		Dimensions: []string{"AccessView.id"},
		Segments:   []string{"AccessView.black"},
		Vars: map[string][]string{
			"api_exact": {},
			"api_regex": {},
		},
	}

	sql, _, err := BuildQuery(req, testCube())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if contains(sql, "WHERE") {
		t.Errorf("expected no WHERE for empty vars, got: %s", sql)
	}
	if contains(sql, "NOT IN ()") || contains(sql, "multiMatchAny(concat") {
		t.Errorf("should not produce invalid SQL for empty lists, got: %s", sql)
	}
}

func TestBuildQuery_SegmentsOrgEmptyVar(t *testing.T) {
	// org 传空字符串时，应生成 org = '' 的 WHERE 条件
	req := &QueryRequest{
		Dimensions: []string{"AccessView.id"},
		Segments:   []string{"AccessView.org"},
		Vars:       map[string][]string{"org": {""}},
	}

	sql, _, err := BuildQuery(req, testCube())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !contains(sql, "WHERE") {
		t.Errorf("expected WHERE for empty org, got: %s", sql)
	}
	if !contains(sql, "org = ''") {
		t.Errorf("expected org = '' in WHERE, got: %s", sql)
	}
}

func TestBuildQuery_SegmentVarsSQLInjection(t *testing.T) {
	// 单引号应被转义，防止 SQL 注入
	req := &QueryRequest{
		Dimensions: []string{"AccessView.id"},
		Segments:   []string{"AccessView.org"},
		Vars:       map[string][]string{"org": {"evil' OR '1'='1"}},
	}

	sql, _, err := BuildQuery(req, testCube())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if contains(sql, "evil' OR") {
		t.Errorf("SQL injection not escaped, got: %s", sql)
	}
	if !contains(sql, "evil'' OR") {
		t.Errorf("expected escaped single quotes, got: %s", sql)
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
		{"today", "toStartOfDay(now())", "toStartOfDay(addDays(now(), 1))", true},
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
		Order:      OrderList{{Member: "AccessView.customData.UserToken", Direction: "desc"}},
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

func TestHandleLoad_MissingOrgHeaderGeneratesEmptyOrg(t *testing.T) {
	modelFS := fstest.MapFS{
		"AccessView.yaml": &fstest.MapFile{Data: []byte(`cube:
  name: AccessView
  sql_table: default.access
  segments:
    org:
      sql:
        - "org = {vars.org}"
  dimensions:
    id:
      sql: id
      type: string
`)},
	}

	var capturedQuery string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, err := io.ReadAll(r.Body)
		if err != nil {
			t.Fatalf("read query body: %v", err)
		}
		capturedQuery = string(body)
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"data":[]}`))
	}))
	defer server.Close()

	host := strings.TrimPrefix(server.URL, "http://")
	chClient, err := sql.NewClient(&config.ClickHouseConfig{
		Hosts:        []string{host},
		Database:     "default",
		QueryTimeout: time.Second,
	})
	if err != nil {
		t.Fatalf("create clickhouse client: %v", err)
	}

	body := `{"dimensions":["AccessView.id"],"segments":["AccessView.org"],"limit":1}`
	req := httptest.NewRequest(http.MethodPost, "/load", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rr := httptest.NewRecorder()

	h := &Handler{modelLoader: model.NewLoader(modelFS), chClient: chClient}
	h.HandleLoad(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rr.Code, rr.Body.String())
	}
	// org 未传时应生成 org = ''，而非跳过 segment
	if !contains(capturedQuery, "org = ''") {
		t.Fatalf("expected org = '' when org header missing, got: %s", capturedQuery)
	}
}

// TestBuildQuery_MeasureFilterGoesToHaving verifies that a filter on a measure
// field is placed in HAVING (not WHERE), so ClickHouse won't reject it with
// "aggregate function found in WHERE".
func TestBuildQuery_MeasureFilterGoesToHaving(t *testing.T) {
	req := &QueryRequest{
		Dimensions: []string{"AccessView.ip"},
		Measures:   []string{"AccessView.count"},
		Filters: []Filter{
			// measure filter → HAVING
			{Member: "AccessView.count", Operator: "gte", Values: []interface{}{"5"}},
			// dimension filter → WHERE
			{Member: "AccessView.ip", Operator: "equals", Values: []interface{}{"1.2.3.4"}},
		},
	}

	sql, params, err := BuildQuery(req, testCube())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	// WHERE must NOT contain the aggregate filter
	whereIdx := strings.Index(sql, "WHERE")
	havingIdx := strings.Index(sql, "HAVING")
	if whereIdx < 0 {
		t.Fatalf("expected WHERE clause, got: %s", sql)
	}
	if havingIdx < 0 {
		t.Fatalf("expected HAVING clause, got: %s", sql)
	}

	// dimension filter in WHERE, before HAVING
	if !contains(sql[:havingIdx], "ip IN (?)") {
		t.Errorf("expected dimension filter in WHERE section, got: %s", sql)
	}
	// measure filter in HAVING, after GROUP BY
	if !contains(sql[havingIdx:], "count() >= ?") {
		t.Errorf("expected measure filter in HAVING section, got: %s", sql)
	}

	if len(params) != 2 {
		t.Errorf("expected 2 params, got %v", params)
	}
}

// contains reports whether s contains substr.
func contains(s, substr string) bool {
	return strings.Contains(s, substr)
}

// TestBuildQuery_SubquerySQLVarsOrg 验证子查询模型的 {vars.org} 被正确注入 FROM 子句
func TestBuildQuery_SubquerySQLVarsOrg(t *testing.T) {
	cube := &model.Cube{
		Name: "WeakView",
		SQL:  "SELECT org, host FROM weak PREWHERE org = {vars.org}",
		Dimensions: map[string]model.Dimension{
			"host": {SQL: "host", Type: "string"},
		},
		Segments: map[string]model.Segment{
			"org": {SQL: []string{""}},
		},
	}

	req := &QueryRequest{
		Dimensions: []string{"WeakView.host"},
		Vars:       map[string][]string{"org": {"tenant_abc"}},
	}

	sql, _, err := BuildQuery(req, cube)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !contains(sql, "PREWHERE org = 'tenant_abc'") {
		t.Errorf("expected org injected into subquery FROM, got: %s", sql)
	}
	// 占位符不应残留
	if contains(sql, "{vars.org}") {
		t.Errorf("placeholder {vars.org} should be replaced, got: %s", sql)
	}
}

// TestBuildQuery_SubquerySQLVarsOrgMissing 验证没有传 vars.org 时，fromSQL 中残余占位符降级为 ”，查询仍能构建
func TestBuildQuery_SubquerySQLVarsOrgMissing(t *testing.T) {
	cube := &model.Cube{
		Name: "WeakView",
		SQL:  "SELECT org, host FROM weak PREWHERE org = {vars.org}",
		Dimensions: map[string]model.Dimension{
			"host": {SQL: "host", Type: "string"},
		},
		Segments: map[string]model.Segment{
			"org": {SQL: []string{""}},
		},
	}

	req := &QueryRequest{
		Dimensions: []string{"WeakView.host"},
		// 不传 vars
	}

	sql, _, err := BuildQuery(req, cube)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// vars 缺失时 fromSQL 中占位符降级为 ''，子查询仍完整，不会产生空 FROM
	if !contains(sql, "FROM (") {
		t.Errorf("expected subquery FROM clause, got: %s", sql)
	}
	if contains(sql, "{vars.") {
		t.Errorf("unresolved vars placeholder remaining, got: %s", sql)
	}
}

func TestBuildQuery_TimeDimension_PhysicalTableToWhere(t *testing.T) {
	req := &QueryRequest{
		Measures: []string{"AccessView.count"},
		TimeDimensions: []TimeDimension{
			{Dimension: "AccessView.ts", DateRange: DateRange{V: []string{"2026-04-01 00:00:00", "2026-04-07 23:59:59"}}},
		},
		Segments: []string{"AccessView.org"},
		Vars:     map[string][]string{"org": {"tenant_abc"}},
	}

	sql, _, err := BuildQuery(req, testCube())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !contains(sql, "WHERE") {
		t.Fatalf("expected WHERE clause, got: %s", sql)
	}
	if !contains(sql, "org = 'tenant_abc'") {
		t.Errorf("expected segment in WHERE, got: %s", sql)
	}
	if !contains(sql, "ts >= '2026-04-01 00:00:00' AND ts <= '2026-04-07 23:59:59'") {
		t.Errorf("expected time dimension in WHERE, got: %s", sql)
	}
}

func TestBuildQuery_TimeDimension_SubqueryStaysInWhere(t *testing.T) {
	cube := &model.Cube{
		Name: "WeakView",
		SQL:  "SELECT ts, host FROM weak WHERE {filter.ts}",
		Dimensions: map[string]model.Dimension{
			"host": {SQL: "host", Type: "string"},
			"ts":   {SQL: "ts", Type: "time"},
		},
		Measures: map[string]model.Measure{
			"count": {SQL: "count()", Type: "number"},
		},
	}

	req := &QueryRequest{
		Measures: []string{"WeakView.count"},
		TimeDimensions: []TimeDimension{
			{Dimension: "WeakView.ts", DateRange: DateRange{V: []string{"2026-04-01 00:00:00", "2026-04-07 23:59:59"}}},
		},
	}

	sql, _, err := BuildQuery(req, cube)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if contains(sql, ") AS WeakView PREWHERE ts >= '2026-04-01 00:00:00'") {
		t.Errorf("expected no outer PREWHERE for subquery cube, got: %s", sql)
	}
	if !contains(sql, ") AS WeakView WHERE ts >= '2026-04-01 00:00:00' AND ts <= '2026-04-07 23:59:59'") {
		t.Errorf("expected time dimension in outer WHERE, got: %s", sql)
	}
	if !contains(sql, "SELECT ts, host FROM weak WHERE ts >= '2026-04-01 00:00:00' AND ts <= '2026-04-07 23:59:59'") {
		t.Errorf("expected {filter.ts} replacement in subquery, got: %s", sql)
	}
}
func TestOrderList_MarshalJSON_Nil(t *testing.T) {
	var ol OrderList
	data, err := json.Marshal(ol)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if string(data) != "[]" {
		t.Errorf("nil OrderList should marshal to [], got: %s", data)
	}
}

func TestOrderList_MarshalJSON_Empty(t *testing.T) {
	ol := OrderList{}
	data, err := json.Marshal(ol)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if string(data) != "[]" {
		t.Errorf("empty OrderList should marshal to [], got: %s", data)
	}
}

func TestOrderList_MarshalJSON_Single(t *testing.T) {
	ol := OrderList{{Member: "AccessView.ts", Direction: "desc"}}
	data, err := json.Marshal(ol)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	want := `[["AccessView.ts","desc"]]`
	if string(data) != want {
		t.Errorf("got %s, want %s", data, want)
	}
}

func TestOrderList_MarshalJSON_Multiple(t *testing.T) {
	ol := OrderList{
		{Member: "AccessView.ts", Direction: "asc"},
		{Member: "AccessView.ip", Direction: "desc"},
	}
	data, err := json.Marshal(ol)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	want := `[["AccessView.ts","asc"],["AccessView.ip","desc"]]`
	if string(data) != want {
		t.Errorf("got %s, want %s", data, want)
	}
}

func TestOrderList_MarshalJSON_RoundTrip_Array(t *testing.T) {
	original := OrderList{
		{Member: "AccessView.ts", Direction: "asc"},
		{Member: "AccessView.ip", Direction: "desc"},
	}
	data, err := json.Marshal(original)
	if err != nil {
		t.Fatalf("marshal error: %v", err)
	}
	var decoded OrderList
	if err := json.Unmarshal(data, &decoded); err != nil {
		t.Fatalf("unmarshal error: %v", err)
	}
	if len(decoded) != len(original) {
		t.Fatalf("length mismatch: got %d, want %d", len(decoded), len(original))
	}
	for i := range original {
		if decoded[i] != original[i] {
			t.Errorf("item %d: got %+v, want %+v", i, decoded[i], original[i])
		}
	}
}

func TestOrderList_UnmarshalJSON_ObjectFormat(t *testing.T) {
	// 对象格式反序列化后再序列化，应输出数组格式
	input := `{"AccessView.ts":"desc"}`
	var ol OrderList
	if err := json.Unmarshal([]byte(input), &ol); err != nil {
		t.Fatalf("unmarshal error: %v", err)
	}
	if len(ol) != 1 || ol[0].Member != "AccessView.ts" || ol[0].Direction != "desc" {
		t.Fatalf("unexpected unmarshal result: %+v", ol)
	}
	data, err := json.Marshal(ol)
	if err != nil {
		t.Fatalf("marshal error: %v", err)
	}
	want := `[["AccessView.ts","desc"]]`
	if string(data) != want {
		t.Errorf("re-serialized object format: got %s, want %s", data, want)
	}
}

func TestOrderList_MarshalJSON_SkipsEmptyMember(t *testing.T) {
	ol := OrderList{
		{Member: "", Direction: "asc"},
		{Member: "AccessView.ts", Direction: "desc"},
		{Member: "", Direction: ""},
	}
	data, err := json.Marshal(ol)
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	want := `[["AccessView.ts","desc"]]`
	if string(data) != want {
		t.Errorf("got %s, want %s", data, want)
	}
}

func TestOrderList_UnmarshalJSON_SkipsEmptyMember_Array(t *testing.T) {
	input := `[["","asc"],["AccessView.ts","desc"]]`
	var ol OrderList
	if err := json.Unmarshal([]byte(input), &ol); err != nil {
		t.Fatalf("unmarshal error: %v", err)
	}
	if len(ol) != 1 || ol[0].Member != "AccessView.ts" {
		t.Errorf("expected 1 item with Member=AccessView.ts, got: %+v", ol)
	}
}

func TestOrderList_UnmarshalJSON_SkipsEmptyMember_Object(t *testing.T) {
	input := `{"":"asc","AccessView.ts":"desc"}`
	var ol OrderList
	if err := json.Unmarshal([]byte(input), &ol); err != nil {
		t.Fatalf("unmarshal error: %v", err)
	}
	if len(ol) != 1 || ol[0].Member != "AccessView.ts" {
		t.Errorf("expected 1 item with Member=AccessView.ts, got: %+v", ol)
	}
}

// riskCube builds a RiskView fixture mirroring model/RiskView.yaml new fields.
func riskCube() *model.Cube {
	filterStatusSQL := "multiIf(arrayStringConcat([risk,host,content],',') not in (select filter from postgres.risk_aggs where filter_type = 4 and org = '')=0, '始终忽略', arrayStringConcat([risk,host,content],',') in (select filter from postgres.risk_aggs where filter_type = 1 and org = ''), '已确认', '待确认')"
	return &model.Cube{
		Name:     "RiskView",
		SQLTable: "default.risk_day",
		Dimensions: map[string]model.Dimension{
			"risk":            {SQL: "risk", Type: "string"},
			"host":            {SQL: "host", Type: "string"},
			"filterRiskLevel": {SQL: "multiIf(dictGetInt64('default.risk_dict', 'score', risk)=80, '高风险', dictGetInt64('default.risk_dict', 'score', risk)=50, '中风险', '低风险')", Type: "string"},
			"filterStatus":    {SQL: filterStatusSQL, Type: "string"},
			"filterShowTime":  {SQL: "if(first_ts >= today(), '首次出现', '重复出现')", Type: "string"},
			"filterTs":        {SQL: "ts", Type: "time"},
		},
		Measures: map[string]model.Measure{
			"count":              {SQL: "count()", Type: "number"},
			"ts":                 {SQL: "max(ts)", Type: "time"},
			"listFilterShowTime": {SQL: "if(min(first_ts) >= today(), '首次出现', '重复出现')", Type: "string"},
		},
		Segments: map[string]model.Segment{
			"org":               {SQL: []string{"org = {vars.org}"}},
			"whiteFilter":       {SQL: []string{"arrayStringConcat([risk,host,content],',') not in (select filter from postgres.risk_aggs where filter_type = 4 and org = {vars.org})"}},
			"whiteRiskFilter":   {SQL: []string{"risk not in (select tag from risk_dict where score <= 0)"}},
			"riskDenoiseFilter": {SQL: []string{"risk in (select risk from risk_agg_local final where ts > today() group by risk having count() < 100)"}},
			"statusFilter":      {SQL: []string{filterStatusSQL + " = '待确认'"}},
		},
	}
}

// TestRiskView_FilterShowTime_WHERE verifies filterShowTime (dimension) produces a WHERE clause.
func TestRiskView_FilterShowTime_WHERE(t *testing.T) {
	req := &QueryRequest{
		Measures: []string{"RiskView.count"},
		Filters: []Filter{
			{Member: "RiskView.filterShowTime", Operator: "equals", Values: []interface{}{"重复出现"}},
			{Member: "RiskView.filterRiskLevel", Operator: "equals", Values: []interface{}{"高风险", "中风险"}},
		},
		Segments: []string{"RiskView.org", "RiskView.whiteFilter", "RiskView.whiteRiskFilter", "RiskView.riskDenoiseFilter", "RiskView.statusFilter"},
		Limit:    20,
		Vars:     map[string][]string{"org": {"testorg"}},
	}
	sql, _, err := BuildQuery(req, riskCube())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// filterShowTime is a dimension → WHERE
	if !contains(sql, "WHERE") {
		t.Errorf("expected WHERE clause, got: %s", sql)
	}
	if !contains(sql, "first_ts >= today()") {
		t.Errorf("expected filterShowTime SQL in WHERE, got: %s", sql)
	}
	// statusFilter segment → WHERE
	if !contains(sql, "'待确认'") {
		t.Errorf("expected statusFilter SQL in WHERE, got: %s", sql)
	}
}

// TestRiskView_ListFilterShowTime_HAVING verifies listFilterShowTime (measure) produces a HAVING clause.
func TestRiskView_ListFilterShowTime_HAVING(t *testing.T) {
	req := &QueryRequest{
		Measures:   []string{"RiskView.ts"},
		Dimensions: []string{"RiskView.risk", "RiskView.host"},
		Filters: []Filter{
			{Member: "RiskView.listFilterShowTime", Operator: "equals", Values: []interface{}{"重复出现"}},
			{Member: "RiskView.filterRiskLevel", Operator: "equals", Values: []interface{}{"高风险", "中风险"}},
		},
		Segments: []string{"RiskView.org", "RiskView.whiteFilter", "RiskView.whiteRiskFilter", "RiskView.riskDenoiseFilter", "RiskView.statusFilter"},
		Limit:    20,
		Vars:     map[string][]string{"org": {"testorg"}},
	}
	sql, _, err := BuildQuery(req, riskCube())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	// listFilterShowTime is a measure → HAVING
	if !contains(sql, "HAVING") {
		t.Errorf("expected HAVING clause, got: %s", sql)
	}
	if !contains(sql, "min(first_ts) >= today()") {
		t.Errorf("expected listFilterShowTime SQL in HAVING, got: %s", sql)
	}
	// filterRiskLevel is a dimension → WHERE
	if !contains(sql, "WHERE") {
		t.Errorf("expected WHERE clause for filterRiskLevel, got: %s", sql)
	}
}

// TestRiskView_StatusFilter_Segment verifies statusFilter segment goes to WHERE.
func TestRiskView_StatusFilter_Segment(t *testing.T) {
	req := &QueryRequest{
		Measures: []string{"RiskView.count"},
		Segments: []string{"RiskView.statusFilter"},
		Limit:    10,
	}
	sql, _, err := BuildQuery(req, riskCube())
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if !contains(sql, "WHERE") {
		t.Errorf("expected WHERE for statusFilter segment, got: %s", sql)
	}
	if !contains(sql, "'待确认'") {
		t.Errorf("expected statusFilter SQL in WHERE, got: %s", sql)
	}
}

// ---------- Search-Target / offline table switching ----------

// accessViewYAML 是测试用的 AccessView 模型定义（含 taskId 字段）。
const accessViewYAML = `cube:
  name: AccessView
  sql_table: default.access
  dimensions:
    id:
      sql: id
      type: string
    taskId:
      sql: task_id
      type: string
  measures:
    count:
      sql: count()
      type: number
`

// newTestHandler 创建一个使用假 ClickHouse 的 Handler，返回 handler 和捕获 SQL 的指针。
func newTestHandler(t *testing.T) (*Handler, *string) {
	t.Helper()
	modelFS := fstest.MapFS{
		"AccessView.yaml": &fstest.MapFile{Data: []byte(accessViewYAML)},
	}
	var captured string
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		body, _ := io.ReadAll(r.Body)
		captured = string(body)
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"data":[]}`))
	}))
	t.Cleanup(server.Close)

	host := strings.TrimPrefix(server.URL, "http://")
	chClient, err := sql.NewClient(&config.ClickHouseConfig{
		Hosts:        []string{host},
		Database:     "default",
		QueryTimeout: time.Second,
	})
	if err != nil {
		t.Fatalf("create clickhouse client: %v", err)
	}
	return &Handler{modelLoader: model.NewLoader(modelFS), chClient: chClient}, &captured
}

func TestHandleLoad_SearchTargetOffline_SwitchesTable(t *testing.T) {
	h, captured := newTestHandler(t)

	body := `{"dimensions":["AccessView.id","AccessView.taskId"],"limit":1}`
	req := httptest.NewRequest(http.MethodPost, "/load", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Search-Target", "offline")
	rr := httptest.NewRecorder()
	h.HandleLoad(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rr.Code, rr.Body.String())
	}
	if !contains(*captured, "default.access_offline_local") {
		t.Errorf("expected access_offline_local table, got: %s", *captured)
	}
	if !contains(*captured, "task_id") {
		t.Errorf("expected task_id field in offline query, got: %s", *captured)
	}
}

func TestHandleLoad_NoSearchTarget_KeepsOriginalTable(t *testing.T) {
	h, captured := newTestHandler(t)

	body := `{"dimensions":["AccessView.id","AccessView.taskId"],"limit":1}`
	req := httptest.NewRequest(http.MethodPost, "/load", strings.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	rr := httptest.NewRecorder()
	h.HandleLoad(rr, req)

	if rr.Code != http.StatusOK {
		t.Fatalf("expected 200, got %d: %s", rr.Code, rr.Body.String())
	}
	if contains(*captured, "access_offline_local") {
		t.Errorf("should NOT switch to offline table, got: %s", *captured)
	}
	if !contains(*captured, "default.access") {
		t.Errorf("expected default.access table, got: %s", *captured)
	}
}

func TestHandleLoad_OfflineDoesNotPolluteCache(t *testing.T) {
	h, captured := newTestHandler(t)

	// 先请求 offline
	body := `{"dimensions":["AccessView.id","AccessView.taskId"],"limit":1}`
	req1 := httptest.NewRequest(http.MethodPost, "/load", strings.NewReader(body))
	req1.Header.Set("Content-Type", "application/json")
	req1.Header.Set("Search-Target", "offline")
	rr1 := httptest.NewRecorder()
	h.HandleLoad(rr1, req1)
	if !contains(*captured, "access_offline_local") {
		t.Fatalf("first request should use offline table, got: %s", *captured)
	}

	// 再请求普通模式，确认缓存没被污染
	req2 := httptest.NewRequest(http.MethodPost, "/load", strings.NewReader(body))
	req2.Header.Set("Content-Type", "application/json")
	rr2 := httptest.NewRecorder()
	h.HandleLoad(rr2, req2)
	if contains(*captured, "access_offline_local") {
		t.Errorf("second request should NOT use offline table (cache pollution), got: %s", *captured)
	}
}
