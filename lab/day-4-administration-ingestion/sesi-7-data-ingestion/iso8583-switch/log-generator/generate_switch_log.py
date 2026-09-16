import json
import os
import platform
import random
import subprocess
import time
from datetime import datetime, timezone

# Sama seperti decoder (RAW_INPUT_SEND/RAW_INPUT_RECV) -- generator & decoder
# jalan di dalam 1 VM/container yang sama sekarang, path ini harus konsisten
# di antara keduanya (lihat vm/entrypoint.sh).
SEND_LOG = os.environ.get("RAW_INPUT_SEND", "/data/raw/switch-send.log")  # request (S), pola penamaan capture switch produksi
RECV_LOG = os.environ.get("RAW_INPUT_RECV", "/data/raw/switch-recv.log")  # response (R), pola penamaan capture switch produksi

# ponytail: pilih binary sesuai arsitektur container saat runtime (bukan
# ARG buildx TARGETARCH) -- lebih portable, tidak bergantung BuildKit.
ARCH_BIN = {
    "aarch64": "/opt/iso8583tool/iso8583tool-linux-arm64",
    "x86_64": "/opt/iso8583tool/iso8583tool-linux-amd64",
}
ISO8583TOOL = ARCH_BIN[platform.machine()]

BANK_HOST_TAG = "TDEMO"  # institusi FIKTIF -- lab ini, bukan bank sungguhan
TERMINALS = [f"ATMD{n:04d}" for n in range(1, 6)]  # field 41: fixed 8 char
MERCHANTS = [f"BANKDEMO{n:07d}" for n in range(1, 4)]  # field 42: fixed 15 char
# BIN uji standar (test BIN range), bukan PAN nasabah nyata
TEST_PAN_PREFIXES = ["400000", "510000", "601100"]
PROCESSING_CODES = {
    "310000": "INQ REK RETAIL IB",
    "400000": "TRANSFER RETAIL IB",
}
# response_code mayoritas approved ("00"), sesekali anomali -- pola sama
# seperti ERROR=1 Robot Shop: minoritas realistis, bukan acak 50/50.
RESPONSE_CODES = ["00"] * 18 + ["05", "51"]

stan_counter = random.randint(100000, 199999)


def dummy_pan():
    prefix = random.choice(TEST_PAN_PREFIXES)
    return prefix + "".join(str(random.randint(0, 9)) for _ in range(10))


def next_stan():
    global stan_counter
    stan_counter = (stan_counter + 1) % 1000000
    return f"{stan_counter:06d}"


def encode(mti, fields):
    payload = {"mti": mti, **fields}
    proc = subprocess.run(
        [ISO8583TOOL, "encode"],
        input=json.dumps(payload) + "\n",
        capture_output=True,
        text=True,
        timeout=5,
    )
    line = proc.stdout.strip()
    if not line:
        raise RuntimeError(f"encode failed: {proc.stderr}")
    return line


def append_tag_message(target_log, seq, direction, raw_message):
    # Layout field: @TAG@ <seq> <len> <session_const=112>
    # <time> <direction:1=send|2=recv> <const=800000> <counter>.
    # `direction` HARUS di posisi ke-6 (parts[5] setelah split), bukan
    # ke-4 -- decoder (main.go) baca capture_direction dari parts[5].
    now = datetime.now(timezone.utc)
    tag_line = (
        f"@TAG@ {seq} {len(raw_message)} 112 "
        f"{now.strftime('%H:%M:%S.%f')} {direction} 800000 {seq}"
    )
    with open(target_log, "a") as f:
        f.write(tag_line + "\n")
        f.write(raw_message + "\n")
        f.flush()


def emit_transaction(seq):
    now = datetime.now(timezone.utc)
    proc_code = random.choice(list(PROCESSING_CODES.keys()))
    stan = next_stan()
    common = {
        "f2": dummy_pan(),
        "f3": proc_code,
        "f4": f"{random.randint(10000, 500000000):012d}",
        "f7": now.strftime("%m%d%H%M%S"),
        "f11": stan,
        "f12": now.strftime("%H%M%S"),
        "f13": now.strftime("%m%d"),
        "f37": now.strftime("%y%m%d") + stan,
        "f41": random.choice(TERMINALS),
        "f42": random.choice(MERCHANTS),
        "f49": "360",  # IDR
    }

    request_raw = encode("0200", common)
    append_tag_message(SEND_LOG, seq, "1", request_raw)

    response_fields = dict(common)
    response_fields["f39"] = random.choice(RESPONSE_CODES)
    response_raw = encode("0210", response_fields)
    append_tag_message(RECV_LOG, seq + 1, "2", response_raw)


def main():
    print(f"iso8583-switch log generator started (tool={ISO8583TOOL})", flush=True)
    seq = 1
    while True:
        try:
            emit_transaction(seq)
        except Exception as exc:  # noqa: BLE001 -- log & keep the switch alive
            print(f"emit_transaction error: {exc}", flush=True)
        seq += 2
        time.sleep(random.uniform(0.5, 2.0))


if __name__ == "__main__":
    main()
