package api

import (
	"encoding/json"
	"fmt"
	"strings"

	"github.com/Servicewall/go-cube/model"
)

type QueryRequest struct {
	Ungrouped      bool                   `json:"ungrouped"`
	Measures       []string               `json:"measures"`
	TimeDimensions []TimeDimension        `json:"timeDimensions"`
	Order          OrderMap               `json:"order"`
	Filters        []Filter               `json:"filters"`
	Dimensions     []string               `json:"dimensions"`
	Limit          int                    `json:"limit"`
	Offset         int                    `json:"offset"`
	Segments       []string               `json:"segments"`
	Timezone       string                 `json:"timezone"`
	CustomData     map[string]interface{} `json:"customData,omitempty"`
}

// DateRange 支持字符串或字符串数组格式
type DateRange struct{ V interface{} }

func (dr *DateRange) UnmarshalJSON(data []byte) error {
	var arr []string
	if json.Unmarshal(data, &arr) == nil {
		dr.V = arr
		return nil
	}
	var str string
	if json.Unmarshal(data, &str) == nil {
		dr.V = str
		return nil
	}
	return fmt.Errorf("dateRange must be a string or array of strings")
}

type TimeDimension struct {
	Dimension   string    `json:"dimension"`
	DateRange   DateRange `json:"dateRange"`
	Granularity string    `json:"granularity,omitempty"`
}

type OrderMap map[string]string

type Filter struct {
	Member   string      `json:"member"`
	Operator string      `json:"operator"`
	Values   interface{} `json:"values"`
}

type QueryResponse struct {
	QueryType string        `json:"queryType"`
	Results   []QueryResult `json:"results"`
	SlowQuery bool          `json:"slowQuery,omitempty"`
}

type QueryResult struct {
	Query QueryRequest `json:"query"`
	Data  []RowData    `json:"data"`
}

type RowData = map[string]interface{}

// splitMemberName 将 "CubeName.fieldName" 拆分为 (cubeName, fieldName)
func splitMemberName(s string) (string, string) {
	cube, field, _ := strings.Cut(s, ".")
	return cube, field
}

// resolveCompileContext 将 SQL 模板中的 ${COMPILE_CONTEXT["key"]} 占位符替换为实际值。
// 若上下文中不存在对应键，占位符替换为空字符串，避免残留占位符导致 SQL 语法错误。
func resolveCompileContext(sqlExpr string, ctx map[string]string) string {
	// 先替换上下文中有值的键
	for k, v := range ctx {
		placeholder := fmt.Sprintf(`${COMPILE_CONTEXT["%s"]}`, k)
		sqlExpr = strings.ReplaceAll(sqlExpr, placeholder, v)
	}
	// 将剩余未替换的占位符替换为空字符串
	const prefix = `${COMPILE_CONTEXT["`
	const suffix = `"]}`
	for {
		start := strings.Index(sqlExpr, prefix)
		if start < 0 {
			break
		}
		end := strings.Index(sqlExpr[start+len(prefix):], suffix)
		if end < 0 {
			break
		}
		sqlExpr = sqlExpr[:start] + "''" + sqlExpr[start+len(prefix)+end+len(suffix):]
	}
	return sqlExpr
}

