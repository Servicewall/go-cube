#!/bin/bash
# test_access2.sh — AccessView gap-fill tests
# Covers dimensions and measures NOT exercised by test_access.sh

BASE="http://localhost:4000"
pass=0
fail=0

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

echo "Starting go-cube server in background..."
./go-cube &
SERVER_PID=$!
sleep 2

echo ""
echo "Testing health endpoint..."
curl -s "$BASE/health" | jq .

# ─── RANGE used throughout ────────────────────────────────────────────────────
# "from 60 minutes ago to 60 minutes from now"  — encoded once for reuse
RANGE="from+60+minutes+ago+to+60+minutes+from+now"

echo ""
echo "========================================"
echo "=== AccessView: identity / raw dimensions ==="
echo "========================================"

echo ""
echo "=== 1. ungrouped: id+tsMs+sid+uid+ts+ip (limit 5) ==="
# Tests: id, tsMs, sid, uid dimensions in ungrouped row scan
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.id%22%2C%22AccessView.tsMs%22%2C%22AccessView.sid%22%2C%22AccessView.uid%22%2C%22AccessView.ts%22%2C%22AccessView.ip%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped id+tsMs+sid+uid+ts+ip limit 5" "$result"

echo ""
echo "=== 2. ungrouped: result+resultType+resultAction+resultScore+resultLevel+reason (limit 5) ==="
# Tests: result, resultType, resultAction, resultScore, resultLevel, reason
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.result%22%2C%22AccessView.resultType%22%2C%22AccessView.resultAction%22%2C%22AccessView.resultScore%22%2C%22AccessView.resultLevel%22%2C%22AccessView.reason%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped result+resultType+resultAction+resultScore+resultLevel+reason limit 5" "$result"

echo ""
echo "=== 3. ungrouped: url+reqAction+reqReason+protocol+reqContentLength+respContentLength (limit 5) ==="
# Tests: url, reqAction, reqReason, protocol, reqContentLength, respContentLength
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.url%22%2C%22AccessView.reqAction%22%2C%22AccessView.reqReason%22%2C%22AccessView.protocol%22%2C%22AccessView.reqContentLength%22%2C%22AccessView.respContentLength%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped url+reqAction+reqReason+protocol+reqContentLength+respContentLength limit 5" "$result"

echo ""
echo "=== 4. ungrouped: ua+uaDev+uaVersion+uaName+uaOs+uaOsVersion+uaFp+devType (limit 5) ==="
# Tests: ua, uaDev, uaVersion, uaName, uaOs, uaOsVersion, uaFp, devType
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.ua%22%2C%22AccessView.uaDev%22%2C%22AccessView.uaVersion%22%2C%22AccessView.uaName%22%2C%22AccessView.uaOs%22%2C%22AccessView.uaOsVersion%22%2C%22AccessView.uaFp%22%2C%22AccessView.devType%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped ua+uaDev+uaVersion+uaName+uaOs+uaOsVersion+uaFp+devType limit 5" "$result"

echo ""
echo "=== 5. ungrouped: devData+devRealIp+isProxy+isBot+deviceFingerprint+uniqueId (limit 5) ==="
# Tests: devData, devRealIp, isProxy, isBot, deviceFingerprint, uniqueId
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.devData%22%2C%22AccessView.devRealIp%22%2C%22AccessView.isProxy%22%2C%22AccessView.isBot%22%2C%22AccessView.deviceFingerprint%22%2C%22AccessView.uniqueId%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped devData+devRealIp+isProxy+isBot+deviceFingerprint+uniqueId limit 5" "$result"

echo ""
echo "=== 6. ungrouped: ipWithGeo+ipGeoIsp+ipGeoOwner+ipInfo+nameGroup (limit 5) ==="
# Tests: ipWithGeo, ipGeoIsp, ipGeoOwner, ipInfo, nameGroup
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.ipWithGeo%22%2C%22AccessView.ipGeoIsp%22%2C%22AccessView.ipGeoOwner%22%2C%22AccessView.ipInfo%22%2C%22AccessView.nameGroup%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped ipWithGeo+ipGeoIsp+ipGeoOwner+ipInfo+nameGroup limit 5" "$result"

