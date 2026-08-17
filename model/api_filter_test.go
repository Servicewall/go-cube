package model

import (
	"strings"
	"testing"
)

func TestHTTPViewsUsePreprocessedAPIFilters(t *testing.T) {
	loader, err := NewLoaderFromFS(InternalFS)
	if err != nil {
		t.Fatalf("load models: %v", err)
	}
	for _, name := range []string{
		"AccessView", "DatabaseView", "ApiRouteView", "ApiDayView", "WeakView",
		"AiApiAnalysisView", "AiSensRecommendView", "ApiView",
	} {
		cube, err := loader.Load(name)
		if err != nil {
			t.Fatalf("load %s: %v", name, err)
		}
		sql := cube.Segments["black"].SQL
		for _, want := range []string{"api_filter_exact_hosts", "api_filter_exact_urls", "api_filter_regex_hosts", "api_filter_regex_suffixes"} {
			if !strings.Contains(sql, want) {
				t.Errorf("%s.black missing %s", name, want)
			}
		}
		if strings.Contains(sql, "multiMatchAny") || strings.Contains(sql, "replaceRegexp") || strings.Contains(sql, "= ['']") {
			t.Errorf("%s.black still processes regex at query time: %s", name, sql)
		}
	}
}

func TestApiViewFilterDimensionsUsePreprocessedAPIFilters(t *testing.T) {
	loader, _ := NewLoaderFromFS(InternalFS)
	cube, err := loader.Load("ApiView")
	if err != nil {
		t.Fatal(err)
	}
	for _, name := range []string{"filtered", "sidebarTypeArray", "sidebarFirstLevelTypeArray", "sidebarTypeCount", "sidebarFirstLevelTypeCount"} {
		field, ok := cube.GetField(name, "")
		if !ok {
			t.Fatalf("ApiView.%s not found", name)
		}
		sql := field.SQL
		if !strings.Contains(sql, "api_filter_exact_hosts") {
			t.Errorf("ApiView.%s was not migrated", name)
		}
	}
}

func TestApiDBFlowUsesPreprocessedHosts(t *testing.T) {
	loader, _ := NewLoaderFromFS(InternalFS)
	cube, err := loader.Load("ApiDBFlowView")
	if err != nil {
		t.Fatal(err)
	}
	for _, segment := range []string{"white", "black"} {
		sql := cube.Segments[segment].SQL
		if !strings.Contains(sql, " IN arrayConcat") || !strings.Contains(sql, "{vars.api_filter_exact_hosts}") || !strings.Contains(sql, "{vars.api_filter_regex_hosts}") || strings.Contains(sql, "multiMatchAny") {
			t.Fatalf("ApiDBFlowView.%s must use preprocessed hosts: %s", segment, sql)
		}
	}
}
