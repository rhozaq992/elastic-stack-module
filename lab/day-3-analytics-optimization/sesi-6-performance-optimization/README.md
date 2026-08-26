# Sesi 6 — Search Performance Optimization

## a. Tujuan Sesi

Setelah sesi ini, kamu mampu mengukur performa query Elasticsearch secara
nyata (bukan menebak), memahami cara kerja request cache, tahu pengaturan
index apa yang perlu disesuaikan saat bulk-loading data besar, DAN
memahami APM (Application Performance Monitoring) — cara melihat latency
tiap microservice secara individual untuk tahu persis servis mana yang
lambat, bukan cuma menduga dari gejala di permukaan.

## b. Output yang Diharapkan

Sesi ini selesai kalau kamu berhasil mengukur & membandingkan `took`
(waktu eksekusi) query sebelum/sesudah cache aktif, menjalankan `_profile`
API untuk membedah waktu eksekusi query, mengubah `refresh_interval` index
lalu mengembalikannya ke semula, DAN melihat di Kibana APM **Service
Inventory** bahwa service `cart` dan `payment` tampil dengan angka latency
yang jauh berbeda — kamu bisa sebutkan mana yang lebih lambat dan berapa
kira-kira selisihnya.

## c. Teori & Struktur Sistem

Robot Shop sesi ini **BUKAN** reuse dari Sesi 4 — sesi ini punya stack
Robot Shop sendiri (lihat bagian d), di mana dua service (`cart` dan
`payment`) sudah disisipi **Elastic APM agent**. Traffic dari load
generator (Locust) yang mengalir ke keduanya sekarang benar-benar
**terpakai**: setiap request yang diproses menghasilkan data trace yang
tersimpan di Elasticsearch dan bisa kamu analisis — bukan cuma lewat di
log lalu hilang seperti sebelumnya.

**Apa itu APM?** Application Performance Monitoring — cara mengukur
seberapa cepat/lambat aplikasi merespons, DI DALAM kode aplikasi itu
sendiri (beda dari mengukur dari luar seperti curl timing). Untuk sistem
microservice (seperti Robot Shop, 12 service saling panggil lewat HTTP),
APM sangat penting karena satu request pengguna bisa melewati BANYAK
service — tanpa APM, kalau checkout terasa lambat, kamu cuma tahu
"checkout lambat", tidak tahu APAKAH itu `cart`, `payment`, `shipping`,
atau kombinasi ketiganya.

**Cara kerja APM di stack ini:**
```
[cart / payment]  --trace-->  [apm-server:8200]  -->  [Elasticsearch]  <--  [Kibana APM UI]
  (APM agent                   (terima data,           (index                (baca &
   di dalam kode)                kirim ke ES)            traces-apm-*,         visualisasi)
                                                          metrics-apm-*)
```
1. **APM agent** — library kecil yang di-install DI DALAM kode aplikasi
   (satu per bahasa pemrograman: Python, Node.js, Java, dst). Tugasnya:
   catat setiap request masuk (disebut **transaction**) dan setiap
   operasi di dalamnya (disebut **span** — mis. query database, panggil
   API lain) beserta durasinya, lalu kirim data itu ke APM Server.
2. **APM Server** — komponen terpisah (container `apm-server` di sesi
   ini) yang menerima data dari semua agent, lalu menyimpannya ke
   Elasticsearch sebagai index `traces-apm-*` (per transaction/span) dan
   `metrics-apm-*` (metrik teragregasi per menit).
3. **Kibana APM UI** (menu ☰ → Observability → APM) — baca index-index
   itu, tampilkan sebagai tabel per-service, grafik latency, dan detail
   per transaksi — tanpa kamu perlu nulis query manual (walau datanya
   tetap bisa di-query manual seperti index lain, lihat bagian e).

**Kenapa cuma `cart` dan `payment`** (bukan semua 12 service)? Supaya
sesi ini tetap fokus dan cepat — dua service ini representatif: `cart`
(Node.js, operasi ringan ke Redis) vs `payment` (Python, operasi lebih
berat termasuk panggilan HTTP keluar) — perbandingan keduanya sudah cukup
untuk menunjukkan konsep "per-service latency" dengan jelas.

