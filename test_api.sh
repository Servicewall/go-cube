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
./go-cube > /tmp/go-cube.log 2>&1 &
SERVER_PID=$!

sleep 3


echo ""
echo "=== 1. Apiview列表左边栏 ==="
#{"measures":["ApiView.sidebarTypeCount","ApiView.sidebarFirstLevelTypeCount"],"timeDimensions":[{"dimension":"ApiView.ts","dateRange":"today"}],"filters":[{"member":"ApiView.topoNetwork","operator":"notEquals","values":["外发"]},{"member":"ApiView.apiTypeTag","operator":"equals","values":["API"]}],"dimensions":[],"segments":["ApiView.org","ApiView.black","ApiView.onePerDay"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22ApiView.sidebarTypeCount%22%2C%22ApiView.sidebarFirstLevelTypeCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiView.topoNetwork%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%E5%A4%96%E5%8F%91%22%5D%7D%2C%7B%22member%22%3A%22ApiView.apiTypeTag%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22API%22%5D%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "Apiview列表左边栏" "$result"

echo ""
echo "=== 2. Apiview allCountForList ==="
#{"measures":["ApiView.allCountForList"],"timeDimensions":[{"dimension":"ApiView.ts","dateRange":"today"}],"filters":[{"member":"ApiView.filtered","operator":"equals","values":["1"]}],"dimensions":[],"segments":["ApiView.org","ApiView.onePerDay"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22ApiView.allCountForList%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiView.filtered%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%221%22%5D%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "Apiview allCountForList" "$result"

echo ""
echo "=== 3. Apiview左边栏过滤已发现 allCountForList数量 ==="
#{"measures":["ApiView.allCountForList"],"timeDimensions":[{"dimension":"ApiView.ts","dateRange":"today"}],"filters":[{"member":"ApiView.sidebarType","operator":"contains","values":["已发现->"]},{"member":"ApiView.topoNetwork","operator":"notEquals","values":["外发"]},{"member":"ApiView.apiTypeTag","operator":"equals","values":["API"]}],"dimensions":[],"segments":["ApiView.org","ApiView.black","ApiView.onePerDay"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22ApiView.allCountForList%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiView.sidebarType%22%2C%22operator%22%3A%22contains%22%2C%22values%22%3A%5B%22%E5%B7%B2%E5%8F%91%E7%8E%B0-%3E%22%5D%7D%2C%7B%22member%22%3A%22ApiView.topoNetwork%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%E5%A4%96%E5%8F%91%22%5D%7D%2C%7B%22member%22%3A%22ApiView.apiTypeTag%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22API%22%5D%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "Apiview左边栏过滤已发现 allCountForList数量" "$result"

