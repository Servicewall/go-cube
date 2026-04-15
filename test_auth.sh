#!/bin/bash
# Test UserAuthView and ApiParamView queries against local go-cube server
# Mirrors production curl requests from demo.servicewall.cn

source "$(dirname "$0")/common.sh"

CHECK_TOP_LEVEL_ERROR=1
setup_server_trap
start_server 2
test_health

echo ""
echo "========================================"
echo "=== UserAuthView queries ==="
echo "========================================"

echo ""
echo "=== 1. count+piiCount+loginId+loginTs+loginKey+loginReqInfo+loginResInfo by method+url+appName+loginTokenKey ==="
# measures: count, piiCount, loginId, loginTs, loginKey, loginReqInfo, loginResInfo
# dimensions: method, url, appName, loginTokenKey
# order: piiCount desc, count desc
# segments: org, confFilter
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22UserAuthView.count%22%2C%22UserAuthView.piiCount%22%2C%22UserAuthView.loginId%22%2C%22UserAuthView.loginTs%22%2C%22UserAuthView.loginKey%22%2C%22UserAuthView.loginReqInfo%22%2C%22UserAuthView.loginResInfo%22%5D%2C%22order%22%3A%7B%22UserAuthView.piiCount%22%3A%22desc%22%2C%22UserAuthView.count%22%3A%22desc%22%7D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22UserAuthView.method%22%2C%22UserAuthView.url%22%2C%22UserAuthView.appName%22%2C%22UserAuthView.loginTokenKey%22%5D%2C%22segments%22%3A%5B%22UserAuthView.org%22%2C%22UserAuthView.confFilter%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "UserAuthView: count+piiCount+loginId+loginTs+loginKey+loginReqInfo+loginResInfo by method+url+appName+loginTokenKey" "$result"

echo ""
echo "========================================"
echo "=== ApiParamView queries ==="
echo "========================================"

echo ""
echo "=== 2. ApiParamView key+path+rank limit 10 ==="
# dimensions: key, path, rank
# no measures, no timeDimensions, no filters
# limit: 10, segments: org
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ApiParamView.key%22%2C%22ApiParamView.path%22%2C%22ApiParamView.rank%22%5D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22ApiParamView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ApiParamView: key+path+rank limit 10" "$result"

echo ""
echo "========================================"
echo "=== UserAuthView: gap-fill tests ==="
echo "========================================"

echo ""
echo "=== 3. UserAuthView: basInfo+authInfo+apiNum measures by host+url+method ==="
# Tests measures: basInfo, authInfo, apiNum
# dimensions: host, url, method
# segments: org, confFilter
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22UserAuthView.basInfo%22%2C%22UserAuthView.authInfo%22%2C%22UserAuthView.apiNum%22%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22UserAuthView.host%22%2C%22UserAuthView.url%22%2C%22UserAuthView.method%22%5D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22UserAuthView.org%22%2C%22UserAuthView.confFilter%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "UserAuthView: basInfo+authInfo+apiNum by host+url+method" "$result"

echo ""
echo "=== 4. UserAuthView: aggAuthKey measure by host+url+method ==="
# Tests measure: aggAuthKey (groupUniqArray)
# dimensions: host, url, method
# segments: org, confFilter
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22UserAuthView.aggAuthKey%22%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22UserAuthView.host%22%2C%22UserAuthView.url%22%2C%22UserAuthView.method%22%5D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22UserAuthView.org%22%2C%22UserAuthView.confFilter%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "UserAuthView: aggAuthKey by host+url+method" "$result"

echo ""
echo "=== 5. UserAuthView: authKey+authApp dimensions with count ==="
# Tests dimensions: authKey (arrayJoin expr), authApp (dict-lookup)
# measure: count
# segments: org, confFilter
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22UserAuthView.count%22%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22UserAuthView.authKey%22%2C%22UserAuthView.authApp%22%5D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22UserAuthView.org%22%2C%22UserAuthView.confFilter%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "UserAuthView: count by authKey+authApp" "$result"

echo ""
echo "=== 6. UserAuthView: lastTs time dimension (order by lastTs desc) ==="
# Tests dimension: lastTs (time type) — included in GROUP BY dimensions
# measures: count, piiCount
# order: lastTs desc
# segments: org, confFilter
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22UserAuthView.count%22%2C%22UserAuthView.piiCount%22%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22UserAuthView.host%22%2C%22UserAuthView.url%22%2C%22UserAuthView.method%22%2C%22UserAuthView.lastTs%22%5D%2C%22order%22%3A%7B%22UserAuthView.lastTs%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22UserAuthView.org%22%2C%22UserAuthView.confFilter%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "UserAuthView: count+piiCount by host+url+method+lastTs order lastTs desc" "$result"

echo ""
echo "=== 7. UserAuthView: full dimension set — host+url+method+appName+loginTokenKey+lastTs+authKey+authApp ==="
# Tests all 8 UserAuthView dimensions together with count
# Uses lastTs as both timeDimension and grouped dimension
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22UserAuthView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22UserAuthView.lastTs%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22UserAuthView.host%22%2C%22UserAuthView.url%22%2C%22UserAuthView.method%22%2C%22UserAuthView.appName%22%2C%22UserAuthView.loginTokenKey%22%2C%22UserAuthView.authKey%22%2C%22UserAuthView.authApp%22%5D%2C%22order%22%3A%7B%22UserAuthView.count%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22UserAuthView.org%22%2C%22UserAuthView.confFilter%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "UserAuthView: count by all 7 dimensions" "$result"

echo ""
echo "--- $pass passed, $fail failed ---"

echo ""
echo "Stopping server..."
stop_server
echo "All tests completed."
