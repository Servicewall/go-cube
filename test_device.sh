#!/bin/bash
# Test DeviceView queries against local go-cube server

source "$(dirname "$0")/common.sh"

setup_server_trap
start_server 2
test_health

echo ""
echo "========================================"
echo "=== DeviceView queries ==="
echo "========================================"

echo ""
echo "=== 1. Android点击位置聚合 (androidClickArray + count + uniqDevCount + top3DeviceSet, filter: devType=Android + count>10 + uniqDevCount>10) ==="
# measures: [count, uniqDevCount, top3DeviceSet]
# timeDimensions: [{DeviceView.ts, dateRange: today}]
# filters: [androidClickArray set, devType = Android, count > 10, uniqDevCount > 10]
# dimensions: [androidClickArray, androidClickName]
# segments: [DeviceView.org]
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22DeviceView.count%22%2C%22DeviceView.uniqDevCount%22%2C%22DeviceView.top3DeviceSet%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22DeviceView.ts%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22DeviceView.androidClickArray%22%2C%22operator%22%3A%22set%22%7D%2C%7B%22member%22%3A%22DeviceView.devType%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22Android%22%5D%7D%2C%7B%22member%22%3A%22DeviceView.count%22%2C%22operator%22%3A%22gt%22%2C%22values%22%3A%5B%2210%22%5D%7D%2C%7B%22member%22%3A%22DeviceView.uniqDevCount%22%2C%22operator%22%3A%22gt%22%2C%22values%22%3A%5B%2210%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22DeviceView.androidClickArray%22%2C%22DeviceView.androidClickName%22%5D%2C%22limit%22%3A20%2C%22segments%22%3A%5B%22DeviceView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
check "Android点击位置聚合 (androidClickArray + count + uniqDevCount + top3DeviceSet)" "$result"

echo ""
echo "=== 2. 设备数汇总 (uniqDevCount + iOS/Android/Harmony分类, 近15分钟) ==="
# measures: [uniqDevCount, uniqIosDevCount, uniqAndroidDevCount, uniqHarmonyDevCount]
# timeDimensions: [{DeviceView.ts, dateRange: from 15 minutes ago to 15 minutes from now}]
# dimensions: []
# segments: [DeviceView.org]
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22DeviceView.uniqDevCount%22%2C%22DeviceView.uniqIosDevCount%22%2C%22DeviceView.uniqAndroidDevCount%22%2C%22DeviceView.uniqHarmonyDevCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22DeviceView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22DeviceView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
check "设备数汇总 (uniqDevCount + iOS/Android/Harmony分类)" "$result"

echo ""
echo "=== 3. 按分钟粒度时间趋势 (count + uniqDevCount, granularity: minute) ==="
# measures: [count, uniqDevCount]
# timeDimensions: [{DeviceView.ts, dateRange: from 15 minutes ago to 15 minutes from now, granularity: minute}]
# dimensions: []
# segments: [DeviceView.org]
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22DeviceView.count%22%2C%22DeviceView.uniqDevCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22DeviceView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%2C%22granularity%22%3A%22minute%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22DeviceView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
check "按分钟粒度时间趋势 (count + uniqDevCount by minute)" "$result"

echo ""
echo "=== 4. 厂商分布 (count by vendor, filter: vendor != '') ==="
# measures: [count]
# timeDimensions: [{DeviceView.ts, dateRange: from 15 minutes ago to 15 minutes from now}]
# filters: [vendor != '']
# dimensions: [vendor]
# segments: [DeviceView.org]
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22DeviceView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22DeviceView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22DeviceView.vendor%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22DeviceView.vendor%22%5D%2C%22segments%22%3A%5B%22DeviceView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
check "厂商分布 (count by vendor, vendor != '')" "$result"

echo ""
echo "=== 5. 系统版本分布 (count by platform, filter: platform != '') ==="
# measures: [count]
# timeDimensions: [{DeviceView.ts, dateRange: from 15 minutes ago to 15 minutes from now}]
# filters: [platform != '']
# dimensions: [platform]
# segments: [DeviceView.org]
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22DeviceView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22DeviceView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22DeviceView.platform%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22DeviceView.platform%22%5D%2C%22segments%22%3A%5B%22DeviceView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
check "系统版本分布 (count by platform, platform != '')" "$result"

