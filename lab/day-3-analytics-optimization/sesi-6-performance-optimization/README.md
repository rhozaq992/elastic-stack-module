# Sesi 6 — Search Performance Optimization

## a. Tujuan Sesi

Setelah sesi ini, Anda mampu mengukur performa query Elasticsearch secara
langsung (bukan menebak), memahami cara kerja request cache, mengetahui
pengaturan index yang perlu disesuaikan saat bulk-loading data besar, serta
memahami APM (Application Performance Monitoring), yaitu cara melihat
latency setiap microservice secara individual untuk mengetahui secara
pasti service mana yang lambat, bukan sekadar menduga dari gejala di
permukaan.

## b. Output yang Diharapkan

Sesi ini dianggap selesai apabila Anda berhasil mengukur dan
membandingkan `took` (waktu eksekusi) query sebelum/sesudah cache aktif,
menjalankan `_profile` API untuk membedah waktu eksekusi query, mengubah
`refresh_interval` index lalu mengembalikannya ke semula, serta melihat di
Kibana APM **Service Inventory** bahwa service `cart` dan `payment`
tampil dengan angka latency yang jauh berbeda, sehingga Anda dapat
menyebutkan service mana yang lebih lambat dan berapa kira-kira
selisihnya.

## c. Teori & Struktur Sistem

Robot Shop pada sesi ini adalah **kelanjutan langsung dari Sesi 4** —
`cart` dan `payment` (image `:v2-apm`) sudah disisipi **Elastic APM
agent** sejak awal. Traffic dari load generator (Locust) yang mengalir
ke keduanya kini benar-benar **terpakai**: setiap request yang diproses
menghasilkan data trace yang tersimpan di Elasticsearch dan dapat Anda
analisis, bukan sekadar lewat di log lalu hilang seperti sebelumnya.

**Apa itu APM?** Application Performance Monitoring adalah cara mengukur
seberapa cepat/lambat aplikasi merespons dari DALAM kode aplikasi itu
sendiri (berbeda dari mengukur dari luar seperti curl timing). Untuk
sistem microservice (seperti Robot Shop, 12 service saling memanggil
lewat HTTP), APM sangat penting karena satu request pengguna bisa
melewati BANYAK service. Tanpa APM, apabila proses checkout terasa
lambat, Anda hanya tahu "checkout lambat" tanpa mengetahui apakah
penyebabnya `cart`, `payment`, `shipping`, atau kombinasi ketiganya.

**Cara kerja APM di stack ini:**

![Diagram cara kerja APM: cart/payment mengirim trace ke apm-server, disimpan ke Elasticsearch, dibaca oleh Kibana APM UI](../../../docs/diagrams/sesi6-apm-architecture.svg)

1. **APM agent** — library kecil yang di-install DI DALAM kode aplikasi
   (satu per bahasa pemrograman: Python, Node.js, Java, dst.). Tugasnya
   mencatat setiap request masuk (disebut **transaction**) dan setiap
   operasi di dalamnya (disebut **span** — mis. query database, panggil
   API lain) beserta durasinya, lalu mengirim data itu ke APM Server.
2. **APM Server** — komponen terpisah (container `apm-server` pada sesi
   ini) yang menerima data dari semua agent, lalu menyimpannya ke
   Elasticsearch sebagai index `traces-apm-*` (per transaction/span) dan
   `metrics-apm-*` (metrik teragregasi per menit).
3. **Kibana APM UI** (menu ☰ → Observability → APM) — membaca index-index
   itu, menampilkannya sebagai tabel per-service, grafik latency, dan
   detail per transaksi, tanpa Anda perlu menulis query manual (walaupun
   datanya tetap bisa di-query manual seperti index lain, lihat bagian d topik 3).

**Mengapa hanya `cart` dan `payment`** (bukan seluruh 12 service)? Supaya
sesi ini tetap fokus dan cepat — dua service ini representatif: `cart`
(Node.js, operasi ringan ke Redis) berbanding `payment` (Python, operasi
lebih berat termasuk panggilan HTTP keluar). Perbandingan keduanya sudah
cukup untuk menunjukkan konsep "per-service latency" dengan jelas.

**Tiga teknik optimasi lain yang tetap dibahas pada sesi ini** (memakai
`kibana_sample_data_logs`, dataset besar dan deterministik supaya
angkanya konsisten untuk mempelajari konsepnya terlebih dahulu, sebelum
diterapkan pada data trace APM Anda sendiri yang jumlahnya tidak pasti
di bagian d topik 3):
- **Query profiling** (`_profile` API) — membedah SATU query, menunjukkan
  berapa lama tiap bagian internal (matching, scoring, dst.) memakan
  waktu, dipakai untuk mendiagnosis query yang lambat.
