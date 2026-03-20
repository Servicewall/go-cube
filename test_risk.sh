#!/bin/bash
# Test RiskView queries against local go-cube server
# Mirrors production curl requests from demo.servicewall.cn

BASE="http://localhost:4000"
pass=0
fail=0

check() {
    local desc="$1"
    local result="$2"
    if echo "$result" | jq -e '.results[0].data' > /dev/null 2>&1; then
        # Check for error field inside data rows
        if echo "$result" | jq -e '.results[0].data[0].error' > /dev/null 2>&1; then
            echo "[FAIL] $desc — error in data"
            echo "$result" | jq '.results[0].data[0].error'
            ((fail++))
        else
            count=$(echo "$result" | jq '.results[0].data | length')
            echo "[PASS] $desc — $count rows"
            ((pass++))
        fi
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
echo "=== RiskView queries ==="
echo "========================================"

echo ""
echo "=== 1. 汇总统计 (ungrouped, summary dims: total/levelCount/statusCount/showTimeCount/tagsCount) ==="
# ungrouped=true, dimensions: total, levelCount, statusCount, showTimeCount, tagsCount
# timeDimensions: RiskView.filterTs today
# segments: org, whiteFilter, whiteRiskFilter, riskDenoiseFilter
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3A%20true%2C%20%22measures%22%3A%20%5B%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22RiskView.filterTs%22%2C%20%22dateRange%22%3A%20%22today%22%7D%5D%2C%20%22filters%22%3A%20%5B%5D%2C%20%22dimensions%22%3A%20%5B%22RiskView.total%22%2C%20%22RiskView.levelCount%22%2C%20%22RiskView.statusCount%22%2C%20%22RiskView.showTimeCount%22%2C%20%22RiskView.tagsCount%22%5D%2C%20%22segments%22%3A%20%5B%22RiskView.org%22%2C%20%22RiskView.whiteFilter%22%2C%20%22RiskView.whiteRiskFilter%22%2C%20%22RiskView.riskDenoiseFilter%22%5D%2C%20%22timezone%22%3A%20%22Asia%2FShanghai%22%7D")
check "summary stats (total/levelCount/statusCount/showTimeCount/tagsCount)" "$result"

echo ""
echo "=== 2. 忽略计数 (ungrouped, ignoreCount) ==="
# ungrouped=true, dimensions: ignoreCount
# segments: org, whiteRiskFilter, riskDenoiseFilter
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3A%20true%2C%20%22measures%22%3A%20%5B%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22RiskView.filterTs%22%2C%20%22dateRange%22%3A%20%22today%22%7D%5D%2C%20%22filters%22%3A%20%5B%5D%2C%20%22dimensions%22%3A%20%5B%22RiskView.ignoreCount%22%5D%2C%20%22segments%22%3A%20%5B%22RiskView.org%22%2C%20%22RiskView.whiteRiskFilter%22%2C%20%22RiskView.riskDenoiseFilter%22%5D%2C%20%22timezone%22%3A%20%22Asia%2FShanghai%22%7D")
check "ignore count (ignoreCount)" "$result"

echo ""
echo "=== 3. 汇总统计 重复 (same as Q1, second query in multi) ==="
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3A%20true%2C%20%22measures%22%3A%20%5B%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22RiskView.filterTs%22%2C%20%22dateRange%22%3A%20%22today%22%7D%5D%2C%20%22filters%22%3A%20%5B%5D%2C%20%22dimensions%22%3A%20%5B%22RiskView.total%22%2C%20%22RiskView.levelCount%22%2C%20%22RiskView.statusCount%22%2C%20%22RiskView.showTimeCount%22%2C%20%22RiskView.tagsCount%22%5D%2C%20%22segments%22%3A%20%5B%22RiskView.org%22%2C%20%22RiskView.whiteFilter%22%2C%20%22RiskView.whiteRiskFilter%22%2C%20%22RiskView.riskDenoiseFilter%22%5D%2C%20%22timezone%22%3A%20%22Asia%2FShanghai%22%7D")
check "summary stats repeat (total/levelCount/statusCount/showTimeCount/tagsCount)" "$result"

echo ""
echo "=== 4. 忽略计数 重复 (same as Q2, second query in multi) ==="
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3A%20true%2C%20%22measures%22%3A%20%5B%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22RiskView.filterTs%22%2C%20%22dateRange%22%3A%20%22today%22%7D%5D%2C%20%22filters%22%3A%20%5B%5D%2C%20%22dimensions%22%3A%20%5B%22RiskView.ignoreCount%22%5D%2C%20%22segments%22%3A%20%5B%22RiskView.org%22%2C%20%22RiskView.whiteRiskFilter%22%2C%20%22RiskView.riskDenoiseFilter%22%5D%2C%20%22timezone%22%3A%20%22Asia%2FShanghai%22%7D")
check "ignore count repeat (ignoreCount)" "$result"

echo ""
echo "=== 5. 风险计数 (measure: count, filters: filterStatus=待确认, filterRiskLevel in [高风险,中风险]) ==="
# measures: count
# filters: filterStatus contains 待确认, filterRiskLevel contains [高风险, 中风险]
# segments: org, whiteFilter, whiteRiskFilter, riskDenoiseFilter
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%20%5B%22RiskView.count%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22RiskView.filterTs%22%2C%20%22dateRange%22%3A%20%22today%22%7D%5D%2C%20%22filters%22%3A%20%5B%7B%22member%22%3A%20%22RiskView.filterStatus%22%2C%20%22operator%22%3A%20%22contains%22%2C%20%22values%22%3A%20%5B%22%E5%BE%85%E7%A1%AE%E8%AE%A4%22%5D%7D%2C%20%7B%22member%22%3A%20%22RiskView.filterRiskLevel%22%2C%20%22operator%22%3A%20%22contains%22%2C%20%22values%22%3A%20%5B%22%E9%AB%98%E9%A3%8E%E9%99%A9%22%2C%20%22%E4%B8%AD%E9%A3%8E%E9%99%A9%22%5D%7D%5D%2C%20%22dimensions%22%3A%20%5B%5D%2C%20%22segments%22%3A%20%5B%22RiskView.org%22%2C%20%22RiskView.whiteFilter%22%2C%20%22RiskView.whiteRiskFilter%22%2C%20%22RiskView.riskDenoiseFilter%22%5D%2C%20%22timezone%22%3A%20%22Asia%2FShanghai%22%7D")
check "risk count (measure: count, filters: filterStatus+filterRiskLevel)" "$result"

echo ""
echo "=== 6. 风险列表 (measures: ts/firstTs/status/data/riskClues/isRealtimeRule/filters/orderBy + dimensions) ==="
# measures: ts, firstTs, status, data, riskClues, isRealtimeRule, filters, orderBy
# dimensions: risk, host, channel, filterRiskLevel, type, content, filterScore, nameGroup
# order: filterScore desc, ts desc
# filters: filterStatus contains 待确认, filterRiskLevel contains [高风险,中风险]
# limit: 20, offset: 0
# segments: org, whiteFilter, whiteRiskFilter, riskDenoiseFilter
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%20%5B%22RiskView.ts%22%2C%20%22RiskView.firstTs%22%2C%20%22RiskView.status%22%2C%20%22RiskView.data%22%2C%20%22RiskView.riskClues%22%2C%20%22RiskView.isRealtimeRule%22%2C%20%22RiskView.filters%22%2C%20%22RiskView.orderBy%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22RiskView.filterTs%22%2C%20%22dateRange%22%3A%20%22today%22%7D%5D%2C%20%22order%22%3A%20%7B%22RiskView.filterScore%22%3A%20%22desc%22%2C%20%22RiskView.ts%22%3A%20%22desc%22%7D%2C%20%22filters%22%3A%20%5B%7B%22member%22%3A%20%22RiskView.filterStatus%22%2C%20%22operator%22%3A%20%22contains%22%2C%20%22values%22%3A%20%5B%22%E5%BE%85%E7%A1%AE%E8%AE%A4%22%5D%7D%2C%20%7B%22member%22%3A%20%22RiskView.filterRiskLevel%22%2C%20%22operator%22%3A%20%22contains%22%2C%20%22values%22%3A%20%5B%22%E9%AB%98%E9%A3%8E%E9%99%A9%22%2C%20%22%E4%B8%AD%E9%A3%8E%E9%99%A9%22%5D%7D%5D%2C%20%22dimensions%22%3A%20%5B%22RiskView.risk%22%2C%20%22RiskView.host%22%2C%20%22RiskView.channel%22%2C%20%22RiskView.filterRiskLevel%22%2C%20%22RiskView.type%22%2C%20%22RiskView.content%22%2C%20%22RiskView.filterScore%22%2C%20%22RiskView.nameGroup%22%5D%2C%20%22limit%22%3A%2020%2C%20%22offset%22%3A%200%2C%20%22segments%22%3A%20%5B%22RiskView.org%22%2C%20%22RiskView.whiteFilter%22%2C%20%22RiskView.whiteRiskFilter%22%2C%20%22RiskView.riskDenoiseFilter%22%5D%2C%20%22timezone%22%3A%20%22Asia%2FShanghai%22%7D")
check "risk list (measures + dimensions, order by filterScore/ts, limit 20)" "$result"

echo ""
echo "=== 7. 触发次数 countNum (measure: countNum, dimensions: risk/host/channel) ==="
# measures: countNum (sum(count))
# dimensions: risk, host, channel
# timeDimensions: filterTs today
# segments: org, whiteFilter, whiteRiskFilter
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%20%5B%22RiskView.countNum%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22RiskView.filterTs%22%2C%20%22dateRange%22%3A%20%22today%22%7D%5D%2C%20%22filters%22%3A%20%5B%5D%2C%20%22dimensions%22%3A%20%5B%22RiskView.risk%22%2C%20%22RiskView.host%22%2C%20%22RiskView.channel%22%5D%2C%20%22segments%22%3A%20%5B%22RiskView.org%22%2C%20%22RiskView.whiteFilter%22%2C%20%22RiskView.whiteRiskFilter%22%5D%2C%20%22timezone%22%3A%20%22Asia%2FShanghai%22%2C%20%22limit%22%3A%205%7D")
check "countNum measure (sum of count col per risk/host/channel)" "$result"

echo ""
echo "=== 8. 完整风险描述 riskFullDesc (measure: riskFullDesc, dimensions: risk/host/content) ==="
# measures: riskFullDesc (argMax of dict desc)
# dimensions: risk, host, content
# timeDimensions: filterTs today
# segments: org
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%20%5B%22RiskView.riskFullDesc%22%5D%2C%20%22timeDimensions%22%3A%20%5B%7B%22dimension%22%3A%20%22RiskView.filterTs%22%2C%20%22dateRange%22%3A%20%22today%22%7D%5D%2C%20%22filters%22%3A%20%5B%5D%2C%20%22dimensions%22%3A%20%5B%22RiskView.risk%22%2C%20%22RiskView.host%22%2C%20%22RiskView.content%22%5D%2C%20%22segments%22%3A%20%5B%22RiskView.org%22%5D%2C%20%22timezone%22%3A%20%22Asia%2FShanghai%22%2C%20%22limit%22%3A%205%7D")
check "riskFullDesc measure (argMax of dict desc)" "$result"

echo ""
echo "=== 9. riskFullDesc + resSensKv + countNum (单条风险详情) ==="
# measures: riskFullDesc, resSensKv, countNum
# filters: risk=境外IP使用账号访问多个应用, type=ip, content=172.31.45.232
# segments: org
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22RiskView.riskFullDesc%22%2C%22RiskView.resSensKv%22%2C%22RiskView.countNum%22%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22RiskView.risk%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22%E5%A2%83%E5%A4%96IP%E4%BD%BF%E7%94%A8%E8%B4%A6%E5%8F%B7%E8%AE%BF%E9%97%AE%E5%A4%9A%E4%B8%AA%E5%BA%94%E7%94%A8%22%5D%7D%2C%7B%22member%22%3A%22RiskView.type%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22ip%22%5D%7D%2C%7B%22member%22%3A%22RiskView.content%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22172.31.45.232%22%5D%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22RiskView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "riskFullDesc+resSensKv+countNum (single risk detail)" "$result"

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null

if [ $fail -gt 0 ]; then
    exit 1
fi
