package api

import (
	"encoding/json"
	"fmt"
	"log"
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
	Query      QueryRequest `json:"query"`
	Data       []RowData    `json:"data"`
	Annotation Annotation   `json:"annotation"`
}

type RowData = map[string]interface{}

type Annotation struct {
	Measures       map[string]MemberAnnotation `json:"measures"`
	Dimensions     map[string]MemberAnnotation `json:"dimensions"`
	Segments       map[string]MemberAnnotation `json:"segments"`
	TimeDimensions map[string]MemberAnnotation `json:"timeDimensions"`
}

type MemberAnnotation struct {
	Title      string `json:"title"`
	ShortTitle string `json:"shortTitle"`
	Type       string `json:"type,omitempty"`
}

// annotateMembers 为一组成员名构建 annotation map。
func annotateMembers[T model.Annotatable](names []string, members map[string]T) map[string]MemberAnnotation {
	out := make(map[string]MemberAnnotation, len(names))
	for _, name := range names {
		_, fieldName, _ := splitMemberName(name)
		m, ok := members[fieldName]
		if !ok {
			continue
		}
		short := m.MemberTitle()
		if short == "" {
			short = fieldName
		}
		out[name] = MemberAnnotation{Title: short, ShortTitle: short, Type: m.MemberType()}
	}
	return out
}

// buildAnnotation 根据请求和 cube 模型构建 annotation 元数据。
func buildAnnotation(req *QueryRequest, cube *model.Cube) Annotation {
	tdNames := make([]string, len(req.TimeDimensions))
	for i, td := range req.TimeDimensions {
		tdNames[i] = td.Dimension
	}
	return Annotation{
		Dimensions:     annotateMembers(req.Dimensions, cube.Dimensions),
		Measures:       annotateMembers(req.Measures, cube.Measures),
		Segments:       annotateMembers(req.Segments, cube.Segments),
		TimeDimensions: annotateMembers(tdNames, cube.Dimensions),
	}
}

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

// formatArg 将绑定参数格式化为 SQL 字面值：字符串加单引号并转义，其余 fmt.Sprintf。
func formatArg(v interface{}) string {
	s, ok := v.(string)
	if !ok {
		return fmt.Sprintf("%v", v)
	}
	return "'" + strings.ReplaceAll(s, "'", "''") + "'"
}

