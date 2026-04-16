#!/bin/bash
source "$(dirname "$0")/common.sh"

setup_server_trap
start_server 3 "/tmp/go-cube-event.log" "Starting go-cube server..."
test_health

echo "========================================"
echo "EventView Tests"
echo "========================================"

echo ""
echo "=== EventView 告警聚合列表 ==="
#{"measures":["EventView.count","EventView.firstTs","EventView.lastTs"],"timeDimensions":[{"dimension":"EventView.ts","dateRange":"from 15 minutes ago to 15 minutes from now"}],"order":[["EventView.lastTs","desc"],["EventView.firstTs","desc"]],"filters":[],"dimensions":["EventView.risk","EventView.desc","EventView.level","EventView.data","EventView.content"],"segments":["EventView.org","EventView.expired"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22EventView.count%22%2C%22EventView.firstTs%22%2C%22EventView.lastTs%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22EventView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22order%22%3A%5B%5B%22EventView.lastTs%22%2C%22desc%22%5D%2C%5B%22EventView.firstTs%22%2C%22desc%22%5D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22EventView.risk%22%2C%22EventView.desc%22%2C%22EventView.level%22%2C%22EventView.data%22%2C%22EventView.content%22%5D%2C%22segments%22%3A%5B%22EventView.org%22%2C%22EventView.expired%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "EventView 告警聚合列表" "$result"

echo "========================================"
echo "Results: $pass passed, $fail failed"
echo "========================================"

if [ $fail -gt 0 ]; then
    echo ""
    echo "=== Server log (last 50 lines) ==="
    tail -50 /tmp/go-cube-event.log
fi

echo ""
echo "All tests completed."
[ $fail -gt 0 ] && exit 1
exit 0
