#!/bin/bash
# Test CustomAppView queries against local go-cube server

source "$(dirname "$0")/common.sh"

setup_server_trap
start_server 2
test_health

echo ""
echo "========================================"
echo "=== CustomAppView queries ==="
echo "========================================"

echo ""
echo "=== 1. 应用列表 (uniqueId + name, filter: uniqueId != '', segment: org) ==="
# measures: []
# timeDimensions: []
# filters: [{member: CustomAppView.uniqueId, operator: notEquals, values: ['']}]
# dimensions: [uniqueId, name]
# segments: [CustomAppView.org]
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22CustomAppView.uniqueId%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22CustomAppView.uniqueId%22%2C%22CustomAppView.name%22%5D%2C%22segments%22%3A%5B%22CustomAppView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
check "应用列表 (uniqueId + name, uniqueId != '')" "$result"

echo ""
echo "========================================"
echo "Results: $pass passed, $fail failed"
echo "========================================"

stop_server
