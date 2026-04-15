#!/bin/bash
# Test AccessRawView queries against local go-cube server
# NOTE: uses access_raw (local dev); production uses access_raw_local

source "$(dirname "$0")/common.sh"

CHECK_TOP_LEVEL_ERROR=1

echo "Building go-cube..."
# Swap access_raw_local -> access_raw for local testing, restore on exit
cp model/AccessRawView.yaml /tmp/AccessRawView_prod.yaml
sed -i '' 's/access_raw_local/access_raw/' model/AccessRawView.yaml
trap 'stop_server; cp /tmp/AccessRawView_prod.yaml model/AccessRawView.yaml' EXIT INT TERM

go build -o go-cube . || { echo "Build failed"; exit 1; }

echo "Starting server..."
start_server 1 "" "Starting server..."

echo ""
echo "=== 1. ungrouped request+response (limit 1) ==="
# ungrouped: true, dimensions: request, response
# filters: id != '', segments: org, black
# mirrors the original query from dsp.servicewall.cn translated to AccessRawView
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3A%20true%2C%20%22measures%22%3A%20%5B%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22AccessRawView.ts%22%2C%20%22dateRange%22%3A%20%22from%207%20days%20ago%20to%20now%22%7D%5D%2C%20%22filters%22%3A%20%5B%7B%22member%22%3A%20%22AccessRawView.id%22%2C%20%22operator%22%3A%20%22notEquals%22%2C%20%22values%22%3A%20%5B%22%22%5D%7D%5D%2C%20%22dimensions%22%3A%20%5B%22AccessRawView.request%22%2C%20%22AccessRawView.response%22%5D%2C%20%22limit%22%3A%201%2C%20%22segments%22%3A%20%5B%22AccessRawView.org%22%2C%20%22AccessRawView.black%22%5D%2C%20%22timezone%22%3A%20%22Asia/Shanghai%22%7D")
check "ungrouped request+response id!='' limit 1" "$result"

echo ""
echo "=== 2. ungrouped id+ts+url+gorId+fileContent (limit 5) ==="
# ungrouped: true, dimensions: id, ts, url, gorId, fileContent
# segments: org, limit 5
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3A%20true%2C%20%22measures%22%3A%20%5B%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22AccessRawView.ts%22%2C%20%22dateRange%22%3A%20%22from%207%20days%20ago%20to%20now%22%7D%5D%2C%20%22dimensions%22%3A%20%5B%22AccessRawView.id%22%2C%20%22AccessRawView.ts%22%2C%20%22AccessRawView.url%22%2C%20%22AccessRawView.gorId%22%2C%20%22AccessRawView.fileContent%22%5D%2C%20%22limit%22%3A%205%2C%20%22segments%22%3A%20%5B%22AccessRawView.org%22%5D%2C%20%22timezone%22%3A%20%22Asia/Shanghai%22%7D")
check "ungrouped id+ts+url+gorId+fileContent limit 5" "$result"

echo ""
echo "--- $pass passed, $fail failed ---"

echo ""
echo "Stopping server..."
stop_server
echo "All tests completed."
