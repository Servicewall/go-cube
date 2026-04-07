# Go-Cube

Cube.js的Go语言最小替换实现，专注于ClickHouse性能和简洁性。

## 特性

**Cube.js 兼容**
- ✅ 兼容Cube.js REST API (`/load`)
- ✅ 官方YAML格式模型定义
- ✅ 基本查询功能：dimensions, measures, filters, order, limit/offset

**Go-Cube 增强**
- ⚡ ClickHouse原生性能优化，直接SQL拼接无模板引擎开销
- ⚡ 数组类型字段支持，filter 自动使用 `has`/`hasAll`/`hasAny` 替代 `LIKE`
- ⚡ 单二进制部署，无Node.js依赖，无外部依赖
- ⚡ 可作为Go库直接嵌入调用，无需独立HTTP服务

## 架构设计

```
go-cube/
├── main.go                 # HTTP服务器入口
├── api/
│   ├── handler.go         # REST API处理器
│   └── query.go           # 查询解析和验证
├── model/
│   ├── loader.go          # YAML模型加载器
│   └── schema.go          # 数据结构定义
├── sql/
│   ├── builder.go         # SQL构建器（直接拼接）
│   └── clickhouse.go      # ClickHouse连接和执行
└── config/
    └── config.go          # 配置管理
```

## 快速开始

### 1. 安装

```bash
# 克隆项目
git clone <repository>
cd go-cube

# 编译
go build -o go-cube .
```

### 2. 作为库嵌入使用（v2推荐方式）

go-cube 可以作为Go库直接嵌入到您的应用中，无需启动独立的HTTP服务（端口4000）：

```go
import (
    "time"
    "github.com/Servicewall/go-cube/api"
)

// 初始化（只需调用一次）
err := api.Init(
    []string{"localhost:9000"},
    "default",        // database
    "default",        // username
    "",               // password
    60*time.Second,   // query timeout（可选，默认30s）
)
if err != nil {
    log.Fatal(err)
}

// 挂载到路由（标准库）
mux := http.NewServeMux()
mux.Handle("/cube/load", api.HTTPHandler())

// 挂载到 gin
engine.Any("/cube-api/v2/load", gin.WrapH(api.HTTPHandler()))
```

### 3. 配置

创建 `config.yaml`:

```yaml
server:
  port: 4000
  read_timeout: 30s
  write_timeout: 30s

clickhouse:
  hosts:
    - localhost:9000
  database: default
  username: default
  password: ""
  dial_timeout: 10s
  max_open_conns: 10
  max_idle_conns: 5

models:
  path: ./models
  watch: false
```

### 3. 创建模型

在 `models/` 目录下创建YAML模型文件，例如 `AccessView.yaml`:

```yaml
cube:
  name: AccessView
  sql: SELECT * FROM default.access_view
  
  dimensions:
    id:
      sql: id
      type: string
      primary_key: true
      title: ID
    
    ts:
      sql: ts
      type: time
      title: 时间
  
  measures:
    count:
      sql: count()
      type: number
      title: 访问量
```

### 4. 运行

```bash
# 使用默认配置
./go-cube

# 指定配置文件
./go-cube /path/to/config.yaml
```

### 5. 测试查询

```bash
# 健康检查
curl http://localhost:4000/health

# Cube.js兼容查询
curl "http://localhost:4000/load?query=%7B%22dimensions%22%3A%5B%22AccessView.id%22%2C%22AccessView.ts%22%5D%2C%22measures%22%3A%5B%22AccessView.count%22%5D%2C%22limit%22%3A10%7D"
```

## API兼容性

### 支持的查询参数

- `dimensions`: 维度字段列表
- `measures`: 度量字段列表  
- `filters`: 过滤条件，支持普通字段和数组类型字段高性能过滤
- `order`: 排序规则
- `limit`: 返回行数限制
- `offset`: 偏移量
- `timeDimensions`: 时间维度（简化实现）
- `timezone`: 时区

### 响应格式

```json
{
  "queryType": "regularQuery",
  "results": [
    {
      "query": { ... },
      "data": [
        { "field1": "value1", "field2": "value2" },
        ...
      ]
    }
  ]
}
```

## 数组字段过滤

模型中 `type: array` 的字段（如风险规则、敏感数据Key等）在 filter 时自动使用 ClickHouse 原生数组函数，
避免 `arrayStringConcat + LIKE` 的低效字符串扫描。

### 生成规则

| operator | 单值 | 多值 |
|---|---|---|
| `equals` | `has(arr, ?)` | `hasAll(arr, [?,?,...])` — 全部匹配 |
| `contains` | `has(arr, ?)` | `hasAny(arr, [?,?,...])` — 任意匹配 |
| `notEquals` | `NOT has(arr, ?)` | `NOT hasAll(arr, [?,?,...])` |
| `notContains` | `NOT has(arr, ?)` | `NOT hasAny(arr, [?,?,...])` |

### 模型定义示例

```yaml
dimensions:
  riskFilterTag:
    sql: arrayConcat(req_risk, res_risk)
    type: array        # 标记为数组类型，filter 自动走 has/hasAll/hasAny
    title: 风险规则过滤器

  reqSensKey:
    sql: req_sens_k
    type: array
    title: 请求敏感数据Key
```

**注意**：无需为 filter 单独创建 `arrayStringConcat` 版本的字段，直接在原始数组字段上定义 `type: array` 即可复用。

## 与Cube.js的区别

### 简化功能
- ❌ 无预聚合（pre-aggregations）
- ❌ 无复杂Join
- ❌ 无动态计算成员
- ❌ 无缓存机制

### 性能优化
- ✅ 直接SQL拼接，无模板引擎开销
- ✅ ClickHouse连接池
- ✅ 简单HTTP服务器，无中间件
- ✅ 最小化内存占用
- ✅ 数组字段用 `has`/`hasAll`/`hasAny` 替代 `LIKE`，充分利用 ClickHouse 数组索引

### 部署优势
- ✅ 单二进制文件
- ✅ 无Node.js依赖
- ✅ 静态编译，易于容器化

## 性能预期

- **查询速度**: 预计比Cube.js快3-5倍
- **内存占用**: 减少50%以上
- **启动时间**: < 1秒
- **并发能力**: 1000+ QPS（取决于ClickHouse）

## 注意事项

1. **模型转换**: 需要将现有的Cube.js `.js` 文件转换为YAML格式
2. **功能限制**: 仅支持核心查询功能，复杂场景需要评估
3. **测试验证**: 建议并行运行，逐步迁移流量
4. **监控部署**: 添加适当的监控和告警

## 许可证

MIT License