- **Request cache** — Elasticsearch otomatis meng-cache hasil query yang
  identik (khususnya `size:0` dengan aggregation) — request kedua dengan
  query yang PERSIS SAMA jauh lebih cepat, sampai ada dokumen baru masuk
  (cache otomatis invalidasi).
- **Index settings saat bulk load** — `refresh_interval` (jarak waktu
  hingga dokumen baru bisa dicari) dan jumlah replica dapat disesuaikan
  sementara untuk mempercepat proses index besar-besaran.

## d. Praktik: Instalasi & Konfigurasi

### 1. Verifikasi Robot Shop & Nyalakan Traffic Anomali

**Prasyarat:** stack Sesi 1 dan Robot Shop Sesi 4 (termasuk
`apm-server`) masih berjalan. Apabila sudah dimatikan, nyalakan kembali
sesuai instruksi Sesi 4 bagian (d) topik 1 sebelum melanjutkan.

**[Terminal] Verifikasi servis masih berjalan:**
```bash
cd lab/day-2-query-relevance/sesi-4-relevance-scoring
docker compose ps
```
Expected Output: seluruh servis Robot Shop + `apm-server` berstatus
`Up`/`healthy` (lihat Sesi 4 bagian (b) untuk daftar lengkapnya).

**[Terminal] Ganti load generator ke mode anomali** (`ERROR=1` —
mengaktifkan transaksi anomali bawaan Robot Shop, bahan latihan Sesi 7 —
menggantikan load generator `ERROR=0` yang sudah berjalan sejak Sesi 4,
BUKAN menambah instance baru):
```bash
docker compose -f docker-compose.yml -f docker-compose.arm64-override.yml \
  -f ../../day-3-analytics-optimization/sesi-6-performance-optimization/docker-compose.load.yml \
  up -d load
```
*(Tanpa ARM override, cukup hilangkan
`-f docker-compose.arm64-override.yml` dari perintah di atas. Perintah
ini WAJIB dijalankan dari direktori `sesi-4-relevance-scoring` — bukan
dari direktori sesi ini — supaya container `load` yang sudah ada
di-Recreate, bukan membuat instance kedua yang terpisah.)*
Expected Output (dari `docker compose logs -f load` setelah
beberapa menit): traffic asli mengalir ke `/api/user/login`,
`/api/catalogue/*`, `/api/shipping/confirm/*`, dst.

> **INFORMATION:** jumlah request yang tampil pada layar Anda akan
> berbeda — traffic Robot Shop bersifat acak (lihat catatan di Sesi 4).

> **INFORMATION:** `NUM_CLIENTS` di `docker-compose.load.yml` sengaja
> diset rendah (6), bukan tinggi, karena `payment` (uwsgi, single worker
> process, lihat `[pid: 6|app: 0|...]` pada log-nya) hanya memiliki
> kapasitas concurrent request yang kecil. Pada host dengan beban Docker
> lain yang berjalan bersamaan, hal ini dapat menyebabkan `payment`
> mengembalikan **HTTP 429** (Too Many Requests) untuk sebagian besar
> request. **Namun hal ini TIDAK selalu terjadi** — pada host yang lebih
> lega (CPU/RAM cukup, tidak banyak proses lain berjalan bersamaan),
> uwsgi mungkin sanggup menangani `NUM_CLIENTS: 6` tanpa masalah sama
> sekali, dan traffic-nya akan 100% `200`. Apabila hal itu yang terjadi
> pada perangkat Anda, itu bukan kegagalan — justru itu bukti sistemnya
> memiliki kapasitas yang cukup untuk beban ini.
>
> Anda baru bisa memverifikasi status code traffic ini secara nyata pada
> **Sesi 7** — index `payment-service-parsed-*` yang berisi field
> `http_status` baru dibuat oleh pipeline Logstash yang Anda bangun pada
> sesi itu, belum tersedia pada titik ini. Catat baik-baik apakah
> traffic Anda tadi lancar (kemungkinan besar semua `200`) atau banyak
> yang gagal — Anda akan memeriksanya kembali secara nyata pada Sesi 7
> setelah pipeline-nya siap.

### 2. Request Cache & Pengukuran `took`

**Contoh Implementasi — ukur query TANPA cache (request pertama):**
```
GET kibana_sample_data_logs/_search
{ "size": 0, "query": { "bool": { "filter": [ { "range": { "bytes": { "gt": 5000 } } } ] } } }
```
Expected Output: `"took": 3` (ms), `"hits":{"total":{"value":7696}}`.

