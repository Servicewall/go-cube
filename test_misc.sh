#!/bin/bash
# test_misc.sh — WeakView, AuditView, ApiDayView, PromptView gap-fill tests
# Covers fields NOT exercised by existing test_weak.sh, test_audit.sh, test_api.sh, test_prompt.sh

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
echo "=== WeakView: gap-fill tests ==="
echo "========================================"

echo ""
echo "=== 1. WeakView: owaspTop10+firstCategory+weakLevel+defectId+host (count, limit 10) ==="
# Tests dimension: owaspTop10 (dict-lookup expression)
# Already covered: firstCategory, weakLevel, defectId, host — kept for context
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22WeakView.riskCount%22%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22WeakView.owaspTop10%22%2C%22WeakView.firstCategory%22%2C%22WeakView.weakLevel%22%2C%22WeakView.defectId%22%2C%22WeakView.host%22%5D%2C%22order%22%3A%7B%22WeakView.riskCount%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22WeakView.org%22%2C%22WeakView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "WeakView: riskCount by owaspTop10+firstCategory+weakLevel+defectId+host limit 10" "$result"

echo ""
echo "=== 2. WeakView: addTime+tag+manageId+defectId (ungrouped, order addTime desc, limit 10) ==="
# Tests dimension: addTime (fromUnixTimestamp time dim), tag, manageId
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22WeakView.last%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22WeakView.defectId%22%2C%22WeakView.host%22%2C%22WeakView.method%22%2C%22WeakView.urlRoute%22%2C%22WeakView.addTime%22%2C%22WeakView.tag%22%2C%22WeakView.manageId%22%5D%2C%22order%22%3A%7B%22WeakView.addTime%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22WeakView.org%22%2C%22WeakView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "WeakView: ungrouped defectId+host+method+urlRoute+addTime+tag+manageId order addTime desc limit 10" "$result"

echo ""
echo "=== 3. WeakView: assetName+appName+netDomain dimensions (riskCount, limit 10) ==="
# Tests dimensions: assetName (url_action expr), appName (dict-lookup), netDomain (url_action[7])
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22WeakView.riskCount%22%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22WeakView.assetName%22%2C%22WeakView.appName%22%2C%22WeakView.netDomain%22%5D%2C%22order%22%3A%7B%22WeakView.riskCount%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22WeakView.org%22%2C%22WeakView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "WeakView: riskCount by assetName+appName+netDomain limit 10" "$result"

echo ""
echo "=== 4. WeakView: target dimension (ungrouped, limit 5) ==="
# Tests dimension: target (concat expression)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22WeakView.last%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22WeakView.target%22%2C%22WeakView.defectId%22%2C%22WeakView.host%22%2C%22WeakView.method%22%2C%22WeakView.urlRoute%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22WeakView.org%22%2C%22WeakView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "WeakView: ungrouped target+defectId+host+method+urlRoute limit 5" "$result"

echo ""
echo "=== 5. WeakView: analysis dimension (ungrouped, limit 5) ==="
# Tests dimension: analysis (weak_data['analysis'] map access)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22WeakView.last%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22WeakView.defectId%22%2C%22WeakView.host%22%2C%22WeakView.analysis%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22WeakView.org%22%2C%22WeakView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "WeakView: ungrouped defectId+host+analysis limit 5" "$result"

echo ""
echo "=== 6. WeakView: uniqWeakApi measure (no dims, segment org+black) ==="
# Tests measure: uniqWeakApi (uniqHLL12)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22WeakView.uniqWeakApi%22%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22WeakView.org%22%2C%22WeakView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "WeakView: uniqWeakApi (no dims)" "$result"

echo ""
echo "=== 7. WeakView: sum measure (total trigger count, no dims) ==="
# Tests measure: sum (sum(count))
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22WeakView.sum%22%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22WeakView.org%22%2C%22WeakView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "WeakView: sum (no dims)" "$result"

echo ""
echo "=== 8. WeakView: secondCategoryCount measure (by firstCategory, limit 10) ==="
# Tests measure: secondCategoryCount (sumMapIf on weak_name)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22WeakView.secondCategoryCount%22%2C%22WeakView.riskCount%22%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22WeakView.firstCategory%22%5D%2C%22order%22%3A%7B%22WeakView.riskCount%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22WeakView.org%22%2C%22WeakView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "WeakView: secondCategoryCount+riskCount by firstCategory limit 10" "$result"

