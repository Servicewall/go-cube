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
	SQLMask    string `yaml:"sql_mask,omitempty"`
	Type       string `yaml:"type"`
	Title      string `yaml:"title,omitempty"`
	PrimaryKey bool   `yaml:"primary_key,omitempty"`
}

type Measure struct {
	SQL     string `yaml:"sql"`
	SQLMask string `yaml:"sql_mask,omitempty"`
	Type    string `yaml:"type"`
	Title   string `yaml:"title,omitempty"`
}

type Segment struct {
	SQL   []string `yaml:"sql"`
	Title string   `yaml:"title,omitempty"`
}

// Annotatable 表示可被 annotation 描述的 cube 成员。
type Annotatable interface {
	MemberTitle() string
	MemberType() string
}

func (d Dimension) MemberTitle() string { return d.Title }
func (d Dimension) MemberType() string  { return d.Type }
func (m Measure) MemberTitle() string   { return m.Title }
func (m Measure) MemberType() string    { return m.Type }
func (s Segment) MemberTitle() string   { return s.Title }
func (s Segment) MemberType() string    { return "" }

// GetField 查找维度或度量字段，subKey 非空时将 SQL 模板中的 {key} 替换为 subKey。
func (c *Cube) GetField(name string, subKey string) (Field, bool) {
	if dim, ok := c.Dimensions[name]; ok {
		sql := dim.SQL
		sqlMask := dim.SQLMask
		if subKey != "" {
			sql = strings.ReplaceAll(sql, "{key}", subKey)
			if sqlMask != "" {
				sqlMask = strings.ReplaceAll(sqlMask, "{key}", subKey)
			}
		}
		return Field{
			Name:    name,
			SQL:     sql,
			SQLMask: sqlMask,
			Type:    dim.Type,
		}, true
	}

	if measure, ok := c.Measures[name]; ok {
		return Field{
			Name:    name,
			SQL:     measure.SQL,
			SQLMask: measure.SQLMask,
			Type:    measure.Type,
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

// Clone 返回 Cube 的独立副本，修改返回值不会影响缓存中的原始对象。
func (c *Cube) Clone() *Cube {
	cp := *c
	cp.Dimensions = make(map[string]Dimension, len(c.Dimensions))
	for k, v := range c.Dimensions {
		cp.Dimensions[k] = v
	}
	cp.Measures = make(map[string]Measure, len(c.Measures))
	for k, v := range c.Measures {
		cp.Measures[k] = v
	}
	cp.Segments = make(map[string]Segment, len(c.Segments))
	for k, v := range c.Segments {
		cp.Segments[k] = v
	}
	return &cp
}

type Field struct {
	Name    string
	SQL     string
	SQLMask string
	Type    string
}
