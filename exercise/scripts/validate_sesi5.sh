#!/usr/bin/env bash
# Validasi Exercise Sesi 5: kibana_sample_data_ecommerce tersedia untuk
# latihan cardinality/geo/pipeline aggregation, DAN tepat 5 visualisasi/
# map tersimpan dengan nama berpola "sesi-5-*" (dashboard flights).
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

flights_count=$(curl -s "http://localhost:9200/kibana_sample_data_flights/_count" 2>/dev/null | grep -o '"count":[0-9]*' | head -1 | grep -o '[0-9]*')
flights_count=${flights_count:-0}
if [ "$flights_count" -eq 13014 ] 2>/dev/null; then
  check "Index kibana_sample_data_flights count = 13014" 0
else
  check "Index kibana_sample_data_flights count = 13014 (got $flights_count)" 1
fi

# 5 visualisasi/map berpola "sesi-5-*" (Lens tersimpan type=lens, Maps type=map)
lens_json=$(curl -s "http://localhost:5601/api/saved_objects/_find?type=lens&search_fields=title&search=sesi-5-*&per_page=50" -H 'kbn-xsrf: true' 2>/dev/null)
map_json=$(curl -s "http://localhost:5601/api/saved_objects/_find?type=map&search_fields=title&search=sesi-5-*&per_page=50" -H 'kbn-xsrf: true' 2>/dev/null)

lens_count=$(echo "$lens_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('total',0))" 2>/dev/null)
map_count=$(echo "$map_json" | python3 -c "import json,sys; print(json.load(sys.stdin).get('total',0))" 2>/dev/null)
lens_count=${lens_count:-0}
map_count=${map_count:-0}
total_saved=$((lens_count + map_count))

if [ "$total_saved" -ge 5 ] 2>/dev/null; then
  check "Ada minimal 5 visualisasi/map tersimpan berpola 'sesi-5-*' (Lens: $lens_count, Maps: $map_count, total: $total_saved)" 0
else
  check "Ada minimal 5 visualisasi/map tersimpan berpola 'sesi-5-*' (Lens: $lens_count, Maps: $map_count, total: $total_saved) -- pastikan tiap visualisasi di-Save dengan nama diawali 'sesi-5-'" 1
fi

echo "$lens_json" > /tmp/sesi5_lens.json
echo "$map_json" > /tmp/sesi5_map.json
python3 << 'PYEOF'
import json

titles = []
for fname in ('/tmp/sesi5_lens.json', '/tmp/sesi5_map.json'):
    try:
        with open(fname) as f:
            data = json.load(f)
        for obj in data.get('saved_objects', []):
            titles.append(obj['attributes']['title'])
    except Exception:
        pass

if titles:
    print("  Ditemukan:")
    for t in sorted(titles):
        print(f"    - {t}")
PYEOF

echo ""
echo "Ringkasan: $PASS pass, $FAIL fail"
echo "(Jumlah pelanggan unik, area geohash, tanggal revenue tertinggi, dan"
echo "maskapai paling sering delay tetap Anda tunjukkan sendiri sesuai kriteria di README.)"

if [ "$FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
