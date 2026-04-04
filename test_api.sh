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

echo ""
echo "=== 15. ApiDayView protectCount by dt (7天) ==="
#{"measures":["ApiDayView.protectCount"],"timeDimensions":[{"dimension":"ApiDayView.dt","granularity":"day","dateRange":"from 7 days ago to now"}],"dimensions":[],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%20%5B%22ApiDayView.protectCount%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22ApiDayView.dt%22%2C%20%22granularity%22%3A%20%22day%22%2C%20%22dateRange%22%3A%20%22from%207%20days%20ago%20to%20now%22%7D%5D%2C%20%22dimensions%22%3A%20%5B%5D%2C%20%22timezone%22%3A%20%22Asia/Shanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiDayView protectCount by dt (7天)" "$result"

echo ""
echo "=== 16. ApiDayView count by urlRoute/channel/host/method (limit 20) ==="
#{"measures":["ApiDayView.count"],"timeDimensions":[{"dimension":"ApiDayView.dt","dateRange":"from 7 days ago to now"}],"dimensions":["ApiDayView.urlRoute","ApiDayView.channel","ApiDayView.host","ApiDayView.method"],"order":{"ApiDayView.count":"desc"},"limit":20,"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%20%5B%22ApiDayView.count%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22ApiDayView.dt%22%2C%20%22dateRange%22%3A%20%22from%207%20days%20ago%20to%20now%22%7D%5D%2C%20%22dimensions%22%3A%20%5B%22ApiDayView.urlRoute%22%2C%20%22ApiDayView.channel%22%2C%20%22ApiDayView.host%22%2C%20%22ApiDayView.method%22%5D%2C%20%22order%22%3A%20%7B%22ApiDayView.count%22%3A%20%22desc%22%7D%2C%20%22limit%22%3A%2020%2C%20%22timezone%22%3A%20%22Asia/Shanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiDayView count by urlRoute/channel/host/method (limit 20)" "$result"

echo ""
echo "=== 17. ApiDayView 汇总 hourSumMap+riskSumMap+count+reqSensTuple+resSensTuple ==="
#{"measures":["ApiDayView.hourSumMap","ApiDayView.riskSumMap","ApiDayView.count","ApiDayView.reqSensTuple","ApiDayView.resSensTuple"],"timeDimensions":[{"dimension":"ApiDayView.dt","dateRange":"from 7 days ago to now"}],"dimensions":[],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%20%5B%22ApiDayView.hourSumMap%22%2C%20%22ApiDayView.riskSumMap%22%2C%20%22ApiDayView.count%22%2C%20%22ApiDayView.reqSensTuple%22%2C%20%22ApiDayView.resSensTuple%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22ApiDayView.dt%22%2C%20%22dateRange%22%3A%20%22from%207%20days%20ago%20to%20now%22%7D%5D%2C%20%22dimensions%22%3A%20%5B%5D%2C%20%22timezone%22%3A%20%22Asia/Shanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiDayView 汇总 hourSumMap+riskSumMap+count+reqSensTuple+resSensTuple" "$result"

echo ""
echo "=== 18. ApiDayView aggResSensScore+resSensCount by resSens/host/method/urlRoute (filter appName+hasResSens) ==="
#{"measures":["ApiDayView.aggResSensScore","ApiDayView.resSensCount"],"timeDimensions":[{"dimension":"ApiDayView.dt","dateRange":"from 7 days ago to now"}],"filters":[{"member":"ApiDayView.appName","operator":"equals","values":["脱敏测试"]},{"member":"ApiDayView.hasResSens","operator":"equals","values":["1"]}],"dimensions":["ApiDayView.resSens","ApiDayView.host","ApiDayView.method","ApiDayView.urlRoute"],"order":{"ApiDayView.aggResSensScore":"desc"},"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%20%5B%22ApiDayView.aggResSensScore%22%2C%20%22ApiDayView.resSensCount%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22ApiDayView.dt%22%2C%20%22dateRange%22%3A%20%22from%207%20days%20ago%20to%20now%22%7D%5D%2C%20%22filters%22%3A%20%5B%7B%22member%22%3A%20%22ApiDayView.appName%22%2C%20%22operator%22%3A%20%22equals%22%2C%20%22values%22%3A%20%5B%22%E8%84%B1%E6%95%8F%E6%B5%8B%E8%AF%95%22%5D%7D%2C%20%7B%22member%22%3A%20%22ApiDayView.hasResSens%22%2C%20%22operator%22%3A%20%22equals%22%2C%20%22values%22%3A%20%5B%221%22%5D%7D%5D%2C%20%22dimensions%22%3A%20%5B%22ApiDayView.resSens%22%2C%20%22ApiDayView.host%22%2C%20%22ApiDayView.method%22%2C%20%22ApiDayView.urlRoute%22%5D%2C%20%22order%22%3A%20%7B%22ApiDayView.aggResSensScore%22%3A%20%22desc%22%7D%2C%20%22timezone%22%3A%20%22Asia/Shanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiDayView aggResSensScore+resSensCount by resSens/host/method/urlRoute" "$result"

