#!/bin/bash
# Test AuditView queries against local go-cube server
# Mirrors production curl requests from demo.servicewall.cn

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
./go-cube &
SERVER_PID=$!
sleep 2

echo ""
echo "Testing health endpoint..."
curl -s "$BASE/health" | jq .

echo ""
echo "========================================"
echo "=== AuditView queries ==="
echo "========================================"

echo ""
echo "=== 1. 地图分析汇总指标 (map aggregation, no dimensions, segment: org) ==="
# measures: [countryIpSumMap, provinceIpSumMap, departmentUserSumMap, deviceTypeSumMap]
# timeDimensions: [{AuditView.dt, dateRange: today}]
# segments: [AuditView.org]
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AuditView.countryIpSumMap%22%2C%22AuditView.provinceIpSumMap%22%2C%22AuditView.departmentUserSumMap%22%2C%22AuditView.deviceTypeSumMap%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AuditView.dt%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AuditView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "map aggregation (countryIpSumMap, provinceIpSumMap, departmentUserSumMap, deviceTypeSumMap)" "$result"

echo ""
echo "=== 2. IP维度明细 (type=IP, segments: org+top) ==="
# measures: [sidUniq, ipUniq, uaUniq, uidUniq, apiUniq, appUniq, count, ipGeo, riskScoreTuple, reqSensScoreTuple, resSensScoreTuple]
# timeDimensions: [{AuditView.dt, dateRange: today}]
# order: {AuditView.count: desc}
# filters: [{member: AuditView.type, operator: equals, values: [IP]}]
# dimensions: [type, content, nameGroup, department]
# segments: [AuditView.org, AuditView.top]
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AuditView.sidUniq%22%2C%22AuditView.ipUniq%22%2C%22AuditView.uaUniq%22%2C%22AuditView.uidUniq%22%2C%22AuditView.apiUniq%22%2C%22AuditView.appUniq%22%2C%22AuditView.count%22%2C%22AuditView.ipGeo%22%2C%22AuditView.riskScoreTuple%22%2C%22AuditView.reqSensScoreTuple%22%2C%22AuditView.resSensScoreTuple%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AuditView.dt%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22order%22%3A%7B%22AuditView.count%22%3A%22desc%22%7D%2C%22filters%22%3A%5B%7B%22member%22%3A%22AuditView.type%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22IP%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22AuditView.type%22%2C%22AuditView.content%22%2C%22AuditView.nameGroup%22%2C%22AuditView.department%22%5D%2C%22offset%22%3A0%2C%22segments%22%3A%5B%22AuditView.org%22%2C%22AuditView.top%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "IP dimension detail (type=IP, with measures + nameGroup + department)" "$result"

echo ""
echo "=== 3. Device维度明细 (type=Device, segments: org+top) ==="
# Same as query 2 but type=Device
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AuditView.sidUniq%22%2C%22AuditView.ipUniq%22%2C%22AuditView.uaUniq%22%2C%22AuditView.uidUniq%22%2C%22AuditView.apiUniq%22%2C%22AuditView.appUniq%22%2C%22AuditView.count%22%2C%22AuditView.ipGeo%22%2C%22AuditView.riskScoreTuple%22%2C%22AuditView.reqSensScoreTuple%22%2C%22AuditView.resSensScoreTuple%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AuditView.dt%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22order%22%3A%7B%22AuditView.count%22%3A%22desc%22%7D%2C%22filters%22%3A%5B%7B%22member%22%3A%22AuditView.type%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22Device%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22AuditView.type%22%2C%22AuditView.content%22%2C%22AuditView.nameGroup%22%2C%22AuditView.department%22%5D%2C%22offset%22%3A0%2C%22segments%22%3A%5B%22AuditView.org%22%2C%22AuditView.top%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "Device dimension detail (type=Device, with measures + nameGroup + department)" "$result"

echo ""
echo "========================================"
echo "=== AuditView: gap-fill tests ==="
echo "========================================"

echo ""
echo "=== 4. AuditView: channel dimension (count by channel, segment org) ==="
# Tests dimension: channel
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AuditView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AuditView.dt%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AuditView.channel%22%5D%2C%22order%22%3A%7B%22AuditView.count%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22AuditView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "AuditView: count by channel limit 10" "$result"

echo ""
echo "=== 5. AuditView: ipGeoCountry+ipGeoProvince dimensions (count, type=IP, limit 10) ==="
# Tests dimensions: ipGeoCountry (ip_geo[1]), ipGeoProvince (ip_geo[2])
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AuditView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AuditView.dt%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22AuditView.type%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22IP%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22AuditView.ipGeoCountry%22%2C%22AuditView.ipGeoProvince%22%5D%2C%22order%22%3A%7B%22AuditView.count%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22AuditView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "AuditView: count by ipGeoCountry+ipGeoProvince (type=IP) limit 10" "$result"

echo ""
echo "=== 6. AuditView: deviceType dimension (count, type=Device, limit 10) ==="
# Tests dimension: deviceType (multiIf on content prefix)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AuditView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AuditView.dt%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22AuditView.type%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22Device%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22AuditView.deviceType%22%5D%2C%22order%22%3A%7B%22AuditView.count%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22AuditView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "AuditView: count by deviceType (type=Device) limit 10" "$result"

echo ""
echo "=== 7. AuditView: lastTs measure (max last_ts by type, order lastTs desc, limit 5) ==="
# Tests measure: lastTs (max(last_ts) time measure)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AuditView.lastTs%22%2C%22AuditView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AuditView.dt%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AuditView.type%22%5D%2C%22order%22%3A%7B%22AuditView.lastTs%22%3A%22desc%22%7D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AuditView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "AuditView: lastTs+count by type order lastTs desc limit 5" "$result"

echo ""
echo "=== 8. AuditView: channel+ipGeoCountry+ipGeoProvince+deviceType (count, today) ==="
# Exercises all 4 gap dimensions in a single query
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AuditView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AuditView.dt%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AuditView.channel%22%2C%22AuditView.ipGeoCountry%22%2C%22AuditView.ipGeoProvince%22%2C%22AuditView.deviceType%22%5D%2C%22order%22%3A%7B%22AuditView.count%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22AuditView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "AuditView: count by channel+ipGeoCountry+ipGeoProvince+deviceType limit 10" "$result"

echo ""
echo "========================================"
echo "Results: $pass passed, $fail failed"
echo "========================================"

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null

if [ $fail -gt 0 ]; then
    exit 1
fi