func BuildQuery(req *QueryRequest, cube *model.Cube) (string, []interface{}, error) {
	var sql strings.Builder
	var params []interface{}

	// 从 CustomData 构建编译上下文，用于解析 SQL 模板中的 ${COMPILE_CONTEXT["key"]} 占位符
	compileContext := make(map[string]string)
	for k, v := range req.CustomData {
		if s, ok := v.(string); ok {
			compileContext[k] = s
		}
	}
	resolve := func(sqlExpr string) string {
		return resolveCompileContext(sqlExpr, compileContext)
	}

	// SELECT
	sql.WriteString("SELECT ")
	first := true
	writeFields := func(names []string) {
		for _, name := range names {
			_, fieldName := splitMemberName(name)
			if field, ok := cube.GetField(fieldName); ok {
				if !first {
					sql.WriteString(", ")
				}
				fmt.Fprintf(&sql, "%s AS \"%s\"", resolve(field.SQL), name)
				first = false
			}
		}
	}
	writeFields(req.Dimensions)
	writeFields(req.Measures)
	if first {
		sql.WriteString("1")
	}

	// FROM
	sql.WriteString(" FROM ")
	sql.WriteString(cube.GetSQLTable())

	// WHERE
	var where []string

	// segments
	for _, seg := range req.Segments {
		_, segName := splitMemberName(seg)
		if s, ok := cube.Segments[segName]; ok && s.SQL != "" {
			where = append(where, s.SQL)
		}
	}

	// filters
	for _, filter := range req.Filters {
		_, fieldName := splitMemberName(filter.Member)
		field, ok := cube.GetField(fieldName)
		if !ok || field.SQL == "" {
			continue
		}

		// set/notSet 对所有类型统一处理
		switch filter.Operator {
		case "set":
			where = append(where, fmt.Sprintf("notEmpty(%s)", resolve(field.SQL)))
			continue
		case "notSet":
			where = append(where, fmt.Sprintf("empty(%s)", resolve(field.SQL)))
			continue
		}

		valuesArr, _ := filter.Values.([]interface{})
		if len(valuesArr) == 0 && filter.Values != nil {
			valuesArr = []interface{}{filter.Values}
		}
		if len(valuesArr) == 0 {
			continue
		}

		if field.Type == "array" {
			clause, p := buildArrayClause(resolve(field.SQL), filter.Operator, valuesArr)
			where = append(where, clause)
			params = append(params, p...)
			continue
		}

		// 普通字段
		if filter.Operator == "equals" || filter.Operator == "notEquals" {
			clause, p := buildInClause(resolve(field.SQL), filter.Operator, valuesArr)
			where = append(where, clause)
			params = append(params, p...)
		} else {
			sqlOp := convertOperator(filter.Operator)
			value := processFilterValue(valuesArr[0], filter.Operator)
			where = append(where, fmt.Sprintf("%s %s ?", resolve(field.SQL), sqlOp))
			params = append(params, value)
		}
	}

	// timeDimensions
	for _, td := range req.TimeDimensions {
		_, fieldName := splitMemberName(td.Dimension)
		field, ok := cube.GetField(fieldName)
		if !ok || td.DateRange.V == nil {
			continue
		}
		fieldSQL := resolve(field.SQL)
		switch v := td.DateRange.V.(type) {
		case []string:
			if len(v) == 2 {
				where = append(where, fmt.Sprintf("%s >= ? AND %s <= ?", fieldSQL, fieldSQL))
				params = append(params, v[0], v[1])
			}
		case string:
			if v != "" {
				if start, end, ok := parseRelativeTimeRange(v); ok {
					where = append(where, fmt.Sprintf("%s >= %s AND %s <= %s", fieldSQL, start, fieldSQL, end))
				} else {
					where = append(where, fmt.Sprintf("toDate(%s) = %s", fieldSQL, convertToClickHouseTimeExpr(v)))
				}
			}
		}
	}

	if len(where) > 0 {
		sql.WriteString(" WHERE ")
		sql.WriteString(strings.Join(where, " AND "))
	}

	// GROUP BY
	if len(req.Measures) > 0 && len(req.Dimensions) > 0 {
		sql.WriteString(" GROUP BY ")
		for i, dim := range req.Dimensions {
			if i > 0 {
				sql.WriteString(", ")
			}
			_, fieldName := splitMemberName(dim)
			if field, ok := cube.GetField(fieldName); ok {
				sql.WriteString(resolve(field.SQL))
			} else {
				sql.WriteString(dim)
			}
		}
	}

	// ORDER BY
	if len(req.Order) > 0 {
		sql.WriteString(" ORDER BY ")
		i := 0
		for member, direction := range req.Order {
			if i > 0 {
				sql.WriteString(", ")
			}
			_, fieldName := splitMemberName(member)
			if f, ok := cube.GetField(fieldName); ok {
				sql.WriteString(resolve(f.SQL))
			} else {
				sql.WriteString(member)
			}
			if direction == "desc" {
				sql.WriteString(" DESC")
			}
			i++
		}
	}

	// LIMIT/OFFSET
	if req.Limit > 0 {
		fmt.Fprintf(&sql, " LIMIT %d", req.Limit)
	}
	if req.Offset > 0 {
		fmt.Fprintf(&sql, " OFFSET %d", req.Offset)
	}

	return sql.String(), params, nil
}

func validateQuery(req *QueryRequest) error {
	if len(req.Dimensions) == 0 && len(req.Measures) == 0 {
		return fmt.Errorf("query must have at least one dimension or measure")
	}
	if req.Limit < 0 {
		return fmt.Errorf("limit must be non-negative")
	}
	if req.Offset < 0 {
		return fmt.Errorf("offset must be non-negative")
	}
	return nil
}