echo ""
echo "=== 6. 应用分布 (count by customAppName, filter: customAppName != '') ==="
# measures: [count]
# timeDimensions: [{DeviceView.ts, dateRange: from 15 minutes ago to 15 minutes from now}]
# filters: [customAppName != '']
# dimensions: [customAppName]
# segments: [DeviceView.org]
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22DeviceView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22DeviceView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22DeviceView.customAppName%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22DeviceView.customAppName%22%5D%2C%22segments%22%3A%5B%22DeviceView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
check "应用分布 (count by customAppName, customAppName != '')" "$result"

echo ""
echo "=== 7. 省份分布 (count by province) ==="
# measures: [count]
# timeDimensions: [{DeviceView.ts, dateRange: from 15 minutes ago to 15 minutes from now}]
# dimensions: [province]
# segments: [DeviceView.org]
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22DeviceView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22DeviceView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22DeviceView.province%22%5D%2C%22segments%22%3A%5B%22DeviceView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
check "省份分布 (count by province)" "$result"

echo ""
echo "=== 8. 崩溃汇总指标 (crashCount + crashRatio + totalAndroidLaunchCount) ==="
# measures: [crashCount, crashRatio, totalAndroidLaunchCount]
# timeDimensions: [{DeviceView.ts, dateRange: from 15 minutes ago to 15 minutes from now}]
# dimensions: []
# segments: [DeviceView.org]
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22DeviceView.crashCount%22%2C%22DeviceView.crashRatio%22%2C%22DeviceView.totalAndroidLaunchCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22DeviceView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22DeviceView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
check "崩溃汇总指标 (crashCount + crashRatio + totalAndroidLaunchCount)" "$result"

echo ""
echo "=== 9. 崩溃趋势 (count by minute, filter: crashStack != '') ==="
# measures: [count]
# timeDimensions: [{DeviceView.ts, dateRange: from 15 minutes ago to 15 minutes from now, granularity: minute}]
# filters: [crashStack != '']
# dimensions: []
# segments: [DeviceView.org]
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22DeviceView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22DeviceView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%2C%22granularity%22%3A%22minute%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22DeviceView.crashStack%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%22%5D%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22DeviceView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
check "崩溃趋势 (count by minute, crashStack != '')" "$result"

echo ""
echo "=== 10. 崩溃平台分布 (count by platform, filter: crashStack != '') ==="
# measures: [count]
# timeDimensions: [{DeviceView.ts, dateRange: from 15 minutes ago to 15 minutes from now}]
# filters: [crashStack != '']
# dimensions: [platform]
# segments: [DeviceView.org]
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22DeviceView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22DeviceView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22DeviceView.crashStack%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22DeviceView.platform%22%5D%2C%22segments%22%3A%5B%22DeviceView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
check "崩溃平台分布 (count by platform, crashStack != '')" "$result"

echo ""
echo "=== 11. 崩溃机型分布 (count by vendor + module, filter: crashStack != '') ==="
# measures: [count]
# timeDimensions: [{DeviceView.ts, dateRange: from 15 minutes ago to 15 minutes from now}]
# filters: [crashStack != '']
# dimensions: [vendor, module]
# segments: [DeviceView.org]
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22DeviceView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22DeviceView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22DeviceView.crashStack%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22DeviceView.vendor%22%2C%22DeviceView.module%22%5D%2C%22segments%22%3A%5B%22DeviceView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
check "崩溃机型分布 (count by vendor + module, crashStack != '')" "$result"

