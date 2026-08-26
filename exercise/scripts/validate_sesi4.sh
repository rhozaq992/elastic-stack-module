#!/usr/bin/env bash
# Validasi Exercise Sesi 4: index robot-shop-catalogue ada dan bisa
# dipakai untuk query boost.
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

count=$(curl -s "http://localhost:9200/robot-shop-catalogue/_count" 2>/dev/null | grep -o '"count":[0-9]*' | head -1 | grep -o '[0-9]*')
count=${count:-0}
if [ "$count" -gt 0 ] 2>/dev/null; then
  check "Index robot-shop-catalogue tersedia untuk latihan boost (count=$count)" 0
else
  check "Index robot-shop-catalogue tersedia untuk latihan boost (count=$count)" 1
fi

echo ""
echo "Ringkasan: $PASS pass, $FAIL fail"
echo "(Script ini cuma cek data tersedia -- perbandingan urutan hasil"
echo "boost kamu tunjukkan sendiri sesuai kriteria selesai di README.)"

if [ "$FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
