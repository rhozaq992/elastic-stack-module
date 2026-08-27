#!/usr/bin/env bash
# Validasi Exercise Sesi 6: Bagian 1 (kibana_sample_data_ecommerce +
# request cache) dan Bagian 2 (data trace APM cart & payment tersedia).
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

apm_services=$(curl -s "http://localhost:9200/traces-apm-default/_search" -H 'Content-Type: application/json' -d '{"size":0,"aggs":{"svc":{"terms":{"field":"service.name"}}}}' 2>/dev/null | grep -o '"key":"[a-z]*"' | sort -u | wc -l | tr -d ' ')
apm_services=${apm_services:-0}
if [ "$apm_services" -ge 2 ] 2>/dev/null; then
  check "Data trace APM ada untuk minimal 2 service (ditemukan $apm_services)" 0
else
  check "Data trace APM ada untuk minimal 2 service (ditemukan $apm_services) -- pastikan load generator sudah jalan beberapa menit" 1
fi

span_dest_count=$(curl -s "http://localhost:9200/traces-apm-default/_search" -H 'Content-Type: application/json' -d '{"size":0,"query":{"bool":{"filter":[{"term":{"service.name":"payment"}},{"exists":{"field":"span.destination.service.resource"}}]}}}' 2>/dev/null | grep -o '"value":[0-9]*' | head -1 | grep -o '[0-9]*')
span_dest_count=${span_dest_count:-0}
if [ "$span_dest_count" -gt 0 ] 2>/dev/null; then
  check "Data span payment punya field span.destination.service.resource (count=$span_dest_count) -- cukup untuk Bagian 2 langkah 3" 0
else
  check "Data span payment punya field span.destination.service.resource (count=$span_dest_count) -- pastikan load generator sudah jalan beberapa menit" 1
fi

echo ""
echo "Ringkasan: $PASS pass, $FAIL fail"
echo "(Bagian 2 -- endpoint paling lambat, dependency spesifik penyebabnya,"
echo "dan kesimpulan akar penyebab Anda tunjukkan sendiri sesuai kriteria di README.)"

if [ "$FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