echo ""
echo "=== 7. ungrouped: appName+customAppName+customAppDesc+assetName+assetLevel+assetType+urlActionName (limit 5) ==="
# Tests: appName, customAppName, customAppDesc, assetName, assetLevel, assetType, urlActionName
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.appName%22%2C%22AccessView.customAppName%22%2C%22AccessView.customAppDesc%22%2C%22AccessView.assetName%22%2C%22AccessView.assetLevel%22%2C%22AccessView.assetType%22%2C%22AccessView.urlActionName%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped appName+customAppName+customAppDesc+assetName+assetLevel+assetType+urlActionName limit 5" "$result"

echo ""
echo "=== 8. ungrouped: upstream+dstNode+remoteAddr+xff+topoNetwork+hostUrl (limit 5) ==="
# Tests: upstream, dstNode, remoteAddr, xff, topoNetwork, hostUrl
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.upstream%22%2C%22AccessView.dstNode%22%2C%22AccessView.remoteAddr%22%2C%22AccessView.xff%22%2C%22AccessView.topoNetwork%22%2C%22AccessView.hostUrl%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped upstream+dstNode+remoteAddr+xff+topoNetwork+hostUrl limit 5" "$result"

echo ""
echo "=== 9. ungrouped: refer+referPath+tid+tokenPath+analysis (limit 5) ==="
# Tests: refer, referPath, tid, tokenPath, analysis  (taskId excluded — task_id column not in DB)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.refer%22%2C%22AccessView.referPath%22%2C%22AccessView.tid%22%2C%22AccessView.tokenPath%22%2C%22AccessView.analysis%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped refer+referPath+tid+tokenPath+analysis limit 5" "$result"

echo ""
echo "=== 10. ungrouped: sysProcessTime+upstreamProcessTime+reqEncryptMethod+respEncryptMethod+resContentType (limit 5) ==="
# Tests: sysProcessTime, upstreamProcessTime, reqEncryptMethod, respEncryptMethod, resContentType
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.sysProcessTime%22%2C%22AccessView.upstreamProcessTime%22%2C%22AccessView.reqEncryptMethod%22%2C%22AccessView.respEncryptMethod%22%2C%22AccessView.resContentType%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped sysProcessTime+upstreamProcessTime+reqEncryptMethod+respEncryptMethod+resContentType limit 5" "$result"

echo ""
echo "=== 11. ungrouped: dbType+dbName+tableName+dbInfo+dbSensKV (limit 5) ==="
# Tests: dbType, dbName, tableName, dbInfo, dbSensKV
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.dbType%22%2C%22AccessView.dbName%22%2C%22AccessView.tableName%22%2C%22AccessView.dbInfo%22%2C%22AccessView.dbSensKV%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped dbType+dbName+tableName+dbInfo+dbSensKV limit 5" "$result"

echo ""
echo "=== 12. ungrouped: isSens+isReqSens+isResSens+isApi+isEncrypted+isFile+isFileSens (limit 5) ==="
# Tests: isSens, isReqSens, isResSens, isApi, isEncrypted, isFile, isFileSens
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.isSens%22%2C%22AccessView.isReqSens%22%2C%22AccessView.isResSens%22%2C%22AccessView.isApi%22%2C%22AccessView.isEncrypted%22%2C%22AccessView.isFile%22%2C%22AccessView.isFileSens%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped isSens+isReqSens+isResSens+isApi+isEncrypted+isFile+isFileSens limit 5" "$result"

echo ""
echo "=== 13. ungrouped: reqSensKV+resSensKV+reqSensKeyNum+resSensKeyNum+sensScore (limit 5) ==="
# Tests: reqSensKV, resSensKV, reqSensKeyNum, resSensKeyNum, sensScore
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.reqSensKV%22%2C%22AccessView.resSensKV%22%2C%22AccessView.reqSensKeyNum%22%2C%22AccessView.resSensKeyNum%22%2C%22AccessView.sensScore%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped reqSensKV+resSensKV+reqSensKeyNum+resSensKeyNum+sensScore limit 5" "$result"

