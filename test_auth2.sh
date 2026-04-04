#!/bin/bash
# test_auth2.sh — UserAuthView and ApiView gap-fill tests
# Covers fields NOT exercised by test_auth.sh and test_api.sh

BASE="http://localhost:4000"
pass=0
fail=0

check() {
    local desc="$1"
    local result="$2"
    if echo "$result" | jq -e '.error' > /dev/null 2>&1; then
        echo "[FAIL] $desc — server error: $(echo "$result" | jq -r '.error')"
        ((fail++))
    elif echo "$result" | jq -e '.results[0].data' > /dev/null 2>&1; then
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
echo "Testing health endpoint..."
curl -s "$BASE/health" | jq .

echo ""
echo "========================================"
echo "=== UserAuthView: gap-fill tests ==="
echo "========================================"

echo ""
echo "=== 1. UserAuthView: basInfo+authInfo+apiNum measures by host+url+method ==="
# Tests measures: basInfo, authInfo, apiNum
# dimensions: host, url, method
# segments: org, confFilter
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22UserAuthView.basInfo%22%2C%22UserAuthView.authInfo%22%2C%22UserAuthView.apiNum%22%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22UserAuthView.host%22%2C%22UserAuthView.url%22%2C%22UserAuthView.method%22%5D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22UserAuthView.org%22%2C%22UserAuthView.confFilter%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "UserAuthView: basInfo+authInfo+apiNum by host+url+method" "$result"

echo ""
echo "=== 2. UserAuthView: aggAuthKey measure by host+url+method ==="
# Tests measure: aggAuthKey (groupUniqArray)
# dimensions: host, url, method
# segments: org, confFilter
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22UserAuthView.aggAuthKey%22%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22UserAuthView.host%22%2C%22UserAuthView.url%22%2C%22UserAuthView.method%22%5D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22UserAuthView.org%22%2C%22UserAuthView.confFilter%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "UserAuthView: aggAuthKey by host+url+method" "$result"

echo ""
echo "=== 3. UserAuthView: authKey+authApp dimensions with count ==="
# Tests dimensions: authKey (arrayJoin expr), authApp (dict-lookup)
# measure: count
# segments: org, confFilter
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22UserAuthView.count%22%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22UserAuthView.authKey%22%2C%22UserAuthView.authApp%22%5D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22UserAuthView.org%22%2C%22UserAuthView.confFilter%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "UserAuthView: count by authKey+authApp" "$result"

echo ""
echo "=== 4. UserAuthView: lastTs time dimension (order by lastTs desc) ==="
# Tests dimension: lastTs (time type) — included in GROUP BY dimensions
# measures: count, piiCount
# order: lastTs desc
# segments: org, confFilter
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22UserAuthView.count%22%2C%22UserAuthView.piiCount%22%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22UserAuthView.host%22%2C%22UserAuthView.url%22%2C%22UserAuthView.method%22%2C%22UserAuthView.lastTs%22%5D%2C%22order%22%3A%7B%22UserAuthView.lastTs%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22UserAuthView.org%22%2C%22UserAuthView.confFilter%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "UserAuthView: count+piiCount by host+url+method+lastTs order lastTs desc" "$result"

echo ""
echo "=== 5. UserAuthView: full dimension set — host+url+method+appName+loginTokenKey+lastTs+authKey+authApp ==="
# Tests all 8 UserAuthView dimensions together with count
# Uses lastTs as both timeDimension and grouped dimension
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22UserAuthView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22UserAuthView.lastTs%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22UserAuthView.host%22%2C%22UserAuthView.url%22%2C%22UserAuthView.method%22%2C%22UserAuthView.appName%22%2C%22UserAuthView.loginTokenKey%22%2C%22UserAuthView.authKey%22%2C%22UserAuthView.authApp%22%5D%2C%22order%22%3A%7B%22UserAuthView.count%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22UserAuthView.org%22%2C%22UserAuthView.confFilter%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "UserAuthView: count by all 7 dimensions" "$result"

echo ""
echo "========================================"
echo "=== ApiView: gap-fill tests ==="
echo "========================================"

echo ""
echo "=== 6. ApiView: reqKeyTupleArray+currentReqKeyTs dimensions (ungrouped, limit 5) ==="
# Tests dimensions: reqKeyTupleArray (groupUniqArray expression), currentReqKeyTs (time)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ApiView.api%22%2C%22ApiView.reqKeyTupleArray%22%2C%22ApiView.currentReqKeyTs%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiView: ungrouped reqKeyTupleArray+currentReqKeyTs limit 5" "$result"

echo ""
echo "=== 7. ApiView: metricMap+successCount+hourCount+weakCount dimensions (ungrouped, limit 5) ==="
# Tests dimensions: metricMap (mapFromArrays expression), successCount, hourCount, weakCount (number dims)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ApiView.api%22%2C%22ApiView.metricMap%22%2C%22ApiView.successCount%22%2C%22ApiView.hourCount%22%2C%22ApiView.weakCount%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiView: ungrouped metricMap+successCount+hourCount+weakCount limit 5" "$result"

echo ""
echo "=== 8. ApiView: statusCount+timeSum+lengthSum dimensions (ungrouped, limit 5) ==="
# Tests dimensions: statusCount, timeSum, lengthSum (number dims from metric_count map)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ApiView.api%22%2C%22ApiView.statusCount%22%2C%22ApiView.timeSum%22%2C%22ApiView.lengthSum%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiView: ungrouped statusCount+timeSum+lengthSum limit 5" "$result"

echo ""
echo "=== 9. ApiView: protocol dimension grouped by appName+protocol (count, limit 10) ==="
# Tests dimension: protocol (multiIf expression — HTTP/HTTP2/WebSocket/MQTT)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ApiView.allCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ApiView.appName%22%2C%22ApiView.protocol%22%5D%2C%22order%22%3A%7B%22ApiView.allCount%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiView: allCount by appName+protocol limit 10" "$result"

echo ""
echo "=== 10. ApiView: sidebarTypeArray+sidebarFirstLevelTypeArray dimensions (ungrouped, limit 5) ==="
# Tests dimensions: sidebarTypeArray (array), sidebarFirstLevelTypeArray (array)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiView.topoNetwork%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%E5%A4%96%E5%8F%91%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22ApiView.api%22%2C%22ApiView.sidebarTypeArray%22%2C%22ApiView.sidebarFirstLevelTypeArray%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiView: ungrouped sidebarTypeArray+sidebarFirstLevelTypeArray limit 5" "$result"

echo ""
echo "=== 11. ApiView: id dimension grouped by appName+method+urlRoute (count, filter by id) ==="
# Tests dimension: id (cityHash64 fingerprint)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ApiView.allCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ApiView.id%22%2C%22ApiView.appName%22%2C%22ApiView.method%22%2C%22ApiView.urlRoute%22%5D%2C%22order%22%3A%7B%22ApiView.allCount%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiView: allCount by id+appName+method+urlRoute limit 10" "$result"

echo ""
echo "=== 12. ApiView: isFavorite dimension filter (equals 1, grouped) ==="
# Tests dimension: isFavorite (subquery-based boolean)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ApiView.allCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiView.isFavorite%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%221%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22ApiView.appName%22%2C%22ApiView.isFavorite%22%5D%2C%22order%22%3A%7B%22ApiView.allCount%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiView: allCount by appName+isFavorite (filter isFavorite=1) limit 10" "$result"

echo ""
echo "=== 13. ApiView: appId dimension grouped (allCount, limit 10) ==="
# Tests dimension: appId (dict-lookup subquery)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ApiView.allCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ApiView.appId%22%2C%22ApiView.appName%22%5D%2C%22order%22%3A%7B%22ApiView.allCount%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiView: allCount by appId+appName limit 10" "$result"

echo ""
echo "========================================"
echo "Results: $pass passed, $fail failed"
echo "========================================"

if [ $fail -gt 0 ]; then
    echo ""
    echo "=== Server log ==="
    cat /tmp/go-cube.log
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null

[ $fail -gt 0 ] && exit 1
exit 0
