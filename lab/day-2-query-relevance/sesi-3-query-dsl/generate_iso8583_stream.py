#!/usr/bin/env python3
"""
Generator + parser ISO 8583 versi STREAMING untuk latihan pipeline:
  sistem generate raw ISO 8583 -> translator parse ke JSON -> Filebeat tail -> ELK

Pola traffic: N transaksi/menit, ON selama X detik, lalu OFF (jeda, tidak ada
transaksi) selama Y detik, berulang terus (siklus). Tiap siklus ON, persentase
approve/decline di-random ulang supaya karakter traffic tiap jam berbeda.

File output di-APPEND terus menerus (bukan ditimpa) supaya bisa langsung
di-tail Filebeat seperti log yang benar-benar hidup:
  raw_switch_capture.log     -> raw message (hex bytes), simulasi keluaran switch/ATM
  parsed_transactions.jsonl  -> hasil terjemahan (satu JSON per baris)

Jalankan:
  python3 generate_iso8583_stream.py                     # default: 2 tx/menit, ON 1 jam, OFF 1 jam, tanpa batas
  python3 generate_iso8583_stream.py --demo               # versi cepat buat verifikasi (ON 15s, OFF 8s, 2 siklus)
  python3 generate_iso8583_stream.py --cycles 3            # berhenti otomatis setelah 3 siklus ON
  nohup python3 generate_iso8583_stream.py > stream.out 2>&1 &   # jalan di background beneran
"""

import argparse
import json
import random
import time
from datetime import datetime, timezone

# ---------------------------------------------------------------------------
# Kamus Data Element (subset yang lazim dipakai di lab/training)
# ---------------------------------------------------------------------------
FIELD_SPECS = {
    2:  ("pan",                  "llvar", 19, "n"),
    3:  ("processing_code",      "fixed", 6,  "n"),
    4:  ("amount_transaction",   "fixed", 12, "n"),
    7:  ("transmission_datetime","fixed", 10, "n"),
    11: ("stan",                 "fixed", 6,  "n"),
    12: ("local_time",           "fixed", 6,  "n"),
    13: ("local_date",           "fixed", 4,  "n"),
    22: ("pos_entry_mode",       "fixed", 3,  "n"),
    37: ("rrn",                  "fixed", 12, "a"),
    38: ("auth_id_response",     "fixed", 6,  "a"),
    39: ("response_code",        "fixed", 2,  "n"),
    41: ("terminal_id",          "fixed", 8,  "a"),
    42: ("merchant_id",          "fixed", 15, "a"),
    49: ("currency_code",        "fixed", 3,  "n"),
}

PROCESSING_CODES = {
    "000000": "purchase",
    "010000": "cash_withdrawal",
    "200000": "refund",
}

# response code -> (deskripsi, approved?) -- "00" approved, sisanya alasan decline
DECLINE_CODES = {
    "05": "do_not_honor",
    "14": "invalid_card_number",
    "51": "insufficient_funds",
    "91": "issuer_or_switch_inoperative",
}

BIN_PREFIXES = ["455673", "521234", "400123", "601100"]  # contoh BIN, bukan BIN asli bank manapun


# --- encode/decode ISO 8583 (sama seperti versi batch) --------------------

def build_bitmap(des_present):
    bits = ["0"] * 64
    for de in des_present:
        bits[de - 1] = "1"
    return "%016X" % int("".join(bits), 2)


def parse_bitmap(hex_bitmap):
    binary = bin(int(hex_bitmap, 16))[2:].zfill(64)
    return [i + 1 for i, b in enumerate(binary) if b == "1"]


def encode_field(de, value):
    name, ftype, length, kind = FIELD_SPECS[de]
    value = str(value)
    if ftype == "llvar":
        return "%02d" % len(value) + value
    if kind == "n":
        return value.zfill(length)[-length:]
    return value.ljust(length)[:length]


def decode_field(de, raw, pos):
    name, ftype, length, kind = FIELD_SPECS[de]
    if ftype == "llvar":
        var_len = int(raw[pos:pos + 2])
        pos += 2
        value = raw[pos:pos + var_len]
        pos += var_len
        return name, value, pos
    value = raw[pos:pos + length]
    pos += length
    return name, value.strip(), pos


