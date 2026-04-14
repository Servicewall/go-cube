# SQL 拼接设计

go-cube 将 CubeJS 兼容的 JSON 查询请求翻译为 ClickHouse SQL，入口为 `api/query.go` 的 `BuildQuery(req, cube) → (sql, params, error)`。

## 整体数据流

```
QueryRequest (CubeJS JSON)
    ↓
BuildQuery
    ├── SELECT   dimensions + measures + granularity 截断列
    ├── FROM     cube.GetSQLTable()，支持 {filter.<field>} 占位符替换
    ├── PREWHERE segments + 安全可下推的 timeDimensions（仅物理表）
    ├── WHERE    filters(dimension 字段) + 其余 timeDimensions
    ├── GROUP BY ungrouped=false 且有 dimensions 或 granularity 时生成，使用 field.SQL（非别名）
    ├── HAVING   filters(measure 字段)
    ├── ORDER BY 支持 granularity 表达式，查 granByDim map
    └── LIMIT / OFFSET
    ↓
(sqlString, []interface{} params)
    ↓
ClickHouse HTTP client（值内联替换，无 ? 占位符）
```

## 各子句生成规则

### SELECT

每个 dimension / measure 解析为 `field.SQL AS "CubeName.fieldName"`。

有 granularity 的时间维度额外追加截断列，例如：
```sql
toStartOfMinute(ts) AS "AccessView.ts.minute"
```

### FROM

`cube.GetSQLTable()` 返回：
- 若 cube 定义了 `sql_table`：直接返回表名
- 若定义了 `sql`（子查询）：返回 `(SELECT ...) AS CubeName`

子查询内可含 `{filter.<field>}` 占位符，在 timeDimensions 循环内同步替换（见下文）。

### WHERE / HAVING 路由

`isMeasure(member)` 检查字段是否在 `cube.Measures` 中：
- dimension 字段 → WHERE
- measure 字段 → HAVING

OR 复合条件：任一子条件是 measure 则整体走 HAVING。

segments 在物理表 cube 上追加到 `PREWHERE`；子查询 cube 上退回 `WHERE`，无参数绑定。

timeDimensions 默认生成时间范围条件。若满足“物理表 + `time` 字段 + 非 `arrayJoin` 表达式”的保守规则，则下推到 `PREWHERE`；否则保留在 `WHERE`。

### GROUP BY

`ungrouped=false`（默认）且请求包含 dimensions 或带 granularity 的时间维度时生成。使用 `field.SQL`（原始表达式），不使用 SELECT 别名，兼容 ClickHouse 语义。

仅有 measures、无任何 dimensions / granularity 时，不生成 GROUP BY——ClickHouse 对聚合函数做全表聚合，无需显式 GROUP BY。

纯 dimensions 查询（无 measures）也会生成 GROUP BY，语义等价于 DISTINCT 去重，适用于 `arrayJoin` 展开后取去重标签值列表等场景。

### ORDER BY

**显式排序**：请求携带 `order` 字段时，按其指定的成员和方向生成 ORDER BY。
granularity 时间维度的排序使用截断表达式（如 `toStartOfMinute(ts)`）而非原始列名。
实现上通过 `granByDim map[string]granularityCol`（key = `td.Dimension`）在函数入口一次性计算，SELECT / GROUP BY / ORDER BY 三处共用，避免重复解析。

**隐式排序**（兼容 CubeJS 默认行为）：`order` 为空且请求包含带 granularity 的时间维度时，自动按 `timeDimensions` 中第一个有粒度的维度 **ASC** 排序：

```sql
-- 示例：granularity = "minute"，无 order 字段
ORDER BY toStartOfMinute(ts) ASC
```

这与 CubeJS 的隐式排序规则一致（第一个带粒度的时间维度升序），解决前端图表 x 轴时间乱序问题。若不希望隐式排序，需显式传入 `order: []`（空数组）—— 但当前实现会将空数组解析为 0 个 OrderItem，与未传 order 等价，即无法通过空数组关闭隐式排序（CubeJS 完整语义，此处简化处理）。

