# Go-Cube

Cube.js的Go语言最小替换实现，专注于ClickHouse性能和简洁性。

## 特性

- ✅ 兼容Cube.js REST API (`/load`)
- ✅ 官方YAML格式模型定义
- ✅ ClickHouse原生性能优化
- ✅ 简洁SQL拼接，无复杂抽象
- ✅ 单二进制部署，无外部依赖
- ✅ 基本查询功能：dimensions, measures, filters, order, limit/offset
- ✅ 可作为Go库直接嵌入调用，无需独立HTTP服务

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
    "context"
    "github.com/Servicewall/go-cube/api"
    "github.com/Servicewall/go-cube/config"
)

// 初始化（只需调用一次）
err := api.Init(&api.Config{
    ClickHouse: config.ClickHouseConfig{
        Hosts:    []string{"localhost:9000"},
        Database: "default",
        Username: "default",
        Password: "",
    },
})
if err != nil {
    log.Fatal(err)
}

// 执行 cubejs-graph 查询（与 /load?query=... HTTP 接口 JSON 格式相同）
resp, err := api.Load(context.Background(), `{
    "dimensions": ["AccessView.ts", "AccessView.ip", "AccessView.host"],
    "filters": [{"member": "AccessView.ip", "operator": "equals", "values": ["1.2.3.4"]}],
    "timeDimensions": [{"dimension": "AccessView.ts", "dateRange": "from 15 minutes ago to now"}],
    "order": {"AccessView.ts": "desc"},
    "limit": 50
}`)
if err != nil {
    log.Fatal(err)
}
// resp.Results[0].Data 包含查询结果
```

如果同时需要保留 HTTP 接口，可以挂载内置处理器：

```go
mux := http.NewServeMux()
mux.Handle("/cube/", http.StripPrefix("/cube", api.RegisterHandler()))
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
- `filters`: 过滤条件（简化实现）
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

## 与Cube.js的区别

### 简化功能
- ❌ 无预聚合（pre-aggregations）
- ❌ 无复杂Join
- ❌ 无动态计算成员
- ❌ 无segments支持（第一版）
- ❌ 无缓存机制

### 性能优化
- ✅ 直接SQL拼接，无模板引擎开销
- ✅ ClickHouse连接池
- ✅ 简单HTTP服务器，无中间件
- ✅ 最小化内存占用

### 部署优势
- ✅ 单二进制文件
- ✅ 无Node.js依赖
- ✅ 静态编译，易于容器化

## 开发计划

### 第一版（已完成）
- [x] 基本HTTP服务器
- [x] YAML模型加载
- [x] 简单SQL拼接
- [x] ClickHouse连接
- [x] REST API兼容

### 第二版（规划中）
- [ ] 时间维度支持
- [ ] 复杂过滤条件
- [ ] 安全上下文支持
- [ ] 错误处理和日志

### 后续版本
- [ ] segments支持
- [ ] 预聚合基础
- [ ] 性能监控
- [ ] 管理API

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