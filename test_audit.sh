#!/bin/bash
# Test AuditView queries against local go-cube server
# Mirrors production curl requests from demo.servicewall.cn

source "$(dirname "$0")/common.sh"

setup_server_trap
start_server 2
test_health

echo ""
echo "========================================"
echo "=== AuditView queries ==="
echo "========================================"

echo ""
echo "=== 1. IP维度明细 (type=IP, segments: org+top) ==="
# measures: [sidUniq, ipUniq, uaUniq, uidUniq, apiUniq, appUniq, count, ipGeo, riskScoreTuple, reqSensScoreTuple, resSensScoreTuple]
# timeDimensions: [{AuditView.dt, dateRange: today}]
# order: {AuditView.count: desc}
# filters: [{member: AuditView.type, operator: equals, values: [IP]}]
# dimensions: [type, content, nameGroup, department]
# segments: [AuditView.org, AuditView.top]
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AuditView.sidUniq%22%2C%22AuditView.ipUniq%22%2C%22AuditView.uaUniq%22%2C%22AuditView.uidUniq%22%2C%22AuditView.apiUniq%22%2C%22AuditView.appUniq%22%2C%22AuditView.count%22%2C%22AuditView.ipGeo%22%2C%22AuditView.riskScoreTuple%22%2C%22AuditView.reqSensScoreTuple%22%2C%22AuditView.resSensScoreTuple%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AuditView.dt%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22order%22%3A%7B%22AuditView.count%22%3A%22desc%22%7D%2C%22filters%22%3A%5B%7B%22member%22%3A%22AuditView.type%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22IP%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22AuditView.type%22%2C%22AuditView.content%22%2C%22AuditView.nameGroup%22%2C%22AuditView.department%22%5D%2C%22offset%22%3A0%2C%22segments%22%3A%5B%22AuditView.org%22%2C%22AuditView.top%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "IP dimension detail (type=IP, with measures + nameGroup + department)" "$result"

echo ""
echo "=== 2. Device维度明细 (type=Device, segments: org+top) ==="
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
echo "=== 6. AuditView: lastTs measure (max last_ts by type, order lastTs desc, limit 5) ==="
# Tests measure: lastTs (max(last_ts) time measure)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AuditView.lastTs%22%2C%22AuditView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AuditView.dt%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AuditView.type%22%5D%2C%22order%22%3A%7B%22AuditView.lastTs%22%3A%22desc%22%7D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AuditView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "AuditView: lastTs+count by type order lastTs desc limit 5" "$result"

echo ""
echo "=== 7. AuditView: channel+ipGeoCountry+ipGeoProvince+deviceType (count, today) ==="
# Exercises all 4 gap dimensions in a single query
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AuditView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AuditView.dt%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AuditView.channel%22%2C%22AuditView.ipGeoCountry%22%2C%22AuditView.ipGeoProvince%22%2C%22AuditView.deviceType%22%5D%2C%22order%22%3A%7B%22AuditView.count%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22AuditView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "AuditView: count by channel+ipGeoCountry+ipGeoProvince+deviceType limit 10" "$result"

echo ""
echo "========================================"
echo "=== AuditView: map aggregation (4 independent queries) ==="
echo "========================================"

encode_query() {
    jq -r '@uri' <<< "$1"
}

echo ""
echo "=== 8. 国家IP统计 (dimension: ipGeoCountry, type=IP) ==="
q=$(jq -c -n '{
  measures: ["AuditView.count"],
  dimensions: ["AuditView.ipGeoCountry"],
  timeDimensions: [{"dimension": "AuditView.dt", "dateRange": "today"}],
  filters: [{"member": "AuditView.type", "operator": "equals", "values": ["IP"]}],
  segments: ["AuditView.org"],
  timezone: "Asia/Shanghai"
}')
result=$(curl -s "$BASE/load?queryType=multi&query=$(encode_query "$q")")
check "国家IP统计 (ipGeoCountry, type=IP)" "$result"

echo ""
echo "=== 9. 省份IP统计 (dimension: ipGeoProvince, type=IP, country=中国) ==="
q=$(jq -c -n '{
  measures: ["AuditView.count"],
  dimensions: ["AuditView.ipGeoProvince"],
  timeDimensions: [{"dimension": "AuditView.dt", "dateRange": "today"}],
  filters: [
    {"member": "AuditView.type", "operator": "equals", "values": ["IP"]},
    {"member": "AuditView.ipGeoCountry", "operator": "equals", "values": ["中国"]}
  ],
  segments: ["AuditView.org"],
  timezone: "Asia/Shanghai"
}')
result=$(curl -s "$BASE/load?queryType=multi&query=$(encode_query "$q")")
check "省份IP统计 (ipGeoProvince, type=IP, country=中国)" "$result"

echo ""
echo "=== 10. 部门用户统计 (dimension: department, type=User, segment: hasValidDepartment) ==="
q=$(jq -c -n '{
  measures: ["AuditView.count"],
  dimensions: ["AuditView.department"],
  timeDimensions: [{"dimension": "AuditView.dt", "dateRange": "today"}],
  filters: [{"member": "AuditView.type", "operator": "equals", "values": ["User"]}],
  segments: ["AuditView.org", "AuditView.hasValidDepartment"],
  timezone: "Asia/Shanghai"
}')
result=$(curl -s "$BASE/load?queryType=multi&query=$(encode_query "$q")")
check "部门用户统计 (department, type=User, hasValidDepartment)" "$result"

echo ""
echo "=== 11. 设备类型统计 (dimension: deviceType, type=Device) ==="
q=$(jq -c -n '{
  measures: ["AuditView.count"],
  dimensions: ["AuditView.deviceType"],
  timeDimensions: [{"dimension": "AuditView.dt", "dateRange": "today"}],
  filters: [{"member": "AuditView.type", "operator": "equals", "values": ["Device"]}],
  segments: ["AuditView.org"],
  timezone: "Asia/Shanghai"
}')
result=$(curl -s "$BASE/load?queryType=multi&query=$(encode_query "$q")")
check "设备类型统计 (deviceType, type=Device)" "$result"

echo ""
echo "========================================"
echo "Results: $pass passed, $fail failed"
echo "========================================"

stop_server

if [ $fail -gt 0 ]; then
    exit 1
fi
