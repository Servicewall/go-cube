#!/bin/bash
# test_todo.sh — Placeholder tests for UNDEFINED models
#
# These models are referenced in curl requests from demo.servicewall.cn but
# have NOT been defined in the model/ directory yet.  Each test case is
# commented out and marked TODO so it is easy to enable once the model is
# added to model/.
#
# Models covered:
#   1. EventView
#   2. ApiRouteView
#   3. AuthorizationView
#   4. AiApiAnalysisView
#   5. WaapView

BASE="http://localhost:4000"
pass=0
fail=0
skip=0

check() {
    local desc="$1"
    local result="$2"
    if echo "$result" | jq -e '.error' > /dev/null 2>&1; then
        echo "[FAIL] $desc — server error: $(echo "$result" | jq -r '.error')"
        ((fail++))
    elif echo "$result" | jq -e '.results[0].data' > /dev/null 2>&1; then
        count=$(echo "$result" | jq '.results[0].data | length')
        echo "[PASS] $desc — $count rows"
        ((pass++))
    else
        echo "[FAIL] $desc"
        echo "$result" | jq . 2>/dev/null || echo "$result"
        ((fail++))
    fi
}

skip_test() {
    local desc="$1"
    echo "[SKIP] $desc — model not yet defined"
    ((skip++))
}

echo "Starting go-cube server in background..."
./go-cube > /tmp/go-cube.log 2>&1 &
SERVER_PID=$!
sleep 3

echo ""
echo "Testing health endpoint..."
curl -s "$BASE/health" | jq .

echo ""
echo "========================================"
echo "=== TODO: EventView (not yet defined) ==="
echo "========================================"
# EventView — risk event log
# Expected schema:
#   measures:  count, firstTs (min), lastTs (max)
#   dimensions: risk, desc, level, data, content
#   segments:   org, expired
#
# TODO: Create model/EventView.yaml, then enable these tests.

skip_test "EventView: count by risk+level (today)"
# result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22EventView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22EventView.lastTs%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22EventView.risk%22%2C%22EventView.level%22%5D%2C%22order%22%3A%7B%22EventView.count%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22EventView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
# check "EventView: count by risk+level limit 10 (today)" "$result"

skip_test "EventView: ungrouped risk+desc+level+data+content (limit 5)"
# result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22EventView.lastTs%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22EventView.risk%22%2C%22EventView.desc%22%2C%22EventView.level%22%2C%22EventView.data%22%2C%22EventView.content%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22EventView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
# check "EventView: ungrouped risk+desc+level+data+content limit 5" "$result"

skip_test "EventView: count (segment org+expired, today)"
# result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22EventView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22EventView.lastTs%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22EventView.org%22%2C%22EventView.expired%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
# check "EventView: count (segment expired, today)" "$result"

echo ""
echo "========================================"
echo "=== TODO: ApiRouteView (not yet defined) ==="
echo "========================================"
# ApiRouteView — URL route discovery/management
# Expected schema:
#   dimensions: host, method, urlRoute, count, sample, appName, urlRouteType
#   segments:   org, black
#
# TODO: Create model/ApiRouteView.yaml, then enable these tests.

skip_test "ApiRouteView: count by host+method+urlRoute (limit 10)"
# result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22ApiRouteView.count%22%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ApiRouteView.host%22%2C%22ApiRouteView.method%22%2C%22ApiRouteView.urlRoute%22%5D%2C%22order%22%3A%7B%22ApiRouteView.count%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22ApiRouteView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
# check "ApiRouteView: count by host+method+urlRoute limit 10" "$result"

skip_test "ApiRouteView: sample+appName+urlRouteType (ungrouped, limit 5)"
# result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22ApiRouteView.host%22%2C%22ApiRouteView.method%22%2C%22ApiRouteView.urlRoute%22%2C%22ApiRouteView.sample%22%2C%22ApiRouteView.appName%22%2C%22ApiRouteView.urlRouteType%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22ApiRouteView.org%22%2C%22ApiRouteView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
# check "ApiRouteView: ungrouped sample+appName+urlRouteType limit 5" "$result"

echo ""
echo "========================================"
echo "=== TODO: AuthorizationView (not yet defined) ==="
echo "========================================"
# AuthorizationView — API authorization/token analysis
# Expected schema:
#   measures:   tokenArray (groupUniqArray), tokenCount
#   dimensions: authKey, host, method, url, loginUrl, loginMethod, loginAuthKey, appName
#   segment:    org
#
# TODO: Create model/AuthorizationView.yaml, then enable these tests.

