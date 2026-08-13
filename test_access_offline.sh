#!/bin/bash
# Test AccessView offline tracing (Search-Target: offline) against local go-cube server
# Verifies table switching to access_offline_local and taskId dimension/filter behavior.

source "$(dirname "$0")/common.sh"

CHECK_TOP_LEVEL_ERROR=1
setup_server_trap
start_server 2
test_health

echo ""
echo "========================================"
echo "=== AccessView offline tracing ==="
echo "========================================"

echo ""
echo "=== 1. offline: ungrouped id+taskId+ts (verify table=access_offline_local, taskId=task_id) ==="
# Search-Target: offline → FROM access_offline_local, taskId returns real task_id
result=$(curl -s -H "Search-Target: offline" "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22from+60+minutes+ago+to+60+minutes+from+now%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.id%22%2C%22AccessView.taskId%22%2C%22AccessView.ts%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "offline: ungrouped id+taskId+ts limit 5" "$result"

echo ""
echo "=== 2. offline: filter taskId=2 (verify task_id IN filter in WHERE) ==="
# Search-Target: offline + filter on taskId → WHERE task_id IN (?)
result=$(curl -s -H "Search-Target: offline" -H "Content-Type: application/json" \
  -d '{"ungrouped":true,"measures":[],"timeDimensions":[{"dimension":"AccessView.ts","dateRange":"from 60 minutes ago to 60 minutes from now"}],"filters":[{"member":"AccessView.taskId","operator":"equals","values":["2"]}],"dimensions":["AccessView.id","AccessView.taskId","AccessView.ts"],"limit":5,"segments":["AccessView.org"],"timezone":"Asia/Shanghai"}' \
  "$BASE/load")
check "offline: filter taskId=2, ungrouped id+taskId+ts limit 5" "$result"

echo ""
echo "=== 3. offline: count by taskId (grouped aggregation on task_id) ==="
# Search-Target: offline, grouped count by taskId
result=$(curl -s -H "Search-Target: offline" "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22from+60+minutes+ago+to+60+minutes+from+now%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.taskId%22%5D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "offline: count by taskId limit 10" "$result"

echo ""
echo "=== 4. non-offline: ungrouped id+ts (verify table=access, no offline table) ==="
# No Search-Target header → FROM access (not access_offline_local)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22from+60+minutes+ago+to+60+minutes+from+now%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.id%22%2C%22AccessView.ts%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "non-offline: ungrouped id+ts limit 5 (table=access)" "$result"

echo ""
echo "=== 5. offline: full detail query (mirrors production offline tracing page) ==="
# Search-Target: offline, ungrouped, many dimensions, filter taskId=2, limit 50000
result=$(curl -s -H "Search-Target: offline" -H "Content-Type: application/json" \
  -d '{"ungrouped":true,"measures":[],"timeDimensions":[{"dimension":"AccessView.ts"}],"order":[["AccessView.ts","desc"]],"filters":[{"member":"AccessView.taskId","operator":"equals","values":["2"]}],"dimensions":["AccessView.id","AccessView.ts","AccessView.sid","AccessView.uid","AccessView.ip","AccessView.ipGeoCity","AccessView.ipGeoProvince","AccessView.ipGeoCountry","AccessView.resultRisk","AccessView.reqAction","AccessView.reqReason","AccessView.reqContentLength","AccessView.responseRisk","AccessView.responseAction","AccessView.responseReason","AccessView.respContentLength","AccessView.resultType","AccessView.resultAction","AccessView.resultScore","AccessView.result","AccessView.reason","AccessView.assetName","AccessView.channel","AccessView.host","AccessView.method","AccessView.url","AccessView.urlRoute","AccessView.status","AccessView.ua","AccessView.uaName","AccessView.uaOs","AccessView.customAppName","AccessView.deviceFingerprint","AccessView.topoNetwork","AccessView.netDomainName","AccessView.dstNode","AccessView.protocol","AccessView.nodeIp","AccessView.nodeName","AccessView.reqSensKeyNum","AccessView.resSensKeyNum","AccessView.sensScore","AccessView.request","AccessView.response","AccessView.taskId"],"limit":50000,"segments":["AccessView.org","AccessView.black"],"timezone":"Asia/Shanghai"}' \
  "$BASE/load")
check "offline: full detail query with taskId filter (production mirror)" "$result"

echo ""
echo "========================================"
echo "Results: $pass passed, $fail failed"
echo "========================================"
exit $fail
