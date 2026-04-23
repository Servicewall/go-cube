#!/bin/bash
# Test UserView queries against local go-cube server
# Mirrors production curl requests from demo.servicewall.cn

source "$(dirname "$0")/common.sh"

CHECK_NESTED_ERROR=1
setup_server_trap
start_server 2
test_health

echo ""
echo "========================================"
echo "=== UserView queries ==="
echo "========================================"

echo ""
echo "=== 1. UserView: userDepartment+userInfo+userName+uid+userRole+userStatus, segment org ==="
# dimensions: userDepartment, userInfo, userName, uid, userRole, userStatus
# segments: org
result=$(curl -s "$BASE/load?queryType=multi&query=%7B%22measures%22%3A%5B%5D%2C%22filters%22%3A%5B%5D%2C%22dimensions%22%3A%5B%22UserView.userDepartment%22%2C%22UserView.userInfo%22%2C%22UserView.userName%22%2C%22UserView.uid%22%2C%22UserView.userRole%22%2C%22UserView.userStatus%22%5D%2C%22segments%22%3A%5B%22UserView.org%22%5D%2C%22timezone%22%3A%22Asia%2FShanghai%22%7D")
check "UserView: userDepartment+userInfo+userName+uid+userRole+userStatus (segment org)" "$result"

echo ""
echo "--- $pass passed, $fail failed ---"

echo ""
echo "Stopping server..."
stop_server
echo "All tests completed."
