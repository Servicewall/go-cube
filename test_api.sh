#!/bin/bash
# Test ApiView queries against local go-cube server
# Verifies {filter.ts} placeholder injection in subquery SQL

BASE="http://localhost:4000"
pass=0
fail=0

check() {
    local desc="$1"
    local result="$2"
    if echo "$result" | jq -e '.results[0].data' > /dev/null 2>&1; then
        count=$(echo "$result" | jq '.results[0].data | length')
        echo "[PASS] $desc — $count rows"
        ((pass++))
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
echo "=== ApiView queries ==="
echo "========================================"

echo ""
echo "=== 1. API总数 (allCount, no dimensions, with timeDimension: last 7 days) ==="
# measures: [ApiView.allCount]
# timeDimensions: [{ApiView.ts, dateRange: "from 7 days ago to now"}]
# segments: [ApiView.org]
# Verifies {filter.ts} is injected as ts >= now()-INTERVAL 7 DAY AND ts <= now()
QUERY='{"measures":["ApiView.allCount"],"timeDimensions":[{"dimension":"ApiView.ts","dateRange":"from 7 days ago to now"}],"filters":[],"dimensions":[],"segments":["ApiView.org"],"timezone":"Asia/Shanghai"}'
ENCODED=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$QUERY")
result=$(curl -s "$BASE/load?queryType=multi&query=$ENCODED")
check "ApiView allCount with 7-day time filter ({filter.ts} injection)" "$result"

echo ""
echo "=== 2. API访问量汇总 (sum, no dimensions, no timeDimension) ==="
# measures: [ApiView.sum]
# No timeDimensions — {filter.ts} should be replaced with 1=1
QUERY='{"measures":["ApiView.sum"],"timeDimensions":[],"filters":[],"dimensions":[],"segments":["ApiView.org"],"timezone":"Asia/Shanghai"}'
ENCODED=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$QUERY")
result=$(curl -s "$BASE/load?queryType=multi&query=$ENCODED")
check "ApiView sum without timeDimension ({filter.ts} -> 1=1)" "$result"

echo ""
echo "========================================"
echo "Results: $pass passed, $fail failed"
echo "========================================"

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null

if [ $fail -gt 0 ]; then
    exit 1
fi
