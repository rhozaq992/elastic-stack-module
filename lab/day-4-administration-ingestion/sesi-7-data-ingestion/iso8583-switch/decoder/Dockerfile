# Build context: iso8583-switch/ (lihat docker-compose.iso8583-switch.yml)
FROM debian:bookworm-slim
COPY decoder/bin/iso8583tool-linux-arm64 /opt/iso8583tool/iso8583tool-linux-arm64
COPY decoder/bin/iso8583tool-linux-amd64 /opt/iso8583tool/iso8583tool-linux-amd64
COPY decoder/entrypoint.sh /entrypoint.sh
RUN chmod +x /opt/iso8583tool/iso8583tool-linux-* /entrypoint.sh
ENV RAW_INPUT_SEND=/data/raw/switch-send.log
ENV RAW_INPUT_RECV=/data/raw/switch-recv.log
ENV DECODED_OUTPUT=/data/decoded/decoded.jsonl
ENTRYPOINT ["/entrypoint.sh"]
