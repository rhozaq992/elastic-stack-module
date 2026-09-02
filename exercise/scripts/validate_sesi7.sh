#!/usr/bin/env bash
# Validasi Exercise Sesi 7: Bagian 1 (payment-service-parsed-* punya
# transaksi anomali http_status 500) dan Bagian 2 (pipeline parser
# custom untuk Task Tracker menghasilkan index dengan field numerik benar).
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

# 429 TIDAK selalu muncul -- tergantung performa host (lihat catatan Sesi 6/8).
# Ini info, BUKAN syarat lulus (tidak menambah PASS/FAIL).
count_429=$(curl -s "http://localhost:9200/payment-service-parsed-*/_count" -H 'Content-Type: application/json' -d '{"query":{"term":{"http_status":429}}}' 2>/dev/null | grep -o '"count":[0-9]*' | head -1 | grep -o '[0-9]*')
count_429=${count_429:-0}
if [ "$count_429" -gt 0 ] 2>/dev/null; then
  echo "INFO - payment-service-parsed-* punya transaksi kapasitas http_status=429 (count=$count_429) -- host Anda mengalami bottleneck, bahan bagus untuk perbandingan"
else
  echo "INFO - payment-service-parsed-* tidak ada http_status=429 (count=0) -- normal, host Anda cukup kuat menangani NUM_CLIENTS:6 tanpa payment kewalahan"
fi

count_200=$(curl -s "http://localhost:9200/payment-service-parsed-*/_count" -H 'Content-Type: application/json' -d '{"query":{"term":{"http_status":200}}}' 2>/dev/null | grep -o '"count":[0-9]*' | head -1 | grep -o '[0-9]*')
count_200=${count_200:-0}
if [ "$count_200" -gt 0 ] 2>/dev/null; then
  check "payment-service-parsed-* punya transaksi normal http_status=200 untuk pembanding (count=$count_200)" 0
else
  check "payment-service-parsed-* punya transaksi normal http_status=200 untuk pembanding (count=$count_200)" 1
fi

tt_count=$(curl -s "http://localhost:9200/task-tracker-parsed-*/_count" 2>/dev/null | grep -o '"count":[0-9]*' | head -1 | grep -o '[0-9]*')
tt_count=${tt_count:-0}
if [ "$tt_count" -gt 0 ] 2>/dev/null; then
  check "Bagian 2: index task-tracker-parsed-* punya dokumen ter-parse (count=$tt_count)" 0
else
  check "Bagian 2: index task-tracker-parsed-* punya dokumen ter-parse (count=$tt_count) -- pastikan pipeline .conf sudah dibuat dan logstash-rs (folder sesi-4-relevance-scoring) sudah di-restart" 1
fi

tt_status_type=$(curl -s "http://localhost:9200/task-tracker-parsed-*/_mapping" 2>/dev/null | grep -o '"status":{"type":"[a-z]*"' | head -1 | grep -oE '"(long|integer|short)"$')
if [ -n "$tt_status_type" ]; then
  check "Bagian 2: field status di-mapping sebagai tipe numerik" 0
else
  check "Bagian 2: field status di-mapping sebagai tipe numerik -- periksa apakah grok pattern Anda menggunakan :int" 1
fi

echo ""
echo "Ringkasan: $PASS pass, $FAIL fail"
echo "(Script ini hanya memeriksa ketersediaan DATA untuk dianalisis -- kesimpulan"
echo "anomali Anda sendiri yang menilai berdasarkan kriteria di README.)"

if [ "$FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
