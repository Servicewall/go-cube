#!/bin/bash
source "$(dirname "$0")/common.sh"

setup_server_trap
start_server 3 "/tmp/go-cube.log"
test_health

echo ""
echo "=== ApiDayView 今日新增风险TOP5 ==="
#{"measures":["ApiDayView.newRiskToday","ApiDayView.highRiskRatioToday"],"timeDimensions":[{"dimension":"ApiDayView.dt","dateRange":["2026-04-06 00:00:00","2026-04-07 23:59:59"]}],"filters":[],"dimensions":[],"segments":["ApiDayView.org","ApiDayView.black"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22ApiDayView.newRiskToday%22%2C%22ApiDayView.highRiskRatioToday%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiDayView.dt%22%2C%22dateRange%22%3A%5B%222026-04-06%2000%3A00%3A00%22%2C%222026-04-07%2023%3A59%3A59%22%5D%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22ApiDayView.org%22%2C%22ApiDayView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiDayView 今日新增风险TOP5" "$result"

echo ""
echo "=== ApiDayView 涉敏API TOP1000 ==="
#{"measures":["ApiDayView.reqSensTuple","ApiDayView.resSensTuple","ApiDayView.sensValUniq"],"timeDimensions":[{"dimension":"ApiDayView.dt","dateRange":"from 7 days ago to now"}],"order":[["ApiDayView.sensValUniq","desc"]],"filters":[{"member":"ApiDayView.hasSens","operator":"gt","values":["0"]}],"dimensions":["ApiDayView.host","ApiDayView.method","ApiDayView.urlRoute"],"limit":1000,"segments":["ApiDayView.org","ApiDayView.black"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22ApiDayView.reqSensTuple%22%2C%22ApiDayView.resSensTuple%22%2C%22ApiDayView.sensValUniq%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiDayView.dt%22%2C%22dateRange%22%3A%22from%207%20days%20ago%20to%20now%22%7D%5D%2C%22order%22%3A%5B%5B%22ApiDayView.sensValUniq%22%2C%22desc%22%5D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiDayView.hasSens%22%2C%22operator%22%3A%22gt%22%2C%22values%22%3A%5B%220%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22ApiDayView.host%22%2C%22ApiDayView.method%22%2C%22ApiDayView.urlRoute%22%5D%2C%22limit%22%3A1000%2C%22segments%22%3A%5B%22ApiDayView.org%22%2C%22ApiDayView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiDayView 涉敏API TOP1000" "$result"

echo ""
echo "=== ApiDayView 请求涉敏TOP5 ==="
#{"measures":["ApiDayView.reqSensValUniq"],"timeDimensions":[{"dimension":"ApiDayView.dt","dateRange":"from 7 days ago to now"}],"order":[["ApiDayView.reqSensValUniq","desc"]],"filters":[],"dimensions":["ApiDayView.urlRoute"],"limit":5,"segments":["ApiDayView.org","ApiDayView.black"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22ApiDayView.reqSensValUniq%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiDayView.dt%22%2C%22dateRange%22%3A%22from%207%20days%20ago%20to%20now%22%7D%5D%2C%22order%22%3A%5B%5B%22ApiDayView.reqSensValUniq%22%2C%22desc%22%5D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ApiDayView.urlRoute%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22ApiDayView.org%22%2C%22ApiDayView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiDayView 请求涉敏TOP5" "$result"

echo ""
echo "=== ApiDayView 响应涉敏TOP5 ==="
#{"measures":["ApiDayView.resSensValUniq"],"timeDimensions":[{"dimension":"ApiDayView.dt","dateRange":"from 7 days ago to now"}],"order":[["ApiDayView.resSensValUniq","desc"]],"filters":[],"dimensions":["ApiDayView.urlRoute"],"limit":5,"segments":["ApiDayView.org","ApiDayView.black"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22ApiDayView.resSensValUniq%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiDayView.dt%22%2C%22dateRange%22%3A%22from%207%20days%20ago%20to%20now%22%7D%5D%2C%22order%22%3A%5B%5B%22ApiDayView.resSensValUniq%22%2C%22desc%22%5D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ApiDayView.urlRoute%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22ApiDayView.org%22%2C%22ApiDayView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiDayView 响应涉敏TOP5" "$result"