echo ""
echo "========================================"
echo "=== AuditView: gap-fill tests ==="
echo "========================================"

echo ""
echo "=== 9. AuditView: channel dimension (count by channel, segment org) ==="
# Tests dimension: channel
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AuditView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AuditView.dt%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AuditView.channel%22%5D%2C%22order%22%3A%7B%22AuditView.count%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22AuditView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "AuditView: count by channel limit 10" "$result"

echo ""
echo "=== 10. AuditView: ipGeoCountry+ipGeoProvince dimensions (count, type=IP, limit 10) ==="
# Tests dimensions: ipGeoCountry (ip_geo[1]), ipGeoProvince (ip_geo[2])
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AuditView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AuditView.dt%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22AuditView.type%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22IP%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22AuditView.ipGeoCountry%22%2C%22AuditView.ipGeoProvince%22%5D%2C%22order%22%3A%7B%22AuditView.count%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22AuditView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "AuditView: count by ipGeoCountry+ipGeoProvince (type=IP) limit 10" "$result"

echo ""
echo "=== 11. AuditView: deviceType dimension (count, type=Device, limit 10) ==="
# Tests dimension: deviceType (multiIf on content prefix)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AuditView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AuditView.dt%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22AuditView.type%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22Device%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22AuditView.deviceType%22%5D%2C%22order%22%3A%7B%22AuditView.count%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22AuditView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "AuditView: count by deviceType (type=Device) limit 10" "$result"

echo ""
echo "=== 12. AuditView: lastTs measure (max last_ts, no dims, today) ==="
# Tests measure: lastTs (max(last_ts) time measure)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AuditView.lastTs%22%2C%22AuditView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AuditView.dt%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AuditView.type%22%5D%2C%22order%22%3A%7B%22AuditView.lastTs%22%3A%22desc%22%7D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AuditView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "AuditView: lastTs+count by type order lastTs desc limit 5" "$result"

echo ""
echo "=== 13. AuditView: all gap dims together — channel+ipGeoCountry+ipGeoProvince+deviceType (count, today) ==="
# Exercises all 4 gap dimensions in a single query; type filter not applied so all rows included
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AuditView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AuditView.dt%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AuditView.channel%22%2C%22AuditView.ipGeoCountry%22%2C%22AuditView.ipGeoProvince%22%2C%22AuditView.deviceType%22%5D%2C%22order%22%3A%7B%22AuditView.count%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22AuditView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "AuditView: count by channel+ipGeoCountry+ipGeoProvince+deviceType limit 10" "$result"

echo ""
echo "========================================"
echo "=== ApiDayView: gap-fill tests ==="
echo "========================================"

echo ""
echo "=== 14. ApiDayView: risk dimension (count by risk, 7 days) ==="
# Tests dimension: risk (arrayJoin + risk_dict filter)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ApiDayView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiDayView.dt%22%2C%22dateRange%22%3A%22from+7+days+ago+to+now%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ApiDayView.risk%22%5D%2C%22order%22%3A%7B%22ApiDayView.count%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiDayView: count by risk limit 10 (7 days)" "$result"

echo ""
echo "=== 15. ApiDayView: hasReqSens dimension (count by hasReqSens, 7 days) ==="
# Tests dimension: hasReqSens (length(finalizeAggregation(req_sens_uniq)))
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ApiDayView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiDayView.dt%22%2C%22dateRange%22%3A%22from+7+days+ago+to+now%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ApiDayView.hasReqSens%22%5D%2C%22order%22%3A%7B%22ApiDayView.count%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiDayView: count by hasReqSens limit 10 (7 days)" "$result"

echo ""
echo "=== 16. ApiDayView: status dimension (count by status, 7 days, filter host+urlRoute+method) ==="
# Tests dimension: status (arrayJoin on status_count)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ApiDayView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiDayView.dt%22%2C%22dateRange%22%3A%22from+7+days+ago+to+now%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiDayView.host%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22127.0.0.1%22%5D%7D%2C%7B%22member%22%3A%22ApiDayView.urlRoute%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22%2FapiAuth%22%5D%7D%2C%7B%22member%22%3A%22ApiDayView.method%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22POST%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22ApiDayView.status%22%5D%2C%22order%22%3A%7B%22ApiDayView.count%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiDayView: count by status (filter host+urlRoute+method) limit 10 (7 days)" "$result"

