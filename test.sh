#!/bin/bash
source "$(dirname "$0")/common.sh"

setup_server_trap
start_server 2
test_health

echo ""
echo "Testing simple query..."
# URL编码的查询: {"dimensions":["AccessView.id"],"measures":["AccessView.count"],"limit":5}
curl -s "$BASE/load?query=%7B%22dimensions%22%3A%5B%22AccessView.id%22%5D%2C%22measures%22%3A%5B%22AccessView.count%22%5D%2C%22limit%22%3A5%7D" | jq .

echo ""
echo "Testing with multiple dimensions..."
# {"dimensions":["AccessView.id","AccessView.ts"],"limit":3}
curl -s "$BASE/load?query=%7B%22dimensions%22%3A%5B%22AccessView.id%22%2C%22AccessView.ts%22%5D%2C%22limit%22%3A3%7D" | jq .

echo ""
echo "=== Testing AccessView with aggregation ==="
# AccessView - aggregation query with measures, time dimensions, segments
curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22AccessView.count%22%2C%22AccessView.minCountArray%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%2C%22AccessView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi" | jq '.results[0].data'

echo ""
echo "=== Testing AccessView ungrouped query ==="
# AccessView - ungrouped query with all dimensions including nameGroup
curl -s "$BASE/load?query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22order%22%3A%7B%22AccessView.ts%22%3A%22desc%22%2C%22AccessView.tsMs%22%3A%22desc%22%7D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.id%22%2C%22AccessView.tsMs%22%2C%22AccessView.ts%22%2C%22AccessView.nameGroup%22%2C%22AccessView.sid%22%2C%22AccessView.uid%22%2C%22AccessView.ip%22%2C%22AccessView.ipGeoCity%22%2C%22AccessView.ipGeoProvince%22%2C%22AccessView.ipGeoCountry%22%2C%22AccessView.resultRisk%22%2C%22AccessView.reqAction%22%2C%22AccessView.reqReason%22%2C%22AccessView.reqContentLength%22%2C%22AccessView.responseRisk%22%2C%22AccessView.responseAction%22%2C%22AccessView.responseReason%22%2C%22AccessView.respContentLength%22%2C%22AccessView.resultType%22%2C%22AccessView.resultAction%22%2C%22AccessView.resultScore%22%2C%22AccessView.result%22%2C%22AccessView.reason%22%2C%22AccessView.assetName%22%2C%22AccessView.channel%22%2C%22AccessView.host%22%2C%22AccessView.method%22%2C%22AccessView.url%22%2C%22AccessView.urlRoute%22%2C%22AccessView.status%22%2C%22AccessView.ua%22%2C%22AccessView.uaName%22%2C%22AccessView.uaOs%22%2C%22AccessView.deviceFingerprint%22%2C%22AccessView.topoNetwork%22%2C%22AccessView.dstNode%22%2C%22AccessView.protocol%22%2C%22AccessView.nodeIp%22%2C%22AccessView.nodeName%22%2C%22AccessView.reqSensKeyNum%22%2C%22AccessView.resSensKeyNum%22%2C%22AccessView.sensScore%22%5D%2C%22limit%22%3A20%2C%22offset%22%3A0%2C%22segments%22%3A%5B%22AccessView.org%22%2C%22AccessView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi" | jq '.results[0].query | {dimensions: (.dimensions | length), limit: .limit, segments: .segments}'

echo ""
echo "=== Testing ApiView with aggregation ==="
# ApiView - aggregation query with sidebar counts
curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22ApiView.sidebarTypeCount%22%2C%22ApiView.sidebarFirstLevelTypeCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiView.topoNetwork%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%E5%A4%96%E5%8F%91%22%5D%7D%2C%7B%22member%22%3A%22ApiView.apiTypeTag%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22API%22%5D%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi" | jq '.results[0].data'

