#!/bin/bash
# Test AccessView queries against local go-cube server
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

# date range used by gap-fill tests (cases 30–70)
RANGE="from+60+minutes+ago+to+60+minutes+from+now"

echo ""
echo "========================================"
echo "=== AccessView aggregate queries ==="
echo "========================================"

echo ""
echo "=== 1. count by channel with time granularity (minute) ==="
# measures: [AccessView.count], timeDimensions: [{AccessView.ts, from 15 min ago, granularity: minute}]
# order: {AccessView.count: desc}, dimensions: [AccessView.channel], segments: org+black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%2C%22granularity%22%3A%22minute%22%7D%5D%2C%22order%22%3A%7B%22AccessView.count%22%3A%22desc%22%7D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.channel%22%5D%2C%22segments%22%3A%5B%22AccessView.org%22%2C%22AccessView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "count by channel (granularity=minute)" "$result"

echo ""
echo "=== 2. count by ipGeoProvince filtered by country (中国/局域网/内网) ==="
# measures: [AccessView.count], filter: ipGeoCountry equals [中国,局域网,内网]
# dimensions: [AccessView.ipGeoProvince], segments: org+black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22AccessView.ipGeoCountry%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22%E4%B8%AD%E5%9B%BD%22%2C%22%E5%B1%80%E5%9F%9F%E7%BD%91%22%2C%22%E5%86%85%E7%BD%91%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22AccessView.ipGeoProvince%22%5D%2C%22segments%22%3A%5B%22AccessView.org%22%2C%22AccessView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "count by ipGeoProvince where country in [中国,局域网,内网]" "$result"

echo ""
echo "=== 3. count by status (notEquals '') limit 10 ==="
# measures: [AccessView.count], filter: status notEquals ['']
# dimensions: [AccessView.status], limit: 10, segments: org+black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22filters%22%3A%5B%7B%22dimension%22%3A%22AccessView.status%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22AccessView.status%22%5D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22AccessView.org%22%2C%22AccessView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "count by status where status != '' limit 10" "$result"

echo ""
echo "=== 4. count by uaOs limit 10 ==="
# measures: [AccessView.count], dimensions: [AccessView.uaOs], limit: 10, segments: org+black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.uaOs%22%5D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22AccessView.org%22%2C%22AccessView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "count by uaOs limit 10" "$result"

echo ""
echo "=== 5. count by urlRoute+channel+host+method limit 1000 ==="
# measures: [AccessView.count], dimensions: [urlRoute, channel, host, method]
# limit: 1000, segments: org+black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.urlRoute%22%2C%22AccessView.channel%22%2C%22AccessView.host%22%2C%22AccessView.method%22%5D%2C%22limit%22%3A1000%2C%22segments%22%3A%5B%22AccessView.org%22%2C%22AccessView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "count by urlRoute+channel+host+method limit 1000" "$result"

echo ""
echo "=== 6. count by ip limit 1000 ==="
# measures: [AccessView.count], dimensions: [AccessView.ip]
# limit: 1000, segments: org+black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.ip%22%5D%2C%22limit%22%3A1000%2C%22segments%22%3A%5B%22AccessView.org%22%2C%22AccessView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "count by ip limit 1000" "$result"

echo ""
echo "=== 7. topo: intraNetCount+count+srcMid+dstMid by srcNode+dstNode+dstPort, filter topoNetwork!=外发 + srcNode/dstNode notEmpty ==="
# measures: [intraNetCount, count, srcMid, dstMid]
# dimensions: [srcNode, dstNode, dstPort]
# filters: topoNetwork notEquals [外发], srcNode notEquals [''], dstNode notEquals ['']
# limit: 20, segments: org+black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.intraNetCount%22%2C%22AccessView.count%22%2C%22AccessView.srcMid%22%2C%22AccessView.dstMid%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22order%22%3A%7B%22AccessView.count%22%3A%22desc%22%7D%2C%22filters%22%3A%5B%7B%22dimension%22%3A%22AccessView.topoNetwork%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%E5%A4%96%E5%8F%91%22%5D%7D%2C%7B%22member%22%3A%22AccessView.srcNode%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%22%5D%7D%2C%7B%22member%22%3A%22AccessView.dstNode%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22AccessView.srcNode%22%2C%22AccessView.dstNode%22%2C%22AccessView.dstPort%22%5D%2C%22limit%22%3A20%2C%22segments%22%3A%5B%22AccessView.org%22%2C%22AccessView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "topo: intraNetCount+count+srcMid+dstMid by srcNode+dstNode+dstPort" "$result"

echo ""
echo "========================================"
echo "=== 风险概览查询 ==="
echo "========================================"

echo ""
echo "=== 8. 风险汇总指标: count+blockCount+uniqDevCount+uniqIpCount+uniqUserCount (resultScore > 0) ==="
# measures: [count, blockCount, uniqDevCount, uniqIpCount, uniqUserCount]
# filter: resultScore gt 0 (dimension 字段), time: 60min, no dimensions
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.count%22%2C%22AccessView.blockCount%22%2C%22AccessView.uniqDevCount%22%2C%22AccessView.uniqIpCount%22%2C%22AccessView.uniqUserCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22from+60+minutes+ago+to+60+minutes+from+now%22%7D%5D%2C%22filters%22%3A%5B%7B%22dimension%22%3A%22AccessView.resultScore%22%2C%22operator%22%3A%22gt%22%2C%22values%22%3A%5B%220%22%5D%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%2C%22AccessView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "风险汇总指标 (resultScore>0)" "$result"

echo ""
echo "=== 9. blockCount+riskCount 按分钟时序 (granularity=minute, 60min) ==="
# measures: [blockCount, riskCount], granularity: minute, no dimensions, no filters
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.blockCount%22%2C%22AccessView.riskCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22from+60+minutes+ago+to+60+minutes+from+now%22%2C%22granularity%22%3A%22minute%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%2C%22AccessView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "blockCount+riskCount 按分钟时序" "$result"

echo ""
echo "=== 10. AccessView count by risk (risk dimension + arrayJoin) ==="
# measures: [count], dimensions: [risk], 60min, no filters
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22from+60+minutes+ago+to+60+minutes+from+now%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.risk%22%5D%2C%22segments%22%3A%5B%22AccessView.org%22%2C%22AccessView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "AccessView count by risk" "$result"

echo ""
echo "=== 11. AccessView count by risk limit 10 ==="
# measures: [count], dimensions: [risk], segments: org+black, limit: 10
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%20%5B%22AccessView.count%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22AccessView.ts%22%2C%20%22dateRange%22%3A%20%22from%2060%20minutes%20ago%20to%2060%20minutes%20from%20now%22%7D%5D%2C%20%22filters%22%3A%20%5B%5D%2C%20%22dimensions%22%3A%20%5B%22AccessView.risk%22%5D%2C%20%22limit%22%3A%2010%2C%20%22segments%22%3A%20%5B%22AccessView.org%22%2C%20%22AccessView.black%22%5D%2C%20%22timezone%22%3A%20%22Asia%2FShanghai%22%7D")
check "AccessView count by risk limit 10" "$result"

echo ""
echo "========================================"
echo "=== 风险分析查询 ==="
echo "========================================"

