#!/bin/bash
# Test DatabaseView queries against local go-cube server
# Mirrors production curl requests from dsp.servicewall.cn

source "$(dirname "$0")/common.sh"

setup_server_trap
start_server 2
test_health

echo ""
echo "========================================"
echo "=== DatabaseView queries ==="
echo "========================================"

echo ""
echo "=== 1. dbTableGroup measure (no dimensions, segment: org) ==="
# measures: [DatabaseView.dbTableGroup]
# segments: [DatabaseView.org]
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22DatabaseView.dbTableGroup%22%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22DatabaseView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "dbTableGroup (no dimensions, segment org)" "$result"

echo ""
echo "=== 2. columns measure (dbType+database+table dimensions, segment: org) ==="
# measures: [DatabaseView.columns]
# dimensions: [DatabaseView.dbType, DatabaseView.database, DatabaseView.table]
# segments: [DatabaseView.org]
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22DatabaseView.columns%22%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22DatabaseView.dbType%22%2C%22DatabaseView.database%22%2C%22DatabaseView.table%22%5D%2C%22segments%22%3A%5B%22DatabaseView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "columns by dbType+database+table (segment org)" "$result"

echo ""
echo "========================================"
echo "=== ApiDBFlowView queries ==="
echo "========================================"

echo ""
echo "=== 3. ApiDBFlowView all dimensions (no segment) ==="
# dimensions: [ts, dbType, dbHost, dbName, tableName, tableColumns, httpData]
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22dimensions%22%3A%5B%22ApiDBFlowView.ts%22%2C%22ApiDBFlowView.dbType%22%2C%22ApiDBFlowView.dbHost%22%2C%22ApiDBFlowView.dbName%22%2C%22ApiDBFlowView.tableName%22%2C%22ApiDBFlowView.tableColumns%22%2C%22ApiDBFlowView.httpData%22%5D%2C%22filters%22%3A%5B%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiDBFlowView all dimensions" "$result"

echo ""
echo "========================================"
echo "Results: $pass passed, $fail failed"
echo "========================================"

stop_server

if [ $fail -gt 0 ]; then
    exit 1
fi