echo ""
echo "=== 19. ApiDayView newRiskToday+highRiskRatioToday+newWeakToday+newSensToday (filter appName) ==="
#{"measures":["ApiDayView.newRiskToday","ApiDayView.highRiskRatioToday","ApiDayView.newWeakToday","ApiDayView.newSensToday"],"timeDimensions":[{"dimension":"ApiDayView.dt","dateRange":"today"}],"filters":[{"member":"ApiDayView.appName","operator":"equals","values":["脱敏测试"]}],"dimensions":[],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%20%5B%22ApiDayView.newRiskToday%22%2C%20%22ApiDayView.highRiskRatioToday%22%2C%20%22ApiDayView.newWeakToday%22%2C%20%22ApiDayView.newSensToday%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22ApiDayView.dt%22%2C%20%22dateRange%22%3A%20%22today%22%7D%5D%2C%20%22filters%22%3A%20%5B%7B%22member%22%3A%20%22ApiDayView.appName%22%2C%20%22operator%22%3A%20%22equals%22%2C%20%22values%22%3A%20%5B%22%E8%84%B1%E6%95%8F%E6%B5%8B%E8%AF%95%22%5D%7D%5D%2C%20%22dimensions%22%3A%20%5B%5D%2C%20%22timezone%22%3A%20%22Asia/Shanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiDayView newRiskToday+highRiskRatioToday+newWeakToday+newSensToday" "$result"

echo ""
echo "=== 20. ApiDayView aggRiskScore+count+riskSumMap by host/method/urlRoute (filter aggRiskScore>=95, limit 5) ==="
#{"measures":["ApiDayView.aggRiskScore","ApiDayView.count","ApiDayView.riskSumMap"],"timeDimensions":[{"dimension":"ApiDayView.dt","dateRange":"from 7 days ago to now"}],"filters":[{"member":"ApiDayView.aggRiskScore","operator":"gte","values":["95"]}],"dimensions":["ApiDayView.host","ApiDayView.method","ApiDayView.urlRoute"],"order":{"ApiDayView.aggRiskScore":"desc"},"limit":5,"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%20%5B%22ApiDayView.aggRiskScore%22%2C%20%22ApiDayView.count%22%2C%20%22ApiDayView.riskSumMap%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22ApiDayView.dt%22%2C%20%22dateRange%22%3A%20%22from%207%20days%20ago%20to%20now%22%7D%5D%2C%20%22filters%22%3A%20%5B%7B%22member%22%3A%20%22ApiDayView.aggRiskScore%22%2C%20%22operator%22%3A%20%22gte%22%2C%20%22values%22%3A%20%5B%2295%22%5D%7D%5D%2C%20%22dimensions%22%3A%20%5B%22ApiDayView.host%22%2C%20%22ApiDayView.method%22%2C%20%22ApiDayView.urlRoute%22%5D%2C%20%22order%22%3A%20%7B%22ApiDayView.aggRiskScore%22%3A%20%22desc%22%7D%2C%20%22limit%22%3A%205%2C%20%22timezone%22%3A%20%22Asia/Shanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiDayView aggRiskScore+count+riskSumMap by host/method/urlRoute (aggRiskScore>=95, limit 5)" "$result"