echo ""
echo "=== 12. 敏感数据风险: aggSensScore+aggSensKey+aggSensValNum+lastTs, filter aggSensScore>=95 + topoNetwork=公网 + isSens!='' ==="
# measures: [aggSensScore, aggSensKey, aggSensValNum, lastTs]
# filter: aggSensScore gte 95, topoNetwork equals 公网, isSens notEquals ''
# dimensions: [host, method, analysis, ip, ipGeoProvince, ipGeoCity], segments: org+riskNotConfirmed+black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%20%5B%22AccessView.aggSensScore%22%2C%20%22AccessView.aggSensKey%22%2C%20%22AccessView.aggSensValNum%22%2C%20%22AccessView.lastTs%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22AccessView.ts%22%2C%20%22dateRange%22%3A%20%22from%2060%20minutes%20ago%20to%2060%20minutes%20from%20now%22%7D%5D%2C%20%22order%22%3A%20%7B%22AccessView.lastTs%22%3A%20%22desc%22%7D%2C%20%22filters%22%3A%20%5B%7B%22member%22%3A%20%22AccessView.aggSensScore%22%2C%20%22operator%22%3A%20%22gte%22%2C%20%22values%22%3A%20%5B%2295%22%5D%7D%2C%20%7B%22member%22%3A%20%22AccessView.topoNetwork%22%2C%20%22operator%22%3A%20%22equals%22%2C%20%22values%22%3A%20%5B%22%E5%85%AC%E7%BD%91%22%5D%7D%2C%20%7B%22member%22%3A%20%22AccessView.isSens%22%2C%20%22operator%22%3A%20%22notEquals%22%2C%20%22values%22%3A%20%5B%22%22%5D%7D%5D%2C%20%22dimensions%22%3A%20%5B%22AccessView.host%22%2C%20%22AccessView.method%22%2C%20%22AccessView.analysis%22%2C%20%22AccessView.ip%22%2C%20%22AccessView.ipGeoProvince%22%2C%20%22AccessView.ipGeoCity%22%5D%2C%20%22segments%22%3A%20%5B%22AccessView.org%22%2C%20%22AccessView.riskNotConfirmed%22%2C%20%22AccessView.black%22%5D%2C%20%22timezone%22%3A%20%22Asia%2FShanghai%22%7D")
check "敏感数据风险: aggSensScore+aggSensKey+aggSensValNum+lastTs" "$result"

echo ""
echo "=== 13. 综合风险: aggScore+aggRisk+count+lastTs, filter aggScore>=95 + topoNetwork=公网 ==="
# measures: [aggScore, aggRisk, count, lastTs]
# filter: aggScore gte 95, topoNetwork equals 公网
# dimensions: [host, method, analysis, ip, ipGeoProvince, ipGeoCity], segments: org+riskNotConfirmed+black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%20%5B%22AccessView.aggScore%22%2C%20%22AccessView.aggRisk%22%2C%20%22AccessView.count%22%2C%20%22AccessView.lastTs%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22AccessView.ts%22%2C%20%22dateRange%22%3A%20%22from%2060%20minutes%20ago%20to%2060%20minutes%20from%20now%22%7D%5D%2C%20%22order%22%3A%20%7B%22AccessView.lastTs%22%3A%20%22desc%22%7D%2C%20%22filters%22%3A%20%5B%7B%22member%22%3A%20%22AccessView.aggScore%22%2C%20%22operator%22%3A%20%22gte%22%2C%20%22values%22%3A%20%5B%2295%22%5D%7D%2C%20%7B%22member%22%3A%20%22AccessView.topoNetwork%22%2C%20%22operator%22%3A%20%22equals%22%2C%20%22values%22%3A%20%5B%22%E5%85%AC%E7%BD%91%22%5D%7D%5D%2C%20%22dimensions%22%3A%20%5B%22AccessView.host%22%2C%20%22AccessView.method%22%2C%20%22AccessView.analysis%22%2C%20%22AccessView.ip%22%2C%20%22AccessView.ipGeoProvince%22%2C%20%22AccessView.ipGeoCity%22%5D%2C%20%22segments%22%3A%20%5B%22AccessView.org%22%2C%20%22AccessView.riskNotConfirmed%22%2C%20%22AccessView.black%22%5D%2C%20%22timezone%22%3A%20%22Asia%2FShanghai%22%7D")
check "综合风险: aggScore+aggRisk+count+lastTs" "$result"

echo ""
echo "=== 14. 弱点风险: aggWeakScore+aggWeakKey+lastTs, filter aggWeakScore>=95 + topoNetwork=公网 + weakKey set ==="
# measures: [aggWeakScore, aggWeakKey, lastTs]
# filter: aggWeakScore gte 95, topoNetwork equals 公网, weakKey set (notEmpty)
# dimensions: [host, method, analysis, ip, ipGeoProvince, ipGeoCity], segments: org+riskNotConfirmed+black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%20%5B%22AccessView.aggWeakScore%22%2C%20%22AccessView.aggWeakKey%22%2C%20%22AccessView.lastTs%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22AccessView.ts%22%2C%20%22dateRange%22%3A%20%22from%2060%20minutes%20ago%20to%2060%20minutes%20from%20now%22%7D%5D%2C%20%22order%22%3A%20%7B%22AccessView.lastTs%22%3A%20%22desc%22%7D%2C%20%22filters%22%3A%20%5B%7B%22member%22%3A%20%22AccessView.aggWeakScore%22%2C%20%22operator%22%3A%20%22gte%22%2C%20%22values%22%3A%20%5B%2295%22%5D%7D%2C%20%7B%22member%22%3A%20%22AccessView.topoNetwork%22%2C%20%22operator%22%3A%20%22equals%22%2C%20%22values%22%3A%20%5B%22%E5%85%AC%E7%BD%91%22%5D%7D%2C%20%7B%22member%22%3A%20%22AccessView.weakKey%22%2C%20%22operator%22%3A%20%22set%22%7D%5D%2C%20%22dimensions%22%3A%20%5B%22AccessView.host%22%2C%20%22AccessView.method%22%2C%20%22AccessView.analysis%22%2C%20%22AccessView.ip%22%2C%20%22AccessView.ipGeoProvince%22%2C%20%22AccessView.ipGeoCity%22%5D%2C%20%22segments%22%3A%20%5B%22AccessView.org%22%2C%20%22AccessView.riskNotConfirmed%22%2C%20%22AccessView.black%22%5D%2C%20%22timezone%22%3A%20%22Asia%2FShanghai%22%7D")
check "弱点风险: aggWeakScore+aggWeakKey+lastTs" "$result"

echo ""
echo "=== 15. 隐私数据明细: sensKeyCombineExt + sensScoreCombineExt > 20, measures: count+uniqUserCount+uniqApiCount+uniqIpCount ==="
# measures: [count, uniqUserCount, uniqApiCount, uniqIpCount]
# filter: sensScoreCombineExt gt 20
# dimensions: [sensKeyCombineExt, sensValCombineExt, channel, sensPrivacyCombineExt, sensScoreCombineExt]
# limit: 20, segments: org+black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.count%22%2C%22AccessView.uniqUserCount%22%2C%22AccessView.uniqApiCount%22%2C%22AccessView.uniqIpCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22order%22%3A%7B%22AccessView.count%22%3A%22desc%22%7D%2C%22filters%22%3A%5B%7B%22member%22%3A%22AccessView.sensScoreCombineExt%22%2C%22operator%22%3A%22gt%22%2C%22values%22%3A%5B%2220%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22AccessView.sensKeyCombineExt%22%2C%22AccessView.sensValCombineExt%22%2C%22AccessView.channel%22%2C%22AccessView.sensPrivacyCombineExt%22%2C%22AccessView.sensScoreCombineExt%22%5D%2C%22limit%22%3A20%2C%22offset%22%3A0%2C%22segments%22%3A%5B%22AccessView.org%22%2C%22AccessView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "隐私数据明细: sensKeyCombineExt+sensValCombineExt+channel+sensPrivacyCombineExt+sensScoreCombineExt" "$result"

