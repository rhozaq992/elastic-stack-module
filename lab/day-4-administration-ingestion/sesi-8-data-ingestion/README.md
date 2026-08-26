# Sesi 8 — Data Ingestion with Logstash & Beats

## a. Tujuan Sesi

Setelah sesi ini, kamu mampu membangun pipeline ingestion data dari sumber
nyata (log container Robot Shop) ke Elasticsearch memakai Filebeat +
Logstash, termasuk parsing 3 format log yang berbeda (grok manual, JSON,
dan format standar industri).

## b. Output yang Diharapkan

Sesi ini selesai kalau index `payment-service-parsed-*`,
`cart-service-parsed-*`, dan `web-service-parsed-*` terisi dokumen nyata
dari log Robot Shop, dengan field yang benar ter-extract (bukan `null`).

## c. Teori & Struktur Sistem

**Kenapa Filebeat DAN Logstash, bukan salah satu saja?** Logstash secara
desain **menolak dijalankan sebagai root** (`Logstash cannot be run as
superuser`), sementara direktori log container di host
(`/var/lib/docker/containers`) cuma bisa dibaca oleh root. Filebeat, di
sisi lain, memang didesain bisa jalan sebagai root dengan aman. Solusinya:
**Filebeat (root) baca file log** → kirim lewat network (port beats 5044)
→ **Logstash (non-root) yang parsing** → Elasticsearch. Logstash sendiri
tidak pernah menyentuh filesystem host.

```
Filebeat (root, baca /var/lib/docker/containers)
  --output.logstash-->  Logstash (non-root, port 5044)
    --filter (grok/json per service)-->  Elasticsearch (single-node Sesi 1)
```

> **Kenapa balik ke single-node Sesi 1, bukan lanjut cluster 3-node
> Sesi 7?** Dites nyata: menjalankan cluster 3-node Sesi 7 BERSAMAAN
> dengan Robot Shop (Sesi 4) + load generator (Sesi 6) + pipeline sesi ini
> sekaligus butuh RAM lebih dari yang tersedia di banyak laptop — pada
> pengujian ini bahkan sampai bikin salah satu node ES mati ke-OOM-kill
> Docker. Sesi 7 sengaja jadi modul MANDIRI (boleh kamu matikan setelah
> selesai) — Sesi 8 lanjut pakai cluster single-node yang sama dari Sesi
> 1-6, jauh lebih ringan. Kalau kamu sudah selesai Sesi 7 dan cluster
> 3-node-nya masih jalan, matikan dulu sebelum lanjut ke sesi ini:
> `docker compose -f lab/day-4-administration-ingestion/sesi-7-administration-scaling/docker-compose.yml down`.

**Grok** = filter Logstash untuk mengekstrak field terstruktur dari teks
bebas pakai named-pattern (`%{PATTERN:nama_field}`, opsional `:tipe` untuk
cast, mis. `%{NUMBER:amount:float}`). Dokumen yang gagal di-match grok
ditandai lewat `tag_on_failure` (lihat masing-masing file `.conf`) — cek
field `tags` di ES kalau field yang diharapkan kosong.

**Tiga teknik parsing berbeda dipakai sesi ini** (lihat 3 file `.conf` di
`logstash/pipeline/`):
- `payment-service.conf` — log plain-text tidak terstruktur → **grok manual**.
- `cart-service.conf` — log sudah berbentuk JSON dari aplikasinya sendiri → **JSON filter**.
- `web-service.conf` — log format standar Apache/Nginx Combined Log Format
  → **grok pattern bawaan** (`%{COMBINEDAPACHELOG}`), tidak perlu tulis regex sendiri.

## d. Praktik: Instalasi & Konfigurasi

*(Prasyarat: stack single-node Sesi 1 dan Robot Shop Sesi 4 masih jalan.
Traffic dari load generator Sesi 6 sebaiknya masih mengalir supaya ada log
untuk di-parsing.)*

```bash
cd lab/day-4-administration-ingestion/sesi-8-data-ingestion
docker compose up -d
```

**Generate traffic** (kalau load generator Sesi 6 belum jalan):
```bash
docker start sesi-6-performance-optimization-load-1
```

**Cek data masuk** (tunggu beberapa menit supaya ada cukup log):
```bash
curl "http://localhost:9200/payment-service-parsed-*/_count"
curl "http://localhost:9200/cart-service-parsed-*/_count"
curl "http://localhost:9200/web-service-parsed-*/_count"
```
Expected Output (aktual, satu pengukuran nyata — angkamu akan beda,
tergantung berapa lama traffic sudah mengalir):
```
payment-service-parsed-*: 322
cart-service-parsed-*: 2206
web-service-parsed-*: 3138
```

## e. Contoh Implementasi

**Cek hasil parsing payment** (grok manual):
```
GET payment-service-parsed-*/_search
{ "query": { "exists": { "field": "http_status" } }, "size": 1 }
```
Expected Output (aktual) — field `payment_user`, `http_status`,
`response_time_ms`, `response_bytes` ter-extract dari baris log plain-text:
```json
{
  "payment_user": "anonymous-30",
  "http_status": 200,
  "response_time_ms": 588.0,
  "response_bytes": "51",
  "log_type": "payment_access"
}
```

**Cari transaksi anomali.** Traffic Robot Shop di sesi ini sebenarnya
punya DUA pola "tidak normal" yang berbeda sifatnya (lihat catatan
performa di Sesi 6):
```
GET payment-service-parsed-*/_search
{ "size": 0, "aggs": { "by_status": { "terms": { "field": "http_status" } } } }
```
Expected Output (aktual): `429: 133`, `200: 14`, `500: 13`. Breakdown per
`payment_user` untuk masing-masing status menunjukkan pola yang SANGAT
berbeda:
```
GET payment-service-parsed-*/_search
{ "size": 0, "query": { "term": { "http_status": 500 } },
  "aggs": { "by_user": { "terms": { "field": "payment_user.keyword" } } } }
```
Expected Output (aktual): **SEMUA 13 dokumen `http_status: 500` berasal
dari SATU user id yang sama, `partner-57`** — bukan pola `anonymous-N`
normal. Ini transaksi yang sengaja disuntik (fitur `ERROR=1` load
generator, lihat Sesi 6) — pola KONSENTRASI pada satu identitas
mencurigakan adalah tanda anomali/fraud.

Bandingkan dengan `http_status: 429` — breakdown per user menunjukkan **133
dokumen TERSEBAR ke ~130 user id `anonymous-N` yang berbeda-beda** (masing-
masing cuma 1 kejadian) — ini BUKAN anomali/fraud, tapi tanda **kapasitas
service kewalahan** (lihat Sesi 6): banyak user LEGITIMATE yang kebetulan
sama-sama gagal karena `payment` tidak sanggup menampung request
bersamaan. Dua pola yang sama-sama "tidak normal", tapi butuh respons
berbeda — 500 butuh investigasi keamanan, 429 butuh perbaikan kapasitas/scaling.

## f. Referensi Exercise

Lanjutkan latihan mandiri di [`exercise/sesi-8/README.md`](../../../exercise/sesi-8/README.md)
— termasuk latihan deteksi transaksi anomali secara lengkap.