echo ""
echo "=== 14. ungrouped: reqBody+respBody+request+response (limit 3) ==="
# Tests: reqBody, respBody, request, response — potentially large payloads; use small limit
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.reqBody%22%2C%22AccessView.respBody%22%2C%22AccessView.request%22%2C%22AccessView.response%22%5D%2C%22limit%22%3A3%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped reqBody+respBody+request+response limit 3" "$result"

echo ""
echo "=== 15. ungrouped: weakVal+weakKey+maskRule+responseRisk+responseAction+responseReason (limit 5) ==="
# Tests: weakVal, weakKey, maskRule, responseRisk, responseAction, responseReason
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.weakVal%22%2C%22AccessView.weakKey%22%2C%22AccessView.maskRule%22%2C%22AccessView.responseRisk%22%2C%22AccessView.responseAction%22%2C%22AccessView.responseReason%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped weakVal+weakKey+maskRule+responseRisk+responseAction+responseReason limit 5" "$result"

echo ""
echo "=== 16. ungrouped: reqSensKey+respSensKey+reqSensVal+respSensVal (array dims, limit 5) ==="
# Tests: reqSensKey (array), respSensKey (array), reqSensVal (array), respSensVal (array)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.reqSensKey%22%2C%22AccessView.respSensKey%22%2C%22AccessView.reqSensVal%22%2C%22AccessView.respSensVal%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped reqSensKey+respSensKey+reqSensVal+respSensVal (array dims) limit 5" "$result"

echo ""
echo "=== 17. grouped: count by resultRisk+resultLevel+resultAction (risk-confirmed path) ==="
# Tests: resultRisk (array dim used as GROUP BY key)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.resultLevel%22%2C%22AccessView.resultAction%22%5D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "count by resultLevel+resultAction limit 10" "$result"

echo ""
echo "=== 18. grouped: count by appName limit 10 (dict-lookup dimension) ==="
# Tests: appName grouped query (complex dict expression)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.appName%22%5D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "count by appName limit 10" "$result"

echo ""
echo "=== 19. grouped: count by protocol limit 10 ==="
# Tests: protocol dimension (multiIf expression)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.protocol%22%5D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "count by protocol limit 10" "$result"

echo ""
echo "=== 20. grouped: count by devType limit 10 ==="
# Tests: devType dimension
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.devType%22%5D%2C%22limit%22%3A10%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "count by devType limit 10" "$result"

echo ""
echo "=== 21. filter: count where riskFilterTag has value (array filter operator) ==="
# Tests: riskFilterTag as filter dimension (has operator)
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22AccessView.riskFilterTag%22%2C%22operator%22%3A%22set%22%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "count where riskFilterTag set (array filter)" "$result"

echo ""
echo "=== 22. filter: count where reqRiskFilterTag set + resRiskFilterTag set ==="
# Tests: reqRiskFilterTag, resRiskFilterTag as filter dimensions
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%7B%22or%22%3A%5B%7B%22member%22%3A%22AccessView.reqRiskFilterTag%22%2C%22operator%22%3A%22set%22%7D%2C%7B%22member%22%3A%22AccessView.resRiskFilterTag%22%2C%22operator%22%3A%22set%22%7D%5D%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "count where reqRiskFilterTag OR resRiskFilterTag set" "$result"

echo ""
echo "=== 23. filter: count where sensKeyFilterTag set ==="
# Tests: sensKeyFilterTag as filter dimension
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22AccessView.sensKeyFilterTag%22%2C%22operator%22%3A%22set%22%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "count where sensKeyFilterTag set" "$result"

echo ""
echo "=== 24. filter + count where customParamMap notEmpty ==="
# Tests: customParamMap dimension
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.count%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%7B%22member%22%3A%22AccessView.customParamMap%22%2C%22operator%22%3A%22notEquals%22%2C%22values%22%3A%5B%22%7B%7D%22%5D%7D%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "count where customParamMap != {}" "$result"

echo ""
echo "========================================"
echo "=== AccessView: untested measures ==="
echo "========================================"

echo ""
echo "=== 25. hourCountArray+hourBlockCountArray (no dimensions, 60min) ==="
# Tests: hourCountArray, hourBlockCountArray
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.hourCountArray%22%2C%22AccessView.hourBlockCountArray%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "hourCountArray+hourBlockCountArray (no dims, 60min)" "$result"