## 参数绑定与顺序保证

ClickHouse HTTP 接口不支持 prepared statement，所有值直接内联进 SQL 字符串。

filter 条件中的字符串值用单引号包裹并转义（`'` → `''`），由 `clickhouse.go` 的 `Query` 方法在发送前按 `?` 出现顺序逐一替换。

WHERE 参数（`whereParams`）和 HAVING 参数（`havingParams`）**必须分两组收集**，最后 `append(whereParams, havingParams...)` 合并。

原因：filter 循环里 WHERE/HAVING 条件的 append 顺序取决于请求中 filter 的排列，但 SQL 字符串里 WHERE 的 `?` 永远在 HAVING 的 `?` 之前，两组分离才能保证顺序正确。

timeDimensions 的时间范围条件（包括绝对时间范围 `["2026-01-01", "2026-01-31"]` 和相对时间）均直接内联进 SQL，不产生 `?` 参数，原因是子查询内 `{filter.<field>}` 占位符替换也必须内联，统一处理可避免两套路径。

## 子查询占位符替换（{filter.\<field\>}）

部分 cube 的 `sql` 是多层子查询（如 `ApiView`），时间过滤需下推到最内层原始表，否则会全表扫描后再过滤。

**机制**：子查询 SQL 中用 `{filter.ts}` 作占位符，`BuildQuery` 在 timeDimensions 循环内，生成外层 WHERE 条件的同时，用相同的 dateRange 生成针对原始列名的条件，替换占位符：

```sql
-- ApiView.yaml 中的子查询片段
FROM default.access_sample_raw
WHERE {filter.ts}

-- 替换后（dateRange = "from 15 minutes ago to 15 minutes from now"）
WHERE ts >= now() - INTERVAL 15 MINUTE AND ts <= now() + INTERVAL 15 MINUTE
```

FROM 写入被延迟到 timeDimensions 循环结束后，确保所有占位符已替换。若循环结束仍有未替换的 `{filter.`，返回 error。

## array 类型字段的过滤

`type: array` 字段不使用 `IN`，使用 ClickHouse 数组函数：

| 场景 | 生成 SQL |
|------|---------|
| 单值 equals | `has(arr, ?)` |
| 多值 equals | `hasAll(arr, [?,?,...])` |
| 多值 contains | `hasAny(arr, [?,?,...])` |
| notEquals / notContains | 前缀 `NOT` |

## set / notSet 过滤

`set` 和 `notSet` 是两个特殊操作符，不需要 values，直接检查字段是否为空：

| 操作符 | 生成 SQL |
|--------|---------|
| `set` | `notEmpty(field)` |
| `notSet` | `empty(field)` |

## 相对时间表达式

相对时间直接翻译为 ClickHouse 函数表达式，内联进 SQL，不产生参数绑定：

```
"from 15 minutes ago to 15 minutes from now"
→ ts >= now() - INTERVAL 15 MINUTE AND ts <= now() + INTERVAL 15 MINUTE

"last month"
→ ts >= toStartOfMonth(addMonths(now(), -1)) AND ts <= toStartOfMonth(now())
```

绝对时间范围（数组格式 `["2026-01-01", "2026-01-31"]`）同样内联进 SQL，不使用 `?` 绑定。

## 有意省略的功能

| 功能 | 说明 |
|------|------|
| `timezone` 时区转换 | 字段保留兼容性，ClickHouse 服务端已配置时区，Go 层不处理 |
| response 元数据字段 | `transformedQuery`、`annotation` 等前端不读取，省略 |
| SQL 预编译 | ClickHouse HTTP 接口不支持，用字符串替换代替 |
| 缓存 / 预聚合 | CubeJS 核心复杂度来源，完全省略 |