> **INFORMATION:** `hits.total.value` akan selalu persis `7696` (data
> sample bersifat statis, tidak tergantung waktu) — tetapi angka `took`
> sendiri bisa berbeda beberapa ms pada perangkat Anda (tergantung beban
> CPU/proses lain yang berjalan bersamaan), hal ini normal.

**Jalankan query PERSIS SAMA lagi:**
```
GET kibana_sample_data_logs/_search
{ "size": 0, "query": { "bool": { "filter": [ { "range": { "bytes": { "gt": 5000 } } } ] } } }
```
Expected Output: `"took": 0` (ms) — request cache Elasticsearch
langsung mengembalikan hasil tanpa eksekusi ulang. **Query ini memang
sudah sangat cepat sejak awal**, sehingga `took` terkadang TIDAK
terlihat turun banyak (bisa saja masih 1-2ms) — bukti yang lebih
diandalkan adalah statistik cache-nya langsung, bukan sekadar `took`:
```
GET kibana_sample_data_logs/_stats/request_cache
```
Expected Output: `miss_count: 1` (index ini cuma punya 1 shard pada
cluster single-node — angka `miss` mengikuti JUMLAH SHARD, karena tiap
shard punya cache-nya sendiri; kalau index-nya punya N shard, angka ini
akan jadi N), `hit_count` bertambah 1 setiap kali Anda mengulang query
yang PERSIS SAMA (nilainya kumulatif sejak index ini pertama kali
dibuat, jadi tidak selalu mulai dari 0/1 — yang penting `hit_count`
bertambah setelah query kedua di atas, bukan angka absolutnya).

### 3. Melihat Latency per Microservice Lewat APM

**Contoh Implementasi — perubahan NYATA pada source code Robot Shop**
(bukan kode ilustrasi — ini persis diff yang diterapkan pada source asli
Robot Shop, SEBELUM di-build menjadi image `:v2-apm` yang Anda pakai):

Python (Flask) — `payment/payment.py` + `payment/requirements.txt`:
```diff
--- a/payment/payment.py
+++ b/payment/payment.py
@@ -17,10 +17,19 @@ from rabbitmq import Publisher
 # Prometheus
 import prometheus_client
 from prometheus_client import Counter, Histogram
+# Elastic APM
+from elasticapm.contrib.flask import ElasticAPM

 app = Flask(__name__)
 app.logger.setLevel(logging.INFO)

+app.config['ELASTIC_APM'] = {
+    'SERVICE_NAME': 'payment',
+    'SERVER_URL': os.getenv('ELASTIC_APM_SERVER_URL', 'http://apm-server:8200'),
+    'ENVIRONMENT': os.getenv('ELASTIC_APM_ENVIRONMENT', 'training'),
+}
+apm = ElasticAPM(app)
+
 CART = os.getenv('CART_HOST', 'cart')
 USER = os.getenv('USER_HOST', 'user')
 PAYMENT_GATEWAY = os.getenv('PAYMENT_GATEWAY', 'https://paypal.com/')
--- a/payment/requirements.txt
+++ b/payment/requirements.txt
@@ -5,3 +5,4 @@ pika
 prometheus_client
 opentracing
 instana
+elastic-apm[flask]
```

Node.js (Express) — `cart/server.js` + `cart/package.json`:
```diff
--- a/cart/server.js
+++ b/cart/server.js
@@ -7,6 +7,13 @@ instana({
     }
 });

+// Elastic APM -- also MUST be required/started before other modules
+require('elastic-apm-node').start({
+    serviceName: 'cart',
+    serverUrl: process.env.ELASTIC_APM_SERVER_URL || 'http://apm-server:8200',
+    environment: process.env.ELASTIC_APM_ENVIRONMENT || 'training'
+});
+
 const redis = require('redis');
 const request = require('request');
 const bodyParser = require('body-parser');
--- a/cart/package.json
+++ b/cart/package.json
@@ -17,6 +17,7 @@
       "express-pino-logger": "^4.0.0",
       "pino-pretty": "^2.5.0",
       "@instana/collector": "^1.132.2",
-      "prom-client": "^11.5.3"
+      "prom-client": "^11.5.3",
+      "elastic-apm-node": "^3.52.0"
   }
 }
```
Pola yang sama di kedua bahasa: agent di-`start()`/di-inisialisasi pada
titik PALING AWAL aplikasi (sebelum route/module lain), diberi
`serviceName` dan `serverUrl` APM Server tujuan. Begitu agent aktif,
SETIAP request yang masuk ke `cart`/`payment` otomatis tercatat sebagai
**transaction**, tanpa perlu kode tambahan apa pun di tiap endpoint.