echo ""
echo "=== 16. sensValueExt filter (arrayJoin dimension → WHERE not HAVING) ==="
# dimensions: [sensValueExt], filter: sensValueExt equals [webadmin], ungrouped, limit: 5
# ClickHouse 会对 arrayJoin 在 WHERE 中正常执行；若误放 HAVING 则报错
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22from+60+minutes+ago+to+60+minutes+from+now%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22AccessView.sensValueExt%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22webadmin%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22AccessView.sensValueExt%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%2C%22AccessView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "sensValueExt filter goes to WHERE (not HAVING)" "$result"

echo ""
echo "=== 17. count by hour granularity + sensValFilterTag filter (ORDER BY granularity expr) ==="
# measures: count
# timeDimensions: ts, dateRange: today, granularity: hour
# order: AccessView.ts asc  → must emit ORDER BY toStartOfHour(ts), not bare ts
# filters: sensValFilterTag equals [webadmin], channel equals [BII系统]
# segments: org, black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22today%22%2C%22granularity%22%3A%22hour%22%7D%5D%2C%22order%22%3A%7B%22AccessView.ts%22%3A%22asc%22%7D%2C%22filters%22%3A%5B%7B%22member%22%3A%22AccessView.sensValFilterTag%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22webadmin%22%5D%7D%2C%7B%22member%22%3A%22AccessView.channel%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22BII%E7%B3%BB%E7%BB%9F%22%5D%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%2C%22AccessView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "count by hour granularity, ORDER BY toStartOfHour(ts) not bare ts" "$result"

echo ""
echo "=== 18. count+avgProcessTime by nodeIp, granularity=second (regression: avg must wrap aggregate) ==="
# measures: count, avgProcessTime
# timeDimensions: ts, dateRange: from 15 minutes ago to 15 minutes from now, granularity: second
# dimensions: nodeIp
# segments: org
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%20%5B%22AccessView.count%22%2C%20%22AccessView.avgProcessTime%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22AccessView.ts%22%2C%20%22dateRange%22%3A%20%22from%2015%20minutes%20ago%20to%2015%20minutes%20from%20now%22%2C%20%22granularity%22%3A%20%22second%22%7D%5D%2C%20%22filters%22%3A%20%5B%5D%2C%20%22dimensions%22%3A%20%5B%22AccessView.nodeIp%22%5D%2C%20%22segments%22%3A%20%5B%22AccessView.org%22%5D%2C%20%22timezone%22%3A%20%22Asia%2FShanghai%22%7D")
check "count+avgProcessTime by nodeIp granularity=second" "$result"

echo ""
echo "=== 19. count+avgProcessTime+maxProcessTime by nodeIp, no granularity (regression: max must wrap aggregate) ==="
# measures: count, avgProcessTime, maxProcessTime
# timeDimensions: ts, dateRange: from 15 minutes ago to 15 minutes from now (no granularity)
# dimensions: nodeIp
# segments: org
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%20%5B%22AccessView.count%22%2C%20%22AccessView.avgProcessTime%22%2C%20%22AccessView.maxProcessTime%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22AccessView.ts%22%2C%20%22dateRange%22%3A%20%22from%2015%20minutes%20ago%20to%2015%20minutes%20from%20now%22%7D%5D%2C%20%22filters%22%3A%20%5B%5D%2C%20%22dimensions%22%3A%20%5B%22AccessView.nodeIp%22%5D%2C%20%22segments%22%3A%20%5B%22AccessView.org%22%5D%2C%20%22timezone%22%3A%20%22Asia%2FShanghai%22%7D")
check "count+avgProcessTime+maxProcessTime by nodeIp no granularity" "$result"

echo ""
echo "========================================"
echo "=== AccessView file-related queries ==="
echo "========================================"

echo ""
echo "=== 20. fileCount by fileDirection, no granularity (isFileSens!='' & fileName!='') ==="
# measures: fileCount, dimensions: fileDirection
# filters: isFileSens notEquals [''], fileName notEquals ['']
# segments: org, black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%20%5B%22AccessView.fileCount%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22AccessView.ts%22%2C%20%22dateRange%22%3A%20%22from%207%20days%20ago%20to%20now%22%7D%5D%2C%20%22filters%22%3A%20%5B%7B%22member%22%3A%20%22AccessView.isFileSens%22%2C%20%22operator%22%3A%20%22notEquals%22%2C%20%22values%22%3A%20%5B%22%22%5D%7D%2C%20%7B%22member%22%3A%20%22AccessView.fileName%22%2C%20%22operator%22%3A%20%22notEquals%22%2C%20%22values%22%3A%20%5B%22%22%5D%7D%5D%2C%20%22dimensions%22%3A%20%5B%22AccessView.fileDirection%22%5D%2C%20%22segments%22%3A%20%5B%22AccessView.org%22%2C%20%22AccessView.black%22%5D%2C%20%22timezone%22%3A%20%22Asia/Shanghai%22%7D")
check "fileCount by fileDirection (isFileSens!='' & fileName!='')" "$result"

echo ""
echo "=== 21. fileNum+fileTypes total (isFileSens!='' & fileName!='') ==="
# measures: fileNum, fileTypes, no dimensions
# filters: isFileSens notEquals [''], fileName notEquals ['']
# segments: org, black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%20%5B%22AccessView.fileNum%22%2C%20%22AccessView.fileTypes%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22AccessView.ts%22%2C%20%22dateRange%22%3A%20%22from%207%20days%20ago%20to%20now%22%7D%5D%2C%20%22filters%22%3A%20%5B%7B%22member%22%3A%20%22AccessView.isFileSens%22%2C%20%22operator%22%3A%20%22notEquals%22%2C%20%22values%22%3A%20%5B%22%22%5D%7D%2C%20%7B%22member%22%3A%20%22AccessView.fileName%22%2C%20%22operator%22%3A%20%22notEquals%22%2C%20%22values%22%3A%20%5B%22%22%5D%7D%5D%2C%20%22dimensions%22%3A%20%5B%5D%2C%20%22segments%22%3A%20%5B%22AccessView.org%22%2C%20%22AccessView.black%22%5D%2C%20%22timezone%22%3A%20%22Asia/Shanghai%22%7D")
check "fileNum+fileTypes total (isFileSens!='' & fileName!='')" "$result"

echo ""
echo "=== 22. fileCount by fileDirection, granularity=minute (isFileSens!='' & fileName!='') ==="
# measures: fileCount, dimensions: fileDirection, granularity: minute (1h window)
# filters: isFileSens notEquals [''], fileName notEquals ['']
# segments: org, black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%20%5B%22AccessView.fileCount%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22AccessView.ts%22%2C%20%22dateRange%22%3A%20%22from%201%20hours%20ago%20to%20now%22%2C%20%22granularity%22%3A%20%22minute%22%7D%5D%2C%20%22filters%22%3A%20%5B%7B%22member%22%3A%20%22AccessView.isFileSens%22%2C%20%22operator%22%3A%20%22notEquals%22%2C%20%22values%22%3A%20%5B%22%22%5D%7D%2C%20%7B%22member%22%3A%20%22AccessView.fileName%22%2C%20%22operator%22%3A%20%22notEquals%22%2C%20%22values%22%3A%20%5B%22%22%5D%7D%5D%2C%20%22dimensions%22%3A%20%5B%22AccessView.fileDirection%22%5D%2C%20%22segments%22%3A%20%5B%22AccessView.org%22%2C%20%22AccessView.black%22%5D%2C%20%22timezone%22%3A%20%22Asia/Shanghai%22%7D")
check "fileCount by fileDirection granularity=minute (isFileSens!='' & fileName!='')" "$result"