def encode_message(mti, fields):
    des = sorted(fields.keys())
    bitmap = build_bitmap(des)
    body = "".join(encode_field(de, fields[de]) for de in des)
    return mti + bitmap + body


def decode_message(raw):
    mti = raw[0:4]
    bitmap_hex = raw[4:20]
    des = parse_bitmap(bitmap_hex)
    pos = 20
    fields = {}
    for de in des:
        name, value, pos = decode_field(de, raw, pos)
        fields[name] = value
    return {"mti": mti, "bitmap": bitmap_hex, "fields": fields}


def mask_pan(pan):
    if len(pan) <= 10:
        return "*" * len(pan)
    return pan[:6] + "*" * (len(pan) - 10) + pan[-4:]


def random_pan():
    bin_prefix = random.choice(BIN_PREFIXES)
    rest_len = random.choice([16, 16, 16, 19]) - len(bin_prefix)
    return bin_prefix + "".join(str(random.randint(0, 9)) for _ in range(rest_len))


def to_ascii_hex(raw_message):
    payload = raw_message.encode("ascii")
    length_header = len(payload).to_bytes(2, "big")
    return (length_header + payload).hex()


def parse_ascii_hex(hex_str):
    raw_bytes = bytes.fromhex(hex_str)
    length = int.from_bytes(raw_bytes[0:2], "big")
    return raw_bytes[2:2 + length].decode("ascii")


def build_json_record(decoded, message_type, tx_time, transaction_id):
    f = decoded["fields"]
    processing_code = f.get("processing_code")
    resp_code = f.get("response_code")
    record = {
        "@timestamp": tx_time.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z"),
        "transaction_id": transaction_id,
        "message_type": message_type,
        "mti": decoded["mti"],
        "pan_masked": mask_pan(f["pan"]) if "pan" in f else None,
        "processing_code": processing_code,
        "transaction_type": PROCESSING_CODES.get(processing_code, "unknown"),
        "amount": int(f["amount_transaction"]) / 100 if "amount_transaction" in f else None,
        "currency_code": f.get("currency_code"),
        "stan": f.get("stan"),
        "rrn": f.get("rrn"),
        "terminal_id": f.get("terminal_id"),
        "merchant_id": f.get("merchant_id", "").strip() if "merchant_id" in f else None,
        "pos_entry_mode": f.get("pos_entry_mode"),
    }
    if message_type == "response":
        approved = resp_code == "00"
        record["response_code"] = resp_code
        record["response_description"] = "approved" if approved else DECLINE_CODES.get(resp_code, "unknown")
        record["approved"] = approved
        record["auth_id_response"] = f.get("auth_id_response", "").strip()
    return record


# --- pemilihan response code per siklus (persentase di-random ulang tiap ON) --

def roll_cycle_distribution(approve_min, approve_max):
    """Kembalikan (approve_rate, {decline_code: share}) untuk satu siklus ON."""
    approve_rate = random.uniform(approve_min, approve_max)
    decline_total = 1 - approve_rate
    raw_weights = [random.random() for _ in DECLINE_CODES]
    weight_sum = sum(raw_weights) or 1
    decline_shares = {
        code: (w / weight_sum) * decline_total
        for code, w in zip(DECLINE_CODES.keys(), raw_weights)
    }
    return approve_rate, decline_shares


def pick_response_code(approve_rate, decline_shares):
    roll = random.random()
    if roll < approve_rate:
        return "00"
    cumulative = approve_rate
    for code, share in decline_shares.items():
        cumulative += share
        if roll < cumulative:
            return code
    return "00"  # fallback pembulatan


# --- generate satu transaksi ------------------------------------------------

