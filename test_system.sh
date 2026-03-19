#!/bin/bash
# Test SystemNodesView queries against local go-cube server
# Mirrors production curl requests from demo.servicewall.cn

BASE="http://localhost:4000"
pass=0
fail=0

check() {
    local desc="$1"
    local result="$2"
    if echo "$result" | jq -e '.results[0].data' > /dev/null 2>&1; then
        # Check for error field inside data rows
        if echo "$result" | jq -e '.results[0].data[0].error' > /dev/null 2>&1; then
            echo "[FAIL] $desc — error in data"
            echo "$result" | jq '.results[0].data[0].error'
            ((fail++))
        else
            count=$(echo "$result" | jq '.results[0].data | length')
            echo "[PASS] $desc — $count rows"
            ((pass++))
        fi
    else
        echo "[FAIL] $desc"
        echo "$result" | jq . 2>/dev/null || echo "$result"
        ((fail++))
    fi
}

echo "Starting go-cube server in background..."
./go-cube &
SERVER_PID=$!
sleep 2

echo ""
echo "Testing health endpoint..."
curl -s "$BASE/health" | jq .

echo ""
echo "========================================"
echo "=== SystemNodesView queries ==="
echo "========================================"

echo ""
echo "=== 1. SystemNodesView 节点状态 (measures: lastFreeSpace/lastTotalSpace/daysEstimated/healthCount, dims: ip/name, segment: org, timeDim: ts last 4d) ==="
# measures: lastFreeSpace, lastTotalSpace, daysEstimated, healthCount
# timeDimensions: ts, dateRange: from 4 days ago to now (no granularity)
# dimensions: ip, name
# segments: org
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%20%5B%22SystemNodesView.lastFreeSpace%22%2C%20%22SystemNodesView.lastTotalSpace%22%2C%20%22SystemNodesView.daysEstimated%22%2C%20%22SystemNodesView.healthCount%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22SystemNodesView.ts%22%2C%20%22dateRange%22%3A%20%22from%204%20days%20ago%20to%20now%22%7D%5D%2C%20%22order%22%3A%20%7B%22SystemNodesView.ip%22%3A%20%22asc%22%7D%2C%20%22filters%22%3A%20%5B%5D%2C%20%22dimensions%22%3A%20%5B%22SystemNodesView.ip%22%2C%20%22SystemNodesView.name%22%5D%2C%20%22segments%22%3A%20%5B%22SystemNodesView.org%22%5D%2C%20%22timezone%22%3A%20%22Asia%2FShanghai%22%7D")
check "SystemNodesView node status (lastFreeSpace/lastTotalSpace/daysEstimated/healthCount by ip/name)" "$result"

echo ""
echo "=== 2. SystemNodesView 磁盘趋势 (measure: avgFreeSpace, granularity: day, filter: ip='172.31.38.218', from 7 days ago to now) ==="
# measures: avgFreeSpace
# timeDimensions: ts, dateRange: from 7 days ago to now, granularity: day
# filters: ip = '172.31.38.218'
# dimensions: ip, name
# segments: org
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%20%5B%22SystemNodesView.avgFreeSpace%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22SystemNodesView.ts%22%2C%20%22dateRange%22%3A%20%22from%207%20days%20ago%20to%20now%22%2C%20%22granularity%22%3A%20%22day%22%7D%5D%2C%20%22order%22%3A%20%7B%22SystemNodesView.ts%22%3A%20%22asc%22%7D%2C%20%22filters%22%3A%20%5B%7B%22member%22%3A%20%22SystemNodesView.ip%22%2C%20%22operator%22%3A%20%22equals%22%2C%20%22values%22%3A%20%5B%22172.31.38.218%22%5D%7D%5D%2C%20%22dimensions%22%3A%20%5B%22SystemNodesView.ip%22%2C%20%22SystemNodesView.name%22%5D%2C%20%22segments%22%3A%20%5B%22SystemNodesView.org%22%5D%2C%20%22timezone%22%3A%20%22Asia%2FShanghai%22%7D")
check "SystemNodesView disk trend (avgFreeSpace by day, filtered by ip)" "$result"

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null

echo ""
echo "========================================"
echo "Results: $pass passed, $fail failed"
echo "========================================"

if [ $fail -gt 0 ]; then
    exit 1
fi