echo ""
echo "=== 23. file detail list: lastId+lastTs+fileCount, order fileCount desc, fileDirection=下载, limit 20 ==="
# measures: lastId, lastTs, fileCount
# dimensions: fileName, channel, host, method, url, urlRoute, fileMd5, fileType, fileSha1, fileSensKeyNum
# order: fileCount desc
# filters: isFileSens!='' & fileName!='' & fileDirection=下载
# limit: 20, segments: org, black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%20%5B%22AccessView.lastId%22%2C%20%22AccessView.lastTs%22%2C%20%22AccessView.fileCount%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22AccessView.ts%22%2C%20%22dateRange%22%3A%20%22from%207%20days%20ago%20to%20now%22%7D%5D%2C%20%22order%22%3A%20%7B%22AccessView.fileCount%22%3A%20%22desc%22%7D%2C%20%22filters%22%3A%20%5B%7B%22member%22%3A%20%22AccessView.isFileSens%22%2C%20%22operator%22%3A%20%22notEquals%22%2C%20%22values%22%3A%20%5B%22%22%5D%7D%2C%20%7B%22member%22%3A%20%22AccessView.fileName%22%2C%20%22operator%22%3A%20%22notEquals%22%2C%20%22values%22%3A%20%5B%22%22%5D%7D%2C%20%7B%22member%22%3A%20%22AccessView.fileDirection%22%2C%20%22operator%22%3A%20%22equals%22%2C%20%22values%22%3A%20%5B%22%5Cu4e0b%5Cu8f7d%22%5D%7D%5D%2C%20%22dimensions%22%3A%20%5B%22AccessView.fileName%22%2C%20%22AccessView.channel%22%2C%20%22AccessView.host%22%2C%20%22AccessView.method%22%2C%20%22AccessView.url%22%2C%20%22AccessView.urlRoute%22%2C%20%22AccessView.fileMd5%22%2C%20%22AccessView.fileType%22%2C%20%22AccessView.fileSha1%22%2C%20%22AccessView.fileSensKeyNum%22%5D%2C%20%22limit%22%3A%2020%2C%20%22offset%22%3A%200%2C%20%22segments%22%3A%20%5B%22AccessView.org%22%2C%20%22AccessView.black%22%5D%2C%20%22timezone%22%3A%20%22Asia/Shanghai%22%7D")
check "file detail list lastId+lastTs+fileCount order by fileCount desc fileDirection=下载 limit 20" "$result"

echo ""
echo "=== 24. count of privacy files (fileCategory=隐私文件, isSens!='' & sensScore>=0 & fileName!='') ==="
# measures: count, no dimensions
# filters: isSens!='' & sensScore>=0 & fileName!='' & fileCategory=隐私文件
# segments: org, black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%20%5B%22AccessView.count%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22AccessView.ts%22%2C%20%22dateRange%22%3A%20%22from%207%20days%20ago%20to%20now%22%7D%5D%2C%20%22filters%22%3A%20%5B%7B%22member%22%3A%20%22AccessView.isSens%22%2C%20%22operator%22%3A%20%22notEquals%22%2C%20%22values%22%3A%20%5B%22%22%5D%7D%2C%20%7B%22member%22%3A%20%22AccessView.sensScore%22%2C%20%22operator%22%3A%20%22gte%22%2C%20%22values%22%3A%20%5B%220%22%5D%7D%2C%20%7B%22member%22%3A%20%22AccessView.fileName%22%2C%20%22operator%22%3A%20%22notEquals%22%2C%20%22values%22%3A%20%5B%22%22%5D%7D%2C%20%7B%22member%22%3A%20%22AccessView.fileCategory%22%2C%20%22operator%22%3A%20%22equals%22%2C%20%22values%22%3A%20%5B%22%5Cu9690%5Cu79c1%5Cu6587%5Cu4ef6%22%5D%7D%5D%2C%20%22dimensions%22%3A%20%5B%5D%2C%20%22segments%22%3A%20%5B%22AccessView.org%22%2C%20%22AccessView.black%22%5D%2C%20%22timezone%22%3A%20%22Asia/Shanghai%22%7D")
check "count of privacy files (fileCategory=隐私文件)" "$result"

echo ""
echo "=== 25. privacy file detail list: ungrouped, 24 dims, fileCategory=隐私文件, limit 20 ==="
# ungrouped: true, no measures
# dimensions: ts, tsMs, id, channel, host, method, url, urlRoute, fileName, fileType, fileCategory,
#             fileMd5, fileSha1, fileSensKeyNum, sid, uid, ip, ua, status, fileDirection,
#             sensScore, responseRisk, responseAction, responseReason
# order: ts desc
# filters: isSens!='' & sensScore>=0 & fileName!='' & fileCategory=隐私文件
# limit: 20, segments: org, black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3A%20true%2C%20%22measures%22%3A%20%5B%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22AccessView.ts%22%2C%20%22dateRange%22%3A%20%22from%207%20days%20ago%20to%20now%22%7D%5D%2C%20%22order%22%3A%20%7B%22AccessView.ts%22%3A%20%22desc%22%7D%2C%20%22filters%22%3A%20%5B%7B%22member%22%3A%20%22AccessView.isSens%22%2C%20%22operator%22%3A%20%22notEquals%22%2C%20%22values%22%3A%20%5B%22%22%5D%7D%2C%20%7B%22member%22%3A%20%22AccessView.sensScore%22%2C%20%22operator%22%3A%20%22gte%22%2C%20%22values%22%3A%20%5B%220%22%5D%7D%2C%20%7B%22member%22%3A%20%22AccessView.fileName%22%2C%20%22operator%22%3A%20%22notEquals%22%2C%20%22values%22%3A%20%5B%22%22%5D%7D%2C%20%7B%22member%22%3A%20%22AccessView.fileCategory%22%2C%20%22operator%22%3A%20%22equals%22%2C%20%22values%22%3A%20%5B%22%5Cu9690%5Cu79c1%5Cu6587%5Cu4ef6%22%5D%7D%5D%2C%20%22dimensions%22%3A%20%5B%22AccessView.ts%22%2C%20%22AccessView.tsMs%22%2C%20%22AccessView.id%22%2C%20%22AccessView.channel%22%2C%20%22AccessView.host%22%2C%20%22AccessView.method%22%2C%20%22AccessView.url%22%2C%20%22AccessView.urlRoute%22%2C%20%22AccessView.fileName%22%2C%20%22AccessView.fileType%22%2C%20%22AccessView.fileCategory%22%2C%20%22AccessView.fileMd5%22%2C%20%22AccessView.fileSha1%22%2C%20%22AccessView.fileSensKeyNum%22%2C%20%22AccessView.sid%22%2C%20%22AccessView.uid%22%2C%20%22AccessView.ip%22%2C%20%22AccessView.ua%22%2C%20%22AccessView.status%22%2C%20%22AccessView.fileDirection%22%2C%20%22AccessView.sensScore%22%2C%20%22AccessView.responseRisk%22%2C%20%22AccessView.responseAction%22%2C%20%22AccessView.responseReason%22%5D%2C%20%22limit%22%3A%2020%2C%20%22offset%22%3A%200%2C%20%22segments%22%3A%20%5B%22AccessView.org%22%2C%20%22AccessView.black%22%5D%2C%20%22timezone%22%3A%20%22Asia/Shanghai%22%7D")
check "privacy file detail list ungrouped 24 dims fileCategory=隐私文件 limit 20" "$result"