**Kibana juga punya panduan instalasi APM agent bawaan** (generik, bukan
khusus Robot Shop) — menu ☰ → Observability → APM → tombol **Add data**
di kanan atas → pilih tab bahasa (mis. **Flask** untuk `payment`):

![Kibana APM Agents onboarding guide untuk Flask, menampilkan perintah pip install elastic-apm[flask] dan contoh kode from elasticapm.contrib.flask import ElasticAPM](../../../docs/screenshots/sesi-6/05-apm-onboarding-flask-agent-guide.png)

*Perhatikan: perintah `pip install elastic-apm[flask]` dan baris kode
`from elasticapm.contrib.flask import ElasticAPM` pada panduan Kibana ini
PERSIS sama dengan yang diterapkan pada `payment/requirements.txt` dan
`payment/payment.py` di atas — panduan ini berguna sebagai referensi
generik ketika Anda menginstrumentasi aplikasi Anda sendiri, di luar
Robot Shop.*

**Apa bedanya `trace`, `transaction`, `span`, dan istilah APM lain?**

![Diagram terminologi APM: satu trace berisi transaksi payment yang terdiri dari beberapa span anak, dengan definisi tiap istilah](../../../docs/diagrams/sesi6-trace-span-terminology.svg)

*Berdasarkan trace nyata `POST /pay/<id>` (904ms) dari stack Anda sendiri
— `trace` adalah SELURUH perjalanan satu request (904ms, garis besar),
`transaction` adalah unit kerja tingkat-atas yang diukur agent PADA SATU
service (di sini: request `payment` itu sendiri), dan `span` adalah
operasi ANAK di dalam transaction itu (di sini: 3 pemanggilan keluar ke
`payment-gateway`/`cart`/`user`). Satu trace berisi TEPAT SATU transaction
per service yang dilewati, tapi bisa berisi BANYAK span.*

**Buka Kibana APM** (menu ☰ → Observability → APM → Service inventory):

![Kibana APM Service inventory menampilkan service cart dan payment dengan kolom latency, throughput, failed transaction rate](../../../docs/screenshots/sesi-6/01-apm-service-inventory.png)

*Dua service muncul otomatis — `cart` (ikon Node.js) dan `payment` (ikon
Python) — kolom **Latency (avg.)** menunjukkan `payment` jauh lebih
lambat dari `cart` (bedanya bisa puluhan hingga ratusan kali lipat,
tergantung berapa lama load generator sudah berjalan pada perangkat
Anda — coba refresh setelah beberapa menit apabila baru mulai). Ini
PERSIS pertanyaan "servis mana yang lambat" yang tidak bisa dijawab
hanya dari log biasa.*

**Klik salah satu service** (mis. `payment`) untuk melihat detail:

![Halaman detail service payment di Kibana APM menampilkan grafik latency, throughput, dan failed transaction rate](../../../docs/screenshots/sesi-6/02-apm-payment-overview.png)

*Tab **Overview** menampilkan grafik latency & throughput dari waktu ke
waktu, tab **Transactions** untuk melihat breakdown per-endpoint
(`POST /pay/<id>` dst.), **Dependencies** untuk melihat apa yang
dipanggil service ini ke luar (database, service lain), dan **Errors**
untuk exception yang tertangkap.*

![Detail transaksi POST /pay/id menampilkan breakdown time spent by span type, mayoritas di kategori http](../../../docs/screenshots/sesi-6/03-apm-transaction-detail.png)

*Klik transaksi tertentu (mis. `POST /pay/<id>`) — panel **"Time spent by
span type"** inilah yang menjawab PERTANYAAN LANJUTAN "mengapa lambat":
apabila mayoritas waktu berada di kategori `app` (kode aplikasi
sendiri), optimasi perlu diarahkan ke kode; apabila mayoritas di
`http`/`db` (panggilan keluar), masalahnya ada pada service/dependency
lain yang dipanggil, bukan pada `payment` itu sendiri.*

**Telusuri SATU trace spesifik — lihat persis service apa saja yang
dilewati.** Panel di atas menampilkan agregat (rata-rata banyak
transaksi) — untuk memahami satu request SECARA UTUH, scroll ke bawah
ke bagian **Trace samples**, lalu klik salah satu sampel untuk membuka
**Timeline**-nya:

