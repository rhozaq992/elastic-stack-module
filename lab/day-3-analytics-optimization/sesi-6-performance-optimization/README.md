# Sesi 6 — Search Performance Optimization

## a. Tujuan Sesi

Setelah sesi ini, kamu mampu mengukur performa query Elasticsearch secara
nyata (bukan menebak), memahami cara kerja request cache, dan tahu
pengaturan index apa yang perlu disesuaikan saat proses bulk-loading data
besar berlangsung.

## b. Output yang Diharapkan

Sesi ini selesai kalau kamu berhasil mengukur & membandingkan `took` (waktu
eksekusi) query sebelum/sesudah cache aktif, menjalankan `_profile` API
untuk membedah waktu eksekusi query, dan mengubah `refresh_interval` index
lalu mengembalikannya ke semula.

## c. Teori & Struktur Sistem

Robot Shop yang sudah kamu jalankan di Sesi 4 sekarang diberi **traffic
nyata** memakai load generator bawaannya (Locust) — supaya kamu terbiasa
mengukur performa terhadap sistem yang benar-benar "hidup", bukan cuma
teori. Untuk latihan profiling & caching sendiri, kita pakai
`kibana_sample_data_logs` (14074 dokumen) — jauh lebih besar dari katalog
Robot Shop (cuma 11 produk), supaya perbedaan performanya benar-benar
terlihat.

**Tiga teknik optimasi yang dibahas sesi ini:**
- **Query profiling** (`_profile` API) — membedah SATU query, menunjukkan
  berapa lama tiap bagian internal (matching, scoring, dst.) makan waktu —
  dipakai untuk mendiagnosis query yang lambat.
- **Request cache** — Elasticsearch otomatis meng-cache hasil query yang
  identik (khususnya `size:0` dengan aggregation) — request kedua dengan
  query PERSIS sama jauh lebih cepat, sampai ada dokumen baru masuk (cache
  otomatis invalidasi).
- **Index settings saat bulk load** — `refresh_interval` (jarak waktu
  dokumen baru jadi bisa dicari) dan jumlah replica bisa disesuaikan
  sementara untuk mempercepat proses index besar-besaran.

## d. Praktik: Instalasi & Konfigurasi

*(Prasyarat: Robot Shop Sesi 4 masih jalan.)*

**Jalankan load generator** (traffic nyata ke Robot Shop, ~4% di antaranya
transaksi anomali — bahan latihan Sesi 8):
```bash
cd lab/day-3-analytics-optimization/sesi-6-performance-optimization
docker compose -f docker-compose.load.yml up -d
```
Expected Output (aktual, dari `docker logs -f <container>_load_1` setelah
beberapa menit): traffic asli mengalir ke `/api/user/login`,
`/api/catalogue/*`, `/api/shipping/confirm/*`, dst. (jumlahmu akan beda,
traffic Robot Shop random — lihat catatan di Sesi 4).

> **Temuan performa nyata (bukan cuma teori):** `NUM_CLIENTS` di
> `docker-compose.load.yml` sengaja diset **rendah (6)** — dicoba nyata
> dengan `NUM_CLIENTS: 20`, service `payment` (uwsgi, single worker process
> — lihat `[pid: 6|app: 0|...]` di log-nya) langsung kewalahan dan
> mengembalikan **HTTP 429** (Too Many Requests) untuk MAYORITAS
> request — bahkan di `NUM_CLIENTS: 6` pun 429 tetap muncul signifikan.
> Ini contoh nyata bottleneck performa: satu service dengan kapasitas
> concurrent request kecil, gejala persis yang mestinya kamu deteksi &
> selidiki di produksi sungguhan (lihat exercise Sesi 6 untuk latihan
> membedakan pola 429 "kapasitas" vs pola 500 "anomali transaksi").

Cek breakdown status code hasil traffic ini:
```
GET payment-service-parsed-*/_search
{ "size": 0, "aggs": { "by_status": { "terms": { "field": "http_status" } } } }
```
Expected Output (aktual, satu pengukuran nyata): `429: 133`, `200: 14`,
`500: 13` — **429 justru mendominasi**, bukan 200. Ini sinyal performa
nyata: `payment` (uwsgi single-worker) adalah bottleneck di topologi Robot
Shop ini begitu ada beberapa request concurrent.

**Ukur query TANPA cache (request pertama):**
```
GET kibana_sample_data_logs/_search
{ "size": 0, "query": { "bool": { "filter": [ { "range": { "bytes": { "gt": 5000 } } } ] } } }
```
Expected Output (aktual): `"took": 3` (ms), `"hits":{"total":{"value":7696}}`.

**Jalankan query PERSIS SAMA lagi:**
```
GET kibana_sample_data_logs/_search
{ "size": 0, "query": { "bool": { "filter": [ { "range": { "bytes": { "gt": 5000 } } } ] } } }
```
Expected Output (aktual): `"took": 0` (ms) — request cache Elasticsearch
langsung mengembalikan hasil tanpa eksekusi ulang. Cek statistiknya:
```
GET kibana_sample_data_logs/_stats/request_cache
```
Expected Output (aktual): `hit_count: 1`, `miss_count: 4` (angka `miss`
lebih dari 1 karena tiap shard punya cache-nya sendiri).

## e. Contoh Implementasi

**`_profile` API** — membedah query yang sama, lihat waktu eksekusi internal:
```
GET kibana_sample_data_logs/_search
{
  "profile": true,
  "size": 0,
  "query": { "bool": { "filter": [ { "range": { "bytes": { "gt": 5000 } } } ] } }
}
```
Expected Output (aktual): `profile.shards[0].searches[0].query[0]` berisi
`"type": "ConstantScoreQuery"`, `"time_in_nanos": 299250` (~0.3ms), dan
`breakdown` — rincian per operasi internal (`match_count`,
`next_doc`, dst.). Query kompleks/lambat akan menunjukkan operasi mana
yang paling banyak makan waktu lewat breakdown ini.

**Ubah `refresh_interval` sebelum bulk load besar** (index baru butuh
waktu ~1 detik default sebelum dokumen bisa dicari — kalau kamu mau bulk
index jutaan dokumen, menaikkan interval ini mengurangi overhead):
```
PUT kibana_sample_data_logs/_settings
{ "index": { "refresh_interval": "30s" } }
```
Expected Output (aktual): `{"acknowledged":true}`. **Setelah bulk load
selesai, WAJIB dikembalikan** ke default (atau nilai produksi normal),
supaya data baru kembali cepat muncul di pencarian:
```
PUT kibana_sample_data_logs/_settings
{ "index": { "refresh_interval": "1s" } }
```

## f. Referensi Exercise

Lanjutkan latihan mandiri di [`exercise/sesi-6/README.md`](../../../exercise/sesi-6/README.md)
— termasuk latihan mendeteksi transaksi anomali dari traffic Robot Shop
yang barusan kamu jalankan.