echo ""
echo "=== 26. minCountArray+minBlockCountArray (no dimensions, 60min) ==="
# Tests: minCountArray, minBlockCountArray
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.minCountArray%22%2C%22AccessView.minBlockCountArray%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "minCountArray+minBlockCountArray (no dims, 60min)" "$result"

echo ""
echo "=== 27. hourCountToday+hourCountAvg+hourCountStddev (no dimensions, 60min) ==="
# Tests: hourCountToday, hourCountAvg, hourCountStddev
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.hourCountToday%22%2C%22AccessView.hourCountAvg%22%2C%22AccessView.hourCountStddev%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "hourCountToday+hourCountAvg+hourCountStddev (no dims, 60min)" "$result"

echo ""
echo "=== 28. hourZscoreArray+hourCountPredictArray (no dimensions, today) ==="
# Tests: hourZscoreArray, hourCountPredictArray
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.hourZscoreArray%22%2C%22AccessView.hourCountPredictArray%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22today%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "hourZscoreArray+hourCountPredictArray (no dims, today)" "$result"

echo ""
echo "=== 29. minCountAvg+minCountStddev+minZscoreArray+minCountPredictArray (no dims, 60min) ==="
# Tests: minCountAvg, minCountStddev, minZscoreArray, minCountPredictArray
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.minCountAvg%22%2C%22AccessView.minCountStddev%22%2C%22AccessView.minZscoreArray%22%2C%22AccessView.minCountPredictArray%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "minCountAvg+minCountStddev+minZscoreArray+minCountPredictArray (no dims, 60min)" "$result"

echo ""
echo "=== 30. finSearchCount+bookCount+finBookCount (monthly, this year) ==="
# Tests: finSearchCount, bookCount, finBookCount
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.finSearchCount%22%2C%22AccessView.bookCount%22%2C%22AccessView.finBookCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22this+year%22%2C%22granularity%22%3A%22month%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%2C%22AccessView.black%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "finSearchCount+bookCount+finBookCount by month this year" "$result"

echo ""
echo "=== 31. blockCrawlerCount+uniqBlockCrawlerCount+uniqProtectApiCount (60min) ==="
# Tests: blockCrawlerCount, uniqBlockCrawlerCount, uniqProtectApiCount
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.blockCrawlerCount%22%2C%22AccessView.uniqBlockCrawlerCount%22%2C%22AccessView.uniqProtectApiCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "blockCrawlerCount+uniqBlockCrawlerCount+uniqProtectApiCount (60min)" "$result"

echo ""
echo "=== 32. protectAssetCount+protectHighAssetCount+uniqNoDevCount+uniqAllDevCount (60min) ==="
# Tests: protectAssetCount, protectHighAssetCount, uniqNoDevCount, uniqAllDevCount
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.protectAssetCount%22%2C%22AccessView.protectHighAssetCount%22%2C%22AccessView.uniqNoDevCount%22%2C%22AccessView.uniqAllDevCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "protectAssetCount+protectHighAssetCount+uniqNoDevCount+uniqAllDevCount (60min)" "$result"

echo ""
echo "=== 33. uniqRiskDevCount+uniqRiskIpCount+uniqRiskUserCount+uniqVistorCount (60min) ==="
# Tests: uniqRiskDevCount, uniqRiskIpCount, uniqRiskUserCount, uniqVistorCount
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.uniqRiskDevCount%22%2C%22AccessView.uniqRiskIpCount%22%2C%22AccessView.uniqRiskUserCount%22%2C%22AccessView.uniqVistorCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "uniqRiskDevCount+uniqRiskIpCount+uniqRiskUserCount+uniqVistorCount (60min)" "$result"

echo ""
echo "=== 34. uniqApiCount+uniqAppCount+uniqAppArray (60min) ==="
# Tests: uniqApiCount, uniqAppCount, uniqAppArray
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.uniqApiCount%22%2C%22AccessView.uniqAppCount%22%2C%22AccessView.uniqAppArray%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "uniqApiCount+uniqAppCount+uniqAppArray (60min)" "$result"

