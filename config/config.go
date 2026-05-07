package config

import (
	"os"
	"time"

	"gopkg.in/yaml.v3"
)

type Config struct {
	Server     ServerConfig     `yaml:"server"`
	ClickHouse ClickHouseConfig `yaml:"clickhouse"`
	Models     ModelsConfig     `yaml:"models"`
}

type ServerConfig struct {
	Port         int           `yaml:"port"`
	ReadTimeout  time.Duration `yaml:"read_timeout"`
	WriteTimeout time.Duration `yaml:"write_timeout"`
}

type ClickHouseConfig struct {
	Hosts        []string      `yaml:"hosts"`
	Database     string        `yaml:"database"`
	Username     string        `yaml:"username"`
	Password     string        `yaml:"password"`
	QueryTimeout time.Duration `yaml:"query_timeout"`
}

type ModelsConfig struct {
	Path string `yaml:"path"`
}

func Load(path string) (*Config, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}

	var config Config
	if err := yaml.Unmarshal(data, &config); err != nil {
		return nil, err
	}

	return &config, nil
}

func DefaultConfig() *Config {
	return &Config{
		Server: ServerConfig{
			Port:         4000,
			ReadTimeout:  30 * time.Second,
			WriteTimeout: 30 * time.Second,
		},
		ClickHouse: ClickHouseConfig{
			Hosts:        []string{"localhost:8123"},
			Database:     "default",
			Username:     "default",
			Password:     "",
			QueryTimeout: 60 * time.Second,
		},
		Models: ModelsConfig{
			Path: "./models",
		},
	}
}
