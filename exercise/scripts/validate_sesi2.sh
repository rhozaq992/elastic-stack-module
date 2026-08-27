#!/usr/bin/env bash
# Validasi Exercise Sesi 2: index exercise-inventory ada dengan mapping
# text+keyword yang benar, minimal 2 dokumen tersisa (dari 3, setelah 1 delete).
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

mapping=$(curl -s "http://localhost:9200/exercise-inventory/_mapping" 2>/dev/null)
has_text=$(echo "$mapping" | grep -o '"type":"text"' | head -1)
has_keyword=$(echo "$mapping" | grep -o '"type":"keyword"' | head -1)
if [ -n "$has_text" ] && [ -n "$has_keyword" ]; then
  check "Index exercise-inventory punya mapping text DAN keyword" 0
else
  check "Index exercise-inventory punya mapping text DAN keyword" 1
fi

has_stock=$(echo "$mapping" | grep -o '"stock":{"type":"\(integer\|long\)"}')
has_kategori=$(echo "$mapping" | grep -o '"kategori":{"type":"keyword"}')
if [ -n "$has_stock" ] && [ -n "$has_kategori" ]; then
  check "Mapping punya field stock (angka) dan kategori (keyword) -- minimal 4 field" 0
else
  check "Mapping punya field stock (angka) dan kategori (keyword) -- minimal 4 field" 1
fi

count=$(curl -s "http://localhost:9200/exercise-inventory/_count" 2>/dev/null | grep -o '"count":[0-9]*' | head -1 | grep -o '[0-9]*')
count=${count:-0}
if [ "$count" -ge 2 ] 2>/dev/null; then
  check "Index exercise-inventory punya minimal 2 dokumen tersisa (count=$count)" 0
else
  check "Index exercise-inventory punya minimal 2 dokumen tersisa (count=$count)" 1
fi

echo ""
echo "Ringkasan: $PASS pass, $FAIL fail"
echo "(Script ini hanya memeriksa state akhir -- bukti update/_version naik dan"
echo "404 setelah delete Anda tunjukkan sendiri dari histori perintah Anda.)"

if [ "$FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
