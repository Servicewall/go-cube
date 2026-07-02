#!/bin/bash
source "$(dirname "$0")/common.sh"

setup_server_trap
start_server 3 "/tmp/go-cube-urlseq.log" "Starting go-cube server..."
test_health

echo "========================================"
echo "UrlSeqView Tests"
echo "========================================"

echo ""
echo "=== UrlSeqView URL序列列表 ==="
#{"measures":["UrlSeqView.count","UrlSeqView.statRisk","UrlSeqView.total","UrlSeqView.pass"],"timeDimensions":[{"dimension":"UrlSeqView.ts","dateRange":"from 15 minutes ago to 15 minutes from now"}],"filters":[],"dimensions":["UrlSeqView.urlSeq"],"limit":20,"segments":["UrlSeqView.org"],"timezone":"Asia/Shanghai"}
result=$(curl -s "$BASE/load?query=%7B%22measures%22%3A%5B%22UrlSeqView.count%22%2C%22UrlSeqView.statRisk%22%2C%22UrlSeqView.total%22%2C%22UrlSeqView.pass%22%5D%2C%22timeDimensions%22%3A%5B%7B%22dimension%22%3A%22UrlSeqView.ts%22%2C%22dateRange%22%3A%22from%2015%20minutes%20ago%20to%2015%20minutes%20from%20now%22%7D%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22UrlSeqView.urlSeq%22%5D%2C%22limit%22%3A20%2C%22segments%22%3A%5B%22UrlSeqView.org%22%5D%2C%22timezone%22%3A%22Asia/Shanghai%22%7D&queryType=multi")
echo "Raw: $result"
check "UrlSeqView URL序列列表" "$result"

echo "========================================"
echo "Results: $pass passed, $fail failed"
echo "========================================"

if [ $fail -gt 0 ]; then
    echo ""
    echo "=== Server log (last 50 lines) ==="
    tail -50 /tmp/go-cube-urlseq.log
fi

echo ""
echo "All tests completed."
[ $fail -gt 0 ] && exit 1
exit 0
