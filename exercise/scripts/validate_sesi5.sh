#!/usr/bin/env bash
# Validasi Exercise Sesi 5: kibana_sample_data_ecommerce tersedia untuk
# latihan cardinality/geo/pipeline aggregation.
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

count=$(curl -s "http://localhost:9200/kibana_sample_data_ecommerce/_count" 2>/dev/null | grep -o '"count":[0-9]*' | head -1 | grep -o '[0-9]*')
count=${count:-0}
if [ "$count" -eq 4675 ] 2>/dev/null; then
  check "Index kibana_sample_data_ecommerce count = 4675" 0
else
  check "Index kibana_sample_data_ecommerce count = 4675 (got $count)" 1
fi

echo ""
echo "Ringkasan: $PASS pass, $FAIL fail"

if [ "$FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
