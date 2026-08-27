#!/usr/bin/env bash
# Validasi Exercise Sesi 7: index exercise-cluster-backup ada (hasil
# restore) dan snapshot repository terdaftar. Jalankan SELAGI cluster
# Sesi 7 (multi-node) masih up.
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

repo_status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:9200/_snapshot/lab-fs-repo" 2>/dev/null)
if [ "$repo_status" = "200" ]; then
  check "Snapshot repository lab-fs-repo terdaftar" 0
else
  check "Snapshot repository lab-fs-repo terdaftar (got HTTP $repo_status)" 1
fi

count=$(curl -s "http://localhost:9200/exercise-cluster-backup/_count" 2>/dev/null | grep -o '"count":[0-9]*' | head -1 | grep -o '[0-9]*')
count=${count:-0}
if [ "$count" -ge 10 ] 2>/dev/null; then
  check "Index exercise-cluster-backup punya minimal 10 dokumen (hasil restore, count=$count)" 0
else
  check "Index exercise-cluster-backup punya minimal 10 dokumen (hasil restore, count=$count)" 1
fi

echo ""
echo "Ringkasan: $PASS pass, $FAIL fail"

if [ "$FAIL" -eq 0 ]; then
  exit 0
else
  exit 1
fi