echo ""
echo "=== 17. ApiDayView: riskSumMap measure (filter host+urlRoute+method, 7 days) ==="
# Tests measure: riskSumMap (sumMap aggregation on risk_count zip) — riskTuple is non-aggregate, use riskSumMap
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ApiDayView.riskSumMap%22%2C%22ApiDayView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiDayView.dt%22%2C%22dateRange%22%3A%22from%207%20days%20ago%20to%20now%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiDayView.host%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22127.0.0.1%22%5D%7D%2C%7B%22member%22%3A%22ApiDayView.urlRoute%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22%2FapiAuth%22%5D%7D%2C%7B%22member%22%3A%22ApiDayView.method%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22POST%22%5D%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiDayView: riskSumMap+count (filter host+urlRoute+method, 7 days)" "$result"

echo ""
echo "=== 18. ApiDayView: reqSensUniqMap+resSensUniqMap measures (filter host+urlRoute+method, 7 days) ==="
# Tests measures: reqSensUniqMap (uniqMapMerge), resSensUniqMap (uniqMapMerge)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ApiDayView.reqSensUniqMap%22%2C%22ApiDayView.resSensUniqMap%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiDayView.dt%22%2C%22dateRange%22%3A%22from+7+days+ago+to+now%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiDayView.host%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22127.0.0.1%22%5D%7D%2C%7B%22member%22%3A%22ApiDayView.urlRoute%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22%2FapiAuth%22%5D%7D%2C%7B%22member%22%3A%22ApiDayView.method%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22POST%22%5D%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiDayView: reqSensUniqMap+resSensUniqMap (filter host+urlRoute+method, 7 days)" "$result"

echo ""
echo "=== 19. ApiDayView: risk+hasReqSens+status dimensions together (count, 7 days, limit 5) ==="
# Exercises all 3 gap dimensions in one query (careful: all are arrayJoin dims so may produce fan-out)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ApiDayView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiDayView.dt%22%2C%22dateRange%22%3A%22from+7+days+ago+to+now%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiDayView.host%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22127.0.0.1%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22ApiDayView.risk%22%2C%22ApiDayView.status%22%5D%2C%22order%22%3A%7B%22ApiDayView.count%22%3A%22desc%22%7D%2C%22limit%22%3A5%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiDayView: count by risk+status (filter host, 7 days) limit 5" "$result"

echo ""
echo "========================================"
echo "=== PromptView: gap-fill tests ==="
echo "========================================"

echo ""
echo "=== 20. PromptView: id+method+host+url+embedding dimensions (ungrouped, limit 5) ==="
# Tests dimensions: id (primary_key), method, host, url, embedding
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22PromptView.ts%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22PromptView.id%22%2C%22PromptView.method%22%2C%22PromptView.host%22%2C%22PromptView.url%22%2C%22PromptView.embedding%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22PromptView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "PromptView: ungrouped id+method+host+url+embedding limit 5" "$result"

echo ""
echo "=== 21. PromptView: method dimension grouped (count by method) ==="
# Tests dimension: method grouped query
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22PromptView.count%22%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22PromptView.method%22%5D%2C%22order%22%3A%7B%22PromptView.count%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22PromptView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "PromptView: count by method limit 10" "$result"

echo ""
echo "=== 22. PromptView: host+url dimensions grouped (count, limit 10) ==="
# Tests dimensions: host, url grouped
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22PromptView.count%22%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22PromptView.host%22%2C%22PromptView.url%22%5D%2C%22order%22%3A%7B%22PromptView.count%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22PromptView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "PromptView: count by host+url limit 10" "$result"

echo ""
echo "=== 23. PromptView: filter by id (equals specific value) ==="
# Tests id as a filter dimension
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22PromptView.ts%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22PromptView.id%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22nonexistent-id-for-test%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22PromptView.id%22%2C%22PromptView.ts%22%2C%22PromptView.prompt%22%2C%22PromptView.host%22%2C%22PromptView.url%22%2C%22PromptView.method%22%5D%2C%22limit%22%3A1%2C%22segments%22%3A%5B%22PromptView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "PromptView: ungrouped filter by id (no rows expected)" "$result"

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
