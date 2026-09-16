# Build context HARUS iso8583-switch/ (bukan log-generator/) supaya COPY
# bisa menjangkau decoder/bin/ -- lihat docker-compose.iso8583-switch.yml
# (build.context: ./iso8583-switch, dockerfile: log-generator/Dockerfile).
FROM python:3.11-slim
WORKDIR /app
COPY log-generator/generate_switch_log.py .
COPY decoder/bin/iso8583tool-linux-arm64 /opt/iso8583tool/iso8583tool-linux-arm64
COPY decoder/bin/iso8583tool-linux-amd64 /opt/iso8583tool/iso8583tool-linux-amd64
RUN chmod +x /opt/iso8583tool/iso8583tool-linux-*
CMD ["python", "generate_switch_log.py"]
