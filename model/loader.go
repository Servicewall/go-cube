package model

import (
	"embed"
	"fmt"
	"io/fs"
	"path/filepath"
	"sync"

	"gopkg.in/yaml.v3"
)

// InternalFS 导出嵌入的模型文件
//
//go:embed *.yaml
var InternalFS embed.FS

type Loader struct {
	fsys  fs.FS
	cache map[string]*Cube
	mu    sync.RWMutex
}

func NewLoader(fsys fs.FS) *Loader {
	return &Loader{
		fsys:  fsys,
		cache: make(map[string]*Cube),
	}
}

func (l *Loader) Load(name string) (*Cube, error) {
	l.mu.RLock()
	if cube, ok := l.cache[name]; ok {
		l.mu.RUnlock()
		return cube, nil
	}
	l.mu.RUnlock()

	fileName := name + ".yaml"
	data, err := fs.ReadFile(l.fsys, fileName)
	if err != nil {
		return nil, fmt.Errorf("read model file %s: %w", fileName, err)
	}

	// YAML文件有顶层"cube:"键
	var wrapper struct {
		Cube Cube `yaml:"cube"`
	}
	if err := yaml.Unmarshal(data, &wrapper); err != nil {
		return nil, fmt.Errorf("parse model file %s: %w", fileName, err)
	}

	cube := wrapper.Cube
	if cube.Name == "" {
		cube.Name = name
	}

	l.mu.Lock()
	l.cache[name] = &cube
	l.mu.Unlock()

	return &cube, nil
}

func (l *Loader) LoadAll() (map[string]*Cube, error) {
	entries, err := fs.ReadDir(l.fsys, ".")
	if err != nil {
		return nil, fmt.Errorf("read models directory: %w", err)
	}

	models := make(map[string]*Cube)
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}

		ext := filepath.Ext(entry.Name())
		if ext != ".yaml" && ext != ".yml" {
			continue
		}

		name := entry.Name()[:len(entry.Name())-len(ext)]
		cube, err := l.Load(name)
		if err != nil {
			return nil, fmt.Errorf("load model %s: %w", name, err)
		}

		models[name] = cube
	}

	return models, nil
}

func (l *Loader) ClearCache() {
	l.mu.Lock()
	l.cache = make(map[string]*Cube)
	l.mu.Unlock()
}
