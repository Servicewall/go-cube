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
echo "=== 8. ApiView 应用列表 ==="
#{"renewQuery":false,"measures":["ApiView.allCount","ApiView.uniqApiCount","ApiView.uniqWeakApiCount","ApiView.uniqApiRespSensCount","ApiView.hourCountArray","ApiView.daySum","ApiView.successSum","ApiView.hostSet","ApiView.autoTopoNetwork","ApiView.aggSensScore","ApiView.autoTitleSetStr","ApiView.autoLogo"],"timeDimensions":[{"dimension":"ApiView.ts","dateRange":["2026-03-30 00:00:00","2026-03-30 23:59:59"]}],"order":{"ApiView.isFavorite":"desc","ApiView.daySum":"desc"},"filters":[{"member":"ApiView.topoNetwork","operator":"notEquals","values":["外发"]}],"dimensions":["ApiView.appId","ApiView.appName","ApiView.dctSection","ApiView.isFavorite"],"segments":["ApiView.org","ApiView.black","ApiView.onePerDay"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22renewQuery%22%3Afalse%2C%22measures%22%3A%5B%22ApiView.allCount%22%2C%22ApiView.uniqApiCount%22%2C%22ApiView.uniqWeakApiCount%22%2C%22ApiView.uniqApiRespSensCount%22%2C%22ApiView.hourCountArray%22%2C%22ApiView.daySum%22%2C%22ApiView.successSum%22%2C%22ApiView.hostSet%22%2C%22ApiView.autoTopoNetwork%22%2C%22ApiView.aggSensScore%22%2C%22ApiView.autoTitleSetStr%22%2C%22ApiView.autoLogo%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%2C%22dateRange%22%3A%5B%222026-03-30%2000%3A00%3A00%22%2C%222026-03-31%2000%3A00%3A00%22%5D%7D%5D%2C%22order%22%3A%7B%22ApiView.isFavorite%22%3A%22desc%22%2C%22ApiView.daySum%22%3A%22desc%22%7D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiView.topoNetwork%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%E5%A4%96%E5%8F%91%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22ApiView.appId%22%2C%22ApiView.appName%22%2C%22ApiView.dctSection%22%2C%22ApiView.isFavorite%22%5D%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiView 应用列表" "$result"

echo "" 
echo "=== 9. ApiView 应用详情资产明细 ==="
#{"ungrouped":true,"measures":[],"timeDimensions":[{"dimension":"ApiView.ts","dateRange":["2026-04-01 00:00:00","2026-04-01 23:59:59"]}],"order":{"ApiView.dayCount":"desc"},"filters":[{"member":"ApiView.isApi","operator":"equals","values":["1"]},{"member":"ApiView.topoNetwork","operator":"notEquals","values":["外发"]},{"member":"ApiView.appName","operator":"equals","values":["脱敏测试"]}],"dimensions":["ApiView.hourCount","ApiView.channel","ApiView.urlRoute","ApiView.method","ApiView.host","ApiView.autoTag","ApiView.tag","ApiView.topoNetwork","ApiView.dayCount","ApiView.success"],"limit":10,"offset":0,"segments":["ApiView.org","ApiView.black","ApiView.onePerDay"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%2C%22dateRange%22%3A%5B%222026-04-01+00%3A00%3A00%22%2C%222026-04-01+23%3A59%3A59%22%5D%7D%5D%2C%22order%22%3A%7B%22ApiView.dayCount%22%3A%22desc%22%7D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiView.isApi%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%221%22%5D%7D%2C%7B%22member%22%3A%22ApiView.topoNetwork%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%E5%A4%96%E5%8F%91%22%5D%7D%2C%7B%22member%22%3A%22ApiView.appName%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22%E8%84%B1%E6%95%8F%E6%B5%8B%E8%AF%95%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22ApiView.hourCount%22%2C%22ApiView.channel%22%2C%22ApiView.urlRoute%22%2C%22ApiView.method%22%2C%22ApiView.host%22%2C%22ApiView.autoTag%22%2C%22ApiView.tag%22%2C%22ApiView.topoNetwork%22%2C%22ApiView.dayCount%22%2C%22ApiView.success%22%5D%2C%22limit%22%3A10%2C%22offset%22%3A0%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiView 应用详情资产明细" "$result"