// buildInClause 构建普通字段的 IN/NOT IN 子句
func buildInClause(fieldSQL string, operator string, values []interface{}) (string, []interface{}) {
	placeholders := strings.Repeat("?,", len(values))
	placeholders = placeholders[:len(placeholders)-1]
	params := make([]interface{}, len(values))
	for i, v := range values {
		params[i] = v
	}
	if operator == "notEquals" {
		return fmt.Sprintf("%s NOT IN (%s)", fieldSQL, placeholders), params
	}
	return fmt.Sprintf("%s IN (%s)", fieldSQL, placeholders), params
}

// buildArrayClause 针对数组类型字段生成 has/hasAll/hasAny 条件
// 单值：has(arr, ?)
// 多值：equals -> hasAll，contains -> hasAny
func buildArrayClause(fieldSQL string, operator string, values []interface{}) (string, []interface{}) {
	params := make([]interface{}, len(values))
	for i, v := range values {
		params[i] = v
	}
	negate := operator == "notEquals" || operator == "notContains"
	neg := ""
	if negate {
		neg = "NOT "
	}
	if len(values) == 1 {
		return fmt.Sprintf("%shas(%s, ?)", neg, fieldSQL), params
	}
	placeholders := strings.Repeat("?,", len(values))
	placeholders = placeholders[:len(placeholders)-1]
	fn := "hasAny"
	if operator == "equals" || operator == "notEquals" {
		fn = "hasAll"
	}
	return fmt.Sprintf("%s%s(%s, [%s])", neg, fn, fieldSQL, placeholders), params
}

// operatorMap CubeJS operator -> SQL operator（用于普通字段非 equals 情况）
var operatorMap = map[string]string{
	"contains":    "LIKE",
	"notContains": "NOT LIKE",
	"startsWith":  "LIKE",
	"endsWith":    "LIKE",
	"gt":          ">",
	"gte":         ">=",
	"lt":          "<",
	"lte":         "<=",
}

func convertOperator(op string) string {
	if sqlOp, ok := operatorMap[op]; ok {
		return sqlOp
	}
	return op
}

// processFilterValue 为 LIKE 类 operator 添加通配符
func processFilterValue(value interface{}, operator string) interface{} {
	s, ok := value.(string)
	if !ok {
		return value
	}
	switch operator {
	case "contains", "notContains":
		return "%" + s + "%"
	case "startsWith":
		return s + "%"
	case "endsWith":
		return "%" + s
	}
	return value
}

// parseRelativeTimeRange 解析 "from X to Y" 格式为 ClickHouse 时间表达式对
func parseRelativeTimeRange(s string) (string, string, bool) {
	s = strings.TrimSpace(s)
	switch s {
	case "this month":
		return "toStartOfMonth(now())", "toStartOfMonth(now() + INTERVAL 1 MONTH)", true
	case "last month":
		return "toStartOfMonth(now() - INTERVAL 1 MONTH)", "toStartOfMonth(now())", true
	}
	s = strings.TrimPrefix(s, "from ")
	if idx := strings.LastIndex(s, " to "); idx > 0 {
		start, end := strings.TrimSpace(s[:idx]), strings.TrimSpace(s[idx+4:])
		if start != "" && end != "" {
			return convertToClickHouseTimeExpr(start), convertToClickHouseTimeExpr(end), true
		}
	}
	return "", "", false
}

// convertToClickHouseTimeExpr 将相对时间字符串转为 ClickHouse 表达式
func convertToClickHouseTimeExpr(s string) string {
	s = strings.TrimSpace(strings.ToLower(s))
	switch s {
	case "now":
		return "now()"
	case "today":
		return "today()"
	case "yesterday":
		return "yesterday()"
	}
	if strings.HasSuffix(s, " ago") {
		if parts := strings.Fields(strings.TrimSuffix(s, " ago")); len(parts) == 2 {
			return fmt.Sprintf("now() - INTERVAL %s %s", parts[0], convertUnit(parts[1]))
		}
	}
	if strings.HasSuffix(s, " from now") {
		if parts := strings.Fields(strings.TrimSuffix(s, " from now")); len(parts) == 2 {
			return fmt.Sprintf("now() + INTERVAL %s %s", parts[0], convertUnit(parts[1]))
		}
	}
	return s
}

var unitMap = map[string]string{
	"second": "SECOND", "minute": "MINUTE", "hour": "HOUR",
	"day": "DAY", "week": "WEEK", "month": "MONTH", "year": "YEAR",
}

func convertUnit(unit string) string {
	unit = strings.TrimSuffix(unit, "s")
	if u, ok := unitMap[unit]; ok {
		return u
	}
	return strings.ToUpper(unit)
}
