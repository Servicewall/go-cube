package api

import (
	"encoding/json"
	"fmt"
	"strings"

	"github.com/Servicewall/go-cube/model"
)

type QueryRequest struct {
	Ungrouped      bool            `json:"ungrouped"`
	Measures       []string        `json:"measures"`
	TimeDimensions []TimeDimension `json:"timeDimensions"`
	Order          OrderList       `json:"order"`
	Filters        []Filter        `json:"filters"`
	Dimensions     []string        `json:"dimensions"`
	Limit          int             `json:"limit"`
	Offset         int             `json:"offset"`
	Segments       []string        `json:"segments"`
	Timezone       string          `json:"timezone"`
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

type OrderItem struct {
	Member    string
	Direction string
}

// OrderList 支持两种格式:
// 数组格式: [["field","asc"],...]
// 对象格式: {"field":"asc",...} (无序，兼容旧格式)
type OrderList []OrderItem

func (o *OrderList) UnmarshalJSON(data []byte) error {
	// 数组格式: [["field","dir"],...]
	var arr [][]string
	if json.Unmarshal(data, &arr) == nil {
		list := make(OrderList, 0, len(arr))
		for _, pair := range arr {
			if len(pair) == 2 {
				list = append(list, OrderItem{pair[0], pair[1]})
			}
		}
		*o = list
		return nil
	}
	// 对象格式: {"field":"dir",...}
	var m map[string]string
	if err := json.Unmarshal(data, &m); err != nil {
		return err
	}
	list := make(OrderList, 0, len(m))
	for k, v := range m {
		list = append(list, OrderItem{k, v})
	}
	*o = list
	return nil
}

type Filter struct {
	Member   string      `json:"member"`
	Operator string      `json:"operator"`
	Values   interface{} `json:"values"`
	Or       []Filter    `json:"or,omitempty"`
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

// splitMemberName 将 "CubeName.fieldName" 或 "CubeName.fieldName.subKey" 拆分为
// (cubeName, fieldName, subKey)，subKey 为空表示无三级 key。
func splitMemberName(s string) (string, string, string) {
	cube, rest, _ := strings.Cut(s, ".")
	field, subKey, _ := strings.Cut(rest, ".")
	return cube, field, subKey
}

// granularityFunc 将 CubeJS granularity 映射到 ClickHouse 截断函数名
var granularityFunc = map[string]string{
	"second":  "toDateTime",
	"minute":  "toStartOfMinute",
	"hour":    "toStartOfHour",
	"day":     "toStartOfDay",
	"week":    "toStartOfWeek",
	"month":   "toStartOfMonth",
	"quarter": "toStartOfQuarter",
	"year":    "toStartOfYear",
}

// buildTimeDimensionClause 根据 dateRange 生成时间过滤片段，与外层 timeDimensions WHERE 逻辑完全一致。
func buildTimeDimensionClause(colSQL string, dr DateRange) (string, []interface{}) {
	switch v := dr.V.(type) {
	case []string:
		if len(v) == 2 {
			return fmt.Sprintf("%s >= ? AND %s <= ?", colSQL, colSQL), []interface{}{v[0], v[1]}
		}
	case string:
		if v != "" {
			if start, end, ok := parseRelativeTimeRange(v); ok {
				return fmt.Sprintf("%s >= %s AND %s <= %s", colSQL, start, colSQL, end), nil
			}
			return fmt.Sprintf("toDate(%s) = %s", colSQL, convertToClickHouseTimeExpr(v)), nil
		}
	}
	return "", nil
}

func BuildQuery(req *QueryRequest, cube *model.Cube) (string, []interface{}, error) {
	var sql strings.Builder
	var params []interface{}
	var whereParams []interface{}
	var havingParams []interface{}

	// 收集有 granularity 的时间维度：dimension -> (alias, expr)
	type granularityCol struct {
		alias string
		expr  string
	}
	granByDim := map[string]granularityCol{}
	for _, td := range req.TimeDimensions {
		if td.Granularity == "" {
			continue
		}
		_, fieldName, subKey := splitMemberName(td.Dimension)
		field, ok := cube.GetField(fieldName, subKey)
		if !ok {
			continue
		}
		fn, ok := granularityFunc[td.Granularity]
		if !ok {
			continue
		}
		granByDim[td.Dimension] = granularityCol{
			alias: td.Dimension + "." + td.Granularity,
			expr:  fmt.Sprintf("%s(%s)", fn, field.SQL),
		}
	}

	// SELECT
	sql.WriteString("SELECT ")
	first := true
	writeFields := func(names []string) {
		for _, name := range names {
			_, fieldName, subKey := splitMemberName(name)
			if field, ok := cube.GetField(fieldName, subKey); ok {
				if !first {
					sql.WriteString(", ")
				}
				fmt.Fprintf(&sql, "%s AS \"%s\"", field.SQL, name)
				first = false
			}
		}
	}
	writeFields(req.Dimensions)
	writeFields(req.Measures)
	// granularity 截断列追加在 SELECT 末尾
	for _, gc := range granByDim {
		if !first {
			sql.WriteString(", ")
		}
		fmt.Fprintf(&sql, "%s AS \"%s\"", gc.expr, gc.alias)
		first = false
	}
	if first {
		sql.WriteString("1")
	}

	// FROM（延迟写入，等 timeDimensions 循环替换占位符后再拼）
	fromSQL := cube.GetSQLTable()
	sql.WriteString(" FROM ")

	// WHERE / HAVING
	var where []string
	var having []string

	// isMeasure 判断某个 member 是否为 measure 字段（需走 HAVING）
	isMeasure := func(member string) bool {
		_, fieldName, _ := splitMemberName(member)
		_, ok := cube.Measures[fieldName]
		return ok
	}

	// segments
	for _, seg := range req.Segments {
		_, segName, _ := splitMemberName(seg)
		if s, ok := cube.Segments[segName]; ok && s.SQL != "" {
			where = append(where, s.SQL)
		}
	}

	// filters
	for _, filter := range req.Filters {
		// or 复合条件：将子条件以 OR 拼接后用括号包裹
		if len(filter.Or) > 0 {
			// or 与普通条件字段互斥，不允许同时存在
			if filter.Member != "" || filter.Operator != "" || filter.Values != nil {
				return "", nil, fmt.Errorf("filter 不能同时包含 or 和 member/operator/values 字段")
			}
			var orClauses []string
			var orParams []interface{}
			for _, sub := range filter.Or {
				clause, p := buildFilterClause(sub, cube)
				if clause != "" {
					orClauses = append(orClauses, clause)
					orParams = append(orParams, p...)
				}
			}
			if len(orClauses) > 0 {
				// or 条件如含 measure 子句放 HAVING，否则 WHERE
				hasMeasure := false
				for _, sub := range filter.Or {
					if isMeasure(sub.Member) {
						hasMeasure = true
						break
					}
				}
				combined := "(" + strings.Join(orClauses, " OR ") + ")"
				if hasMeasure {
					having = append(having, combined)
					havingParams = append(havingParams, orParams...)
				} else {
					where = append(where, combined)
					whereParams = append(whereParams, orParams...)
				}
			}
			continue
		}

		clause, p := buildFilterClause(filter, cube)
		if clause != "" {
			if isMeasure(filter.Member) {
				having = append(having, clause)
				havingParams = append(havingParams, p...)
			} else {
				where = append(where, clause)
				whereParams = append(whereParams, p...)
			}
		}
	}

	// timeDimensions
	for _, td := range req.TimeDimensions {
		_, fieldName, subKey := splitMemberName(td.Dimension)
		field, ok := cube.GetField(fieldName, subKey)
		if !ok || td.DateRange.V == nil {
			continue
		}
		if clause, p := buildTimeDimensionClause(field.SQL, td.DateRange); clause != "" {
			where = append(where, clause)
			whereParams = append(whereParams, p...)
			// 同步替换子查询中的占位符（使用原始列名而非 dimension SQL 表达式）
			placeholder := "{filter." + fieldName + "}"
			if strings.Contains(fromSQL, placeholder) {
				subClause, _ := buildTimeDimensionClause(fieldName, td.DateRange)
				fromSQL = strings.ReplaceAll(fromSQL, placeholder, subClause)
			}
		}
	}
	// 没有匹配 timeDimension 的占位符，替换为 1=1（不过滤，保留全量数据）
	if i := strings.Index(fromSQL, "{filter."); i >= 0 {
		j := strings.Index(fromSQL[i:], "}")
		if j < 0 {
			return "", nil, fmt.Errorf("SQL placeholder starting at position %d is not closed (missing '}')", i)
		}
		placeholder := fromSQL[i : i+j+1]
		fromSQL = strings.ReplaceAll(fromSQL, placeholder, "1=1")
	}
	sql.WriteString(fromSQL)

	if len(where) > 0 {
		sql.WriteString(" WHERE ")
		sql.WriteString(strings.Join(where, " AND "))
	}

	// 有 measures 且有 dimension/granularity 时才拼 GROUP BY；纯 measures 做全表聚合，空 GROUP BY 在 ClickHouse 会报语法错误
	if len(req.Measures) > 0 && (len(req.Dimensions) > 0 || len(granByDim) > 0) {
		sql.WriteString(" GROUP BY ")
		groupFirst := true
		for _, dim := range req.Dimensions {
			if !groupFirst {
				sql.WriteString(", ")
			}
			_, fieldName, subKey := splitMemberName(dim)
			if field, ok := cube.GetField(fieldName, subKey); ok {
				sql.WriteString(field.SQL)
			} else {
				sql.WriteString(dim)
			}
			groupFirst = false
		}
		for _, gc := range granByDim {
			if !groupFirst {
				sql.WriteString(", ")
			}
			sql.WriteString(gc.expr)
			groupFirst = false
		}
	}

	// HAVING
	if len(having) > 0 {
		sql.WriteString(" HAVING ")
		sql.WriteString(strings.Join(having, " AND "))
	}

	// params: WHERE params first, then HAVING params — must match ? placeholder order in SQL
	params = append(whereParams, havingParams...)

	// ORDER BY
	if len(req.Order) > 0 {
		sql.WriteString(" ORDER BY ")
		for i, item := range req.Order {
			if i > 0 {
				sql.WriteString(", ")
			}
			if gc, ok := granByDim[item.Member]; ok {
				sql.WriteString(gc.expr)
			} else {
				_, fieldName, subKey := splitMemberName(item.Member)
				if f, ok := cube.GetField(fieldName, subKey); ok {
					sql.WriteString(f.SQL)
				} else {
					sql.WriteString(item.Member)
				}
			}
			if item.Direction == "desc" {
				sql.WriteString(" DESC")
			}
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
	case "this week":
		return "toStartOfWeek(now())", "toStartOfWeek(addWeeks(now(), 1))", true
	case "last week":
		return "toStartOfWeek(addWeeks(now(), -1))", "toStartOfWeek(now())", true
	case "this month":
		return "toStartOfMonth(now())", "toStartOfMonth(addMonths(now(), 1))", true
	case "last month":
		return "toStartOfMonth(addMonths(now(), -1))", "toStartOfMonth(now())", true
	case "this year":
		return "toStartOfYear(now())", "toStartOfYear(addYears(now(), 1))", true
	case "last year":
		return "toStartOfYear(addYears(now(), -1))", "toStartOfYear(now())", true
	case "today":
		return "toStartOfDay(now())", "toStartOfDay(addDays(now(), 1))", true
	case "yesterday":
		return "toStartOfDay(addDays(now(), -1))", "toStartOfDay(now())", true
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

// buildFilterClause 将单个非 or 的 Filter 转换为 SQL 条件片段和绑定参数。
// 若字段不存在或条件无法生成，返回空字符串。
func buildFilterClause(filter Filter, cube *model.Cube) (string, []interface{}) {
	_, fieldName, subKey := splitMemberName(filter.Member)
	field, ok := cube.GetField(fieldName, subKey)
	if !ok || field.SQL == "" {
		return "", nil
	}

	// set/notSet 对所有类型统一处理
	switch filter.Operator {
	case "set":
		return fmt.Sprintf("notEmpty(%s)", field.SQL), nil
	case "notSet":
		return fmt.Sprintf("empty(%s)", field.SQL), nil
	}

	valuesArr, _ := filter.Values.([]interface{})
	if len(valuesArr) == 0 && filter.Values != nil {
		valuesArr = []interface{}{filter.Values}
	}
	if len(valuesArr) == 0 {
		return "", nil
	}

	if field.Type == "array" {
		clause, p := buildArrayClause(field.SQL, filter.Operator, valuesArr)
		return clause, p
	}

	// 普通字段
	if filter.Operator == "equals" || filter.Operator == "notEquals" {
		return buildInClause(field.SQL, filter.Operator, valuesArr)
	}
	sqlOp := convertOperator(filter.Operator)
	value := processFilterValue(valuesArr[0], filter.Operator)
	return fmt.Sprintf("%s %s ?", field.SQL, sqlOp), []interface{}{value}
}