echo ""
echo "=== 12. 崩溃应用分布 (count by appName, filter: crashStack != '' + appName != '') ==="
# measures: [count]
# timeDimensions: [{DeviceView.ts, dateRange: from 15 minutes ago to 15 minutes from now}]
# filters: [crashStack != '', appName != '']
# dimensions: [appName]
# segments: [DeviceView.org]
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22DeviceView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22DeviceView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22DeviceView.crashStack%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%22%5D%7D%2C%7B%22member%22%3A%22DeviceView.appName%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22DeviceView.appName%22%5D%2C%22segments%22%3A%5B%22DeviceView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
check "崩溃应用分布 (count by appName, crashStack != '' + appName != '')" "$result"

echo ""
echo "=== 13. 崩溃明细列表 (无measures, filter: crashStack != '', dimensions: devType+appName+crashStack+module+platform+vendor+sid+ip+ts) ==="
# measures: []
# timeDimensions: [{DeviceView.ts, dateRange: from 15 minutes ago to 15 minutes from now}]
# filters: [crashStack != '']
# dimensions: [devType, appName, crashStack, module, platform, vendor, sid, ip, ts]
# segments: [DeviceView.org]
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22DeviceView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22DeviceView.crashStack%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22DeviceView.devType%22%2C%22DeviceView.appName%22%2C%22DeviceView.crashStack%22%2C%22DeviceView.module%22%2C%22DeviceView.platform%22%2C%22DeviceView.vendor%22%2C%22DeviceView.sid%22%2C%22DeviceView.ip%22%2C%22DeviceView.ts%22%5D%2C%22segments%22%3A%5B%22DeviceView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
check "崩溃明细列表 (devType+appName+crashStack+module+platform+vendor+sid+ip+ts)" "$result"

echo ""
echo "=== 14. 设备群聚合 (count+aggRisk+ipGeoSet+uniqDevCount+uniqIpCount+uniqUserCount by cluster+devType, OR filter) ==="
# measures: [count, aggRisk, ipGeoSet, uniqDevCount, uniqIpCount, uniqUserCount]
# timeDimensions: [{DeviceView.ts, dateRange: from 15 minutes ago to 15 minutes from now}]
# filters: [cluster != '', OR(count>=10000, uniqDevCount>=5, uniqIpCount>=1000)]
# dimensions: [cluster, devType]
# segments: [DeviceView.org]
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22DeviceView.count%22%2C%22DeviceView.aggRisk%22%2C%22DeviceView.ipGeoSet%22%2C%22DeviceView.uniqDevCount%22%2C%22DeviceView.uniqIpCount%22%2C%22DeviceView.uniqUserCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22DeviceView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22DeviceView.cluster%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%22%5D%7D%2C%7B%22or%22%3A%5B%7B%22member%22%3A%22DeviceView.count%22%2C%22operator%22%3A%22gte%22%2C%22values%22%3A%5B%2210000%22%5D%7D%2C%7B%22member%22%3A%22DeviceView.uniqDevCount%22%2C%22operator%22%3A%22gte%22%2C%22values%22%3A%5B%225%22%5D%7D%2C%7B%22member%22%3A%22DeviceView.uniqIpCount%22%2C%22operator%22%3A%22gte%22%2C%22values%22%3A%5B%221000%22%5D%7D%5D%7D%5D%2C%22dimensions%22%3A%5B%22DeviceView.cluster%22%2C%22DeviceView.devType%22%5D%2C%22segments%22%3A%5B%22DeviceView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
check "设备群聚合 (cluster+devType, OR filter: count>=10000 OR uniqDevCount>=5 OR uniqIpCount>=1000)" "$result"

echo ""
echo "=== 15. 总上报量 (count, 无dimensions) ==="
# measures: [count]
# timeDimensions: [{DeviceView.ts, dateRange: from 15 minutes ago to 15 minutes from now}]
# dimensions: []
# segments: [DeviceView.org]
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22DeviceView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22DeviceView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22DeviceView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
check "总上报量 (count, 无dimensions)" "$result"