def generate_transaction(seq, tx_time, approve_rate, decline_shares):
    processing_code = random.choice(list(PROCESSING_CODES.keys()))
    amount = random.randint(1000, 5_000_000)
    stan = "%06d" % (seq % 1_000_000)
    terminal_id = "ATM%05d" % random.randint(1, 99)
    merchant_id = ("MERCH%09d" % random.randint(1, 999999999))[:15]
    rrn = tx_time.strftime("%y%j") + "%06d" % (seq % 1_000_000)
    pan = random_pan()

    common = {
        2: pan, 3: processing_code, 4: "%012d" % amount,
        7: tx_time.strftime("%m%d%H%M%S"), 11: stan,
        12: tx_time.strftime("%H%M%S"), 13: tx_time.strftime("%m%d"),
        22: "051", 37: rrn, 41: terminal_id, 42: merchant_id, 49: "360",
    }

    request_raw = encode_message("0200", common)

    resp_code = pick_response_code(approve_rate, decline_shares)
    response_fields = dict(common)
    response_fields[39] = resp_code
    response_fields[38] = ("APR" + "%03d" % (seq % 1000)) if resp_code == "00" else "      "
    response_raw = encode_message("0210", response_fields)

    return request_raw, response_raw


# --- loop streaming utama ---------------------------------------------------

def run_stream(args):
    interval = 60.0 / args.tx_per_minute
    raw_path = f"{args.out_dir}/raw_switch_capture.log"
    json_path = f"{args.out_dir}/parsed_transactions.jsonl"

    seq = 0
    cycle = 0
    try:
        while args.cycles == 0 or cycle < args.cycles:
            cycle += 1
            approve_rate, decline_shares = roll_cycle_distribution(args.approve_min, args.approve_max)
            dist_str = ", ".join(f"{c}={s:.1%}" for c, s in decline_shares.items())
            print(f"[{datetime.now().isoformat(timespec='seconds')}] Cycle {cycle} ON selama {args.on_seconds}s "
                  f"| approve={approve_rate:.1%} | decline: {dist_str}", flush=True)

            cycle_end = time.time() + args.on_seconds
            with open(raw_path, "a") as rf, open(json_path, "a") as jf:
                while time.time() < cycle_end:
                    seq += 1
                    tx_time = datetime.now()
                    transaction_id = f"TX{seq:08d}"
                    request_raw, response_raw = generate_transaction(seq, tx_time, approve_rate, decline_shares)

                    req_hex = to_ascii_hex(request_raw)
                    resp_hex = to_ascii_hex(response_raw)
                    rf.write(f"{tx_time.isoformat()}Z REQUEST  len={len(request_raw)} hex={req_hex}\n")
                    rf.write(f"{tx_time.isoformat()}Z RESPONSE len={len(response_raw)} hex={resp_hex}\n")
                    rf.flush()

                    decoded_req = decode_message(parse_ascii_hex(req_hex))
                    decoded_resp = decode_message(parse_ascii_hex(resp_hex))
                    jf.write(json.dumps(build_json_record(decoded_req, "request", tx_time, transaction_id)) + "\n")
                    jf.write(json.dumps(build_json_record(decoded_resp, "response", tx_time, transaction_id)) + "\n")
                    jf.flush()

                    time.sleep(interval)

            if args.cycles == 0 or cycle < args.cycles:
                print(f"[{datetime.now().isoformat(timespec='seconds')}] Cycle {cycle} OFF (jeda) selama {args.off_seconds}s", flush=True)
                time.sleep(args.off_seconds)
    except KeyboardInterrupt:
        print("\nDihentikan oleh user (Ctrl+C). Total transaksi ter-generate:", seq)


def parse_args():
    p = argparse.ArgumentParser(description="Streaming generator sample data ISO 8583")
    p.add_argument("--tx-per-minute", type=float, default=2)
    p.add_argument("--on-seconds", type=int, default=3600)
    p.add_argument("--off-seconds", type=int, default=3600)
    p.add_argument("--cycles", type=int, default=0, help="0 = tanpa batas (jalan terus sampai di-stop)")
    p.add_argument("--approve-min", type=float, default=0.65)
    p.add_argument("--approve-max", type=float, default=0.95)
    p.add_argument("--out-dir", default=".")
    p.add_argument("--demo", action="store_true", help="mode cepat buat verifikasi: ON 15s, OFF 8s, 2 siklus, 60 tx/menit")
    args = p.parse_args()
    if args.demo:
        args.on_seconds, args.off_seconds, args.cycles, args.tx_per_minute = 15, 8, 2, 60
    return args


if __name__ == "__main__":
    run_stream(parse_args())