echo ""
echo "=== 21. ApiDayView 路由汇总 hourSumMap+riskSumMap+reqSensTuple+resSensTuple+statusSumMap+count (filter urlRoute+method+host) ==="
#{"measures":["ApiDayView.hourSumMap","ApiDayView.riskSumMap","ApiDayView.reqSensTuple","ApiDayView.resSensTuple","ApiDayView.statusSumMap","ApiDayView.count"],"timeDimensions":[{"dimension":"ApiDayView.dt","dateRange":"from 7 days ago to now"}],"filters":[{"member":"ApiDayView.urlRoute","operator":"equals","values":["/apiAuth"]},{"member":"ApiDayView.method","operator":"equals","values":["POST"]},{"member":"ApiDayView.host","operator":"equals","values":["127.0.0.1"]}],"dimensions":[],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%20%5B%22ApiDayView.hourSumMap%22%2C%20%22ApiDayView.riskSumMap%22%2C%20%22ApiDayView.reqSensTuple%22%2C%20%22ApiDayView.resSensTuple%22%2C%20%22ApiDayView.statusSumMap%22%2C%20%22ApiDayView.count%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22ApiDayView.dt%22%2C%20%22dateRange%22%3A%20%22from%207%20days%20ago%20to%20now%22%7D%5D%2C%20%22filters%22%3A%20%5B%7B%22member%22%3A%20%22ApiDayView.urlRoute%22%2C%20%22operator%22%3A%20%22equals%22%2C%20%22values%22%3A%20%5B%22/apiAuth%22%5D%7D%2C%20%7B%22member%22%3A%20%22ApiDayView.method%22%2C%20%22operator%22%3A%20%22equals%22%2C%20%22values%22%3A%20%5B%22POST%22%5D%7D%2C%20%7B%22member%22%3A%20%22ApiDayView.host%22%2C%20%22operator%22%3A%20%22equals%22%2C%20%22values%22%3A%20%5B%22127.0.0.1%22%5D%7D%5D%2C%20%22dimensions%22%3A%20%5B%5D%2C%20%22timezone%22%3A%20%22Asia/Shanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiDayView 路由汇总 hourSumMap+riskSumMap+reqSensTuple+resSensTuple+statusSumMap+count" "$result"

echo ""
echo "=== 22. ApiDayView count+riskSumMap+reqSensTuple+resSensTuple+statusSumMap by dt (filter urlRoute+method+host) ==="
#{"measures":["ApiDayView.count","ApiDayView.riskSumMap","ApiDayView.reqSensTuple","ApiDayView.resSensTuple","ApiDayView.statusSumMap"],"timeDimensions":[{"dimension":"ApiDayView.dt","granularity":"day","dateRange":"from 7 days ago to now"}],"filters":[{"member":"ApiDayView.urlRoute","operator":"equals","values":["/apiAuth"]},{"member":"ApiDayView.method","operator":"equals","values":["POST"]},{"member":"ApiDayView.host","operator":"equals","values":["127.0.0.1"]}],"dimensions":[],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%20%5B%22ApiDayView.count%22%2C%20%22ApiDayView.riskSumMap%22%2C%20%22ApiDayView.reqSensTuple%22%2C%20%22ApiDayView.resSensTuple%22%2C%20%22ApiDayView.statusSumMap%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22ApiDayView.dt%22%2C%20%22granularity%22%3A%20%22day%22%2C%20%22dateRange%22%3A%20%22from%207%20days%20ago%20to%20now%22%7D%5D%2C%20%22filters%22%3A%20%5B%7B%22member%22%3A%20%22ApiDayView.urlRoute%22%2C%20%22operator%22%3A%20%22equals%22%2C%20%22values%22%3A%20%5B%22/apiAuth%22%5D%7D%2C%20%7B%22member%22%3A%20%22ApiDayView.method%22%2C%20%22operator%22%3A%20%22equals%22%2C%20%22values%22%3A%20%5B%22POST%22%5D%7D%2C%20%7B%22member%22%3A%20%22ApiDayView.host%22%2C%20%22operator%22%3A%20%22equals%22%2C%20%22values%22%3A%20%5B%22127.0.0.1%22%5D%7D%5D%2C%20%22dimensions%22%3A%20%5B%5D%2C%20%22timezone%22%3A%20%22Asia/Shanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiDayView count+riskSumMap+reqSensTuple+resSensTuple+statusSumMap by dt" "$result"