![Kibana APM Timeline satu trace POST /pay/<id> berdurasi 876ms, menampilkan 3 span anak: GET user:8080 (2.6ms), GET payment-gateway (867ms, mendominasi hampir seluruh lebar timeline), DELETE cart:8080 (2.7ms)](../../../docs/screenshots/sesi-6/04-apm-trace-waterfall.png)

*Satu trace nyata (`POST /pay/<id>`, total 876ms) — Timeline ini
menjawab "trace ini menyentuh service/dependency apa saja, dan berapa
lama masing-masing": `GET user:8080` (2.6ms), `GET payment-gateway`
(867ms — bar teal yang membentang hampir sepanjang timeline, **99% dari
total durasi**), `DELETE cart:8080` (2.7ms). Tidak perlu menghitung
manual — panjang bar SUDAH proporsional terhadap durasinya, dan urutan
dari atas ke bawah mengikuti urutan panggilan sebenarnya di dalam kode
`payment`.*

> **INFORMATION:** trace ini membuktikan `payment` LAMBAT bukan karena
> kode `payment` sendiri (panggilan internalnya ke `user`/`cart`
> sama-sama di bawah 3ms, secepat yang diharapkan), melainkan karena
> menunggu respons `payment-gateway` — dependency eksternal (dummy,
> lihat bagian d) yang disengaja lambat untuk mensimulasikan payment
> gateway pihak ketiga sungguhan. Ini pola yang sama dengan latihan
> exercise Sesi 6 (lihat `exercise/sesi-6/README.md` Bagian 2) — bedanya
> di sini Anda melihat SATU trace individual lewat UI, exercise nanti
> meminta Anda membuktikan pola ini lewat AGREGASI banyak trace
> (`span.destination.service.resource`) lewat query.

**Query data trace-nya secara langsung**:

> **INFORMATION:** APM Server menyimpan data trace sebagai index
> Elasticsearch biasa — dapat di-query seperti index lain, inilah yang
> membuat traffic load generator akhirnya "terpakai" untuk latihan
> aggregation juga.

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
Expected Output: dua bucket, `cart` dengan `avg_duration_ms` di kisaran
satuan milidetik, `payment` di kisaran ratusan milidetik — konsisten
dengan yang tampil di Service Inventory di atas.

> **INFORMATION:** ini adalah pola yang diharapkan, bukan angka pasti —
> angka aktual Anda tergantung berapa lama load generator sudah berjalan.

### 4. Query Profiling, Refresh Interval, & Index Management

**Contoh Implementasi — `_profile` API** — membedah query yang sama, melihat waktu eksekusi internal:
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
(sub-milidetik — contoh: `299250` ≈ 0.3ms), dan `breakdown` — rincian per
operasi internal (`match_count`, `next_doc`, dst.).

> **INFORMATION:** angka pasti `time_in_nanos` bergantung beban host Anda
> saat itu — yang menjadi patokan adalah satuannya (skala sub-milidetik),
> bukan angka mutlaknya. Query yang kompleks/lambat akan menunjukkan
> operasi mana yang paling banyak memakan waktu lewat breakdown ini.

**Ubah `refresh_interval` sebelum bulk load besar**:
```
PUT kibana_sample_data_logs/_settings
{ "index": { "refresh_interval": "30s" } }
```

> **INFORMATION:** index baru membutuhkan waktu ~1 detik secara default
> sebelum dokumen bisa dicari — apabila Anda hendak melakukan bulk index
> jutaan dokumen, menaikkan `refresh_interval` mengurangi overhead ini.

Expected Output: `{"acknowledged":true}`. **Setelah bulk load
selesai, WAJIB dikembalikan** ke nilai default (atau nilai produksi normal),
supaya data baru kembali cepat muncul di pencarian:
```
PUT kibana_sample_data_logs/_settings
{ "index": { "refresh_interval": "1s" } }
```

**Lihat semua index dari satu tempat** — Kibana **Stack Management → Index
Management** menampilkan seluruh index di cluster sekaligus (health, status,
jumlah dokumen, ukuran storage) — cara cepat untuk memeriksa index mana yang
paling besar/perlu dioptimasi:

![Kibana Index Management menampilkan daftar seluruh index lab dengan document count dan storage size](../../../docs/screenshots/sesi-6/01-index-management.png)

*Stack Management → Index Management → Indices — semua index yang sudah
Anda buat sepanjang lab ini (sample data, hasil pipeline, index exercise)
terlihat sekaligus di sini.*

## e. Referensi Exercise

Lanjutkan latihan mandiri di [`exercise/sesi-6/README.md`](../../../exercise/sesi-6/README.md)
— termasuk latihan mendeteksi transaksi anomali dari traffic Robot Shop
yang baru saja Anda jalankan.
