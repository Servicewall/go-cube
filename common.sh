#!/bin/bash

# Shared helpers for test scripts.
BASE="${BASE:-http://localhost:4000}"
pass=0
fail=0

# Per-script switches:
# CHECK_TOP_LEVEL_ERROR=1 -> fail when response has top-level .error
# CHECK_NESTED_ERROR=1 -> fail when response has .results[0].data[0].error
CHECK_TOP_LEVEL_ERROR="${CHECK_TOP_LEVEL_ERROR:-0}"
CHECK_NESTED_ERROR="${CHECK_NESTED_ERROR:-0}"

check() {
    local desc="$1"
    local result="$2"

    if [ "$CHECK_TOP_LEVEL_ERROR" = "1" ] && echo "$result" | jq -e '.error' > /dev/null 2>&1; then
        echo "[FAIL] $desc - server error: $(echo "$result" | jq -r '.error')"
        ((fail++))
        return
    fi

    if echo "$result" | jq -e '.results[0].data' > /dev/null 2>&1; then
        if [ "$CHECK_NESTED_ERROR" = "1" ] && echo "$result" | jq -e '.results[0].data[0].error' > /dev/null 2>&1; then
            echo "[FAIL] $desc - error in data"
            echo "$result" | jq '.results[0].data[0].error'
            ((fail++))
        else
            local count
            count=$(echo "$result" | jq '.results[0].data | length')
            echo "[PASS] $desc - $count rows"
            ((pass++))
        fi
    else
        echo "[FAIL] $desc"
        echo "$result" | jq . 2>/dev/null || echo "$result"
        ((fail++))
    fi
}

start_server() {
    local wait_seconds="${1:-2}"
    local log_file="${2:-}"
    local message="${3:-Starting go-cube server in background...}"

    echo "$message"
    if [ -n "$log_file" ]; then
        ./go-cube > "$log_file" 2>&1 &
    else
        ./go-cube &
    fi
    SERVER_PID=$!
    sleep "$wait_seconds"
}

stop_server() {
    if [ -n "${SERVER_PID:-}" ]; then
        kill "$SERVER_PID" 2>/dev/null
        wait "$SERVER_PID" 2>/dev/null
        SERVER_PID=""
    fi
}

setup_server_trap() {
    trap 'stop_server' EXIT INT TERM
}

test_health() {
    echo ""
    echo "Testing health endpoint..."
    curl -s "$BASE/health" | jq .
}
