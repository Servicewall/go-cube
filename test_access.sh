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
echo "--- $pass passed, $fail failed ---"

echo ""
echo "Stopping server..."
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null
echo "All tests completed."
