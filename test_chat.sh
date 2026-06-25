#!/bin/bash
# Test ChatView queries against local go-cube server
# Mirrors production curl requests from demo.servicewall.cn

source "$(dirname "$0")/common.sh"

CHECK_NESTED_ERROR=1
setup_server_trap
start_server 2
test_health

echo ""
echo "========================================"
echo "=== ChatView aggregate queries ==="
echo "========================================"

echo ""
echo "=== 1. count by channel with time granularity (minute) ==="
# measures: [ChatView.count], timeDimensions: [{ChatView.ts, from 1 month ago, granularity: minute}]
# dimensions: [ChatView.channel], segments: org
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ChatView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ChatView.ts%22%2C%22dateRange%22%3A%22from+1+month+ago+to+now%22%2C%22granularity%22%3A%22minute%22%7D%5D%2C%22order%22%3A%7B%22ChatView.count%22%3A%22desc%22%7D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ChatView.channel%22%5D%2C%22segments%22%3A%5B%22ChatView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
echo "Raw: $result"
check "count by channel (granularity=minute)" "$result"

echo ""
echo "=== 2. sumTokens+avgTokens+countUid summary stats (no dimensions, 1 month) ==="
# measures: [sumTokens, avgTokens, countUid], no dimensions
# segments: org
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ChatView.sumTokens%22%2C%22ChatView.avgTokens%22%2C%22ChatView.countUid%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ChatView.ts%22%2C%22dateRange%22%3A%22from+1+month+ago+to+now%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22ChatView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
echo "Raw: $result"
check "sumTokens+avgTokens+countUid summary (no dims, 1 month)" "$result"

echo ""
echo "=== 3. count by modelName+modelUser, limit 20 ==="
# measures: [count], dimensions: [modelName, modelUser]
# limit: 20, segments: org
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ChatView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ChatView.ts%22%2C%22dateRange%22%3A%22from+1+month+ago+to+now%22%7D%5D%2C%22order%22%3A%7B%22ChatView.count%22%3A%22desc%22%7D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ChatView.modelName%22%2C%22ChatView.modelUser%22%5D%2C%22limit%22%3A20%2C%22segments%22%3A%5B%22ChatView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
echo "Raw: $result"
check "count by modelName+modelUser limit 20" "$result"

echo ""
echo "=== 4. count by resultLevel (risk level distribution) ==="
# measures: [count], dimensions: [resultLevel]
# segments: org
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ChatView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ChatView.ts%22%2C%22dateRange%22%3A%22from+1+month+ago+to+now%22%7D%5D%2C%22order%22%3A%7B%22ChatView.count%22%3A%22desc%22%7D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ChatView.resultLevel%22%5D%2C%22segments%22%3A%5B%22ChatView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
echo "Raw: $result"
check "count by resultLevel (risk distribution)" "$result"

echo ""
echo "=== 5. count by resultScore range (filter resultScore > 0) ==="
# measures: [count], filter: resultScore > 0
# segments: org
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ChatView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ChatView.ts%22%2C%22dateRange%22%3A%22from+1+month+ago+to+now%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ChatView.resultScore%22%2C%22operator%22%3A%22gt%22%2C%22values%22%3A%5B%220%22%5D%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22ChatView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
echo "Raw: $result"
check "count where resultScore > 0" "$result"

echo ""
echo "=== 6. ungrouped: id+ts+ip+uid+channel+modelName (limit 5) ==="
# Tests basic dimensions in ungrouped mode
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ChatView.ts%22%2C%22dateRange%22%3A%22from+1+month+ago+to+now%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ChatView.id%22%2C%22ChatView.ts%22%2C%22ChatView.ip%22%2C%22ChatView.uid%22%2C%22ChatView.channel%22%2C%22ChatView.modelName%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22ChatView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
echo "Raw: $result"
check "ungrouped id+ts+ip+uid+channel+modelName limit 5" "$result"

echo ""
echo "=== 7. ungrouped: prompt+answer+risk+reqAction+reqReason (limit 3) ==="
# Tests text fields — potentially large payloads
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ChatView.ts%22%2C%22dateRange%22%3A%22from+1+month+ago+to+now%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ChatView.prompt%22%2C%22ChatView.answer%22%2C%22ChatView.risk%22%2C%22ChatView.reqAction%22%2C%22ChatView.reqReason%22%5D%2C%22limit%22%3A3%2C%22segments%22%3A%5B%22ChatView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
echo "Raw: $result"
check "ungrouped prompt+answer+risk+reqAction+reqReason limit 3" "$result"

echo ""
echo "=== 8. ungrouped: promptTokens+completionTokens+totalTokens+maxTokens+temperature+stream (limit 5) ==="
# Tests token usage and model config fields
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ChatView.ts%22%2C%22dateRange%22%3A%22from+1+month+ago+to+now%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ChatView.promptTokens%22%2C%22ChatView.completionTokens%22%2C%22ChatView.totalTokens%22%2C%22ChatView.maxTokens%22%2C%22ChatView.temperature%22%2C%22ChatView.stream%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22ChatView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
echo "Raw: $result"
check "ungrouped promptTokens+completionTokens+totalTokens+maxTokens+temperature+stream limit 5" "$result"

