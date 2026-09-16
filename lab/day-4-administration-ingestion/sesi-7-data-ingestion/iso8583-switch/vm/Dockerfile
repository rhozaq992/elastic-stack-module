# Build context: iso8583-switch/ (lihat docker-compose.iso8583-switch.yml).
# Satu image = "1 VM" yang di dalamnya log-generator (Python) DAN decoder
# (binary Go) berjalan bersamaan (lihat entrypoint.sh) -- bukan 2 service
# terpisah seperti versi awal topik ini.
FROM python:3.11-slim
WORKDIR /app
COPY log-generator/generate_switch_log.py .
COPY decoder/bin/iso8583tool-linux-arm64 /opt/iso8583tool/iso8583tool-linux-arm64
COPY decoder/bin/iso8583tool-linux-amd64 /opt/iso8583tool/iso8583tool-linux-amd64
COPY vm/entrypoint.sh /entrypoint.sh
RUN chmod +x /opt/iso8583tool/iso8583tool-linux-* /entrypoint.sh
ENV RAW_INPUT_SEND=/data/raw/switch-send.log
ENV RAW_INPUT_RECV=/data/raw/switch-recv.log
ENV DECODED_OUTPUT=/data/decoded/decoded.jsonl
ENTRYPOINT ["/entrypoint.sh"]
