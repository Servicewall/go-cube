#!/bin/bash
# Test PromptView and RiskPromptView queries against local go-cube server
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
echo "=== PromptView queries ==="
echo "========================================"

echo ""
echo "=== 1. PromptView 总数 (measure: count, segment: org) ==="
# measures: count
# segments: org
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22PromptView.count%22%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22PromptView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "PromptView count (total)" "$result"

echo ""
echo "=== 2. PromptView 列表 (dims: ts/prompt/risk/ip/uid/score, order: score desc/ts desc, limit 20) ==="
# measures: []
# dimensions: ts, prompt, risk, ip, uid, score
# order: score desc, ts desc
# segments: org
# limit: 20
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%5D%2C%22order%22%3A%7B%22PromptView.score%22%3A%22desc%22%2C%22PromptView.ts%22%3A%22desc%22%7D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22PromptView.ts%22%2C%22PromptView.prompt%22%2C%22PromptView.risk%22%2C%22PromptView.ip%22%2C%22PromptView.uid%22%2C%22PromptView.score%22%5D%2C%22limit%22%3A20%2C%22offset%22%3A0%2C%22segments%22%3A%5B%22PromptView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "PromptView list (ts/prompt/risk/ip/uid/score, order score desc)" "$result"

echo ""
echo "========================================"
echo "=== RiskPromptView queries ==="
echo "========================================"

echo ""
echo "=== 3. RiskPromptView 总数 (measure: count, segment: org) ==="
# measures: count
# segments: org
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22RiskPromptView.count%22%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22RiskPromptView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "RiskPromptView count (total)" "$result"

echo ""
echo "=== 4. RiskPromptView 列表 (dims: ts/prompt/id, order: ts desc, limit 20) ==="
# measures: []
# dimensions: ts, prompt, id
# order: ts desc
# segments: org
# limit: 20
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%5D%2C%22order%22%3A%7B%22RiskPromptView.ts%22%3A%22desc%22%7D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22RiskPromptView.ts%22%2C%22RiskPromptView.prompt%22%2C%22RiskPromptView.id%22%5D%2C%22limit%22%3A20%2C%22offset%22%3A0%2C%22segments%22%3A%5B%22RiskPromptView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "RiskPromptView list (ts/prompt/id, order ts desc)" "$result"

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null

echo ""
echo "========================================"
echo "Results: $pass passed, $fail failed"
echo "========================================"

if [ $fail -gt 0 ]; then
    exit 1
fi
