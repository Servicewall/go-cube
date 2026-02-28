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

func (dr DateRange) String() string {
	if str, ok := dr.V.(string); ok {
		return str
	}
	if arr, ok := dr.V.([]string); ok {
		return strings.Join(arr, ",")
	}
	return ""
}

type TimeDimension struct {
	Dimension   string    `json:"dimension"`
	DateRange   DateRange `json:"dateRange"`
	Granularity string    `json:"granularity,omitempty"`
}

type Order struct {
	ID   string `json:"id"`
	Desc bool   `json:"desc"`
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

// resolveCompileContext 将 SQL 模板中的 ${COMPILE_CONTEXT["key"]} 占位符替换为实际值。
// 若上下文中不存在对应键，占位符替换为空字符串，避免残留占位符导致 SQL 语法错误。
func resolveCompileContext(sqlExpr string, ctx map[string]string) string {
	// 先替换上下文中有值的键
	for k, v := range ctx {
		placeholder := fmt.Sprintf(`${COMPILE_CONTEXT["%s"]}`, k)
		sqlExpr = strings.ReplaceAll(sqlExpr, placeholder, v)
	}
	// 将剩余未替换的占位符替换为空字符串，占位符格式为 ${COMPILE_CONTEXT["key"]}
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

func BuildQuery(req *QueryRequest, cube *model.Cube, compileContext map[string]string) (string, []interface{}, error) {
	var sql strings.Builder
	var params []interface{}

	resolve := func(sqlExpr string) string {
		return resolveCompileContext(sqlExpr, compileContext)
	}

	// SELECT
	sql.WriteString("SELECT ")

	firstField := true
	writeFields := func(names []string) {
		for _, name := range names {
			fieldName := extractFieldName(name)
			if field, ok := cube.GetField(fieldName); ok {
				if !firstField {
					sql.WriteString(", ")
				}
				fmt.Fprintf(&sql, "%s AS \"%s\"", resolve(field.SQL), name)
				firstField = false
			}
			// 如果字段不存在于模型中，则跳过（不生成到 SQL 中）
		}
	}

	writeFields(req.Dimensions)
	writeFields(req.Measures)

	// 如果没有有效字段，添加默认值避免 SQL 语法错误
	if firstField {
		sql.WriteString("1")
	}

	// FROM
	sql.WriteString(" FROM ")
	sql.WriteString(cube.GetSQLTable())

	// WHERE
	whereConditions := []string{}

	// 处理 filters
	for _, filter := range req.Filters {
		fieldName := extractFieldName(filter.Member)
		fieldSQL := filter.Member
		if field, ok := cube.GetField(fieldName); ok {
			fieldSQL = resolve(field.SQL)
		}

		// 如果字段名为空，跳过此 filter
		if fieldSQL == "" {
			continue
		}

		sqlOperator := convertOperator(filter.Operator)

		// set 和 notSet 不需要 values，统一使用 notEmpty()/empty()
		if filter.Operator == "set" || filter.Operator == "notSet" {
			if filter.Operator == "set" {
				whereConditions = append(whereConditions, fmt.Sprintf("notEmpty(%s)", fieldSQL))
			} else {
				whereConditions = append(whereConditions, fmt.Sprintf("empty(%s)", fieldSQL))
			}
			continue
		}

		// 处理 values（可能是数组或单个值）
		if valuesArr, ok := filter.Values.([]interface{}); ok && len(valuesArr) > 0 {
			// 数组值：对于 equals/notEquals 使用 IN/NOT IN
			if filter.Operator == "equals" || filter.Operator == "notEquals" {
				clause, clauseParams := buildInClause(fieldSQL, filter.Operator, valuesArr)
				whereConditions = append(whereConditions, clause)
				params = append(params, clauseParams...)
			} else {
				// 其他情况，只使用第一个值
				value := processFilterValue(valuesArr[0], filter.Operator)
				whereConditions = append(whereConditions, fmt.Sprintf("%s %s ?", fieldSQL, sqlOperator))
				params = append(params, value)
			}
		} else {
			// 单个值
			value := processFilterValue(filter.Values, filter.Operator)
			whereConditions = append(whereConditions, fmt.Sprintf("%s %s ?", fieldSQL, sqlOperator))
			params = append(params, value)
		}
	}

	// 处理 timeDimensions 的 dateRange
	for _, td := range req.TimeDimensions {
		if field, ok := cube.GetField(extractFieldName(td.Dimension)); ok {
			fieldSQL := resolve(field.SQL)
			if td.DateRange.V != nil {
				if dateRangeArr, ok := td.DateRange.V.([]string); ok && len(dateRangeArr) == 2 {
					// 日期范围：[start, end]
					whereConditions = append(whereConditions, fmt.Sprintf("%s >= ? AND %s <= ?", fieldSQL, fieldSQL))
					params = append(params, dateRangeArr[0], dateRangeArr[1])
				} else if dateRangeStr, ok := td.DateRange.V.(string); ok && dateRangeStr != "" {
					// 处理相对时间范围字符串，如 "from 15 minutes ago to 15 minutes from now"
					if startExpr, endExpr, isRange := parseRelativeTimeRange(dateRangeStr); isRange {
						// 直接嵌入 ClickHouse 时间表达式
						whereConditions = append(whereConditions, fmt.Sprintf("%s >= %s AND %s <= %s", fieldSQL, startExpr, fieldSQL, endExpr))
					} else {
						// 单个日期字符串（如 "today", "yesterday"）
						expr := convertToClickHouseTimeExpr(dateRangeStr)
						whereConditions = append(whereConditions, fmt.Sprintf("toDate(%s) = %s", fieldSQL, expr))
					}
				}
			}
		}
	}

	if len(whereConditions) > 0 {
		sql.WriteString(" WHERE ")
		sql.WriteString(strings.Join(whereConditions, " AND "))
	}

	// GROUP BY
	if len(req.Measures) > 0 && len(req.Dimensions) > 0 {
		sql.WriteString(" GROUP BY ")
		for i, dim := range req.Dimensions {
			if i > 0 {
				sql.WriteString(", ")
			}
			if field, ok := cube.GetField(extractFieldName(dim)); ok {
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
		for field, direction := range req.Order {
			if i > 0 {
				sql.WriteString(", ")
			}
			if f, ok := cube.GetField(extractFieldName(field)); ok {
				sql.WriteString(resolve(f.SQL))
			} else {
				sql.WriteString(field)
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

func extractFieldName(fullName string) string {
	// 提取字段名，去掉模型名前缀
	// 例如: "AccessView.id" -> "id"
	parts := strings.Split(fullName, ".")
	if len(parts) > 1 {
		return parts[1]
	}
	return fullName
}

// buildInClause 构建 IN/NOT IN 子句
func buildInClause(fieldSQL string, operator string, values []interface{}) (string, []interface{}) {
	placeholders := strings.Repeat("?,", len(values))
	placeholders = placeholders[:len(placeholders)-1]

	var params []interface{}
	for _, v := range values {
		params = append(params, processFilterValue(v, operator))
	}

	if operator == "notEquals" {
		return fmt.Sprintf("%s NOT IN (%s)", fieldSQL, placeholders), params
	}
	return fmt.Sprintf("%s IN (%s)", fieldSQL, placeholders), params
}

// operatorMap 定义 CubeJS operator 到 SQL operator 的映射
var operatorMap = map[string]string{
	"equals":      "=",
	"notEquals":   "!=",
	"contains":    "LIKE",
	"notContains": "NOT LIKE",
	"startsWith":  "LIKE",
	"endsWith":    "LIKE",
	"gt":          ">",
	"gte":         ">=",
	"lt":          "<",
	"lte":         "<=",
	"in":          "IN",
	"notIn":       "NOT IN",
}

// convertOperator 将 CubeJS 的 operator 转换为 SQL operator
func convertOperator(op string) string {
	if sqlOp, ok := operatorMap[op]; ok {
		return sqlOp
	}
	// 如果已经是 SQL operator，直接返回
	return op
}

// parseRelativeTimeRange 解析相对时间范围字符串并转换为 ClickHouse 表达式
// 支持格式: "from X to Y" 或 "X to Y"
// 返回 startExpr, endExpr, isRange (ClickHouse SQL 表达式)
func parseRelativeTimeRange(s string) (string, string, bool) {
	s = strings.TrimSpace(s)
	// 尝试匹配 "from ... to ..." 或 "... to ..." 格式
	if strings.HasPrefix(s, "from ") {
		s = s[5:] // 去掉 "from " 前缀
	}

	// 查找 "to" 分隔符
	if idx := strings.LastIndex(s, " to "); idx > 0 {
		start := strings.TrimSpace(s[:idx])
		end := strings.TrimSpace(s[idx+4:])
		if start != "" && end != "" {
			return convertToClickHouseTimeExpr(start), convertToClickHouseTimeExpr(end), true
		}
	}

	return "", "", false
}

// convertToClickHouseTimeExpr 将相对时间字符串转换为 ClickHouse 时间表达式
// 支持: "now", "today", "yesterday", "X minutes ago", "X hours ago", "X days ago", "X minutes from now" 等
func convertToClickHouseTimeExpr(s string) string {
	s = strings.TrimSpace(strings.ToLower(s))

	// 处理 "now"
	if s == "now" {
		return "now()"
	}
	// 处理 "today"
	if s == "today" {
		return "today()"
	}
	// 处理 "yesterday"
	if s == "yesterday" {
		return "yesterday()"
	}

	// 处理 "X units ago" 格式 (e.g., "15 minutes ago")
	if strings.HasSuffix(s, " ago") {
		parts := strings.Fields(s[:len(s)-4]) // 去掉 " ago"
		if len(parts) == 2 {
			return fmt.Sprintf("now() - INTERVAL %s %s", parts[0], convertUnit(parts[1]))
		}
	}

	// 处理 "X units from now" 格式 (e.g., "15 minutes from now")
	if strings.HasSuffix(s, " from now") {
		parts := strings.Fields(s[:len(s)-9]) // 去掉 " from now"
		if len(parts) == 2 {
			return fmt.Sprintf("now() + INTERVAL %s %s", parts[0], convertUnit(parts[1]))
		}
	}

	// 默认返回原始值（假设是标准日期格式）
	return s
}

// unitMap 定义时间单位到 ClickHouse 格式的映射
var unitMap = map[string]string{
	"second": "SECOND",
	"minute": "MINUTE",
	"hour":   "HOUR",
	"day":    "DAY",
	"week":   "WEEK",
	"month":  "MONTH",
	"year":   "YEAR",
}

// convertUnit 转换时间单位到 ClickHouse 格式
func convertUnit(unit string) string {
	// 处理复数形式
	unit = strings.TrimSuffix(unit, "s")
	if u, ok := unitMap[unit]; ok {
		return u
	}
	return strings.ToUpper(unit)
}

// processFilterValue 根据 operator 处理 filter 的值（例如 LIKE 操作符需要添加通配符）
func processFilterValue(value interface{}, operator string) interface{} {
	valueStr, ok := value.(string)
	if !ok {
		return value
	}

	switch operator {
	case "contains":
		return "%" + valueStr + "%"
	case "notContains":
		return "%" + valueStr + "%"
	case "startsWith":
		return valueStr + "%"
	case "endsWith":
		return "%" + valueStr
	default:
		return value
	}
}