func buildQuery(req *QueryRequest, cube *model.Cube) (string, error) {
	mask := req.Mask

	var sql strings.Builder
	var where, having []string

	// 收集有 granularity 的时间维度：dimension -> (alias, expr)
	type granCol struct{ alias, expr string }
	granByDim := map[string]granCol{}
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
		granByDim[td.Dimension] = granCol{
			alias: td.Dimension + "." + td.Granularity,
			expr:  fmt.Sprintf("%s(%s)", fn, field.SQL),
		}
	}

	// SELECT
	var cols []string
	for _, name := range append(req.Dimensions, req.Measures...) {
		_, fieldName, subKey := splitMemberName(name)
		field, ok := cube.GetField(fieldName, subKey)
		if !ok {
			log.Printf("WARN: unknown member %q not found in cube %q, skipped", name, cube.Name)
			continue
		}
		effectiveSQL := field.SQL
		if mask && field.SQLMask != "" {
			effectiveSQL = field.SQLMask
		}
		cols = append(cols, fmt.Sprintf("%s AS \"%s\"", effectiveSQL, name))
	}
	for _, gc := range granByDim {
		cols = append(cols, fmt.Sprintf("%s AS \"%s\"", gc.expr, gc.alias))
	}
	if len(cols) == 0 {
		sql.WriteString("SELECT 1")
	} else {
		sql.WriteString("SELECT " + strings.Join(cols, ", "))
	}

	sql.WriteString(" FROM ")

	// isMeasure 判断某个 member 是否为 measure 字段（需走 HAVING）
	isMeasure := func(member string) bool {
		_, fieldName, _ := splitMemberName(member)
		_, ok := cube.Measures[fieldName]
		return ok
	}

	// 预计算 filterVars：fieldName -> 已内联值的 SQL 条件片段，供 {filter.field} 替换使用。
	// 优先级：TimeDimension > Filter（与原逻辑一致）。
	filterVars := map[string]string{}
	for _, td := range req.TimeDimensions {
		_, fn, _ := splitMemberName(td.Dimension)
		if c := buildTimeDimensionClause(fn, td.DateRange); c != "" {
			filterVars[fn] = c
		}
	}
	for _, f := range req.Filters {
		if len(f.Or) > 0 {
			continue
		}
		_, fn, _ := splitMemberName(f.Member)
		if _, exists := filterVars[fn]; exists {
			continue
		}
		c := buildFilterClause(f, cube)
		if c != "" {
			filterVars[fn] = c
		}
	}

	// applyVars 替换 SQL 中的 {vars.key} 和 {filter.field} 占位符。
	// {vars.key}：有值内联带引号；key 不存在或值为空时返回 "" 跳过整个模板。
	// {filter.field}：查预计算的 filterVars，无匹配降级为 1=1。
	applyVars := func(tmpl string) string {
		for k, vals := range req.Vars {
			ph := "{vars." + k + "}"
			if !strings.Contains(tmpl, ph) || len(vals) == 0 {
				continue
			}
			quoted := make([]string, len(vals))
			for i, v := range vals {
				quoted[i] = "'" + strings.ReplaceAll(v, "'", "''") + "'"
			}
			tmpl = strings.ReplaceAll(tmpl, ph, strings.Join(quoted, ","))
		}
		if strings.Contains(tmpl, "{vars.") {
			return ""
		}
		for fn, clause := range filterVars {
			tmpl = strings.ReplaceAll(tmpl, "{filter."+fn+"}", clause)
		}
		for strings.Contains(tmpl, "{filter.") {
			s := strings.Index(tmpl, "{filter.")
			e := strings.Index(tmpl[s:], "}")
			if e < 0 {
				break
			}
			tmpl = strings.ReplaceAll(tmpl, tmpl[s:s+e+1], "1=1")
		}
		return tmpl
	}

	fromSQL := applyVars(cube.GetSQLTable())

	for _, seg := range req.Segments {
		_, segName, _ := splitMemberName(seg)
		s, ok := cube.Segments[segName]
		if !ok || s.SQL == "" {
			if !ok {
				log.Printf("WARN: unknown segment %q not found in cube %q, skipped", seg, cube.Name)
			}
			continue
		}
		if result := applyVars(s.SQL); result != "" {
			where = append(where, result)
		}
	}

	// filters
	for _, filter := range req.Filters {
		// or 复合条件：将子条件以 OR 拼接后用括号包裹
		if len(filter.Or) > 0 {
			// or 与普通条件字段互斥，不允许同时存在
			if filter.Member != "" || filter.Operator != "" || filter.Values != nil {
				return "", fmt.Errorf("filter 不能同时包含 or 和 member/operator/values 字段")
			}
			var orClauses []string
			hasMeasure := false
			for _, sub := range filter.Or {
				clause := buildFilterClause(sub, cube)
				if clause != "" {
					orClauses = append(orClauses, clause)
				}
				if isMeasure(sub.Member) {
					hasMeasure = true
				}
			}
			if len(orClauses) > 0 {
				combined := "(" + strings.Join(orClauses, " OR ") + ")"
				if hasMeasure {
					having = append(having, combined)
				} else {
					where = append(where, combined)
				}
			}
			continue
		}

		clause := buildFilterClause(filter, cube)
		if clause != "" {
			if isMeasure(filter.Member) {
				having = append(having, clause)
			} else {
				where = append(where, clause)
			}
		}
	}

	// timeDimensions: 统一追加到 WHERE，不再自动路由到 PREWHERE。
	for _, td := range req.TimeDimensions {
		_, fieldName, subKey := splitMemberName(td.Dimension)
		field, ok := cube.GetField(fieldName, subKey)
		if !ok || td.DateRange.V == nil {
			continue
		}
		if clause := buildTimeDimensionClause(field.SQL, td.DateRange); clause != "" {
			where = append(where, clause)
		}
	}
	sql.WriteString(fromSQL)

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
	limit := req.Limit
	if limit <= 0 {
		limit = 1000
	}
	fmt.Fprintf(&sql, " LIMIT %d", limit)
	if req.Offset > 0 {
		fmt.Fprintf(&sql, " OFFSET %d", req.Offset)
	}

	return sql.String(), nil
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

