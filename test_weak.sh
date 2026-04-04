#!/bin/bash
# Test WeakView queries against local go-cube server
# Mirrors production curl requests from demo.servicewall.cn

BASE="http://localhost:4000"
pass=0
fail=0

check() {
    local desc="$1"
    local result="$2"
    # Fail if the response contains a top-level error field
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
./go-cube &
SERVER_PID=$!
sleep 2

echo ""
echo "Testing health endpoint..."
curl -s "$BASE/health" | jq .

echo ""
echo "========================================"
echo "=== WeakView aggregate queries ==="
echo "========================================"

echo ""
echo "=== 1. 弱点概览: riskCount+levelCount+firstCategoryCount+owaspCategoryCount+manageCount+categoryCount (today) ==="
# measures: riskCount, levelCount, firstCategoryCount, owaspCategoryCount, manageCount, categoryCount
# timeDimensions: WeakView.last, dateRange: today
# segments: org+black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22WeakView.riskCount%22%2C%22WeakView.levelCount%22%2C%22WeakView.firstCategoryCount%22%2C%22WeakView.owaspCategoryCount%22%2C%22WeakView.manageCount%22%2C%22WeakView.categoryCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22WeakView.last%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22WeakView.org%22%2C%22WeakView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "弱点概览 riskCount+levelCount+firstCategoryCount+owaspCategoryCount+manageCount+categoryCount" "$result"

echo ""
echo "=== 2. 高危弱点数: riskCount (tag in [first,repeated], weakLevel != 低危害) ==="
# measures: riskCount
# timeDimensions: WeakView.last, dateRange: today
# filters: tag equals [first, repeated], weakLevel notEquals [低危害]
# segments: org+black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22WeakView.riskCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22WeakView.last%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22WeakView.tag%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22first%22%2C%22repeated%22%5D%7D%2C%7B%22member%22%3A%22WeakView.weakLevel%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%E4%BD%8E%E5%8D%B1%E5%AE%B3%22%5D%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22WeakView.org%22%2C%22WeakView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "高危弱点数 riskCount (tag in [first,repeated] & weakLevel != 低危害)" "$result"

echo ""
echo "=== 3. 弱点明细列表: ungrouped, 15 dims, tag in [first,repeated] & weakLevel != 低危害, order weakScore desc+last desc, limit 20 ==="
# ungrouped: true, no measures
# dimensions: defectId, urlRoute, weakLevel, firstCategory, first, last, channel, host, count,
#             topoNetwork, respSensTagSet, method, manageId, tag, weakScore
# order: weakScore desc, last desc
# filters: tag equals [first, repeated], weakLevel notEquals [低危害]
# limit: 20, offset: 0, segments: org+black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22WeakView.last%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22order%22%3A%7B%22WeakView.weakScore%22%3A%22desc%22%2C%22WeakView.last%22%3A%22desc%22%7D%2C%22filters%22%3A%5B%7B%22member%22%3A%22WeakView.tag%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22first%22%2C%22repeated%22%5D%7D%2C%7B%22member%22%3A%22WeakView.weakLevel%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%E4%BD%8E%E5%8D%B1%E5%AE%B3%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22WeakView.defectId%22%2C%22WeakView.urlRoute%22%2C%22WeakView.weakLevel%22%2C%22WeakView.firstCategory%22%2C%22WeakView.first%22%2C%22WeakView.last%22%2C%22WeakView.channel%22%2C%22WeakView.host%22%2C%22WeakView.count%22%2C%22WeakView.topoNetwork%22%2C%22WeakView.respSensTagSet%22%2C%22WeakView.method%22%2C%22WeakView.manageId%22%2C%22WeakView.tag%22%2C%22WeakView.weakScore%22%5D%2C%22limit%22%3A20%2C%22offset%22%3A0%2C%22segments%22%3A%5B%22WeakView.org%22%2C%22WeakView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "弱点明细列表 ungrouped 15 dims order weakScore+last desc limit 20" "$result"

echo ""
echo "========================================"
echo "=== WeakView AI分析字段 ==="
echo "========================================"

echo ""
echo "=== 4. AI弱点分析: lastWeakAnalysis measure, filter by target, segment org ==="
# measures: lastWeakAnalysis
# filters: target equals [无鉴权返回敏感信息-192.168.110.13:63012-MQTT|S2C-/PUBLISH/testA]
# segments: org
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AiWeakAnalysisView.lastWeakAnalysis%22%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22AiWeakAnalysisView.target%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22%E6%97%A0%E9%89%B4%E6%9D%83%E8%BF%94%E5%9B%9E%E6%95%8F%E6%84%9F%E4%BF%A1%E6%81%AF-192.168.110.13%3A63012-MQTT%7CS2C-%2FPUBLISH%2FtestA%22%5D%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AiWeakAnalysisView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "AiWeakAnalysisView lastWeakAnalysis by target" "$result"

echo ""
echo "========================================"
echo "=== WeakDetailView ==="
echo "========================================"

echo ""
echo "=== 5. 弱点明细: ungrouped, 9 dims, 4 filters, order ts desc, limit 3, segment org ==="
# ungrouped: true, no measures
# dimensions: id, ts, evidence, request, response, reqDefectKey, resDefectKey, reqDefectVal, resDefectVal
# filters: defectId=XSS注入..., host=172.31.36.181, method=GET, urlRoute=/invoker/...
# order: ts desc, limit: 3, segments: org
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3A%20true%2C%20%22measures%22%3A%20%5B%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22WeakDetailView.ts%22%7D%5D%2C%20%22order%22%3A%20%7B%22WeakDetailView.ts%22%3A%20%22desc%22%7D%2C%20%22filters%22%3A%20%5B%7B%22member%22%3A%20%22WeakDetailView.defectId%22%2C%20%22operator%22%3A%20%22equals%22%2C%20%22values%22%3A%20%5B%22XSS%E6%B3%A8%E5%85%A5%E8%AF%B7%E6%B1%82%E6%BC%8F%E6%B4%9E%E6%A3%80%E6%B5%8B%28MAX%E7%89%88%29%22%5D%7D%2C%20%7B%22member%22%3A%20%22WeakDetailView.host%22%2C%20%22operator%22%3A%20%22equals%22%2C%20%22values%22%3A%20%5B%22172.31.36.181%22%5D%7D%2C%20%7B%22member%22%3A%20%22WeakDetailView.method%22%2C%20%22operator%22%3A%20%22equals%22%2C%20%22values%22%3A%20%5B%22GET%22%5D%7D%2C%20%7B%22member%22%3A%20%22WeakDetailView.urlRoute%22%2C%20%22operator%22%3A%20%22equals%22%2C%20%22values%22%3A%20%5B%22%2Finvoker%2FJMXInvokerServlet%2Fvulnerabilities%2Fxss_r%2F%22%5D%7D%5D%2C%20%22dimensions%22%3A%20%5B%22WeakDetailView.id%22%2C%20%22WeakDetailView.ts%22%2C%20%22WeakDetailView.evidence%22%2C%20%22WeakDetailView.request%22%2C%20%22WeakDetailView.response%22%2C%20%22WeakDetailView.reqDefectKey%22%2C%20%22WeakDetailView.resDefectKey%22%2C%20%22WeakDetailView.reqDefectVal%22%2C%20%22WeakDetailView.resDefectVal%22%5D%2C%20%22limit%22%3A%203%2C%20%22segments%22%3A%20%5B%22WeakDetailView.org%22%5D%2C%20%22timezone%22%3A%20%22Asia%2FShanghai%22%7D")
check "WeakDetailView ungrouped 9 dims 4 filters limit 3" "$result"

echo ""
echo "========================================"
echo "=== WeakView: gap-fill tests ==="
echo "========================================"

echo ""
echo "=== 6. WeakView: owaspTop10+firstCategory+weakLevel+defectId+host (riskCount, limit 10) ==="
# Tests dimension: owaspTop10 (dict-lookup expression)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22WeakView.riskCount%22%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22WeakView.owaspTop10%22%2C%22WeakView.firstCategory%22%2C%22WeakView.weakLevel%22%2C%22WeakView.defectId%22%2C%22WeakView.host%22%5D%2C%22order%22%3A%7B%22WeakView.riskCount%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22WeakView.org%22%2C%22WeakView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "WeakView: riskCount by owaspTop10+firstCategory+weakLevel+defectId+host limit 10" "$result"

echo ""
echo "=== 7. WeakView: addTime+tag+manageId+defectId (ungrouped, order addTime desc, limit 10) ==="
# Tests dimension: addTime (fromUnixTimestamp time dim), tag, manageId
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22WeakView.last%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22WeakView.defectId%22%2C%22WeakView.host%22%2C%22WeakView.method%22%2C%22WeakView.urlRoute%22%2C%22WeakView.addTime%22%2C%22WeakView.tag%22%2C%22WeakView.manageId%22%5D%2C%22order%22%3A%7B%22WeakView.addTime%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22WeakView.org%22%2C%22WeakView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "WeakView: ungrouped defectId+host+method+urlRoute+addTime+tag+manageId order addTime desc limit 10" "$result"

echo ""
echo "=== 8. WeakView: assetName+appName+netDomain dimensions (riskCount, limit 10) ==="
# Tests dimensions: assetName (url_action expr), appName (dict-lookup), netDomain (url_action[7])
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22WeakView.riskCount%22%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22WeakView.assetName%22%2C%22WeakView.appName%22%2C%22WeakView.netDomain%22%5D%2C%22order%22%3A%7B%22WeakView.riskCount%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22WeakView.org%22%2C%22WeakView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "WeakView: riskCount by assetName+appName+netDomain limit 10" "$result"

echo ""
echo "=== 9. WeakView: target dimension (ungrouped, limit 5) ==="
# Tests dimension: target (concat expression)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22WeakView.last%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22WeakView.target%22%2C%22WeakView.defectId%22%2C%22WeakView.host%22%2C%22WeakView.method%22%2C%22WeakView.urlRoute%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22WeakView.org%22%2C%22WeakView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "WeakView: ungrouped target+defectId+host+method+urlRoute limit 5" "$result"

echo ""
echo "=== 10. WeakView: analysis dimension (ungrouped, limit 5) ==="
# Tests dimension: analysis (weak_data.1 map access — fixed from weak_data['analysis'])
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22WeakView.last%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22WeakView.defectId%22%2C%22WeakView.host%22%2C%22WeakView.analysis%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22WeakView.org%22%2C%22WeakView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "WeakView: ungrouped defectId+host+analysis limit 5" "$result"

echo ""
echo "=== 11. WeakView: uniqWeakApi measure (no dims) ==="
# Tests measure: uniqWeakApi (uniqHLL12)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22WeakView.uniqWeakApi%22%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22WeakView.org%22%2C%22WeakView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "WeakView: uniqWeakApi (no dims)" "$result"

echo ""
echo "=== 12. WeakView: sum measure (total trigger count, no dims) ==="
# Tests measure: sum (sum(count))
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22WeakView.sum%22%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22WeakView.org%22%2C%22WeakView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "WeakView: sum (no dims)" "$result"

echo ""
echo "=== 13. WeakView: secondCategoryCount measure (by firstCategory, limit 10) ==="
# Tests measure: secondCategoryCount (sumMapIf on weak_name)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22WeakView.secondCategoryCount%22%2C%22WeakView.riskCount%22%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22WeakView.firstCategory%22%5D%2C%22order%22%3A%7B%22WeakView.riskCount%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22WeakView.org%22%2C%22WeakView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "WeakView: secondCategoryCount+riskCount by firstCategory limit 10" "$result"

echo ""
echo "--- $pass passed, $fail failed ---"

echo ""
echo "Stopping server..."
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null
echo "All tests completed."
