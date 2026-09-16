#!/bin/sh
# Pilih binary sesuai arsitektur container saat runtime (bukan ARG buildx
# TARGETARCH) -- portable, tidak bergantung BuildKit.
set -e
ARCH=$(uname -m)
case "$ARCH" in
  aarch64) BIN=/opt/iso8583tool/iso8583tool-linux-arm64 ;;
  x86_64)  BIN=/opt/iso8583tool/iso8583tool-linux-amd64 ;;
  *) echo "arsitektur tidak didukung: $ARCH" >&2; exit 1 ;;
esac
mkdir -p "$(dirname "$DECODED_OUTPUT")"
echo "waiting for $RAW_INPUT_SEND and $RAW_INPUT_RECV to exist (log-generator belum mulai menulis)..."
while [ ! -f "$RAW_INPUT_SEND" ] || [ ! -f "$RAW_INPUT_RECV" ]; do sleep 1; done
echo "iso8583-switch decoder started (tool=$BIN, input=$RAW_INPUT_SEND + $RAW_INPUT_RECV, output=$DECODED_OUTPUT)"
exec "$BIN" decode "$RAW_INPUT_SEND" "$RAW_INPUT_RECV" >> "$DECODED_OUTPUT"
