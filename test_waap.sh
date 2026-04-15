#!/bin/bash
source "$(dirname "$0")/common.sh"

setup_server_trap
start_server 3 "/tmp/go-cube-waap.log" "Starting go-cube server..."
test_health

echo "========================================"
echo "WaapView Tests"
echo "========================================"

echo ""
echo "=== WaapView 聚合违规数 ==="
#{"measures":["WaapView.aggCount"],"timeDimensions":[{"dimension":"WaapView.ts","dateRange":"from 15 minutes ago to 15 minutes from now"}],"filters":[],"dimensions":[],"segments":["WaapView.org","WaapView.violations"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22WaapView.aggCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22WaapView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22WaapView.org%22%2C%22WaapView.violations%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "WaapView 聚合违规数" "$result"

echo ""
echo "=== WaapView 违规明细列表 ==="
#{"measures":["WaapView.lastId","WaapView.lastTs","WaapView.urlRoute","WaapView.message","WaapView.uid","WaapView.sid","WaapView.ip","WaapView.status"],"timeDimensions":[{"dimension":"WaapView.ts","dateRange":"from 15 minutes ago to 15 minutes from now"}],"order":[["WaapView.lastTs","desc"]],"filters":[],"dimensions":["WaapView.channel","WaapView.url","WaapView.method","WaapView.type"],"limit":20,"offset":0,"segments":["WaapView.org","WaapView.violations"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22WaapView.lastId%22%2C%22WaapView.lastTs%22%2C%22WaapView.urlRoute%22%2C%22WaapView.message%22%2C%22WaapView.uid%22%2C%22WaapView.sid%22%2C%22WaapView.ip%22%2C%22WaapView.status%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22WaapView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22order%22%3A%5B%5B%22WaapView.lastTs%22%2C%22desc%22%5D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22WaapView.channel%22%2C%22WaapView.url%22%2C%22WaapView.method%22%2C%22WaapView.type%22%5D%2C%22limit%22%3A20%2C%22offset%22%3A0%2C%22segments%22%3A%5B%22WaapView.org%22%2C%22WaapView.violations%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "WaapView 违规明细列表" "$result"

echo ""
echo "=== WaapView 请求违规明细(带filter) ==="
#{"measures":["WaapView.lastId","WaapView.lastTs","WaapView.urlRoute","WaapView.message","WaapView.uid","WaapView.sid","WaapView.ip","WaapView.status"],"timeDimensions":[{"dimension":"WaapView.ts","dateRange":"from 15 minutes ago to 15 minutes from now"}],"order":[["WaapView.lastTs","desc"]],"filters":[{"member":"WaapView.type","operator":"equals","values":["请求违规"]}],"dimensions":["WaapView.channel","WaapView.url","WaapView.method","WaapView.type"],"limit":20,"offset":0,"segments":["WaapView.org","WaapView.violations"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22WaapView.lastId%22%2C%22WaapView.lastTs%22%2C%22WaapView.urlRoute%22%2C%22WaapView.message%22%2C%22WaapView.uid%22%2C%22WaapView.sid%22%2C%22WaapView.ip%22%2C%22WaapView.status%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22WaapView.ts%22%2C%22dateRange%22%3A%22from+15+minutes+ago+to+15+minutes+from+now%22%7D%5D%2C%22order%22%3A%5B%5B%22WaapView.lastTs%22%2C%22desc%22%5D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22WaapView.type%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22%E8%AF%B7%E6%B1%82%E8%BF%9D%E8%A7%84%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22WaapView.channel%22%2C%22WaapView.url%22%2C%22WaapView.method%22%2C%22WaapView.type%22%5D%2C%22limit%22%3A20%2C%22offset%22%3A0%2C%22segments%22%3A%5B%22WaapView.org%22%2C%22WaapView.violations%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "WaapView 请求违规明细(带filter)" "$result"

echo "========================================"
echo "Results: $pass passed, $fail failed"
echo "========================================"

if [ $fail -gt 0 ]; then
    echo ""
    echo "=== Server log (last 50 lines) ==="
    tail -50 /tmp/go-cube-waap.log
fi

echo ""
echo "All tests completed."
[ $fail -gt 0 ] && exit 1
exit 0