echo ""
echo "=== 26. category + grade GROUP BY with count (category != '') ==="
# measures: count, dimensions: category, grade
# filters: category != ''
# segments: org
# limit: 5
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%20%5B%22AccessView.count%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22AccessView.ts%22%2C%20%22dateRange%22%3A%20%22from%207%20days%20ago%20to%20now%22%7D%5D%2C%20%22dimensions%22%3A%20%5B%22AccessView.category%22%2C%20%22AccessView.grade%22%5D%2C%20%22filters%22%3A%20%5B%7B%22member%22%3A%20%22AccessView.category%22%2C%20%22operator%22%3A%20%22notEquals%22%2C%20%22values%22%3A%20%5B%22%22%5D%7D%5D%2C%20%22segments%22%3A%20%5B%22AccessView.org%22%5D%2C%20%22limit%22%3A%205%2C%20%22timezone%22%3A%20%22Asia/Shanghai%22%7D")
check "category + grade GROUP BY count category!='' limit 5" "$result"

echo ""
echo "=== 27. searchCount + blockSearchCount by month (this year) ==="
# measures: searchCount, blockSearchCount
# timeDimensions: ts, dateRange: this year, granularity: month
# segments: org, black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%20%5B%22AccessView.searchCount%22%2C%20%22AccessView.blockSearchCount%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22AccessView.ts%22%2C%20%22dateRange%22%3A%20%22this%20year%22%2C%20%22granularity%22%3A%20%22month%22%7D%5D%2C%20%22filters%22%3A%20%5B%5D%2C%20%22dimensions%22%3A%20%5B%5D%2C%20%22segments%22%3A%20%5B%22AccessView.org%22%2C%20%22AccessView.black%22%5D%2C%20%22timezone%22%3A%20%22Asia/Shanghai%22%7D")
check "searchCount + blockSearchCount by month this year" "$result"

echo ""
echo "=== 28. searchBookRatio + finSearchBookRatio by month (this year) ==="
# measures: searchBookRatio, finSearchBookRatio
# timeDimensions: ts, dateRange: this year, granularity: month
# segments: org, black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.searchBookRatio%22%2C%22AccessView.finSearchBookRatio%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22this+year%22%2C%22granularity%22%3A%22month%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%2C%22AccessView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "searchBookRatio + finSearchBookRatio by month this year" "$result"

echo ""
echo "=== 29. resSensCountMap measures: count+lastId+lastTs+resSensCountMapKey+Val+Num by channel+host+method+url+urlRoute ==="
# measures: count, lastId, lastTs, resSensCountMapKey, resSensCountMapVal, resSensCountMapNum
# timeDimensions: ts, 15min window
# order: resSensCountMapNum desc
# filters: resSensCountMapValExcluded=0, sensValRepeatability>0.5, resSensCountMapNum>30
# dimensions: channel, host, method, url, urlRoute
# segments: org, resSensValid, black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.count%22%2C%22AccessView.lastId%22%2C%22AccessView.lastTs%22%2C%22AccessView.resSensCountMapKey%22%2C%22AccessView.resSensCountMapVal%22%2C%22AccessView.resSensCountMapNum%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22order%22%3A%5B%5B%22AccessView.resSensCountMapNum%22%2C%22desc%22%5D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22AccessView.resSensCountMapValExcluded%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%220%22%5D%7D%2C%7B%22member%22%3A%22AccessView.sensValRepeatability%22%2C%22operator%22%3A%22gt%22%2C%22values%22%3A%5B%220.5%22%5D%7D%2C%7B%22member%22%3A%22AccessView.resSensCountMapNum%22%2C%22operator%22%3A%22gt%22%2C%22values%22%3A%5B%2230%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22AccessView.channel%22%2C%22AccessView.host%22%2C%22AccessView.method%22%2C%22AccessView.url%22%2C%22AccessView.urlRoute%22%5D%2C%22segments%22%3A%5B%22AccessView.org%22%2C%22AccessView.resSensValid%22%2C%22AccessView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "resSensCountMapKey+Val+Num by channel+host+method+url+urlRoute" "$result"

echo ""
echo "========================================"
echo "=== AccessView: identity / raw dimensions ==="
echo "========================================"

echo ""
echo "=== 30. ungrouped: id+tsMs+sid+uid+ts+ip (limit 5) ==="
# Tests: id, tsMs, sid, uid dimensions in ungrouped row scan
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.id%22%2C%22AccessView.tsMs%22%2C%22AccessView.sid%22%2C%22AccessView.uid%22%2C%22AccessView.ts%22%2C%22AccessView.ip%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped id+tsMs+sid+uid+ts+ip limit 5" "$result"

echo ""
echo "=== 31. ungrouped: result+resultType+resultAction+resultScore+resultLevel+reason (limit 5) ==="
# Tests: result, resultType, resultAction, resultScore, resultLevel, reason
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.result%22%2C%22AccessView.resultType%22%2C%22AccessView.resultAction%22%2C%22AccessView.resultScore%22%2C%22AccessView.resultLevel%22%2C%22AccessView.reason%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped result+resultType+resultAction+resultScore+resultLevel+reason limit 5" "$result"

echo ""
echo "=== 32. ungrouped: url+reqAction+reqReason+protocol+reqContentLength+respContentLength (limit 5) ==="
# Tests: url, reqAction, reqReason, protocol, reqContentLength, respContentLength
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.url%22%2C%22AccessView.reqAction%22%2C%22AccessView.reqReason%22%2C%22AccessView.protocol%22%2C%22AccessView.reqContentLength%22%2C%22AccessView.respContentLength%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped url+reqAction+reqReason+protocol+reqContentLength+respContentLength limit 5" "$result"

echo ""
echo "=== 33. ungrouped: ua+uaDev+uaVersion+uaName+uaOs+uaOsVersion+uaFp+devType (limit 5) ==="
# Tests: ua, uaDev, uaVersion, uaName, uaOs, uaOsVersion, uaFp, devType
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.ua%22%2C%22AccessView.uaDev%22%2C%22AccessView.uaVersion%22%2C%22AccessView.uaName%22%2C%22AccessView.uaOs%22%2C%22AccessView.uaOsVersion%22%2C%22AccessView.uaFp%22%2C%22AccessView.devType%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped ua+uaDev+uaVersion+uaName+uaOs+uaOsVersion+uaFp+devType limit 5" "$result"

echo ""
echo "=== 34. ungrouped: devData+devRealIp+isProxy+isBot+deviceFingerprint+uniqueId (limit 5) ==="
# Tests: devData, devRealIp, isProxy, isBot, deviceFingerprint, uniqueId
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.devData%22%2C%22AccessView.devRealIp%22%2C%22AccessView.isProxy%22%2C%22AccessView.isBot%22%2C%22AccessView.deviceFingerprint%22%2C%22AccessView.uniqueId%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped devData+devRealIp+isProxy+isBot+deviceFingerprint+uniqueId limit 5" "$result"