**Tiga teknik optimasi lain yang tetap dibahas sesi ini** (pakai
`kibana_sample_data_logs`, dataset besar & deterministik supaya angkanya
konsisten untuk belajar konsepnya dulu — sebelum diterapkan ke data
trace APM kamu sendiri yang jumlahnya tidak pasti di bagian e):
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

**[Terminal] Matikan dulu Robot Shop Sesi 4** (sesi ini bawa stack Robot
Shop sendiri dengan 2 service ber-APM — menjalankan dua Robot Shop
sekaligus cuma membebani resource host tanpa manfaat tambahan):
```bash
cd lab/day-2-query-relevance/sesi-4-relevance-scoring
docker compose down
```

**[Terminal] Jalankan Robot Shop + APM Server milik sesi ini:**
```bash
cd lab/day-3-analytics-optimization/sesi-6-performance-optimization
docker compose up -d
```
**Kalau laptopmu ARM (Apple Silicon)**, pakai command ini SEBAGAI GANTI
yang di atas (sama alasannya seperti Sesi 4 — base image `mysql`):
```bash
docker compose -f docker-compose.yml -f docker-compose.arm64-override.yml up -d
```
Tunggu semua service `healthy` (`docker compose ps`) — termasuk
`shipping`/`ratings` yang butuh waktu lebih lama saat MySQL inisialisasi
pertama kali (lihat Sesi 4 kalau butuh mengingat detailnya).

**[Terminal] Jalankan load generator** (traffic nyata ke Robot Shop, ~4% di
antaranya transaksi anomali — bahan latihan Sesi 8 — DAN sekarang jadi
sumber data trace APM untuk `cart`/`payment`):
```bash
docker compose -f docker-compose.yml -f docker-compose.load.yml up -d load
```
Expected Output (dari `docker compose logs -f load` setelah
beberapa menit): traffic asli mengalir ke `/api/user/login`,
`/api/catalogue/*`, `/api/shipping/confirm/*`, dst. (jumlahmu akan beda,
traffic Robot Shop random — lihat catatan di Sesi 4).

> **Catatan performa (perilaku bisa beda tergantung host):** `NUM_CLIENTS`
> di `docker-compose.load.yml` sengaja diset rendah (6), bukan tinggi —
> `payment` (uwsgi, single worker process, lihat `[pid: 6|app: 0|...]` di
> log-nya) cuma punya kapasitas concurrent request yang kecil. Di
> pengujian instruktur (host dengan beban Docker lain berjalan bersamaan),
> ini menyebabkan `payment` mengembalikan **HTTP 429** (Too Many Requests)
> untuk sebagian besar request. **Tapi ini TIDAK selalu terjadi** — di host
> yang lebih lega (CPU/RAM cukup, tidak banyak proses lain jalan
> bersamaan), uwsgi mungkin sanggup menangani `NUM_CLIENTS: 6` tanpa
> masalah sama sekali, dan traffic-nya akan 100% `200`. Kalau itu yang
> terjadi di laptopmu, itu bukan kegagalan — itu justru bukti sistemnya
> punya cukup kapasitas untuk beban ini.
>
> Kamu baru bisa VERIFIKASI status code traffic ini secara nyata di
> **Sesi 8** — index `payment-service-parsed-*` yang berisi field
> `http_status` baru dibuat oleh pipeline Logstash yang kamu bangun di
> sesi itu, belum ada di titik ini. Ingat baik-baik apakah traffic-mu tadi
> lancar (kemungkinan besar semua `200`) atau banyak macet — kamu akan
> cek ulang nyata di Sesi 8 begitu pipeline-nya siap.

