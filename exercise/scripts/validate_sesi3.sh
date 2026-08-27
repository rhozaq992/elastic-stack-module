#!/usr/bin/env bash
# Validasi Exercise Sesi 3: kibana_sample_data_flights ter-load lengkap.
set -uo pipefail

PASS=0
FAIL=0

check() {
  local name="$1"
  local result="$2"
  if [ "$result" -eq 0 ]; then
    echo "PASS - $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL - $name"
    FAIL=$((FAIL + 1))
  fi
}

count=$(curl -s "http://localhost:9200/kibana_sample_data_flights/_count" 2>/dev/null | grep -o '"count":[0-9]*' | head -1 | grep -o '[0-9]*')
count=${count:-0}
if [ "$count" -eq 13014 ] 2>/dev/null; then
  check "Index kibana_sample_data_flights count = 13014" 0
else
  check "Index kibana_sample_data_flights count = 13014 (got $count)" 1
fi

echo ""
echo "Ringkasan: $PASS pass, $FAIL fail"

if [ "$FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
