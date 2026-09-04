# Bonus Sesi 3 — Query DSL dengan Data Live (ISO 8583)

> **Opsional.** Ini praktik TAMBAHAN, bukan pengganti materi utama di
> [`README.md`](../README.md). Teori Query DSL (`match`, `match_phrase`,
> `term`, `bool`) sudah dijelaskan di sana — di sini kamu praktikkan query
> yang sama pakai sumber data yang berbeda: transaksi kartu ISO 8583 yang
> mengalir LIVE, bukan `kibana_sample_data_ecommerce` yang statis.

## Kenapa ini beda dari materi utama

Data di sini **terus bertambah selama generator dijalankan**, dan
persentase transaksi approve/decline **acak ulang tiap siklus**. Konsekuensinya:
- Jumlah hits dari query kamu **TIDAK akan sama** dengan punya orang lain,
  atau bahkan beda tiap kamu jalankan ulang — itu **normal**, bukan tanda
  ada yang salah (pola yang sama dipakai untuk traffic Robot Shop di Sesi
  4/6/7 — data live memang begitu, beda dengan sample data statis).
- Fokus latihannya bukan "cocokkan angka pasti", tapi "pastikan query-mu
  menyaring kondisi yang benar" — cek manual beberapa dokumen hasil query
  untuk verifikasi logikanya, bukan cuma lihat angka `hits.total`.

## Setup

*(Prasyarat: stack Sesi 1 — Elasticsearch + Kibana — masih jalan.)*

**1. Nyalakan pipeline Logstash + Filebeat:**
```bash
cd lab/day-2-query-relevance/sesi-3-query-dsl/iso8583-bonus/
docker compose up -d
```

**2. Jalankan generator** (bikin transaksi ISO 8583 dummy secara live, lalu
diterjemahkan otomatis jadi JSON):
```bash
python3 generate_iso8583_stream.py --tx-per-minute 10
```
Biarkan terminal ini tetap terbuka (atau jalankan `nohup ... &` di
background) — script ini generate 10 transaksi/menit, ON 1 jam lalu jeda
1 jam, berulang terus. Tekan `Ctrl+C` kapan saja untuk berhenti.

**3. Buat Data View di Kibana** (sekali saja):
- Menu ☰ → **Stack Management → Data Views → Create data view**
- Index pattern: `iso8583-transactions-*`
- Timestamp field: `@timestamp`

## Field yang tersedia

| Field | Tipe | Contoh nilai |
|---|---|---|
| `transaction_id` | keyword | `TX00000012` |
| `message_type` | keyword | `request` atau `response` |
| `mti` | keyword | `0200` (request) / `0210` (response) |
| `transaction_type` | keyword | `purchase`, `cash_withdrawal`, `refund` |
| `amount` | float | `28243.26` |
| `pan_masked` | keyword | `601100******0144` (nomor kartu, di-mask) |
| `response_code` | keyword | `00` (approved), `05`/`14`/`51`/`91` (decline) — cuma ada di `message_type: response` |
| `response_description` | keyword | `approved`, `do_not_honor`, `insufficient_funds`, dst. |
| `approved` | boolean | `true`/`false` — cuma ada di `message_type: response` |
| `terminal_id`, `merchant_id`, `rrn`, `stan` | keyword | identitas transaksi |

## Contoh praktik Query DSL (Dev Tools Console)

**`term` — cari transaksi dengan kode approve tertentu:**
```
GET iso8583-transactions-*/_search
{ "query": { "term": { "response_code": "00" } } }
```

**`match` — cari berdasarkan jenis transaksi:**
```
GET iso8583-transactions-*/_search
{ "query": { "match": { "transaction_type": "cash_withdrawal" } } }
```

**`bool` — transaksi ditolak DENGAN nominal besar** (kombinasi filter,
kandidat bagus untuk latihan "temukan anomali" seperti pola exercise
Robot Shop di Sesi 6/7):
```
GET iso8583-transactions-*/_search
{
  "query": {
    "bool": {
      "must": [ { "term": { "approved": false } } ],
      "filter": [ { "range": { "amount": { "gt": 1000000 } } } ]
    }
  }
}
```

**Agregasi cepat — hitung approve vs decline** (pratinjau materi Sesi 5,
opsional dicoba di sini):
```
GET iso8583-transactions-*/_search
{
  "size": 0,
  "query": { "term": { "message_type": "response" } },
  "aggs": { "per_response": { "terms": { "field": "response_description" } } }
}
```

## Selesai praktik

`Ctrl+C` di terminal generator, lalu `docker compose down` di folder ini.
Elasticsearch + Kibana Sesi 1 **JANGAN** ikut dimatikan — masih dipakai
sesi-sesi berikutnya.
