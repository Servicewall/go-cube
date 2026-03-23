package model

import "strings"

type Cube struct {
	Name       string               `yaml:"name"`
	SQL        string               `yaml:"sql"`
	SQLTable   string               `yaml:"sql_table"`
	Dimensions map[string]Dimension `yaml:"dimensions"`
	Measures   map[string]Measure   `yaml:"measures"`
	Segments   map[string]Segment   `yaml:"segments,omitempty"`
}

type Dimension struct {
	SQL        string `yaml:"sql"`
	Type       string `yaml:"type"`
	Title      string `yaml:"title,omitempty"`
	PrimaryKey bool   `yaml:"primary_key,omitempty"`
}

type Measure struct {
	SQL   string `yaml:"sql"`
	Type  string `yaml:"type"`
	Title string `yaml:"title,omitempty"`
}

type Segment struct {
	SQL string `yaml:"sql"`
}

// GetField 查找维度或度量字段，subKey 非空时将 SQL 模板中的 {key} 替换为 subKey。
func (c *Cube) GetField(name string, subKey string) (Field, bool) {
	if dim, ok := c.Dimensions[name]; ok {
		sql := dim.SQL
		if subKey != "" {
			sql = strings.ReplaceAll(sql, "{key}", subKey)
		}
		return Field{
			Name: name,
			SQL:  sql,
			Type: dim.Type,
		}, true
	}

	if measure, ok := c.Measures[name]; ok {
		return Field{
			Name: name,
			SQL:  measure.SQL,
			Type: measure.Type,
		}, true
	}

	return Field{}, false
}

func (c *Cube) GetSQLTable() string {
	if c.SQLTable != "" {
		return c.SQLTable
	}
	// 对于复杂子查询，需要添加别名
	if c.SQL != "" {
		return "(" + c.SQL + ") AS " + c.Name
	}
	return ""
}

// WithSQL 返回 Cube 的浅拷贝，SQL 字段替换为给定值（用于子查询占位符注入）。
func (c *Cube) WithSQL(sql string) *Cube {
	copy := *c
	copy.SQL = sql
	return &copy
}

type Field struct {
	Name string
	SQL  string
	Type string
}