echo ""
echo "=== 23. ApiDayView minSumMap+minCountAvg+minCountStddev+minZscoreArray (filter host+urlRoute+method) ==="
#{"measures":["ApiDayView.minSumMap","ApiDayView.minCountAvg","ApiDayView.minCountStddev","ApiDayView.minZscoreArray"],"timeDimensions":[{"dimension":"ApiDayView.dt","dateRange":"from 7 days ago to now"}],"filters":[{"member":"ApiDayView.host","operator":"equals","values":["127.0.0.1"]},{"member":"ApiDayView.urlRoute","operator":"equals","values":["/apiAuth"]},{"member":"ApiDayView.method","operator":"equals","values":["POST"]}],"dimensions":[],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%20%5B%22ApiDayView.minSumMap%22%2C%20%22ApiDayView.minCountAvg%22%2C%20%22ApiDayView.minCountStddev%22%2C%20%22ApiDayView.minZscoreArray%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22ApiDayView.dt%22%2C%20%22dateRange%22%3A%20%22from%207%20days%20ago%20to%20now%22%7D%5D%2C%20%22filters%22%3A%20%5B%7B%22member%22%3A%20%22ApiDayView.host%22%2C%20%22operator%22%3A%20%22equals%22%2C%20%22values%22%3A%20%5B%22127.0.0.1%22%5D%7D%2C%20%7B%22member%22%3A%20%22ApiDayView.urlRoute%22%2C%20%22operator%22%3A%20%22equals%22%2C%20%22values%22%3A%20%5B%22/apiAuth%22%5D%7D%2C%20%7B%22member%22%3A%20%22ApiDayView.method%22%2C%20%22operator%22%3A%20%22equals%22%2C%20%22values%22%3A%20%5B%22POST%22%5D%7D%5D%2C%20%22dimensions%22%3A%20%5B%5D%2C%20%22timezone%22%3A%20%22Asia/Shanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiDayView minSumMap+minCountAvg+minCountStddev+minZscoreArray" "$result"

echo ""
echo "=== 24. ApiDayView minCountToday+minCountPredictArray (filter host+urlRoute+method, 3天) ==="
#{"measures":["ApiDayView.minCountToday","ApiDayView.minCountPredictArray"],"timeDimensions":[{"dimension":"ApiDayView.dt","dateRange":"from 3 days ago to now"}],"filters":[{"member":"ApiDayView.host","operator":"equals","values":["127.0.0.1"]},{"member":"ApiDayView.urlRoute","operator":"equals","values":["/apiAuth"]},{"member":"ApiDayView.method","operator":"equals","values":["POST"]}],"dimensions":[],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%20%5B%22ApiDayView.minCountToday%22%2C%20%22ApiDayView.minCountPredictArray%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22ApiDayView.dt%22%2C%20%22dateRange%22%3A%20%22from%203%20days%20ago%20to%20now%22%7D%5D%2C%20%22filters%22%3A%20%5B%7B%22member%22%3A%20%22ApiDayView.host%22%2C%20%22operator%22%3A%20%22equals%22%2C%20%22values%22%3A%20%5B%22127.0.0.1%22%5D%7D%2C%20%7B%22member%22%3A%20%22ApiDayView.urlRoute%22%2C%20%22operator%22%3A%20%22equals%22%2C%20%22values%22%3A%20%5B%22/apiAuth%22%5D%7D%2C%20%7B%22member%22%3A%20%22ApiDayView.method%22%2C%20%22operator%22%3A%20%22equals%22%2C%20%22values%22%3A%20%5B%22POST%22%5D%7D%5D%2C%20%22dimensions%22%3A%20%5B%5D%2C%20%22timezone%22%3A%20%22Asia/Shanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiDayView minCountToday+minCountPredictArray (3天)" "$result"