**[Dev Tools Console] Ukur query TANPA cache (request pertama):**
```
GET kibana_sample_data_logs/_search
{ "size": 0, "query": { "bool": { "filter": [ { "range": { "bytes": { "gt": 5000 } } } ] } } }
```
Expected Output: `"took": 3` (ms), `"hits":{"total":{"value":7696}}`.
`hits.total.value` akan selalu persis `7696` (data sample statis, tidak
tergantung waktu) — tapi angka `took` sendiri bisa beda beberapa ms di
laptopmu (tergantung beban CPU/proses lain yang jalan bersamaan), itu
normal.

**Jalankan query PERSIS SAMA lagi:**
```
GET kibana_sample_data_logs/_search
{ "size": 0, "query": { "bool": { "filter": [ { "range": { "bytes": { "gt": 5000 } } } ] } } }
```
Expected Output: `"took": 0` (ms) — request cache Elasticsearch
langsung mengembalikan hasil tanpa eksekusi ulang. **Query ini memang
sudah sangat cepat dari awal**, jadi `took` kadang TIDAK terlihat turun
banyak (bisa saja masih 1-2ms) — bukti yang lebih diandalkan adalah
statistik cache-nya langsung, bukan cuma `took`:
```
GET kibana_sample_data_logs/_stats/request_cache
```
Expected Output: `hit_count: 1`, `miss_count: 4` (angka `miss`
lebih dari 1 karena tiap shard punya cache-nya sendiri).

## e. Contoh Implementasi

### Melihat Latency per Microservice Lewat APM

**Cara install APM agent** (contoh nyata, dua bahasa berbeda — kamu TIDAK
perlu menjalankan ini sendiri, `cart`/`payment` di stack sesi ini sudah
disiapkan begitu; ini referensi kalau nanti kamu instrumentasi aplikasimu
sendiri). Pola umumnya SAMA di semua bahasa: agent di-`start()` di titik
paling awal aplikasi, diberi `serverUrl` APM Server tujuan.

Python (Flask) — `payment`:
```python
from elasticapm.contrib.flask import ElasticAPM

app = Flask(__name__)
app.config['ELASTIC_APM'] = {
    'SERVICE_NAME': 'payment',
    'SERVER_URL': 'http://apm-server:8200',
    'ENVIRONMENT': 'training',
}
apm = ElasticAPM(app)
```

Node.js (Express) — `cart`:
```javascript
// WAJIB baris PALING ATAS file, sebelum require() lain
require('elastic-apm-node').start({
    serviceName: 'cart',
    serverUrl: 'http://apm-server:8200',
    environment: 'training'
});
```

Begitu agent aktif, SETIAP request yang masuk ke `cart`/`payment` otomatis
tercatat sebagai **transaction** — tidak perlu kode tambahan apa pun di
tiap endpoint.

**Buka Kibana APM** (menu ☰ → Observability → APM → Service inventory):

![Kibana APM Service inventory menampilkan service cart dan payment dengan kolom latency, throughput, failed transaction rate](../../../docs/screenshots/sesi-6/01-apm-service-inventory.png)

*Dua service muncul otomatis — `cart` (ikon Node.js) dan `payment` (ikon
Python) — kolom **Latency (avg.)** menunjukkan `payment` jauh lebih
lambat dari `cart` (bedanya bisa puluhan-ratusan kali lipat, tergantung
berapa lama load generator sudah jalan di laptopmu — coba refresh setelah
beberapa menit kalau baru mulai). Ini PERSIS pertanyaan "servis mana yang
lambat" yang tidak bisa dijawab cuma dari log biasa.*

**Klik salah satu service** (mis. `payment`) untuk detail:

![Halaman detail service payment di Kibana APM menampilkan grafik latency, throughput, dan failed transaction rate](../../../docs/screenshots/sesi-6/02-apm-payment-overview.png)

*Tab **Overview** — grafik latency & throughput dari waktu ke waktu, plus
tab **Transactions** untuk lihat breakdown per-endpoint (`POST /pay/<id>`
dst.), **Dependencies** untuk lihat apa yang dipanggil service ini keluar
(database, service lain), dan **Errors** untuk exception yang tertangkap.*