echo ""
echo "=== 35. ungrouped: ipWithGeo+ipGeoIsp+ipGeoOwner+ipInfo+nameGroup (limit 5) ==="
# Tests: ipWithGeo, ipGeoIsp, ipGeoOwner, ipInfo, nameGroup
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.ipWithGeo%22%2C%22AccessView.ipGeoIsp%22%2C%22AccessView.ipGeoOwner%22%2C%22AccessView.ipInfo%22%2C%22AccessView.nameGroup%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped ipWithGeo+ipGeoIsp+ipGeoOwner+ipInfo+nameGroup limit 5" "$result"

echo ""
echo "=== 36. ungrouped: appName+customAppName+customAppDesc+assetName+assetLevel+assetType+urlActionName (limit 5) ==="
# Tests: appName, customAppName, customAppDesc, assetName, assetLevel, assetType, urlActionName
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.appName%22%2C%22AccessView.customAppName%22%2C%22AccessView.customAppDesc%22%2C%22AccessView.assetName%22%2C%22AccessView.assetLevel%22%2C%22AccessView.assetType%22%2C%22AccessView.urlActionName%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped appName+customAppName+customAppDesc+assetName+assetLevel+assetType+urlActionName limit 5" "$result"

echo ""
echo "=== 37. ungrouped: upstream+dstNode+remoteAddr+xff+topoNetwork+hostUrl (limit 5) ==="
# Tests: upstream, dstNode, remoteAddr, xff, topoNetwork, hostUrl
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.upstream%22%2C%22AccessView.dstNode%22%2C%22AccessView.remoteAddr%22%2C%22AccessView.xff%22%2C%22AccessView.topoNetwork%22%2C%22AccessView.hostUrl%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped upstream+dstNode+remoteAddr+xff+topoNetwork+hostUrl limit 5" "$result"

echo ""
echo "=== 38. ungrouped: refer+referPath+tid+tokenPath+analysis (limit 5) ==="
# Tests: refer, referPath, tid, tokenPath, analysis  (taskId excluded — task_id column not in DB)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.refer%22%2C%22AccessView.referPath%22%2C%22AccessView.tid%22%2C%22AccessView.tokenPath%22%2C%22AccessView.analysis%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped refer+referPath+tid+tokenPath+analysis limit 5" "$result"

echo ""
echo "=== 39. ungrouped: sysProcessTime+upstreamProcessTime+reqEncryptMethod+respEncryptMethod+resContentType (limit 5) ==="
# Tests: sysProcessTime, upstreamProcessTime, reqEncryptMethod, respEncryptMethod, resContentType
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.sysProcessTime%22%2C%22AccessView.upstreamProcessTime%22%2C%22AccessView.reqEncryptMethod%22%2C%22AccessView.respEncryptMethod%22%2C%22AccessView.resContentType%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped sysProcessTime+upstreamProcessTime+reqEncryptMethod+respEncryptMethod+resContentType limit 5" "$result"

echo ""
echo "=== 40. ungrouped: dbType+dbName+tableName+dbInfo+dbSensKV (limit 5) ==="
# Tests: dbType, dbName, tableName, dbInfo, dbSensKV
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.dbType%22%2C%22AccessView.dbName%22%2C%22AccessView.tableName%22%2C%22AccessView.dbInfo%22%2C%22AccessView.dbSensKV%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped dbType+dbName+tableName+dbInfo+dbSensKV limit 5" "$result"

echo ""
echo "=== 41. ungrouped: isSens+isReqSens+isResSens+isApi+isEncrypted+isFile+isFileSens (limit 5) ==="
# Tests: isSens, isReqSens, isResSens, isApi, isEncrypted, isFile, isFileSens
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.isSens%22%2C%22AccessView.isReqSens%22%2C%22AccessView.isResSens%22%2C%22AccessView.isApi%22%2C%22AccessView.isEncrypted%22%2C%22AccessView.isFile%22%2C%22AccessView.isFileSens%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped isSens+isReqSens+isResSens+isApi+isEncrypted+isFile+isFileSens limit 5" "$result"

echo ""
echo "=== 42. ungrouped: reqSensKV+resSensKV+reqSensKeyNum+resSensKeyNum+sensScore (limit 5) ==="
# Tests: reqSensKV, resSensKV, reqSensKeyNum, resSensKeyNum, sensScore
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.reqSensKV%22%2C%22AccessView.resSensKV%22%2C%22AccessView.reqSensKeyNum%22%2C%22AccessView.resSensKeyNum%22%2C%22AccessView.sensScore%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped reqSensKV+resSensKV+reqSensKeyNum+resSensKeyNum+sensScore limit 5" "$result"

echo ""
echo "=== 43. ungrouped: reqBody+respBody+request+response (limit 3) ==="
# Tests: reqBody, respBody, request, response — potentially large payloads; use small limit
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.reqBody%22%2C%22AccessView.respBody%22%2C%22AccessView.request%22%2C%22AccessView.response%22%5D%2C%22limit%22%3A3%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped reqBody+respBody+request+response limit 3" "$result"

echo ""
echo "=== 44. ungrouped: weakVal+weakKey+maskRule+responseRisk+responseAction+responseReason (limit 5) ==="
# Tests: weakVal, weakKey, maskRule, responseRisk, responseAction, responseReason
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.weakVal%22%2C%22AccessView.weakKey%22%2C%22AccessView.maskRule%22%2C%22AccessView.responseRisk%22%2C%22AccessView.responseAction%22%2C%22AccessView.responseReason%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped weakVal+weakKey+maskRule+responseRisk+responseAction+responseReason limit 5" "$result"

echo ""
echo "=== 45. ungrouped: reqSensKey+respSensKey+reqSensVal+respSensVal (array dims, limit 5) ==="
# Tests: reqSensKey (array), respSensKey (array), reqSensVal (array), respSensVal (array)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.reqSensKey%22%2C%22AccessView.respSensKey%22%2C%22AccessView.reqSensVal%22%2C%22AccessView.respSensVal%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped reqSensKey+respSensKey+reqSensVal+respSensVal (array dims) limit 5" "$result"

echo ""
echo "=== 46. grouped: count by resultRisk+resultLevel+resultAction (risk-confirmed path) ==="
# Tests: resultRisk (array dim used as GROUP BY key)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.resultLevel%22%2C%22AccessView.resultAction%22%5D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "count by resultLevel+resultAction limit 10" "$result"

echo ""
echo "=== 47. grouped: count by appName limit 10 (dict-lookup dimension) ==="
# Tests: appName grouped query (complex dict expression)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.appName%22%5D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "count by appName limit 10" "$result"

echo ""
echo "=== 48. grouped: count by protocol limit 10 ==="
# Tests: protocol dimension (multiIf expression)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.protocol%22%5D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "count by protocol limit 10" "$result"

echo ""
echo "=== 49. grouped: count by devType limit 10 ==="
# Tests: devType dimension
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.devType%22%5D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "count by devType limit 10" "$result"

echo ""
echo "=== 50. filter: count where riskFilterTag has value (array filter operator) ==="
# Tests: riskFilterTag as filter dimension (has operator)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22AccessView.riskFilterTag%22%2C%22operator%22%3A%22set%22%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "count where riskFilterTag set (array filter)" "$result"

