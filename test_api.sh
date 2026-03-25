#!/bin/bash
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
./go-cube > /tmp/go-cube.log 2>&1 &   # ← 日志重定向，不污染脚本输出
SERVER_PID=$!

sleep 5


echo ""
echo "=== 1. sidebarFirstLevelTypeCount with timeDimension (today) ==="
#{"measures":["ApiView.allCountForList"],"timeDimensions":[{"dimension":"ApiView.ts","dateRange":"today"}],"filters":[{"member":"ApiView.filtered","operator":"equals","values":["1"]}],"dimensions":[],"segments":["ApiView.org","ApiView.onePerDay"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22ApiView.sidebarTypeCount%22%2C%22ApiView.sidebarFirstLevelTypeCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiView.topoNetwork%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%E5%A4%96%E5%8F%91%22%5D%7D%2C%7B%22member%22%3A%22ApiView.apiTypeTag%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22API%22%5D%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiView.sidebarFirstLevelTypeCount" "$result"

echo ""
echo "=== 2. allCountForList ==="
#{"measures":["ApiView.allCountForList"],"timeDimensions":[{"dimension":"ApiView.ts","dateRange":"today"}],"filters":[{"member":"ApiView.filtered","operator":"equals","values":["1"]}],"dimensions":[],"segments":["ApiView.org","ApiView.onePerDay"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22ApiView.allCountForList%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiView.filtered%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%221%22%5D%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiView.allCountForList" "$result"

echo ""
echo "=== 3. customRuleTagSet configTagSet ==="
#{"measures":["ApiView.customRuleTagSet","ApiView.configTagSet"],"filters":[],"dimensions":[],"segments":["ApiView.org","ApiView.black","ApiView.onePerDay"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22ApiView.customRuleTagSet%22%2C%22ApiView.configTagSet%22%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiView.customRuleTagSet" "$result"

echo ""
echo "========================================"
echo "Results: $pass passed, $fail failed"
echo "========================================"

# 失败时打印服务日志辅助排查
if [ $fail -gt 0 ]; then
    echo ""
    echo "=== Server log ==="
    cat /tmp/go-cube.log
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null

[ $fail -gt 0 ] && exit 1
exit 0
