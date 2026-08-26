#!/usr/bin/env bash
# Validasi Exercise Sesi 8: index payment-service-parsed-* punya transaksi
# anomali (http_status 500) yang bisa dianalisis.
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

count_500=$(curl -s "http://localhost:9200/payment-service-parsed-*/_count" -H 'Content-Type: application/json' -d '{"query":{"term":{"http_status":500}}}' 2>/dev/null | grep -o '"count":[0-9]*' | head -1 | grep -o '[0-9]*')
count_500=${count_500:-0}
if [ "$count_500" -gt 0 ] 2>/dev/null; then
  check "payment-service-parsed-* punya transaksi anomali http_status=500 (count=$count_500)" 0
else
  check "payment-service-parsed-* punya transaksi anomali http_status=500 (count=$count_500)" 1
fi

count_429=$(curl -s "http://localhost:9200/payment-service-parsed-*/_count" -H 'Content-Type: application/json' -d '{"query":{"term":{"http_status":429}}}' 2>/dev/null | grep -o '"count":[0-9]*' | head -1 | grep -o '[0-9]*')
count_429=${count_429:-0}
if [ "$count_429" -gt 0 ] 2>/dev/null; then
  check "payment-service-parsed-* punya transaksi kapasitas http_status=429 (count=$count_429)" 0
else
  check "payment-service-parsed-* punya transaksi kapasitas http_status=429 (count=$count_429)" 1
fi

count_200=$(curl -s "http://localhost:9200/payment-service-parsed-*/_count" -H 'Content-Type: application/json' -d '{"query":{"term":{"http_status":200}}}' 2>/dev/null | grep -o '"count":[0-9]*' | head -1 | grep -o '[0-9]*')
count_200=${count_200:-0}
if [ "$count_200" -gt 0 ] 2>/dev/null; then
  check "payment-service-parsed-* punya transaksi normal http_status=200 untuk pembanding (count=$count_200)" 0
else
  check "payment-service-parsed-* punya transaksi normal http_status=200 untuk pembanding (count=$count_200)" 1
fi

echo ""
echo "Ringkasan: $PASS pass, $FAIL fail"
echo "(Script ini cuma cek DATA-nya tersedia untuk dianalisis -- kesimpulan"
echo "anomali kamu sendiri yang menilai berdasarkan kriteria di README.)"

if [ "$FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