echo ""
echo "=== 10. ApiView 应用详情资产梳理新上线 ==="
#{"ungrouped":true,"measures":[],"timeDimensions":[],"order":{"ApiView.dayCount":"desc","ApiView.count":"desc"},"filters":[{"member":"ApiView.isApi","operator":"equals","values":["1"]},{"member":"ApiView.topoNetwork","operator":"notEquals","values":["外发"]},{"member":"ApiView.newApiTag","operator":"contains","values":["新上线"]},{"member":"ApiView.appName","operator":"equals","values":["BII系统"]}],"dimensions":["ApiView.id","ApiView.ts","ApiView.firstTs","ApiView.count","ApiView.hourCount","ApiView.channel","ApiView.host","ApiView.urlRoute","ApiView.method","ApiView.bizName","ApiView.topoNetwork","ApiView.autoTag","ApiView.appId","ApiView.appName","ApiView.category","ApiView.dayCount","ApiView.success","ApiView.respSensTagSet","ApiView.weakTag","ApiView.riskTag","ApiView.sensScore","ApiView.riskScore","ApiView.weakScore","ApiView.timeAvg","ApiView.lengthAvg","ApiView.metricTag","ApiView.dctSection","ApiView.director","ApiView.description"],"segments":["ApiView.org","ApiView.black","ApiView.onePerDay"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22order%22%3A%7B%22ApiView.dayCount%22%3A%22desc%22%2C%22ApiView.count%22%3A%22desc%22%7D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiView.isApi%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%221%22%5D%7D%2C%7B%22member%22%3A%22ApiView.topoNetwork%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%E5%A4%96%E5%8F%91%22%5D%7D%2C%7B%22member%22%3A%22ApiView.newApiTag%22%2C%22operator%22%3A%22contains%22%2C%22values%22%3A%5B%22%E6%96%B0%E4%B8%8A%E7%BA%BF%22%5D%7D%2C%7B%22member%22%3A%22ApiView.appName%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22BII%E7%B3%BB%E7%BB%9F%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22ApiView.id%22%2C%22ApiView.ts%22%2C%22ApiView.firstTs%22%2C%22ApiView.count%22%2C%22ApiView.hourCount%22%2C%22ApiView.channel%22%2C%22ApiView.host%22%2C%22ApiView.urlRoute%22%2C%22ApiView.method%22%2C%22ApiView.bizName%22%2C%22ApiView.topoNetwork%22%2C%22ApiView.autoTag%22%2C%22ApiView.appId%22%2C%22ApiView.appName%22%2C%22ApiView.category%22%2C%22ApiView.dayCount%22%2C%22ApiView.success%22%2C%22ApiView.respSensTagSet%22%2C%22ApiView.weakTag%22%2C%22ApiView.riskTag%22%2C%22ApiView.sensScore%22%2C%22ApiView.riskScore%22%2C%22ApiView.weakScore%22%2C%22ApiView.timeAvg%22%2C%22ApiView.lengthAvg%22%2C%22ApiView.metricTag%22%2C%22ApiView.dctSection%22%2C%22ApiView.director%22%2C%22ApiView.description%22%5D%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiView 应用详情资产梳理新上线" "$result"

echo ""
echo "=== 11. ApiView 应用详情资产梳理僵尸 ==="
#{"ungrouped":true,"measures":[],"timeDimensions":[],"order":{"ApiView.dayCount":"desc","ApiView.count":"desc"},"filters":[{"member":"ApiView.isApi","operator":"equals","values":["1"]},{"member":"ApiView.topoNetwork","operator":"notEquals","values":["外发"]},{"member":"ApiView.activeTag","operator":"contains","values":["30天不活跃"]},{"member":"ApiView.appName","operator":"equals","values":["BII系统"]}],"dimensions":["ApiView.id","ApiView.ts","ApiView.firstTs","ApiView.count","ApiView.hourCount","ApiView.channel","ApiView.host","ApiView.urlRoute","ApiView.method","ApiView.bizName","ApiView.topoNetwork","ApiView.autoTag","ApiView.appId","ApiView.appName","ApiView.category","ApiView.dayCount","ApiView.success","ApiView.respSensTagSet","ApiView.weakTag","ApiView.riskTag","ApiView.sensScore","ApiView.riskScore","ApiView.weakScore","ApiView.timeAvg","ApiView.lengthAvg","ApiView.metricTag","ApiView.dctSection","ApiView.director","ApiView.description"],"segments":["ApiView.org","ApiView.black","ApiView.onePerDay"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22order%22%3A%7B%22ApiView.dayCount%22%3A%22desc%22%2C%22ApiView.count%22%3A%22desc%22%7D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiView.isApi%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%221%22%5D%7D%2C%7B%22member%22%3A%22ApiView.topoNetwork%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%E5%A4%96%E5%8F%91%22%5D%7D%2C%7B%22member%22%3A%22ApiView.activeTag%22%2C%22operator%22%3A%22contains%22%2C%22values%22%3A%5B%2230%E5%A4%A9%E4%B8%8D%E6%B4%BB%E8%B7%83%22%5D%7D%2C%7B%22member%22%3A%22ApiView.appName%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22BII%E7%B3%BB%E7%BB%9F%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22ApiView.id%22%2C%22ApiView.ts%22%2C%22ApiView.firstTs%22%2C%22ApiView.count%22%2C%22ApiView.hourCount%22%2C%22ApiView.channel%22%2C%22ApiView.host%22%2C%22ApiView.urlRoute%22%2C%22ApiView.method%22%2C%22ApiView.bizName%22%2C%22ApiView.topoNetwork%22%2C%22ApiView.autoTag%22%2C%22ApiView.appId%22%2C%22ApiView.appName%22%2C%22ApiView.category%22%2C%22ApiView.dayCount%22%2C%22ApiView.success%22%2C%22ApiView.respSensTagSet%22%2C%22ApiView.weakTag%22%2C%22ApiView.riskTag%22%2C%22ApiView.sensScore%22%2C%22ApiView.riskScore%22%2C%22ApiView.weakScore%22%2C%22ApiView.timeAvg%22%2C%22ApiView.lengthAvg%22%2C%22ApiView.metricTag%22%2C%22ApiView.dctSection%22%2C%22ApiView.director%22%2C%22ApiView.description%22%5D%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiView 应用详情资产梳理僵尸" "$result"