echo ""
echo "=== 4. ApiView 列表明细 ==="
#{"ungrouped":true,"measures":[],"timeDimensions":[{"dimension":"ApiView.ts","dateRange":"today"}],"order":{"ApiView.count":"desc","ApiView.ts":"desc"},"filters":[{"member":"ApiView.sidebarType","operator":"contains","values":["已发现->"]},{"member":"ApiView.topoNetwork","operator":"notEquals","values":["外发"]},{"member":"ApiView.apiTypeTag","operator":"equals","values":["API"]}],"dimensions":["ApiView.count","ApiView.activeTag","ApiView.bizImportance","ApiView.webServerTypeTag","ApiView.topoNetwork","ApiView.customRuleTag","ApiView.configTag","ApiView.apiTypeTag","ApiView.riskKeyScoreTuple","ApiView.weakKeyScoreTuple","ApiView.firstTs","ApiView.ts","ApiView.appName","ApiView.currentReqKey","ApiView.reqSensScoreTupleRaw","ApiView.resSensScoreTupleRaw","ApiView.channel","ApiView.host","ApiView.method","ApiView.urlRoute","ApiView.bizName","ApiView.bizAIAnalysis","ApiView.managementStatus","ApiView.filtered","ApiView.dctSection","ApiView.director"],"limit":20,"offset":0,"segments":["ApiView.org","ApiView.black","ApiView.onePerDay"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22order%22%3A%7B%22ApiView.count%22%3A%22desc%22%2C%22ApiView.ts%22%3A%22desc%22%7D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiView.sidebarType%22%2C%22operator%22%3A%22contains%22%2C%22values%22%3A%5B%22%E5%B7%B2%E5%8F%91%E7%8E%B0-%3E%22%5D%7D%2C%7B%22member%22%3A%22ApiView.topoNetwork%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%E5%A4%96%E5%8F%91%22%5D%7D%2C%7B%22member%22%3A%22ApiView.apiTypeTag%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22API%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22ApiView.count%22%2C%22ApiView.activeTag%22%2C%22ApiView.bizImportance%22%2C%22ApiView.webServerTypeTag%22%2C%22ApiView.topoNetwork%22%2C%22ApiView.customRuleTag%22%2C%22ApiView.configTag%22%2C%22ApiView.apiTypeTag%22%2C%22ApiView.riskKeyScoreTuple%22%2C%22ApiView.weakKeyScoreTuple%22%2C%22ApiView.firstTs%22%2C%22ApiView.ts%22%2C%22ApiView.appName%22%2C%22ApiView.currentReqKey%22%2C%22ApiView.reqSensScoreTupleRaw%22%2C%22ApiView.resSensScoreTupleRaw%22%2C%22ApiView.channel%22%2C%22ApiView.host%22%2C%22ApiView.method%22%2C%22ApiView.urlRoute%22%2C%22ApiView.bizName%22%2C%22ApiView.bizAIAnalysis%22%2C%22ApiView.managementStatus%22%2C%22ApiView.filtered%22%2C%22ApiView.dctSection%22%2C%22ApiView.director%22%5D%2C%22limit%22%3A20%2C%22offset%22%3A0%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiView 列表明细" "$result"

echo ""
echo "=== 5. ApiView Tag ==="
#{"measures":["ApiView.customRuleTagSet","ApiView.configTagSet"],"filters":[],"dimensions":[],"segments":["ApiView.org","ApiView.black","ApiView.onePerDay"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22ApiView.customRuleTagSet%22%2C%22ApiView.configTagSet%22%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiView Tag" "$result"

echo ""
echo "=== 6. ApiView 功能分组 ==="
#{"measures":[],"timeDimensions":[{"dimension":"ApiView.ts"}],"filters":[{"member":"ApiView.isApi","operator":"equals","values":["1"]},{"member":"ApiView.topoNetwork","operator":"notEquals","values":["外发"]}],"dimensions":["ApiView.staticTagExt"],"segments":["ApiView.org","ApiView.black","ApiView.onePerDay"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiView.isApi%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%221%22%5D%7D%2C%7B%22member%22%3A%22ApiView.topoNetwork%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%E5%A4%96%E5%8F%91%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22ApiView.staticTagExt%22%5D%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiView 功能分组" "$result"

echo ""
echo "=== 7. ApiView 功能分组列表 ==="
#{"renewQuery":true,"measures":[],"timeDimensions":[{"dimension":"ApiView.ts"}],"filters":[{"member":"ApiView.isApi","operator":"equals","values":["1"]},{"member":"ApiView.topoNetwork","operator":"notEquals","values":["外发"]},{"member":"ApiView.autoTagExt","operator":"equals","values":["新增"]}],"dimensions":["ApiView.channel","ApiView.host","ApiView.method","ApiView.urlRoute","ApiView.autoTagTypeExt"],"segments":["ApiView.org","ApiView.black","ApiView.onePerDay"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22renewQuery%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiView.isApi%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%221%22%5D%7D%2C%7B%22member%22%3A%22ApiView.topoNetwork%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%E5%A4%96%E5%8F%91%22%5D%7D%2C%7B%22member%22%3A%22ApiView.autoTagExt%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22%E6%96%B0%E5%A2%9E%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22ApiView.channel%22%2C%22ApiView.host%22%2C%22ApiView.method%22%2C%22ApiView.urlRoute%22%2C%22ApiView.autoTagTypeExt%22%5D%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiView 功能分组列表" "$result"

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