echo ""
echo "=== Testing ApiView ungrouped query ==="
# ApiView - ungrouped query with filters
curl -s "$BASE/load?query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22order%22%3A%7B%22ApiView.count%22%3A%22desc%22%2C%22ApiView.ts%22%3A%22desc%22%7D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiView.sidebarType%22%2C%22operator%22%3A%22contains%22%2C%22values%22%3A%5B%22%E5%B7%B2%E5%8F%91%E7%8E%B0-%3E%22%5D%7D%2C%7B%22member%22%3A%22ApiView.topoNetwork%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%E5%A4%96%E5%8F%91%22%5D%7D%2C%7B%22member%22%3A%22ApiView.apiTypeTag%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22API%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22ApiView.count%22%2C%22ApiView.activeTag%22%2C%22ApiView.bizImportance%22%2C%22ApiView.webServerTypeTag%22%2C%22ApiView.topoNetwork%22%2C%22ApiView.customRuleTag%22%2C%22ApiView.configTag%22%2C%22ApiView.apiTypeTag%22%2C%22ApiView.riskKeyScoreTuple%22%2C%22ApiView.weakKeyScoreTuple%22%2C%22ApiView.firstTs%22%2C%22ApiView.ts%22%2C%22ApiView.appName%22%2C%22ApiView.currentReqKey%22%2C%22ApiView.reqSensScoreTupleRaw%22%2C%22ApiView.resSensScoreTupleRaw%22%2C%22ApiView.channel%22%2C%22ApiView.host%22%2C%22ApiView.method%22%2C%22ApiView.urlRoute%22%2C%22ApiView.bizName%22%2C%22ApiView.bizAIAnalysis%22%2C%22ApiView.managementStatus%22%2C%22ApiView.filtered%22%2C%22ApiView.dctSection%22%2C%22ApiView.director%22%5D%2C%22limit%22%3A20%2C%22offset%22%3A0%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi" | jq '.results[0].query | {dimensions: (.dimensions | length), filters: (.filters | length), limit: .limit}'

echo ""
echo "Stopping server..."
stop_server

echo "Test completed."

# ============================================================
# GET vs POST 对比测试
# ============================================================

echo ""
echo "========================================"
echo "=== GET vs POST 测试 ==="
echo "========================================"

start_server 2
QUERY='{"ungrouped":true,"measures":[],"timeDimensions":[{"dimension":"AccessView.ts","dateRange":"from 15 minutes ago to 15 minutes from now"}],"order":{"AccessView.ts":"desc"},"filters":[],"dimensions":["AccessView.id","AccessView.ts","AccessView.ip","AccessView.host","AccessView.resultType"],"limit":3,"offset":0,"segments":["AccessView.org","AccessView.black"],"timezone":"Asia/Shanghai"}'

pass=0
fail=0

echo ""
echo "=== GET: query in URL ==="
ENCODED=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$QUERY")
result=$(curl -sf "$BASE/load?query=$ENCODED")
check "GET ?query=" "$result"

echo ""
echo "=== POST: query as JSON body ==="
result=$(curl -sf -X POST "$BASE/load" \
    -H "Content-Type: application/json" \
    -d "$QUERY")
check "POST body (direct JSON)" "$result"

echo ""
echo "=== POST: empty body should fail ==="
result=$(curl -s -X POST "$BASE/load" -H "Content-Type: application/json" -d "")
if echo "$result" | jq -e '.error' > /dev/null 2>&1; then
    echo "[PASS] empty body returns error: $(echo "$result" | jq -r '.error')"
    ((pass++))
else
    echo "[FAIL] expected error response"
    echo "$result"
    ((fail++))
fi

echo ""
echo "=== GET: missing query param should fail ==="
result=$(curl -s "$BASE/load")
if echo "$result" | jq -e '.error' > /dev/null 2>&1; then
    echo "[PASS] missing param returns error: $(echo "$result" | jq -r '.error')"
    ((pass++))
else
    echo "[FAIL] expected error response"
    echo "$result"
    ((fail++))
fi

echo ""
echo "--- $pass passed, $fail failed ---"

echo ""
echo "Stopping server..."
stop_server
echo "All tests completed."
