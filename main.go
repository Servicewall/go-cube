package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/Servicewall/go-cube/api"
	"github.com/Servicewall/go-cube/config"
	"github.com/Servicewall/go-cube/model"
	"github.com/Servicewall/go-cube/sql"
)

func main() {
	// 加载配置
	cfgPath := "config.yaml"
	if len(os.Args) > 1 {
		cfgPath = os.Args[1]
	}

	var cfg *config.Config
	if _, err := os.Stat(cfgPath); os.IsNotExist(err) {
		log.Printf("Config file %s not found, using default config", cfgPath)
		cfg = config.DefaultConfig()
	} else {
		var err error
		cfg, err = config.Load(cfgPath)
		if err != nil {
			log.Fatalf("Load config %s: %v", cfgPath, err)
		}
	}

	// 初始化模型加载器
	modelLoader, err := model.NewLoaderFromFS(os.DirFS(cfg.Models.Path))
	if err != nil {
		log.Printf("Warning: load models: %v", err)
		modelLoader = model.NewLoader()
	}

	// 初始化ClickHouse客户端
	chClient, err := sql.NewClient(&cfg.ClickHouse)
	if err != nil {
		log.Fatalf("Init ClickHouse client: %v", err)
	}

	// 初始化API处理器
	handler := api.NewHandler(modelLoader, chClient)

	// 设置HTTP路由
	mux := http.NewServeMux()

	// API 路由
	mux.HandleFunc("/load", handler.HandleLoad)
	mux.HandleFunc("/health", handler.HealthCheck)

	// 静态文件服务 - 提供前端页面
	staticDir := "./static"
	if _, err := os.Stat(staticDir); err == nil {
		fs := http.FileServer(http.Dir(staticDir))
		mux.Handle("/", http.StripPrefix("/", fs))
		log.Printf("Serving static files from %s", staticDir)
	} else {
		log.Printf("Warning: static directory %s not found", staticDir)
	}

	// 创建HTTP服务器
	server := &http.Server{
		Addr:         fmt.Sprintf("0.0.0.0:%d", cfg.Server.Port),
		Handler:      mux,
		ReadTimeout:  cfg.Server.ReadTimeout,
		WriteTimeout: cfg.Server.WriteTimeout,
	}

	// 启动服务器
	go func() {
		log.Printf("Starting server on :%d", cfg.Server.Port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("Server failed: %v", err)
		}
	}()

	// 等待中断信号
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit
	log.Println("Shutting down server...")

	// 优雅关闭
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Fatalf("Server shutdown failed: %v", err)
	}

	log.Println("Server stopped")
}