skip_test "AuthorizationView: tokenCount by authKey+host+method (limit 10)"
# result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AuthorizationView.tokenCount%22%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AuthorizationView.authKey%22%2C%22AuthorizationView.host%22%2C%22AuthorizationView.method%22%5D%2C%22order%22%3A%7B%22AuthorizationView.tokenCount%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22AuthorizationView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
# check "AuthorizationView: tokenCount by authKey+host+method limit 10" "$result"

skip_test "AuthorizationView: tokenArray+loginUrl+loginMethod+loginAuthKey+appName (ungrouped, limit 5)"
# result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AuthorizationView.host%22%2C%22AuthorizationView.method%22%2C%22AuthorizationView.url%22%2C%22AuthorizationView.loginUrl%22%2C%22AuthorizationView.loginMethod%22%2C%22AuthorizationView.loginAuthKey%22%2C%22AuthorizationView.appName%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AuthorizationView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
# check "AuthorizationView: ungrouped host+method+url+loginUrl+loginMethod+loginAuthKey+appName limit 5" "$result"

echo ""
echo "========================================"
echo "=== TODO: AiApiAnalysisView (not yet defined) ==="
echo "========================================"
# AiApiAnalysisView — AI-based API analysis results
# Expected schema:
#   measures:   lastBizAnalysis (argMax), lastParamAnalysis (argMax), lastRiskAnalysis (argMax)
#   dimensions: host, method, urlRoute (filter-only)
#   segment:    org
#
# TODO: Create model/AiApiAnalysisView.yaml, then enable these tests.

skip_test "AiApiAnalysisView: lastBizAnalysis+lastParamAnalysis+lastRiskAnalysis (filter host+method+urlRoute)"
# result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AiApiAnalysisView.lastBizAnalysis%22%2C%22AiApiAnalysisView.lastParamAnalysis%22%2C%22AiApiAnalysisView.lastRiskAnalysis%22%5D%2C%22timeDimensions%22%3A%5B%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22AiApiAnalysisView.host%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22127.0.0.1%22%5D%7D%2C%7B%22member%22%3A%22AiApiAnalysisView.method%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22POST%22%5D%7D%2C%7B%22member%22%3A%22AiApiAnalysisView.urlRoute%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22%2FapiAuth%22%5D%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AiApiAnalysisView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
# check "AiApiAnalysisView: lastBizAnalysis+lastParamAnalysis+lastRiskAnalysis" "$result"

echo ""
echo "========================================"
echo "=== TODO: WaapView (not yet defined) ==="
echo "========================================"
# WaapView — WAF/WAAP event log (real-time rule hits)
# Expected schema:
#   measure:    aggCount (count)
#   dimensions: lastId, lastTs, urlRoute, message, uid, sid, ip, status (row-level)
#               channel, url, method, type (groupable)
#   segments:   org, violations
#
# TODO: Create model/WaapView.yaml, then enable these tests.

skip_test "WaapView: aggCount by channel+url+method+type (today, limit 10)"
# result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22WaapView.aggCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22WaapView.lastTs%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22WaapView.channel%22%2C%22WaapView.url%22%2C%22WaapView.method%22%2C%22WaapView.type%22%5D%2C%22order%22%3A%7B%22WaapView.aggCount%22%3A%22desc%22%7D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22WaapView.org%22%2C%22WaapView.violations%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
# check "WaapView: aggCount by channel+url+method+type (today) limit 10" "$result"

skip_test "WaapView: ungrouped lastId+urlRoute+message+uid+sid+ip+status (limit 5)"
# result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22WaapView.lastTs%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22WaapView.lastId%22%2C%22WaapView.urlRoute%22%2C%22WaapView.message%22%2C%22WaapView.uid%22%2C%22WaapView.sid%22%2C%22WaapView.ip%22%2C%22WaapView.status%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22WaapView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
# check "WaapView: ungrouped lastId+urlRoute+message+uid+sid+ip+status limit 5" "$result"

echo ""
echo "========================================"
echo "Results: $pass passed, $fail failed, $skip skipped"
echo "========================================"

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null

[ $fail -gt 0 ] && exit 1
exit 0
