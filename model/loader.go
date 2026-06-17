package model

import (
	"embed"
	"fmt"
	"io/fs"
	"maps"
	"path/filepath"
	"sync"

	"gopkg.in/yaml.v3"
)

func unmarshalCube(data []byte, source string) (*Cube, error) {
	var wrapper struct {
		Cube Cube `yaml:"cube"`
	}
	if err := yaml.Unmarshal(data, &wrapper); err != nil {
		return nil, fmt.Errorf("parse %s: %w", source, err)
	}
	return &wrapper.Cube, nil
}

//go:embed *.yaml
var InternalFS embed.FS

type Loader struct {
	cache map[string]*Cube
	mu    sync.RWMutex
}

func NewLoader() *Loader {
	return &Loader{cache: make(map[string]*Cube)}
}

func NewLoaderFromFS(fsys fs.FS) (*Loader, error) {
	l := NewLoader()
	if err := l.LoadFS(fsys); err != nil {
		return nil, err
	}
	return l, nil
}

func (l *Loader) Load(name string) (*Cube, error) {
	l.mu.RLock()
	cube, ok := l.cache[name]
	l.mu.RUnlock()
	if !ok {
		return nil, fmt.Errorf("model %s not found", name)
	}
	return cube.Clone(), nil
}

func (l *Loader) LoadFS(fsys fs.FS) error {
	entries, err := fs.ReadDir(fsys, ".")
	if err != nil {
		return fmt.Errorf("read models directory: %w", err)
	}
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		ext := filepath.Ext(e.Name())
		if ext != ".yaml" && ext != ".yml" {
			continue
		}
		data, err := fs.ReadFile(fsys, e.Name())
		if err != nil {
			return fmt.Errorf("read %s: %w", e.Name(), err)
		}
		name := e.Name()[:len(e.Name())-len(ext)]
		cube, err := unmarshalCube(data, e.Name())
		if err != nil {
			return err
		}
		l.cacheCube(name, cube)
	}
	return nil
}

func (l *Loader) LoadAll() map[string]*Cube {
	l.mu.RLock()
	defer l.mu.RUnlock()
	out := make(map[string]*Cube, len(l.cache))
	for k, v := range l.cache {
		out[k] = v.Clone()
	}
	return out
}

func (l *Loader) PutCube(name string, yamlData []byte) error {
	patch, err := unmarshalCube(yamlData, name)
	if err != nil {
		return err
	}

	l.mu.Lock()
	defer l.mu.Unlock()

	base, exists := l.cache[name]
	if !exists {
		if patch.Name == "" {
			patch.Name = name
		}
		l.cache[name] = patch
		return nil
	}

	merged := base.Clone()
	if patch.SQL != "" {
		merged.SQL = patch.SQL
	}
	if patch.SQLTable != "" {
		merged.SQLTable = patch.SQLTable
	}
	if patch.Name != "" {
		merged.Name = patch.Name
	}
	maps.Copy(merged.Dimensions, patch.Dimensions)
	maps.Copy(merged.Measures, patch.Measures)
	maps.Copy(merged.Segments, patch.Segments)

	l.cache[name] = merged
	return nil
}

func (l *Loader) ClearCache() {
	l.mu.Lock()
	l.cache = make(map[string]*Cube)
	l.mu.Unlock()
}

func (l *Loader) cacheCube(name string, cube *Cube) {
	if cube.Name == "" {
		cube.Name = name
	}
	l.mu.Lock()
	l.cache[name] = cube
	l.mu.Unlock()
}