// buildArrayClause 针对数组类型字段生成 has/hasAll/hasAny 条件
// 单值：has(arr, val)
// 多值：equals -> hasAll，contains -> hasAny
func buildArrayClause(fieldSQL string, operator string, values []interface{}) string {
	negate := operator == "notEquals" || operator == "notContains"
	neg := ""
	if negate {
		neg = "NOT "
	}
	if len(values) == 1 {
		return fmt.Sprintf("%shas(%s, %s)", neg, fieldSQL, formatArg(values[0]))
	}
	lit := make([]string, len(values))
	for i, v := range values {
		lit[i] = formatArg(v)
	}
	placeholders := strings.Join(lit, ",")
	fn := "hasAny"
	if operator == "equals" || operator == "notEquals" {
		fn = "hasAll"
	}
	return fmt.Sprintf("%s%s(%s, [%s])", neg, fn, fieldSQL, placeholders)
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

// processFilterValue 根据操作符和值列表生成 SQL 条件片段（值直接内联）。
// contains/notContains 支持多值，多值时用 OR/AND 拼接并加括号。
func processFilterValue(fieldSQL string, operator string, valuesArr []interface{}) string {
	op, ok := operatorMap[operator]
	if !ok {
		op = operator
	}
	sep := " OR "
	if operator == "notContains" {
		sep = " AND "
	}
	clauses := make([]string, 0, len(valuesArr))
	for _, v := range valuesArr {
		s := fmt.Sprintf("%v", v)
		switch operator {
		case "contains", "notContains":
			s = "%" + s + "%"
		case "startsWith":
			s = s + "%"
		case "endsWith":
			s = "%" + s
		}
		clauses = append(clauses, fmt.Sprintf("%s %s %s", fieldSQL, op, formatArg(s)))
	}
	combined := strings.Join(clauses, sep)
	if len(clauses) > 1 {
		combined = "(" + combined + ")"
	}
	return combined
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

// buildFilterClause 将单个非 or 的 Filter 转换为 SQL 条件片段（值直接内联）。
// 若字段不存在或条件无法生成，返回空字符串。
func buildFilterClause(filter Filter, cube *model.Cube) string {
	_, fieldName, subKey := splitMemberName(filter.Member)
	field, ok := cube.GetField(fieldName, subKey)
	if !ok || field.SQL == "" {
		if !ok {
			log.Printf("WARN: filter references unknown member %q not found in cube %q, skipped", filter.Member, cube.Name)
		}
		return ""
	}

	switch filter.Operator {
	case "set":
		return fmt.Sprintf("notEmpty(%s)", field.SQL)
	case "notSet":
		return fmt.Sprintf("empty(%s)", field.SQL)
	}

	valuesArr, _ := filter.Values.([]interface{})
	if len(valuesArr) == 0 && filter.Values != nil {
		valuesArr = []interface{}{filter.Values}
	}
	if len(valuesArr) == 0 {
		return ""
	}

	if field.Type == "array" {
		return buildArrayClause(field.SQL, filter.Operator, valuesArr)
	}
	if filter.Operator == "equals" || filter.Operator == "notEquals" {
		lit := make([]string, len(valuesArr))
		for i, v := range valuesArr {
			lit[i] = formatArg(v)
		}
		neg := ""
		if filter.Operator == "notEquals" {
			neg = "NOT "
		}
		return fmt.Sprintf("%s %sIN (%s)", field.SQL, neg, strings.Join(lit, ","))
	}
	return processFilterValue(field.SQL, filter.Operator, valuesArr)
}