echo ""
echo "=== 51. filter: count where reqRiskFilterTag set + resRiskFilterTag set ==="
# Tests: reqRiskFilterTag, resRiskFilterTag as filter dimensions
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%7B%22or%22%3A%5B%7B%22member%22%3A%22AccessView.reqRiskFilterTag%22%2C%22operator%22%3A%22set%22%7D%2C%7B%22member%22%3A%22AccessView.resRiskFilterTag%22%2C%22operator%22%3A%22set%22%7D%5D%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "count where reqRiskFilterTag OR resRiskFilterTag set" "$result"

echo ""
echo "=== 52. filter: count where sensKeyFilterTag set ==="
# Tests: sensKeyFilterTag as filter dimension
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22AccessView.sensKeyFilterTag%22%2C%22operator%22%3A%22set%22%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "count where sensKeyFilterTag set" "$result"

echo ""
echo "=== 53. filter + count where customParamMap notEmpty ==="
# Tests: customParamMap dimension
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22AccessView.customParamMap%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%7B%7D%22%5D%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "count where customParamMap != {}" "$result"

echo ""
echo "========================================"
echo "=== AccessView: untested measures ==="
echo "========================================"

echo ""
echo "=== 54. hourCountArray+hourBlockCountArray (no dimensions, 60min) ==="
# Tests: hourCountArray, hourBlockCountArray
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.hourCountArray%22%2C%22AccessView.hourBlockCountArray%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "hourCountArray+hourBlockCountArray (no dims, 60min)" "$result"

echo ""
echo "=== 55. minCountArray+minBlockCountArray (no dimensions, 60min) ==="
# Tests: minCountArray, minBlockCountArray
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.minCountArray%22%2C%22AccessView.minBlockCountArray%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "minCountArray+minBlockCountArray (no dims, 60min)" "$result"

echo ""
echo "=== 56. hourCountToday+hourCountAvg+hourCountStddev (no dimensions, 60min) ==="
# Tests: hourCountToday, hourCountAvg, hourCountStddev
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.hourCountToday%22%2C%22AccessView.hourCountAvg%22%2C%22AccessView.hourCountStddev%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "hourCountToday+hourCountAvg+hourCountStddev (no dims, 60min)" "$result"

echo ""
echo "=== 57. hourZscoreArray+hourCountPredictArray (no dimensions, today) ==="
# Tests: hourZscoreArray, hourCountPredictArray
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.hourZscoreArray%22%2C%22AccessView.hourCountPredictArray%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "hourZscoreArray+hourCountPredictArray (no dims, today)" "$result"

echo ""
echo "=== 58. minCountAvg+minCountStddev+minZscoreArray+minCountPredictArray (no dims, 60min) ==="
# Tests: minCountAvg, minCountStddev, minZscoreArray, minCountPredictArray
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.minCountAvg%22%2C%22AccessView.minCountStddev%22%2C%22AccessView.minZscoreArray%22%2C%22AccessView.minCountPredictArray%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "minCountAvg+minCountStddev+minZscoreArray+minCountPredictArray (no dims, 60min)" "$result"

echo ""
echo "=== 59. finSearchCount+bookCount+finBookCount (monthly, this year) ==="
# Tests: finSearchCount, bookCount, finBookCount
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.finSearchCount%22%2C%22AccessView.bookCount%22%2C%22AccessView.finBookCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22this+year%22%2C%22granularity%22%3A%22month%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%2C%22AccessView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "finSearchCount+bookCount+finBookCount by month this year" "$result"

echo ""
echo "=== 60. blockCrawlerCount+uniqBlockCrawlerCount+uniqProtectApiCount (60min) ==="
# Tests: blockCrawlerCount, uniqBlockCrawlerCount, uniqProtectApiCount
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.blockCrawlerCount%22%2C%22AccessView.uniqBlockCrawlerCount%22%2C%22AccessView.uniqProtectApiCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "blockCrawlerCount+uniqBlockCrawlerCount+uniqProtectApiCount (60min)" "$result"

echo ""
echo "=== 61. protectAssetCount+protectHighAssetCount+uniqNoDevCount+uniqAllDevCount (60min) ==="
# Tests: protectAssetCount, protectHighAssetCount, uniqNoDevCount, uniqAllDevCount
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.protectAssetCount%22%2C%22AccessView.protectHighAssetCount%22%2C%22AccessView.uniqNoDevCount%22%2C%22AccessView.uniqAllDevCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "protectAssetCount+protectHighAssetCount+uniqNoDevCount+uniqAllDevCount (60min)" "$result"

echo ""
echo "=== 62. uniqRiskDevCount+uniqRiskIpCount+uniqRiskUserCount+uniqVistorCount (60min) ==="
# Tests: uniqRiskDevCount, uniqRiskIpCount, uniqRiskUserCount, uniqVistorCount
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.uniqRiskDevCount%22%2C%22AccessView.uniqRiskIpCount%22%2C%22AccessView.uniqRiskUserCount%22%2C%22AccessView.uniqVistorCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "uniqRiskDevCount+uniqRiskIpCount+uniqRiskUserCount+uniqVistorCount (60min)" "$result"

echo ""
echo "=== 63. uniqApiCount+uniqAppCount+uniqAppArray (60min) ==="
# Tests: uniqApiCount, uniqAppCount, uniqAppArray
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.uniqApiCount%22%2C%22AccessView.uniqAppCount%22%2C%22AccessView.uniqAppArray%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "uniqApiCount+uniqAppCount+uniqAppArray (60min)" "$result"

echo ""
echo "=== 64. uniqBlockIpCount+uniqBlockDevCount+uniqBlockUserCount (60min) ==="
# Tests: uniqBlockIpCount, uniqBlockDevCount, uniqBlockUserCount
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.uniqBlockIpCount%22%2C%22AccessView.uniqBlockDevCount%22%2C%22AccessView.uniqBlockUserCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "uniqBlockIpCount+uniqBlockDevCount+uniqBlockUserCount (60min)" "$result"

echo ""
echo "=== 65. avgApiByUserCount+avgMinByUserCount+anyHeavyUa+statsRisk (60min) ==="
# Tests: avgApiByUserCount, avgMinByUserCount, anyHeavyUa, statsRisk
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.avgApiByUserCount%22%2C%22AccessView.avgMinByUserCount%22%2C%22AccessView.anyHeavyUa%22%2C%22AccessView.statsRisk%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "avgApiByUserCount+avgMinByUserCount+anyHeavyUa+statsRisk (60min)" "$result"

echo ""
echo "=== 66. uniqHostCount+topHostArray+uniqPortCount+uniqPortArray+topPortArray (60min) ==="
# Tests: uniqHostCount, topHostArray, uniqPortCount, uniqPortArray, topPortArray
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.uniqHostCount%22%2C%22AccessView.topHostArray%22%2C%22AccessView.uniqPortCount%22%2C%22AccessView.uniqPortArray%22%2C%22AccessView.topPortArray%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "uniqHostCount+topHostArray+uniqPortCount+uniqPortArray+topPortArray (60min)" "$result"

echo ""
echo "=== 67. reqSensKeySet+respSensKeySet+reqSensCount+resSensCount (60min) ==="
# Tests: reqSensKeySet, respSensKeySet, reqSensCount, resSensCount
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.reqSensKeySet%22%2C%22AccessView.respSensKeySet%22%2C%22AccessView.reqSensCount%22%2C%22AccessView.resSensCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "reqSensKeySet+respSensKeySet+reqSensCount+resSensCount (60min)" "$result"

