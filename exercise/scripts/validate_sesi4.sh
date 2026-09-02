#!/usr/bin/env bash
# Validasi Exercise Sesi 4: index robot-shop-catalogue ada dan bisa
# dipakai untuk query boost (Varian A), DAN Discover session tersimpan
# dengan nama pola "sesi-4-*" untuk filter stok (Varian B).
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

# Varian B: Discover session tersimpan dengan nama pola "sesi-4-*"
saved=$(curl -s "http://localhost:5601/api/saved_objects/_find?type=search&search_fields=title&search=sesi-4-*" -H 'kbn-xsrf: true' 2>/dev/null)
saved_total=$(echo "$saved" | python3 -c "import json,sys; print(json.load(sys.stdin).get('total',0))" 2>/dev/null)
saved_total=${saved_total:-0}
if [ "$saved_total" -gt 0 ] 2>/dev/null; then
  check "Ada Discover session tersimpan dengan nama berpola 'sesi-4-*' (ditemukan: $saved_total)" 0
else
  check "Ada Discover session tersimpan dengan nama berpola 'sesi-4-*' (ditemukan: $saved_total) -- di Discover, klik Save, beri nama diawali 'sesi-4-'" 1
fi

if [ "$saved_total" -gt 0 ] 2>/dev/null; then
  echo "$saved" > /tmp/sesi4_saved_search.json
  python3 << 'PYEOF'
import json

with open('/tmp/sesi4_saved_search.json') as f:
    data = json.load(f)

for obj in data.get('saved_objects', []):
    title = obj['attributes'].get('title', '')
    for tab in obj['attributes'].get('tabs', []):
        try:
            meta = json.loads(tab['attributes']['kibanaSavedObjectMeta']['searchSourceJSON'])
            query_text = meta.get('query', {}).get('query', '')
        except Exception:
            query_text = ''
        flag = "mengandung 'instock'" if 'instock' in query_text else "TIDAK menyebut 'instock' -- pastikan filter yang benar sudah disimpan"
        print(f"  -> '{title}': query KQL tersimpan = {query_text!r} ({flag})")
PYEOF
  ref_count=$(curl -s "http://localhost:9200/robot-shop-catalogue/_count?q=instock:>0" 2>/dev/null | grep -o '"count":[0-9]*' | head -1 | grep -o '[0-9]*')
  echo "  -> Jumlah dokumen instock > 0 di Elasticsearch (rujukan silang manual dengan angka 'Documents (N)' di Discover Anda): $ref_count"
fi

echo ""
echo "Ringkasan: $PASS pass, $FAIL fail"
echo "(Perbandingan urutan hasil boost Varian A tetap Anda tunjukkan sendiri"
echo "sesuai kriteria selesai di README -- script ini tidak menilai urutan itu.)"

if [ "$FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