echo "" 
echo "=== 12. Api详情tag ==="
#{"measures":["ApiView.source"],"timeDimensions":[{"dimension":"ApiView.ts"}],"filters":[{"member":"ApiView.urlRoute","operator":"equals","values":["/apiAuth"]},{"member":"ApiView.method","operator":"equals","values":["POST"]},{"member":"ApiView.host","operator":"equals","values":["127.0.0.1"]}],"dimensions":["ApiView.count","ApiView.bizName","ApiView.autoTag","ApiView.appId","ApiView.appName","ApiView.ts","ApiView.firstTs","ApiView.tag"],"segments":["ApiView.org","ApiView.black","ApiView.onePerDay"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22ApiView.source%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiView.urlRoute%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22%2FapiAuth%22%5D%7D%2C%7B%22member%22%3A%22ApiView.method%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22POST%22%5D%7D%2C%7B%22member%22%3A%22ApiView.host%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22127.0.0.1%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22ApiView.count%22%2C%22ApiView.bizName%22%2C%22ApiView.autoTag%22%2C%22ApiView.appId%22%2C%22ApiView.appName%22%2C%22ApiView.ts%22%2C%22ApiView.firstTs%22%2C%22ApiView.tag%22%5D%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "Api详情tag" "$result"

echo ""
echo "=== 13. ApiView 使用标签过滤configTag列表 ==="
#{"ungrouped":true,"measures":[],"timeDimensions":[{"dimension":"ApiView.ts","dateRange":"today"}],"order":{"ApiView.count":"desc","ApiView.ts":"desc"},"filters":[{"member":"ApiView.sidebarType","operator":"contains","values":["已发现->"]},{"member":"ApiView.topoNetwork","operator":"notEquals","values":["外发"]},{"member":"ApiView.apiTypeTag","operator":"equals","values":["API"]},{"operator":"equals","member":"ApiView.configTag","values":["测试"]}],"dimensions":["ApiView.count","ApiView.activeTag","ApiView.bizImportance","ApiView.webServerTypeTag","ApiView.topoNetwork","ApiView.customRuleTag","ApiView.configTag","ApiView.apiTypeTag","ApiView.authParamPath","ApiView.riskKeyScoreTuple","ApiView.weakKeyScoreTuple","ApiView.firstTs","ApiView.ts","ApiView.appName","ApiView.currentReqKey","ApiView.weakScore","ApiView.riskScore","ApiView.sensScore","ApiView.reqSensScoreTupleRaw","ApiView.resSensScoreTupleRaw","ApiView.channel","ApiView.host","ApiView.method","ApiView.urlRoute","ApiView.bizName","ApiView.bizAIAnalysis","ApiView.managementStatus","ApiView.filtered","ApiView.dctSection","ApiView.director"],"limit":20,"offset":0,"segments":["ApiView.org","ApiView.black","ApiView.onePerDay"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22order%22%3A%7B%22ApiView.count%22%3A%22desc%22%2C%22ApiView.ts%22%3A%22desc%22%7D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiView.sidebarType%22%2C%22operator%22%3A%22contains%22%2C%22values%22%3A%5B%22%E5%B7%B2%E5%8F%91%E7%8E%B0-%3E%22%5D%7D%2C%7B%22member%22%3A%22ApiView.topoNetwork%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%E5%A4%96%E5%8F%91%22%5D%7D%2C%7B%22member%22%3A%22ApiView.apiTypeTag%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22API%22%5D%7D%2C%7B%22operator%22%3A%22equals%22%2C%22member%22%3A%22ApiView.configTag%22%2C%22values%22%3A%5B%22%E6%B5%8B%E8%AF%95%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22ApiView.count%22%2C%22ApiView.activeTag%22%2C%22ApiView.bizImportance%22%2C%22ApiView.webServerTypeTag%22%2C%22ApiView.topoNetwork%22%2C%22ApiView.customRuleTag%22%2C%22ApiView.configTag%22%2C%22ApiView.apiTypeTag%22%2C%22ApiView.authParamPath%22%2C%22ApiView.riskKeyScoreTuple%22%2C%22ApiView.weakKeyScoreTuple%22%2C%22ApiView.firstTs%22%2C%22ApiView.ts%22%2C%22ApiView.appName%22%2C%22ApiView.currentReqKey%22%2C%22ApiView.weakScore%22%2C%22ApiView.riskScore%22%2C%22ApiView.sensScore%22%2C%22ApiView.reqSensScoreTupleRaw%22%2C%22ApiView.resSensScoreTupleRaw%22%2C%22ApiView.channel%22%2C%22ApiView.host%22%2C%22ApiView.method%22%2C%22ApiView.urlRoute%22%2C%22ApiView.bizName%22%2C%22ApiView.bizAIAnalysis%22%2C%22ApiView.managementStatus%22%2C%22ApiView.filtered%22%2C%22ApiView.dctSection%22%2C%22ApiView.director%22%5D%2C%22limit%22%3A20%2C%22offset%22%3A0%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiView 使用标签过滤configTag列表" "$result"

