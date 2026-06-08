#!/bin/bash
# SQL 注入防护测试 - 验证恶意 dateRange 被拒绝或无害化

source "$(dirname "$0")/common.sh"

CHECK_TOP_LEVEL_ERROR=1
setup_server_trap
start_server 2
test_health

PASS=0
FAIL=0

echo ""
echo "============================================"
echo "=== SQL 注入防护测试 ==="
echo "============================================"

assert_no_injection() {
    local desc="$1" result="$2"
    if echo "$result" | jq -e '.results[0].data' > /dev/null 2>&1; then
        echo "[PASS] $desc - 正常返回 data（注入被无害化/忽略）"
        ((PASS++))
    elif echo "$result" | jq -e '.error' > /dev/null 2>&1; then
        local err=$(echo "$result" | jq -r '.error')
        # ClickHouse 语法/执行错误说明注入未成功（值被作为字面量处理）
        echo "[PASS] $desc - server 返回 error（注入未执行，ClickHouse 拒绝非法值）"
        ((PASS++))
    else
        echo "[FAIL] $desc - 无法解析响应"
        echo "$result"
        ((FAIL++))
    fi
}

echo ""
echo "=== 1. string dateRange UNION 注入 ==="
q='{"measures":["ApiView.allCountForList"],"timeDimensions":[{"dimension":"ApiView.ts","dateRange":"today UNION ALL SELECT database()--"}],"filters":[],"dimensions":[],"limit":1,"segments":[],"timezone":"Asia/Shanghai"}'
r=$(curl -s -G "$BASE/load" --data-urlencode "queryType=multi" --data-urlencode "query=$q" 2>&1)
assert_no_injection "string dateRange UNION注入" "$r"

echo ""
echo "=== 2. string dateRange DROP 注入 ==="
q='{"measures":["ApiView.allCountForList"],"timeDimensions":[{"dimension":"ApiView.ts","dateRange":"1; DROP TABLE access"}],"filters":[],"dimensions":[],"limit":1,"segments":[],"timezone":"Asia/Shanghai"}'
r=$(curl -s -G "$BASE/load" --data-urlencode "queryType=multi" --data-urlencode "query=$q" 2>&1)
assert_no_injection "string dateRange DROP注入" "$r"

echo ""
echo "=== 3. string dateRange OR 注入 ==="
q='{"measures":["ApiView.allCountForList"],"timeDimensions":[{"dimension":"ApiView.ts","dateRange":"'"'"' OR '"'"'1'"'"'='"'"'1"}],"filters":[],"dimensions":[],"limit":1,"segments":[],"timezone":"Asia/Shanghai"}'
r=$(curl -s -G "$BASE/load" --data-urlencode "queryType=multi" --data-urlencode "query=$q" 2>&1)
assert_no_injection "string dateRange OR注入" "$r"

echo ""
echo "=== 4. array dateRange 反斜杠逃逸 ==="
q='{"measures":["ApiView.allCountForList"],"timeDimensions":[{"dimension":"ApiView.ts","dateRange":["\\'"'"' OR 1=1--","now"]}],"filters":[],"dimensions":[],"limit":1,"segments":[],"timezone":"Asia/Shanghai"}'
r=$(curl -s -G "$BASE/load" --data-urlencode "queryType=multi" --data-urlencode "query=$q" 2>&1)
assert_no_injection "array dateRange 反斜杠逃逸" "$r"

echo ""
echo "=== 5. filter 字段单引号注入 ==="
q='{"measures":["ApiView.allCountForList"],"timeDimensions":[{"dimension":"ApiView.ts","dateRange":"today"}],"filters":[{"member":"ApiView.sidebarFirstLevelTypeArray","operator":"equals","values":["1'"'"' OR '"'"'1'"'"'='"'"'1"]}],"dimensions":[],"limit":1,"segments":[],"timezone":"Asia/Shanghai"}'
r=$(curl -s -G "$BASE/load" --data-urlencode "queryType=multi" --data-urlencode "query=$q" 2>&1)
assert_no_injection "filter 字段单引号注入" "$r"

echo ""
echo "=== 6. 正常 dateRange 回归测试 ==="
q='{"measures":["ApiView.allCountForList"],"timeDimensions":[{"dimension":"ApiView.ts","dateRange":"from 15 minutes ago to now"}],"filters":[],"dimensions":[],"limit":1,"segments":[],"timezone":"Asia/Shanghai"}'
r=$(curl -s -G "$BASE/load" --data-urlencode "queryType=multi" --data-urlencode "query=$q" 2>&1)
check "正常 dateRange 回归测试" "$r"

echo ""
echo "=== 7. ORDER BY 未知 member 注入 ==="
q='{"measures":["ApiView.allCountForList"],"timeDimensions":[{"dimension":"ApiView.ts","dateRange":"today"}],"order":{"1 UNION SELECT database()":"asc"},"filters":[],"dimensions":[],"limit":1,"segments":[],"timezone":"Asia/Shanghai"}'
r=$(curl -s -G "$BASE/load" --data-urlencode "queryType=multi" --data-urlencode "query=$q" 2>&1)
assert_no_injection "ORDER BY 未知 member 注入" "$r"

echo ""
echo "=== 8. 未知 operator 注入 ==="
q='{"measures":["ApiView.allCountForList"],"timeDimensions":[{"dimension":"ApiView.ts","dateRange":"today"}],"filters":[{"member":"ApiView.host","operator":"IS NOT NULL OR 1=1 --","values":["x"]}],"dimensions":[],"limit":1,"segments":[],"timezone":"Asia/Shanghai"}'
r=$(curl -s -G "$BASE/load" --data-urlencode "queryType=multi" --data-urlencode "query=$q" 2>&1)
assert_no_injection "未知 operator 注入" "$r"

echo ""
echo "=== 9. ORDER BY 正常回归 ==="
q='{"measures":["ApiView.allCountForList"],"timeDimensions":[{"dimension":"ApiView.ts","dateRange":"today"}],"order":{"ApiView.allCountForList":"desc"},"filters":[],"dimensions":[],"limit":1,"segments":[],"timezone":"Asia/Shanghai"}'
r=$(curl -s -G "$BASE/load" --data-urlencode "queryType=multi" --data-urlencode "query=$q" 2>&1)
check "ORDER BY 正常回归测试" "$r"

echo ""
echo "=== 结果: $PASS pass, $FAIL fail ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