echo ""
echo "=== 25. ApiDayView hourSumMap (filter host+urlRoute+method, 7天) ==="
#{"measures":["ApiDayView.hourSumMap"],"timeDimensions":[{"dimension":"ApiDayView.dt","dateRange":"from 7 days ago to now"}],"filters":[{"member":"ApiDayView.host","operator":"equals","values":["127.0.0.1"]},{"member":"ApiDayView.urlRoute","operator":"equals","values":["/apiAuth"]},{"member":"ApiDayView.method","operator":"equals","values":["POST"]}],"dimensions":[],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%20%5B%22ApiDayView.hourSumMap%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22ApiDayView.dt%22%2C%20%22dateRange%22%3A%20%22from%207%20days%20ago%20to%20now%22%7D%5D%2C%20%22filters%22%3A%20%5B%7B%22member%22%3A%20%22ApiDayView.host%22%2C%20%22operator%22%3A%20%22equals%22%2C%20%22values%22%3A%20%5B%22127.0.0.1%22%5D%7D%2C%20%7B%22member%22%3A%20%22ApiDayView.urlRoute%22%2C%20%22operator%22%3A%20%22equals%22%2C%20%22values%22%3A%20%5B%22/apiAuth%22%5D%7D%2C%20%7B%22member%22%3A%20%22ApiDayView.method%22%2C%20%22operator%22%3A%20%22equals%22%2C%20%22values%22%3A%20%5B%22POST%22%5D%7D%5D%2C%20%22dimensions%22%3A%20%5B%5D%2C%20%22timezone%22%3A%20%22Asia/Shanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiDayView hourSumMap (filter host+urlRoute+method, 7天)" "$result"

echo "========================================"
echo "=== ApiView: gap-fill tests ==="
echo "========================================"

echo ""
echo "=== 26. ApiView: reqKeyTupleArray+currentReqKeyTs dimensions (ungrouped, limit 5) ==="
# Tests dimensions: reqKeyTupleArray (groupUniqArray expression), currentReqKeyTs (time)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ApiView.api%22%2C%22ApiView.reqKeyTupleArray%22%2C%22ApiView.currentReqKeyTs%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiView: ungrouped reqKeyTupleArray+currentReqKeyTs limit 5" "$result"

echo ""
echo "=== 27. ApiView: metricMap+successCount+hourCount+weakCount dimensions (ungrouped, limit 5) ==="
# Tests dimensions: metricMap (mapFromArrays expression), successCount, hourCount, weakCount (number dims)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ApiView.api%22%2C%22ApiView.metricMap%22%2C%22ApiView.successCount%22%2C%22ApiView.hourCount%22%2C%22ApiView.weakCount%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiView: ungrouped metricMap+successCount+hourCount+weakCount limit 5" "$result"

echo ""
echo "=== 28. ApiView: timeSum+lengthSum dimensions (ungrouped, limit 5) ==="
# Tests dimensions: timeSum, lengthSum (number dims from metric_count map)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ApiView.api%22%2C%22ApiView.timeSum%22%2C%22ApiView.lengthSum%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiView: ungrouped timeSum+lengthSum limit 5" "$result"

echo ""
echo "=== 29. ApiView: protocol dimension grouped by appName+protocol (count, limit 10) ==="
# Tests dimension: protocol (multiIf expression — HTTP/HTTP2/WebSocket/MQTT)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ApiView.allCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ApiView.appName%22%2C%22ApiView.protocol%22%5D%2C%22order%22%3A%7B%22ApiView.allCount%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiView: allCount by appName+protocol limit 10" "$result"

echo ""
echo "=== 30. ApiView: sidebarTypeArray+sidebarFirstLevelTypeArray dimensions (ungrouped, limit 5) ==="
# Tests dimensions: sidebarTypeArray (array), sidebarFirstLevelTypeArray (array)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiView.topoNetwork%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%E5%A4%96%E5%8F%91%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22ApiView.api%22%2C%22ApiView.sidebarTypeArray%22%2C%22ApiView.sidebarFirstLevelTypeArray%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiView: ungrouped sidebarTypeArray+sidebarFirstLevelTypeArray limit 5" "$result"

echo ""
echo "=== 31. ApiView: id dimension grouped by appName+method+urlRoute (count, filter by id) ==="
# Tests dimension: id (cityHash64 fingerprint)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ApiView.allCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ApiView.id%22%2C%22ApiView.appName%22%2C%22ApiView.method%22%2C%22ApiView.urlRoute%22%5D%2C%22order%22%3A%7B%22ApiView.allCount%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiView: allCount by id+appName+method+urlRoute limit 10" "$result"

