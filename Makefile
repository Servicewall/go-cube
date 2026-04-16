.PHONY: build run test test-unit test-script clean

build:
	go build -o go-cube .

run: build
	./go-cube

test: test-unit test-script

test-unit:
	go test ./...

test-script: build
	@total_pass=0; total_fail=0; failed_scripts=""; \
	for f in test*.sh; do \
		echo ""; \
		echo "========== Running $$f =========="; \
		tmpout=$$(mktemp); \
		bash ./$$f > "$$tmpout" 2>&1; script_exit=$$?; \
		cat "$$tmpout"; \
		script_pass=$$(grep -c '^\[PASS\]' "$$tmpout" || true); \
		script_fail=$$(grep -c '^\[FAIL\]' "$$tmpout" || true); \
		rm -f "$$tmpout"; \
		if [ "$$script_exit" -ne 0 ] && [ "$$script_fail" -eq 0 ]; then \
			script_fail=1; \
			echo "[$$f] abnormal exit (code $$script_exit) with no [FAIL] lines  <-- FAILED"; \
		fi; \
		total_pass=$$((total_pass + script_pass)); \
		total_fail=$$((total_fail + script_fail)); \
		if [ "$$script_fail" -gt 0 ]; then \
			failed_scripts="$$failed_scripts $$f"; \
			echo "[$$f] $$script_pass passed, $$script_fail failed  <-- FAILED"; \
		else \
			echo "[$$f] $$script_pass passed, $$script_fail failed"; \
		fi; \
	done; \
	echo ""; \
	echo "======================================"; \
	echo "Total: $$total_pass passed, $$total_fail failed"; \
	if [ -n "$$failed_scripts" ]; then \
		echo "Failed in:$$failed_scripts"; \
	fi; \
	echo "======================================"; \
	[ $$total_fail -eq 0 ]

clean:
	rm -f go-cube
