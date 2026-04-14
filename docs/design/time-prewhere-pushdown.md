# timeDimensions PREWHERE 下推方案

## 背景

当前 `BuildQuery` 会将：

- `segments` 下推到 `PREWHERE`（仅物理表 cube）
- `timeDimensions` 固定追加到 `WHERE`

这导致 `ApiDayView.dt` 这类直接落在物理表上的时间过滤无法参与 `PREWHERE` 提前裁剪。

## 目标

对安全场景的 `timeDimensions` 做选择性下推：

- 物理表 cube：允许下推到 `PREWHERE`
- 子查询 cube：保持在 `WHERE`
- 不改变现有 `HAVING`、`filters`、`{filter.<field>}` 子查询占位符替换语义

## 非目标

- 不将所有 `filters` 一并下推到 `PREWHERE`
- 不修改时间范围表达式生成逻辑
- 不重写 schema 中时间维度定义

## 安全规则

仅当同时满足以下条件时，`timeDimensions` 条件追加到 `PREWHERE`：

1. cube 使用 `sql_table`
2. cube 不使用 `sql` 子查询
3. 字段类型为 `time`
4. 字段 SQL 非空
5. 字段 SQL 不包含 `arrayJoin`

否则仍追加到 `WHERE`。

## 原因

- 物理表上的时间列通常适合尽早过滤
- 子查询 cube 仍需保留外层 `WHERE` 语义，同时兼容 `{filter.ts}` 这类内层占位符替换
- 规则保守，优先避免错误下推复杂表达式

## 测试

需要覆盖两类回归：

1. 物理表 cube 的 `timeDimensions` 进入 `PREWHERE`
2. 子查询 cube 的 `timeDimensions` 仍留在 `WHERE`，且 `{filter.ts}` 继续被正确替换