echo ""
echo "=== 32. ApiView: isFavorite dimension filter (equals 1, grouped) ==="
# Tests dimension: isFavorite (subquery-based boolean)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ApiView.allCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiView.isFavorite%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%221%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22ApiView.appName%22%2C%22ApiView.isFavorite%22%5D%2C%22order%22%3A%7B%22ApiView.allCount%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiView: allCount by appName+isFavorite (filter isFavorite=1) limit 10" "$result"

echo ""
echo "=== 33. ApiView: appId dimension grouped (allCount, limit 10) ==="
# Tests dimension: appId (dict-lookup subquery)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ApiView.allCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiView.ts%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ApiView.appId%22%2C%22ApiView.appName%22%5D%2C%22order%22%3A%7B%22ApiView.allCount%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22ApiView.org%22%2C%22ApiView.black%22%2C%22ApiView.onePerDay%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiView: allCount by appId+appName limit 10" "$result"

echo "========================================"
echo "=== ApiDayView: gap-fill tests ==="
echo "========================================"

echo ""
echo "=== 34. ApiDayView: risk dimension (count by risk, 7 days) ==="
# Tests dimension: risk (arrayJoin + risk_dict filter)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ApiDayView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiDayView.dt%22%2C%22dateRange%22%3A%22from+7+days+ago+to+now%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ApiDayView.risk%22%5D%2C%22order%22%3A%7B%22ApiDayView.count%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiDayView: count by risk limit 10 (7 days)" "$result"

echo ""
echo "=== 35. ApiDayView: hasReqSens dimension (count by hasReqSens, 7 days) ==="
# Tests dimension: hasReqSens (length(finalizeAggregation(req_sens_uniq)))
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ApiDayView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiDayView.dt%22%2C%22dateRange%22%3A%22from+7+days+ago+to+now%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ApiDayView.hasReqSens%22%5D%2C%22order%22%3A%7B%22ApiDayView.count%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiDayView: count by hasReqSens limit 10 (7 days)" "$result"

echo ""
echo "=== 36. ApiDayView: status dimension (count by status, 7 days, filter host+urlRoute+method) ==="
# Tests dimension: status (arrayJoin on status_count)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ApiDayView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiDayView.dt%22%2C%22dateRange%22%3A%22from+7+days+ago+to+now%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiDayView.host%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22127.0.0.1%22%5D%7D%2C%7B%22member%22%3A%22ApiDayView.urlRoute%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22%2FapiAuth%22%5D%7D%2C%7B%22member%22%3A%22ApiDayView.method%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22POST%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22ApiDayView.status%22%5D%2C%22order%22%3A%7B%22ApiDayView.count%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiDayView: count by status (filter host+urlRoute+method) limit 10 (7 days)" "$result"

echo ""
echo "=== 37. ApiDayView: reqSensUniqMap+resSensUniqMap measures (filter host+urlRoute+method, 7 days) ==="
# Tests measures: reqSensUniqMap (uniqMapMerge), resSensUniqMap (uniqMapMerge)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ApiDayView.reqSensUniqMap%22%2C%22ApiDayView.resSensUniqMap%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiDayView.dt%22%2C%22dateRange%22%3A%22from+7+days+ago+to+now%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiDayView.host%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22127.0.0.1%22%5D%7D%2C%7B%22member%22%3A%22ApiDayView.urlRoute%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22%2FapiAuth%22%5D%7D%2C%7B%22member%22%3A%22ApiDayView.method%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22POST%22%5D%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiDayView: reqSensUniqMap+resSensUniqMap (filter host+urlRoute+method, 7 days)" "$result"

echo ""
echo "=== 38. ApiDayView: risk+status dimensions (count, filter host, 7 days, limit 5) ==="
# Exercises risk and status arrayJoin dimensions together
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ApiDayView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiDayView.dt%22%2C%22dateRange%22%3A%22from+7+days+ago+to+now%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiDayView.host%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22127.0.0.1%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22ApiDayView.risk%22%2C%22ApiDayView.status%22%5D%2C%22order%22%3A%7B%22ApiDayView.count%22%3A%22desc%22%7D%2C%22limit%22%3A5%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiDayView: count by risk+status (filter host, 7 days) limit 5" "$result"

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