echo ""
echo "=== 16. 设备明细列表 (ungrouped, ts+sid+ip+uid+customAppName+netType+vendor+module+province, order by ts desc, limit 10) ==="
# ungrouped: true, measures: []
# timeDimensions: [{DeviceView.ts, dateRange: from 15 minutes ago to 15 minutes from now}]
# order: [[ts, desc]]
# dimensions: [ts, sid, ip, uid, customAppName, netType, vendor, module, province]
# limit: 10, offset: 0
# segments: [DeviceView.org]
result=$(curl -s "$BASE/load?query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22DeviceView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22order%22%3A%5B%5B%22DeviceView.ts%22%2C%22desc%22%5D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22DeviceView.ts%22%2C%22DeviceView.sid%22%2C%22DeviceView.ip%22%2C%22DeviceView.uid%22%2C%22DeviceView.customAppName%22%2C%22DeviceView.netType%22%2C%22DeviceView.vendor%22%2C%22DeviceView.module%22%2C%22DeviceView.province%22%5D%2C%22limit%22%3A10%2C%22offset%22%3A0%2C%22segments%22%3A%5B%22DeviceView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
check "设备明细列表 (ungrouped, ts+sid+ip+uid+customAppName+netType+vendor+module+province, limit 10)" "$result"

echo ""
echo "=== 17. 唯一设备数汇总 (uniqDevCount, 无dimensions) ==="
# measures: [uniqDevCount]
# timeDimensions: [{DeviceView.ts, dateRange: from 15 minutes ago to 15 minutes from now}]
# dimensions: []
# segments: [DeviceView.org]
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22DeviceView.uniqDevCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22DeviceView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22DeviceView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
check "唯一设备数汇总 (uniqDevCount, 无dimensions)" "$result"

echo ""
echo "=== 18. 风险设备数 (uniqDevCount, filter: risk != '') ==="
# measures: [uniqDevCount]
# timeDimensions: [{DeviceView.ts, dateRange: from 15 minutes ago to 15 minutes from now}]
# filters: [risk != '']
# dimensions: []
# segments: [DeviceView.org]
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22DeviceView.uniqDevCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22DeviceView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22DeviceView.risk%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%22%5D%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22DeviceView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
check "风险设备数 (uniqDevCount, risk != '')" "$result"

echo ""
echo "=== 19. 风险设备趋势 (uniqDevCount by minute, filter: risk != '') ==="
# measures: [uniqDevCount]
# timeDimensions: [{DeviceView.ts, dateRange: from 15 minutes ago to 15 minutes from now, granularity: minute}]
# filters: [risk != '']
# dimensions: []
# segments: [DeviceView.org]
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22DeviceView.uniqDevCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22DeviceView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%2C%22granularity%22%3A%22minute%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22DeviceView.risk%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%22%5D%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22DeviceView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
check "风险设备趋势 (uniqDevCount by minute, risk != '')" "$result"

echo ""
echo "=== 20. 风险设备明细 (ungrouped, ts+sid+ip+customAppName+platform+vendor+risk, order by ts desc, limit 10) ==="
# ungrouped: true, measures: []
# timeDimensions: [{DeviceView.ts, dateRange: from 15 minutes ago to 15 minutes from now}]
# order: [[ts, desc]]
# dimensions: [ts, sid, ip, customAppName, platform, vendor, risk]
# limit: 10, offset: 0
# segments: [DeviceView.org]
result=$(curl -s "$BASE/load?query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22DeviceView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22order%22%3A%5B%5B%22DeviceView.ts%22%2C%22desc%22%5D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22DeviceView.ts%22%2C%22DeviceView.sid%22%2C%22DeviceView.ip%22%2C%22DeviceView.customAppName%22%2C%22DeviceView.platform%22%2C%22DeviceView.vendor%22%2C%22DeviceView.risk%22%5D%2C%22limit%22%3A10%2C%22offset%22%3A0%2C%22segments%22%3A%5B%22DeviceView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
check "风险设备明细 (ungrouped, ts+sid+ip+customAppName+platform+vendor+risk, limit 10)" "$result"

echo ""
echo "========================================"
echo "Results: $pass passed, $fail failed"
echo "========================================"

stop_server

[ $fail -gt 0 ] && exit 1
exit 0