echo ""
echo "=== ApiDayView 服务器列表 ==="
#{"measures":["ApiDayView.upstreamTop5Port","ApiDayView.upstreamPortUniq","ApiDayView.upstreamTop3App","ApiDayView.appCount","ApiDayView.upstreamTop3Host","ApiDayView.hostCount","ApiDayView.upstreamNodeCount","ApiDayView.count"],"timeDimensions":[{"dimension":"ApiDayView.dt","dateRange":"from 7 days ago to now"}],"order":[["ApiDayView.count","desc"]],"filters":[{"member":"ApiDayView.upstreamNode","operator":"notEquals","values":["127.0.0.1"]}],"dimensions":["ApiDayView.upstreamNodeIP"],"segments":["ApiDayView.org","ApiDayView.black"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22ApiDayView.upstreamTop5Port%22%2C%22ApiDayView.upstreamPortUniq%22%2C%22ApiDayView.upstreamTop3App%22%2C%22ApiDayView.appCount%22%2C%22ApiDayView.upstreamTop3Host%22%2C%22ApiDayView.hostCount%22%2C%22ApiDayView.upstreamNodeCount%22%2C%22ApiDayView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiDayView.dt%22%2C%22dateRange%22%3A%22from%207%20days%20ago%20to%20now%22%7D%5D%2C%22order%22%3A%5B%5B%22ApiDayView.count%22%2C%22desc%22%5D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ApiDayView.upstreamNode%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22127.0.0.1%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22ApiDayView.upstreamNodeIP%22%5D%2C%22segments%22%3A%5B%22ApiDayView.org%22%2C%22ApiDayView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiDayView 服务器列表统计" "$result"

echo ""
echo "=== ApiDayView RiskCount分布 ==="
#{"measures":["ApiDayView.riskCount"],"timeDimensions":[{"dimension":"ApiDayView.dt","dateRange":"from 7 days ago to now"}],"filters":[],"dimensions":["ApiDayView.risk"],"limit":50000,"segments":["ApiDayView.org","ApiDayView.black"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22ApiDayView.riskCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiDayView.dt%22%2C%22dateRange%22%3A%22from%207%20days%20ago%20to%20now%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ApiDayView.risk%22%5D%2C%22limit%22%3A50000%2C%22segments%22%3A%5B%22ApiDayView.org%22%2C%22ApiDayView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiDayView RiskCount分布" "$result"

echo ""
echo "=== ApiDayView 请求涉敏分布 ==="
#{"measures":["ApiDayView.reqSensCount"],"timeDimensions":[{"dimension":"ApiDayView.dt","dateRange":"from 7 days ago to now"}],"filters":[],"dimensions":["ApiDayView.reqSens"],"limit":50000,"segments":["ApiDayView.org","ApiDayView.black"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22ApiDayView.reqSensCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ApiDayView.dt%22%2C%22dateRange%22%3A%22from%207%20days%20ago%20to%20now%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ApiDayView.reqSens%22%5D%2C%22limit%22%3A50000%2C%22segments%22%3A%5B%22ApiDayView.org%22%2C%22ApiDayView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "ApiDayView 请求涉敏分布" "$result"

echo "========================================"
echo "Results: $pass passed, $fail failed"
echo "========================================"

if [ $fail -gt 0 ]; then
    echo ""
    echo "=== Server log (last 50 lines) ==="
    tail -50 /tmp/go-cube.log
fi

echo ""
echo "All tests completed."
[ $fail -gt 0 ] && exit 1
exit 0