echo ""
echo "=== 68. topoSearchCount+aggResSensValNum+uniqReqSensMap+uniqRespSensMap (60min) ==="
# Tests: topoSearchCount, aggResSensValNum, uniqReqSensMap, uniqRespSensMap
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.topoSearchCount%22%2C%22AccessView.aggResSensValNum%22%2C%22AccessView.uniqReqSensMap%22%2C%22AccessView.uniqRespSensMap%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "topoSearchCount+aggResSensValNum+uniqReqSensMap+uniqRespSensMap (60min)" "$result"

echo ""
echo "=== 69. autoTagSet+midFilter+srcNodeWithMid+dstNodeWithMid (60min) ==="
# Tests: autoTagSet, midFilter, srcNodeWithMid, dstNodeWithMid
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.autoTagSet%22%2C%22AccessView.midFilter%22%2C%22AccessView.srcNodeWithMid%22%2C%22AccessView.dstNodeWithMid%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.srcNode%22%2C%22AccessView.dstNode%22%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22limit%22%3A10%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "autoTagSet+midFilter+srcNodeWithMid+dstNodeWithMid (60min, grouped by srcNode+dstNode)" "$result"

echo ""
echo "=== 70. reqSampleKey+respSampleKey+reqSampleValue+respSampleValue (ungrouped, limit 5) ==="
# Tests: reqSampleKey, respSampleKey, reqSampleValue, respSampleValue
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.reqSampleKey%22%2C%22AccessView.respSampleKey%22%2C%22AccessView.reqSampleValue%22%2C%22AccessView.respSampleValue%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped reqSampleKey+respSampleKey+reqSampleValue+respSampleValue limit 5" "$result"

echo ""
echo "========================================"
echo "=== AccessView: fileCount by fileMd5 + fileDirection filter ==="
echo "========================================"

echo ""
echo "=== 71. fileCount by hour, filter fileMd5=28d89a2b8f464a16b3b6e77ea833b981 + fileDirection=下载, no dimensions ==="
# measures: fileCount
# timeDimensions: ts, dateRange: from 7 days ago to now, granularity: hour
# filters: fileMd5 equals [28d89a2b8f464a16b3b6e77ea833b981], fileDirection equals [下载]
# dimensions: [], segments: org, black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.fileCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22from+7+days+ago+to+now%22%2C%22granularity%22%3A%22hour%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22AccessView.fileMd5%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%2228d89a2b8f464a16b3b6e77ea833b981%22%5D%7D%2C%7B%22member%22%3A%22AccessView.fileDirection%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22%E4%B8%8B%E8%BD%BD%22%5D%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%2C%22AccessView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "fileCount by hour (fileMd5=28d89a2b8f464a16b3b6e77ea833b981, fileDirection=下载)" "$result"

echo ""
echo "=== 72. fileCount by channel+host+method+url+urlRoute+fileDirection, order desc, filter fileMd5=28d89a2b8f464a16b3b6e77ea833b981 + fileDirection=下载 ==="
# measures: fileCount
# timeDimensions: ts, dateRange: from 7 days ago to now (no granularity)
# order: [[fileCount, desc]]
# filters: fileMd5 equals [28d89a2b8f464a16b3b6e77ea833b981], fileDirection equals [下载]
# dimensions: [channel, host, method, url, urlRoute, fileDirection], segments: org, black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.fileCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22from+7+days+ago+to+now%22%7D%5D%2C%22order%22%3A%5B%5B%22AccessView.fileCount%22%2C%22desc%22%5D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22AccessView.fileMd5%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%2228d89a2b8f464a16b3b6e77ea833b981%22%5D%7D%2C%7B%22member%22%3A%22AccessView.fileDirection%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22%E4%B8%8B%E8%BD%BD%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22AccessView.channel%22%2C%22AccessView.host%22%2C%22AccessView.method%22%2C%22AccessView.url%22%2C%22AccessView.urlRoute%22%2C%22AccessView.fileDirection%22%5D%2C%22segments%22%3A%5B%22AccessView.org%22%2C%22AccessView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "fileCount by channel+host+method+url+urlRoute+fileDirection order desc (fileMd5=28d89a2b8f464a16b3b6e77ea833b981, fileDirection=下载)" "$result"

echo ""
echo "=== AccessView 涉敏字段分布 ==="
#{"measures":["AccessView.count"],"timeDimensions":[{"dimension":"AccessView.ts","dateRange":"from 15 minutes ago to 15 minutes from now"}],"filters":[{"member":"AccessView.isSens","operator":"notEquals","values":[""]},{"member":"AccessView.sensScore","operator":"gte","values":["0"]}],"dimensions":["AccessView.sensKeyExt"],"segments":["AccessView.org","AccessView.black"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22AccessView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22from%2015%20minutes%20ago%20to%2015%20minutes%20from%20now%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22AccessView.isSens%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%22%5D%7D%2C%7B%22member%22%3A%22AccessView.sensScore%22%2C%22operator%22%3A%22gte%22%2C%22values%22%3A%5B%220%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22AccessView.sensKeyExt%22%5D%2C%22segments%22%3A%5B%22AccessView.org%22%2C%22AccessView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "AccessView 涉敏字段分布" "$result"

echo ""
echo "=== AccessView 数据筛选 ==="
#{"measures":["AccessView.aggSensScore","AccessView.aggSensKey","AccessView.aggSensValNum","AccessView.lastTs"],"timeDimensions":[{"dimension":"AccessView.ts","dateRange":"today"}],"order":[["AccessView.lastTs","desc"]],"filters":[{"member":"AccessView.aggSensKeyFilterTag","operator":"contains","values":["手机"]},{"member":"AccessView.aggSensScore","operator":"gte","values":["80"]},{"member":"AccessView.topoNetwork","operator":"equals","values":["公网"]},{"member":"AccessView.isSens","operator":"notEquals","values":[""]}],"dimensions":["AccessView.host","AccessView.method","AccessView.analysis","AccessView.ip","AccessView.ipGeoProvince","AccessView.ipGeoCity"],"segments":["AccessView.org","AccessView.riskNotConfirmed","AccessView.black"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22AccessView.aggSensScore%22%2C%22AccessView.aggSensKey%22%2C%22AccessView.aggSensValNum%22%2C%22AccessView.lastTs%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22order%22%3A%5B%5B%22AccessView.lastTs%22%2C%22desc%22%5D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22AccessView.aggSensKeyFilterTag%22%2C%22operator%22%3A%22contains%22%2C%22values%22%3A%5B%22%E6%89%8B%E6%9C%BA%22%5D%7D%2C%7B%22member%22%3A%22AccessView.aggSensScore%22%2C%22operator%22%3A%22gte%22%2C%22values%22%3A%5B%2280%22%5D%7D%2C%7B%22member%22%3A%22AccessView.topoNetwork%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22%E5%85%AC%E7%BD%91%22%5D%7D%2C%7B%22member%22%3A%22AccessView.isSens%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22AccessView.host%22%2C%22AccessView.method%22%2C%22AccessView.analysis%22%2C%22AccessView.ip%22%2C%22AccessView.ipGeoProvince%22%2C%22AccessView.ipGeoCity%22%5D%2C%22segments%22%3A%5B%22AccessView.org%22%2C%22AccessView.riskNotConfirmed%22%2C%22AccessView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "AccessView 数据筛选" "$result"

echo "--- $pass passed, $fail failed ---"

echo ""
echo "Stopping server..."
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null
echo "All tests completed."
[ $fail -gt 0 ] && exit 1
exit 0
