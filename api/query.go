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
	Mask           bool            `json:"-"`
	// Vars 供调用方注入模板变量，不经 HTTP 传递。
	// 键值对替换 SQL 中的 {vars.key} 占位符。
	Vars map[string][]string `json:"-"`
}

// DateRange 支持字符串或字符串数组格式
type DateRange struct{ V interface{} }

func (dr DateRange) MarshalJSON() ([]byte, error) { return json.Marshal(dr.V) }

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
	return fmt.Errorf("dateRange must be a string or array of strings, got: %s", string(data))
}

type TimeDimension struct {
	Dimension   string    `json:"dimension"`
	DateRange   DateRange `json:"dateRange"`
	Granularity string    `json:"granularity,omitempty"`
}

type OrderItem struct {
	Member    string `json:"member"`
	Direction string `json:"direction"`
}

// OrderList 反序列化支持两种格式:
// 数组格式: [["field","asc"],...]  (有序，推荐)
// 对象格式: {"field":"asc",...}    (无序，兼容旧格式)
// 序列化始终使用数组格式以保留顺序。
type OrderList []OrderItem

func (o OrderList) MarshalJSON() ([]byte, error) {
	arr := make([][]string, 0, len(o))
	for _, item := range o {
		if item.Member == "" {
			continue
		}
		arr = append(arr, []string{item.Member, item.Direction})
	}
	return json.Marshal(arr)
}

func (o *OrderList) UnmarshalJSON(data []byte) error {
	// 数组格式: [["field","dir"],...]
	var arr [][]string
	if json.Unmarshal(data, &arr) == nil {
		list := make(OrderList, 0, len(arr))
		for _, pair := range arr {
			if len(pair) == 2 && pair[0] != "" {
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
		if k != "" {
			list = append(list, OrderItem{k, v})
		}
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

// buildTimeDimensionClause 根据 dateRange 生成时间过滤片段，值直接内联进 SQL。
func buildTimeDimensionClause(colSQL string, dr DateRange) string {
	switch v := dr.V.(type) {
	case []string:
		if len(v) == 2 {
			start := "'" + strings.ReplaceAll(v[0], "'", "''") + "'"
			end := "'" + strings.ReplaceAll(v[1], "'", "''") + "'"
			return fmt.Sprintf("%s >= %s AND %s <= %s", colSQL, start, colSQL, end)
		}
	case string:
		if v != "" {
			if start, end, ok := parseRelativeTimeRange(v); ok {
				return fmt.Sprintf("%s >= %s AND %s <= %s", colSQL, start, colSQL, end)
			}
			return fmt.Sprintf("toDate(%s) = %s", colSQL, convertToClickHouseTimeExpr(v))
		}
	}
	return ""
}

func BuildQuery(req *QueryRequest, cube *model.Cube) (string, []interface{}, error) {
	mask := req.Mask

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
				effectiveSQL := field.SQL
				if mask && field.SQLMask != "" {
					effectiveSQL = field.SQLMask
				}
				fmt.Fprintf(&sql, "%s AS \"%s\"", effectiveSQL, name)
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

	sql.WriteString(" FROM ")

	// PREWHERE / WHERE / HAVING
	var prewhere []string
	var where []string
	var having []string

	// isMeasure 判断某个 member 是否为 measure 字段（需走 HAVING）
	isMeasure := func(member string) bool {
		_, fieldName, _ := splitMemberName(member)
		_, ok := cube.Measures[fieldName]
		return ok
	}

	// applyVars 替换 SQL 模板中的 {vars.key}，每个值加单引号并转义；
	// key 不存在或值为空 slice 时返回 "" 表示跳过（用于 segment）。
	applyVars := func(tmpl string) string {
		for k, vals := range req.Vars {
			ph := "{vars." + k + "}"
			if !strings.Contains(tmpl, ph) {
				continue
			}
			if len(vals) == 0 {
				return "" // 空 slice 整体跳过 segment
			}
			quoted := make([]string, len(vals))
			for i, v := range vals {
				quoted[i] = "'" + strings.ReplaceAll(v, "'", "''") + "'"
			}
			tmpl = strings.ReplaceAll(tmpl, ph, strings.Join(quoted, ","))
		}
		if strings.Contains(tmpl, "{vars.") {
			return "" // key 不存在，跳过该 segment
		}
		return tmpl
	}

	// fromSQL 中未提供的占位符降级为 ''（子查询不能整体跳过）
	fromSQL := applyVars(cube.GetSQLTable())
	if fromSQL == "" {
		fromSQL = cube.GetSQLTable()
		for strings.Contains(fromSQL, "{vars.") {
			s, e := strings.Index(fromSQL, "{vars."), 0
			if e = strings.Index(fromSQL[s:], "}"); e < 0 {
				break
			}
			fromSQL = fromSQL[:s] + "''" + fromSQL[s+e+1:]
		}
	}
	for _, seg := range req.Segments {
		_, segName, _ := splitMemberName(seg)
		s, ok := cube.Segments[segName]
		if !ok || s.SQL == "" {
			continue
		}
		if result := applyVars(s.SQL); result != "" {
			prewhere = append(prewhere, result)
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
		if clause := buildTimeDimensionClause(field.SQL, td.DateRange); clause != "" {
			where = append(where, clause)
			placeholder := "{filter." + fieldName + "}"
			if strings.Contains(fromSQL, placeholder) {
				fromSQL = strings.ReplaceAll(fromSQL, placeholder, buildTimeDimensionClause(fieldName, td.DateRange))
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

	if len(prewhere) > 0 {
		sql.WriteString(" PREWHERE ")
		sql.WriteString(strings.Join(prewhere, " AND "))
	}

	if len(where) > 0 {
		sql.WriteString(" WHERE ")
		sql.WriteString(strings.Join(where, " AND "))
	}

	// cube的规则是：1.ungrouped: true → 只能有 dimensions，返回明细
	// 2. ungrouped: false（默认）→ dimensions + measures 自由组合，有聚合就有 GROUP BY
	if !req.Ungrouped && (len(req.Dimensions) > 0 || len(granByDim) > 0) {
		var groupCols []string
		for _, dim := range req.Dimensions {
			groupCols = append(groupCols, fmt.Sprintf("\"%s\"", dim))
		}
		for _, gc := range granByDim {
			groupCols = append(groupCols, gc.expr)
		}
		sql.WriteString(" GROUP BY ")
		sql.WriteString(strings.Join(groupCols, ", "))
	}

	// HAVING
	if len(having) > 0 {
		sql.WriteString(" HAVING ")
		sql.WriteString(strings.Join(having, " AND "))
	}

	// params: WHERE params, then HAVING
	params = append(whereParams, havingParams...)

	// ORDER BY
	// 如果显式指定了排序，按请求排序；否则若存在带粒度的时间维度，隐式升序（兼容 CubeJS 默认行为）
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
	} else if len(granByDim) > 0 {
		// 隐式排序：取第一个带粒度的时间维度，按 timeDimensions 顺序确定
		for _, td := range req.TimeDimensions {
			if gc, ok := granByDim[td.Dimension]; ok {
				sql.WriteString(" ORDER BY ")
				sql.WriteString(gc.expr)
				sql.WriteString(" ASC")
				break
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