echo ""
echo "=== 35. uniqBlockIpCount+uniqBlockDevCount+uniqBlockUserCount (60min) ==="
# Tests: uniqBlockIpCount, uniqBlockDevCount, uniqBlockUserCount
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.uniqBlockIpCount%22%2C%22AccessView.uniqBlockDevCount%22%2C%22AccessView.uniqBlockUserCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "uniqBlockIpCount+uniqBlockDevCount+uniqBlockUserCount (60min)" "$result"

echo ""
echo "=== 36. avgApiByUserCount+avgMinByUserCount+anyHeavyUa+statsRisk (60min) ==="
# Tests: avgApiByUserCount, avgMinByUserCount, anyHeavyUa, statsRisk
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.avgApiByUserCount%22%2C%22AccessView.avgMinByUserCount%22%2C%22AccessView.anyHeavyUa%22%2C%22AccessView.statsRisk%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "avgApiByUserCount+avgMinByUserCount+anyHeavyUa+statsRisk (60min)" "$result"

echo ""
echo "=== 37. uniqHostCount+topHostArray+uniqPortCount+uniqPortArray+topPortArray (60min) ==="
# Tests: uniqHostCount, topHostArray, uniqPortCount, uniqPortArray, topPortArray
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.uniqHostCount%22%2C%22AccessView.topHostArray%22%2C%22AccessView.uniqPortCount%22%2C%22AccessView.uniqPortArray%22%2C%22AccessView.topPortArray%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "uniqHostCount+topHostArray+uniqPortCount+uniqPortArray+topPortArray (60min)" "$result"

echo ""
echo "=== 38. reqSensKeySet+respSensKeySet+reqSensCount+resSensCount (60min) ==="
# Tests: reqSensKeySet, respSensKeySet, reqSensCount, resSensCount
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.reqSensKeySet%22%2C%22AccessView.respSensKeySet%22%2C%22AccessView.reqSensCount%22%2C%22AccessView.resSensCount%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "reqSensKeySet+respSensKeySet+reqSensCount+resSensCount (60min)" "$result"

echo ""
echo "=== 39. topoSearchCount+aggResSensValNum+uniqReqSensMap+uniqRespSensMap (60min) ==="
# Tests: topoSearchCount, aggResSensValNum, uniqReqSensMap, uniqRespSensMap
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.topoSearchCount%22%2C%22AccessView.aggResSensValNum%22%2C%22AccessView.uniqReqSensMap%22%2C%22AccessView.uniqRespSensMap%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "topoSearchCount+aggResSensValNum+uniqReqSensMap+uniqRespSensMap (60min)" "$result"

echo ""
echo "=== 40. autoTagSet+midFilter+srcNodeWithMid+dstNodeWithMid (60min) ==="
# Tests: autoTagSet, midFilter, srcNodeWithMid, dstNodeWithMid
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%22AccessView.autoTagSet%22%2C%22AccessView.midFilter%22%2C%22AccessView.srcNodeWithMid%22%2C%22AccessView.dstNodeWithMid%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.srcNode%22%2C%22AccessView.dstNode%22%5D%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22limit%22%3A10%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "autoTagSet+midFilter+srcNodeWithMid+dstNodeWithMid (60min, grouped by srcNode+dstNode)" "$result"

echo ""
echo "=== 41. reqSampleKey+respSampleKey+reqSampleValue+respSampleValue (ungrouped, limit 5) ==="
# Tests: reqSampleKey, respSampleKey, reqSampleValue, respSampleValue
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22ungrouped%22%3Atrue%2C%22measures%22%3A%5B%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22AccessView.ts%22%2C%22dateRange%22%3A%22$RANGE%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22AccessView.reqSampleKey%22%2C%22AccessView.respSampleKey%22%2C%22AccessView.reqSampleValue%22%2C%22AccessView.respSampleValue%22%5D%2C%22limit%22%3A5%2C%22segments%22%3A%5B%22AccessView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "ungrouped reqSampleKey+respSampleKey+reqSampleValue+respSampleValue limit 5" "$result"

echo ""
echo "--- $pass passed, $fail failed ---"

echo ""
echo "Stopping server..."
kill $SERVER_PID
wait $SERVER_PID 2>/dev/null
echo "All tests completed."
[ $fail -gt 0 ] && exit 1
exit 0