![Detail transaksi POST /pay/id menampilkan breakdown time spent by span type, mayoritas di kategori http](../../../docs/screenshots/sesi-6/03-apm-transaction-detail.png)

*Klik transaksi tertentu (mis. `POST /pay/<id>`) — panel **"Time spent by
span type"** ini yang menjawab PERTANYAAN LANJUTAN "kenapa lambat":
kalau mayoritas waktu ada di kategori `app` (kode aplikasi sendiri),
optimasi ada di kode; kalau mayoritas di `http`/`db` (panggilan keluar),
masalahnya ada di service/dependency lain yang dipanggil — bukan di
`payment` sendiri.*

**Query data trace-nya langsung** (APM Server menyimpannya sebagai index
Elasticsearch biasa — bisa di-query seperti index lain, ini yang membuat
traffic load generator akhirnya "terpakai" untuk latihan aggregation
juga):
```
GET traces-apm-default/_search
{
  "size": 0,
  "aggs": {
    "by_service": {
      "terms": { "field": "service.name" },
      "aggs": {
        "avg_duration_ms": { "avg": { "field": "transaction.duration.us", "script": "_value / 1000" } }
      }
    }
  }
}
```
Expected Output (pola-nya — angka pastimu tergantung berapa lama
load generator sudah jalan): dua bucket, `cart` dengan
`avg_duration_ms` di kisaran satuan milidetik, `payment` di kisaran
ratusan milidetik — konsisten dengan yang tampil di Service Inventory di atas.

### Tiga Teknik Optimasi Query (`kibana_sample_data_logs`)

**[Dev Tools Console] `_profile` API** — membedah query yang sama, lihat waktu eksekusi internal:
```
GET kibana_sample_data_logs/_search
{
  "profile": true,
  "size": 0,
  "query": { "bool": { "filter": [ { "range": { "bytes": { "gt": 5000 } } } ] } }
}
```
Expected Output: `profile.shards[0].searches[0].query[0]` berisi
`"type": "ConstantScoreQuery"`, `"time_in_nanos"` di kisaran ratusan ribu
(sub-milidetik — contoh: `299250` ≈ 0.3ms, angka persisnya bergantung
beban host-mu saat itu), dan `breakdown` — rincian per operasi internal
(`match_count`, `next_doc`, dst.). Query kompleks/lambat akan menunjukkan
operasi mana yang paling banyak makan waktu lewat breakdown ini.

**Ubah `refresh_interval` sebelum bulk load besar** (index baru butuh
waktu ~1 detik default sebelum dokumen bisa dicari — kalau kamu mau bulk
index jutaan dokumen, menaikkan interval ini mengurangi overhead):
```
PUT kibana_sample_data_logs/_settings
{ "index": { "refresh_interval": "30s" } }
```
Expected Output: `{"acknowledged":true}`. **Setelah bulk load
selesai, WAJIB dikembalikan** ke default (atau nilai produksi normal),
supaya data baru kembali cepat muncul di pencarian:
```
PUT kibana_sample_data_logs/_settings
{ "index": { "refresh_interval": "1s" } }
```

**Lihat semua index dari satu tempat** — Kibana **Stack Management → Index
Management** menampilkan seluruh index di cluster sekaligus (health, status,
jumlah dokumen, ukuran storage) — cara cepat cek index mana yang paling
besar/perlu dioptimasi:

![Kibana Index Management menampilkan daftar seluruh index lab dengan document count dan storage size](../../../docs/screenshots/sesi-6/01-index-management.png)

*Stack Management → Index Management → Indices — semua index yang sudah
kamu buat sepanjang lab ini (sample data, hasil pipeline, index exercise)
terlihat sekaligus di sini.*

## f. Referensi Exercise

Lanjutkan latihan mandiri di [`exercise/sesi-6/README.md`](../../../exercise/sesi-6/README.md)
— termasuk latihan mendeteksi transaksi anomali dari traffic Robot Shop
yang barusan kamu jalankan.
