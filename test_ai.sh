#!/bin/bash
# Test AiApiAnalysisView and AiSensRecommendView queries against local go-cube server
# Mirrors production curl requests from demo.servicewall.cn

source "$(dirname "$0")/common.sh"

CHECK_NESTED_ERROR=1
setup_server_trap
start_server 2
test_health

echo ""
echo "========================================"
echo "=== AiApiAnalysisView + AiSensRecommendView queries ==="
echo "========================================"

echo ""
echo "=== 1. AiApiAnalysisView: lastBizAnalysis+lastParamAnalysis+lastRiskAnalysis, filter host+method+urlRoute, segment org ==="
# measures: lastBizAnalysis, lastParamAnalysis, lastRiskAnalysis
# filters: host='172.31.38.218:12380', method='GET', urlRoute='/version'
# segments: org
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AiApiAnalysisView.lastBizAnalysis%22%2C%22AiApiAnalysisView.lastParamAnalysis%22%2C%22AiApiAnalysisView.lastRiskAnalysis%22%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22AiApiAnalysisView.host%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22172.31.38.218%3A12380%22%5D%7D%2C%7B%22member%22%3A%22AiApiAnalysisView.method%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22GET%22%5D%7D%2C%7B%22member%22%3A%22AiApiAnalysisView.urlRoute%22%2C%22operator%22%3A%22equals%22%2C%22values%22%3A%5B%22%2Fversion%22%5D%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AiApiAnalysisView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "AiApiAnalysisView: lastBizAnalysis+lastParamAnalysis+lastRiskAnalysis (host+method+urlRoute filter)" "$result"

echo ""
echo "=== 2. AiSensRecommendView: summary stats (minTime/totalScan/uniqAccurateNoiseReductionNum/accuracy/uniqHost/uniqApi), order ts asc, segment org ==="
# measures: minTime, totalScan, uniqAccurateNoiseReductionNum, accuracy, uniqHost, uniqApi
# order: ts asc
# segments: org
# NOTE: order by dimension ts without GROUP BY ts fails in ClickHouse (known go-cube limitation)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AiSensRecommendView.minTime%22%2C%22AiSensRecommendView.totalScan%22%2C%22AiSensRecommendView.uniqAccurateNoiseReductionNum%22%2C%22AiSensRecommendView.accuracy%22%2C%22AiSensRecommendView.uniqHost%22%2C%22AiSensRecommendView.uniqApi%22%5D%2C%22order%22%3A%5B%5B%22AiSensRecommendView.minTime%22%2C%22asc%22%5D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AiSensRecommendView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "AiSensRecommendView: minTime+totalScan+uniqAccurateNoiseReductionNum+accuracy+uniqHost+uniqApi (summary, order minTime asc)" "$result"

echo ""
echo "=== 3. AiSensRecommendView: lastTime+topHostSet+topApiSet by sensKey+sensValue, filter state contains 'noise', segments org+black ==="
# measures: lastTime, topHostSet, topApiSet
# order: lastTime desc
# filter: state contains 'noise'
# dimensions: sensKey, sensValue
# segments: org, black
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AiSensRecommendView.lastTime%22%2C%22AiSensRecommendView.topHostSet%22%2C%22AiSensRecommendView.topApiSet%22%5D%2C%22order%22%3A%5B%5B%22AiSensRecommendView.lastTime%22%2C%22desc%22%5D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22AiSensRecommendView.state%22%2C%22operator%22%3A%22contains%22%2C%22values%22%3A%5B%22noise%22%5D%7D%5D%2C%22dimensions%22%3A%5B%22AiSensRecommendView.sensKey%22%2C%22AiSensRecommendView.sensValue%22%5D%2C%22segments%22%3A%5B%22AiSensRecommendView.org%22%2C%22AiSensRecommendView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "AiSensRecommendView: lastTime+topHostSet+topApiSet by sensKey+sensValue (state contains noise, org+black)" "$result"

echo ""
echo "--- $pass passed, $fail failed ---"

echo ""
echo "Stopping server..."
stop_server
echo "All tests completed."
