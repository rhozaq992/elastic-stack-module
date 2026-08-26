#!/usr/bin/env bash
# Validasi Exercise Sesi 6: kibana_sample_data_ecommerce tersedia dan
# request cache-nya sudah pernah dipakai (hit_count > 0).
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

hits=$(curl -s "http://localhost:9200/kibana_sample_data_ecommerce/_stats/request_cache" 2>/dev/null | grep -o '"hit_count":[0-9]*' | head -1 | grep -o '[0-9]*')
hits=${hits:-0}
if [ "$hits" -gt 0 ] 2>/dev/null; then
  check "Request cache punya hit_count > 0 (hit_count=$hits)" 0
else
  check "Request cache punya hit_count > 0 (hit_count=$hits) -- jalankan query size:0 yang sama 2x" 1
fi

echo ""
echo "Ringkasan: $PASS pass, $FAIL fail"

if [ "$FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