echo ""
echo "=== 14. ApiView 应用列表使用hostUrl过滤 ==="
#{"renewQuery":false,"measures":["ApiView.allCount","ApiView.uniqApiCount","ApiView.uniqWeakApiCount","ApiView.uniqApiRespSensCount","ApiView.hourCountArray","ApiView.daySum","ApiView.successSum","ApiView.hostSet","ApiView.autoTopoNetwork","ApiView.aggSensScore","ApiView.autoTitleSetStr","ApiView.autoLogo"],"timeDimensions":[{"dimension":"ApiView.ts","dateRange":["2026-04-02 00:00:00","2026-04-02 23:59:59"]}],"order":[["ApiView.isFavorite","desc"],["ApiView.daySum","desc"]],"filters":[{"or":[{"member":"ApiView.hostUrl","operator":"contains","values":["123"]},{"member":"ApiView.appName","operator":"contains","values":["123"]},{"member":"ApiView.channel","operator":"contains","values":["123"]}]},{"member":"ApiView.topoNetwork","operator":"notEquals","values":["外发"]}],"dimensions":["ApiView.appId","ApiView.appName","ApiView.dctSection","ApiView.isFavorite"],"segments":["ApiView.org","ApiView.black","ApiView.onePerDay"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22renewQuery%22%3Afalse%2C%22measures%22%3A%5B%22ApiView.allCount%22%2C%22ApiView.uniqApiCount%22%2C%22ApiView.uniqWeakApiCount%22%2C%22ApiView.uniqApiRespSensCount%22%2C%22ApiView.hourCountArray%22%2C%22ApiView.daySum%22%2C%22ApiView.successSum%22%2C%22ApiView.hostSet%22%2C%22ApiView.autoTopoNetwork%22%2C%22ApiView.aggSensScore%22%2C%22ApiView.autoTitleSetStr%22%2C%22ApiView.autoLogo%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%2C%22dateRange%22%3A%5B%222026-04-02+00%3A00%3A00%22%2C%222026-04-02+23%3A59%3A59%22%5D%7D%5D%2C%22order%22%3A%5B%5B%22ApiView.isFavorite%22%2C%22desc%22%5D%2C%5B%22ApiView.daySum%22%2C%22desc%22%5D%5D%2C%22filters%22%3A%5B%7B%22or%22%3A%5B%7B%22member%22%3A%22ApiView.hostUrl%22%2C%22operator%22%3A%22contains%22%2C%22values%22%3A%5B%22123%22%5D%7D%2C%7B%22member%22%3A%22ApiView.appName%22%2C%22operator%22%3A%22contains%22%2C%22values%22%3A%5B%22123%22%5D%7D%2C%7B%22member%22%3A%22ApiView.channel%22%2C%22operator%22%3A%22contains%22%2C%22values%22%3A%5B%22123%22%5D%7D%5D%7D%2C%7B%22member%22%3A%22ApiView.topoNetwork%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%E5%A4%96%E5%8F%91%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22ApiView.appId%22%2C%22ApiView.appName%22%2C%22ApiView.dctSection%22%2C%22ApiView.isFavorite%22%5D%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiView 应用列表使用hostUrl过滤" "$result"

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
