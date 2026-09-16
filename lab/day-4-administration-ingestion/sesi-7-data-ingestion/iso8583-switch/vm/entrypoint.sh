#!/bin/bash
# "VM" tunggal: log-generator (Python) + decoder (binary Go) berjalan
# BERSAMAAN sebagai 2 proses di dalam 1 container -- pola yang sama
# seperti native-vm Topic 3 menjalankan Filebeat+Logstash sekaligus di 1
# VM/bare-metal, bukan 2 container terpisah.
set -e
ARCH=$(uname -m)
case "$ARCH" in
  aarch64) BIN=/opt/iso8583tool/iso8583tool-linux-arm64 ;;
  x86_64)  BIN=/opt/iso8583tool/iso8583tool-linux-amd64 ;;
  *) echo "arsitektur tidak didukung: $ARCH" >&2; exit 1 ;;
esac
mkdir -p "$(dirname "$RAW_INPUT_SEND")" "$(dirname "$DECODED_OUTPUT")"

python3 /app/generate_switch_log.py &
GEN_PID=$!

(
  echo "decoder: waiting for $RAW_INPUT_SEND and $RAW_INPUT_RECV to exist (log-generator belum mulai menulis)..."
  while [ ! -f "$RAW_INPUT_SEND" ] || [ ! -f "$RAW_INPUT_RECV" ]; do sleep 1; done
  echo "decoder started (tool=$BIN, input=$RAW_INPUT_SEND + $RAW_INPUT_RECV, output=$DECODED_OUTPUT)"
  exec "$BIN" decode "$RAW_INPUT_SEND" "$RAW_INPUT_RECV" >> "$DECODED_OUTPUT"
) &
DEC_PID=$!

# Kalau salah satu proses mati, ikut matikan yang lain & exit non-zero --
# `restart: unless-stopped` di compose yang menghidupkan ulang KEDUANYA
# bersih, bukan cuma 1 proses zombie di container yang masih "Up".
trap 'kill $GEN_PID $DEC_PID 2>/dev/null' TERM INT
wait -n "$GEN_PID" "$DEC_PID"
echo "salah satu proses (generator/decoder) berhenti -- menghentikan VM ini supaya restart: unless-stopped menghidupkan ulang keduanya" >&2
kill $GEN_PID $DEC_PID 2>/dev/null || true
exit 1
