#!/usr/bin/env bash
# Validasi Exercise Sesi 1: Latihan 1 (exercise-server-monitoring) dan
# Latihan 2 (exercise-toko-produk) ada dengan jumlah dokumen minimal, cluster sehat.
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

count=$(curl -s "http://localhost:9200/exercise-server-monitoring/_count" 2>/dev/null | grep -o '"count":[0-9]*' | head -1 | grep -o '[0-9]*')
count=${count:-0}
if [ "$count" -ge 5 ] 2>/dev/null; then
  check "Latihan 1: index exercise-server-monitoring punya minimal 5 dokumen (count=$count)" 0
else
  check "Latihan 1: index exercise-server-monitoring punya minimal 5 dokumen (count=$count)" 1
fi

inv_count=$(curl -s "http://localhost:9200/exercise-toko-produk/_count" 2>/dev/null | grep -o '"count":[0-9]*' | head -1 | grep -o '[0-9]*')
inv_count=${inv_count:-0}
if [ "$inv_count" -ge 5 ] 2>/dev/null; then
  check "Latihan 2: index exercise-toko-produk punya minimal 5 dokumen (count=$inv_count)" 0
else
  check "Latihan 2: index exercise-toko-produk punya minimal 5 dokumen (count=$inv_count)" 1
fi

status=$(curl -s "http://localhost:9200/_cluster/health" 2>/dev/null | grep -o '"status":"[a-z]*"' | grep -o '[a-z]*"$' | tr -d '"')
if [ "$status" != "red" ] && [ -n "$status" ]; then
  check "Cluster health bukan red (status=$status)" 0
else
  check "Cluster health bukan red (status=$status)" 1
fi

echo ""
echo "Ringkasan: $PASS pass, $FAIL fail"

if [ "$FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