echo ""
echo "=== 9. ungrouped: reqSensKeyNum+resSensKeyNum+reqSampleKey+respSampleKey (limit 5) ==="
# Tests sensitive data count and sample key fields
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ChatView.ts%22%2C%22dateRange%22%3A%22from+1+month+ago+to+now%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ChatView.reqSensKeyNum%22%2C%22ChatView.resSensKeyNum%22%2C%22ChatView.reqSampleKey%22%2C%22ChatView.respSampleKey%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22ChatView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
echo "Raw: $result"
check "ungrouped reqSensKeyNum+resSensKeyNum+reqSampleKey+respSampleKey limit 5" "$result"

echo ""
echo "=== 10. ungrouped: reqSampleValue+respSampleValue (masked, limit 3) ==="
# Tests masked sensitive value samples
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ChatView.ts%22%2C%22dateRange%22%3A%22from+1+month+ago+to+now%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ChatView.reqSampleValue%22%2C%22ChatView.respSampleValue%22%5D%2C%22limit%22%3A3%2C%22segments%22%3A%5B%22ChatView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
echo "Raw: $result"
check "ungrouped reqSampleValue+respSampleValue (masked) limit 3" "$result"

echo ""
echo "=== 11. count by appName (dict-lookup dimension) ==="
# Tests appName dimension (complex dict expression)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ChatView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ChatView.ts%22%2C%22dateRange%22%3A%22from+1+month+ago+to+now%22%7D%5D%2C%22order%22%3A%7B%22ChatView.count%22%3A%22desc%22%7D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ChatView.appName%22%5D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22ChatView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
echo "Raw: $result"
check "count by appName limit 10" "$result"

echo ""
echo "=== 12. count by uid (top users) ==="
# measures: [count], dimensions: [uid]
# limit: 20, segments: org
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ChatView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ChatView.ts%22%2C%22dateRange%22%3A%22from+1+month+ago+to+now%22%7D%5D%2C%22order%22%3A%7B%22ChatView.count%22%3A%22desc%22%7D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ChatView.uid%22%5D%2C%22limit%22%3A20%2C%22segments%22%3A%5B%22ChatView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
echo "Raw: $result"
check "count by uid (top users) limit 20" "$result"

echo ""
echo "=== 13. count + resultLevel + resultScore by channel (grouped risk analysis) ==="
# measures: [count], dimensions: [channel, resultLevel, resultScore]
# segments: org, limit: 20
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ChatView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ChatView.ts%22%2C%22dateRange%22%3A%22from+1+month+ago+to+now%22%7D%5D%2C%22order%22%3A%7B%22ChatView.count%22%3A%22desc%22%7D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ChatView.channel%22%2C%22ChatView.resultLevel%22%2C%22ChatView.resultScore%22%5D%2C%22limit%22%3A20%2C%22segments%22%3A%5B%22ChatView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
echo "Raw: $result"
check "count+resultLevel+resultScore by channel limit 20" "$result"

echo ""
echo "=== 14. count filtered by channel (filter operator) ==="
# measures: [count], filter: channel equals specific value
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ChatView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ChatView.ts%22%2C%22dateRange%22%3A%22from+1+month+ago+to+now%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22ChatView.channel%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22test%22%5D%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22ChatView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
echo "Raw: $result"
check "count where channel equals 'test'" "$result"

echo ""
echo "=== 15. count + sumTokens by modelName (granularity=hour) ==="
# measures: [count, sumTokens], granularity: hour
# dimensions: [modelName], segments: org
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ChatView.count%22%2C%22ChatView.sumTokens%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ChatView.ts%22%2C%22dateRange%22%3A%22from+1+month+ago+to+now%22%2C%22granularity%22%3A%22hour%22%7D%5D%2C%22order%22%3A%7B%22ChatView.count%22%3A%22desc%22%7D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ChatView.modelName%22%5D%2C%22segments%22%3A%5B%22ChatView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
echo "Raw: $result"
check "count+sumTokens by modelName (granularity=hour)" "$result"

echo ""
echo "=== 16. avgTokens by channel (sorted by avgTokens desc) ==="
# measures: [avgTokens], dimensions: [channel]
# order: avgTokens desc, segments: org
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ChatView.avgTokens%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22ChatView.ts%22%2C%22dateRange%22%3A%22from+1+month+ago+to+now%22%7D%5D%2C%22order%22%3A%7B%22ChatView.avgTokens%22%3A%22desc%22%7D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ChatView.channel%22%5D%2C%22segments%22%3A%5B%22ChatView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
echo "Raw: $result"
check "avgTokens by channel (order by avgTokens desc)" "$result"

echo ""
echo "--- $pass passed, $fail failed ---"

echo ""
echo "Stopping server..."
stop_server
echo "All tests completed."
[ $fail -gt 0 ] && exit 1
exit 0
