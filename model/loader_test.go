package model

import (
	"testing"
	"testing/fstest"
)

func makeBaseFS() fstest.MapFS {
	return fstest.MapFS{
		"TestModel.yaml": &fstest.MapFile{Data: []byte(`cube:
  sql_table: default.test_table
  dimensions:
    host:
      sql: host
      type: string
    method:
      sql: method
      type: string
  measures:
    count:
      type: count
  segments:
    active:
      sql: "status = 'active'"
`)},
	}
}

func TestLoadFS(t *testing.T) {
	loader := NewLoader()
	if err := loader.LoadFS(makeBaseFS()); err != nil {
		t.Fatal(err)
	}
	cube, err := loader.Load("TestModel")
	if err != nil {
		t.Fatal(err)
	}
	if cube.SQLTable != "default.test_table" {
		t.Errorf("expected default.test_table, got %s", cube.SQLTable)
	}
	if len(cube.Dimensions) != 2 {
		t.Errorf("expected 2 dimensions, got %d", len(cube.Dimensions))
	}
}

func TestAccessViewReqReasonOnlyFiltersPairedArrayElements(t *testing.T) {
	loader, err := NewLoaderFromFS(InternalFS)
	if err != nil {
		t.Fatal(err)
	}
	cube, err := loader.Load("AccessView")
	if err != nil {
		t.Fatal(err)
	}

	const want = "arrayMap(i -> req_reason[i], arrayFilter(i -> i <= length(req_reason) AND dictGetInt64('default.risk_dict','score',req_risk[i])!=0, arrayEnumerate(req_risk)))"
	if got := cube.Dimensions["reqReason"].SQL; got != want {
		t.Fatalf("reqReason SQL mismatch:\nwant: %s\n got: %s", want, got)
	}
}

func TestLoadMiss(t *testing.T) {
	loader := NewLoader()
	_, err := loader.Load("NoSuchModel")
	if err == nil {
		t.Error("expected error for missing model")
	}
}

func TestPutCube(t *testing.T) {
	loader := NewLoader()

	err := loader.PutCube("DynamicModel", []byte(`cube:
  sql_table: default.dynamic_table
  dimensions:
    ip:
      sql: ip
      type: string
`))
	if err != nil {
		t.Fatal(err)
	}

	cube, err := loader.Load("DynamicModel")
	if err != nil {
		t.Fatal(err)
	}
	if cube.SQLTable != "default.dynamic_table" {
		t.Errorf("expected default.dynamic_table, got %s", cube.SQLTable)
	}
	if _, ok := cube.Dimensions["ip"]; !ok {
		t.Error("ip dimension missing")
	}
}

func TestPutCubeOverwrite(t *testing.T) {
	loader := NewLoader()
	if err := loader.LoadFS(makeBaseFS()); err != nil {
		t.Fatal(err)
	}

	err := loader.PutCube("TestModel", []byte(`cube:
  sql_table: default.overridden
  dimensions:
    host:
      sql: new_host_expr
      type: string
`))
	if err != nil {
		t.Fatal(err)
	}

	cube, _ := loader.Load("TestModel")
	if cube.SQLTable != "default.overridden" {
		t.Errorf("expected overridden, got %s", cube.SQLTable)
	}
	if cube.Dimensions["host"].SQL != "new_host_expr" {
		t.Errorf("host.sql should be overridden, got %s", cube.Dimensions["host"].SQL)
	}
	if _, ok := cube.Dimensions["method"]; !ok {
		t.Error("method dimension should be preserved from base")
	}
	if _, ok := cube.Measures["count"]; !ok {
		t.Error("count measure should be preserved from base")
	}
}

func TestPutCubeMergePartial(t *testing.T) {
	loader := NewLoader()
	if err := loader.LoadFS(makeBaseFS()); err != nil {
		t.Fatal(err)
	}

	err := loader.PutCube("TestModel", []byte(`cube:
  dimensions:
    host:
      sql: new_host_expr
      type: string
`))
	if err != nil {
		t.Fatal(err)
	}

	cube, _ := loader.Load("TestModel")
	if cube.SQLTable != "default.test_table" {
		t.Errorf("sql_table should be preserved, got %s", cube.SQLTable)
	}
	if cube.Dimensions["host"].SQL != "new_host_expr" {
		t.Errorf("host.sql should be overridden, got %s", cube.Dimensions["host"].SQL)
	}
	if _, ok := cube.Dimensions["method"]; !ok {
		t.Error("method dimension should be preserved")
	}
	if _, ok := cube.Segments["active"]; !ok {
		t.Error("active segment should be preserved")
	}
}

func TestLoadAllIncludesPutCube(t *testing.T) {
	loader := NewLoader()
	if err := loader.LoadFS(makeBaseFS()); err != nil {
		t.Fatal(err)
	}

	_ = loader.PutCube("Extra", []byte(`cube:
  sql_table: default.extra
  dimensions:
    foo:
      sql: foo
      type: string
`))

	models := loader.LoadAll()
	if _, ok := models["TestModel"]; !ok {
		t.Error("TestModel should be present")
	}
	if _, ok := models["Extra"]; !ok {
		t.Error("Extra should be present")
	}
}

func TestPutCubeInvalidYAML(t *testing.T) {
	loader := NewLoader()
	err := loader.PutCube("Bad", []byte(`not: valid: yaml: [[[`))
	if err == nil {
		t.Error("expected error for invalid YAML")
	}
}
