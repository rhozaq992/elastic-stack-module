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
Kibana APM **Service Inventory** bahwa beberapa service (mis. `payment`
dan `shipping`) tampil dengan angka latency yang jauh berbeda dari
service lain (mis. `cart`, `user`), sehingga Anda dapat menyebutkan
service mana yang lebih lambat dan berapa kira-kira selisihnya.

## c. Teori & Struktur Sistem

Robot Shop pada sesi ini adalah **kelanjutan langsung dari Sesi 4** —
tujuh service (`cart`, `payment`, `catalogue`, `user`, `shipping`,
`ratings`, `dispatch`) sudah disisipi **Elastic APM agent** sejak awal
(image `:v2-apm`), masing-masing dengan cara yang sesuai bahasa/framework-nya
sendiri (lihat bagian d topik 3). Traffic dari load generator (Locust)
yang mengalir ke semuanya kini benar-benar **terpakai**: setiap request
yang diproses menghasilkan data trace yang tersimpan di Elasticsearch dan
dapat Anda analisis, bukan sekadar lewat di log lalu hilang seperti
sebelumnya.

**Apa itu APM?** Application Performance Monitoring adalah cara mengukur
seberapa cepat/lambat aplikasi merespons dari DALAM kode aplikasi itu
sendiri (berbeda dari mengukur dari luar seperti curl timing). Untuk
sistem microservice (seperti Robot Shop, 12 service saling memanggil
lewat HTTP), APM sangat penting karena satu request pengguna bisa
melewati BANYAK service. Tanpa APM, apabila proses checkout terasa
lambat, Anda hanya tahu "checkout lambat" tanpa mengetahui apakah
penyebabnya `cart`, `payment`, `shipping`, atau kombinasi ketiganya.

**Cara kerja APM di stack ini:**

![Diagram cara kerja APM: 7 servis Robot Shop mengirim trace ke apm-server, disimpan ke Elasticsearch, dibaca oleh Kibana APM UI](../../../docs/diagrams/sesi6-apm-architecture.svg)

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

**Mengapa BUKAN seluruh 12 servis Robot Shop?** Tujuh service aplikasi
(`cart`, `payment`, `catalogue`, `user`, `shipping`, `ratings`,
`dispatch`) sudah ber-APM — mencakup 5 bahasa/framework berbeda (Node.js,
Python, Java, PHP, Go), jadi Anda tetap bisa membandingkan latency LINTAS
BAHASA, bukan cuma dua titik data. Sisanya SENGAJA tidak diberi APM
agent:
- `web` — reverse proxy Nginx, bukan kode aplikasi yang bisa disisipi
  agent APM (observability untuk Nginx pakai pendekatan lain, mis. modul
  Metricbeat, di luar cakupan sesi ini).
- `mongodb`/`mysql`/`redis`/`rabbitmq` — database/message-queue pihak
  ketiga, sudah dipantau lewat `metricbeat` (Sesi 4) yang mengukur
  metrik server DB-nya sendiri, bukan trace request aplikasi.

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

**Di mana source code `payment.py`?** Robot Shop pada lab ini berjalan
dari image jadi (`:v2-apm`) — sama seperti seluruh servis lain, Anda TIDAK
pernah men-download/membuka/meng-edit source code `payment.py` atau
servis manapun secara langsung (lihat prinsip "Robot Shop = subjek
observasi" di `docs/prerequisites.md`). Instrumentasi APM sudah
disisipkan instruktur SEKALI ke dalam image ini sebelum lab dimulai.
Bagian ini menunjukkan BUKTI NYATA bahwa APM sedang aktif — dengan cara
mematikannya lalu menyalakannya kembali di depan mata Anda — bukan
meminta Anda menulis kode ke file yang memang tidak bisa Anda akses.

**Buktikan Sendiri: APM Bisa Dimatikan/Dinyalakan Tanpa Mengubah Kode**

Ingat env var `ELASTIC_APM_SERVER_URL` dan `ELASTIC_APM_ENVIRONMENT` pada
`payment` di `docker-compose.yml` Sesi 4 (bagian d topik 1)? Agent APM
membaca konfigurasinya dari env var itu SAAT CONTAINER START — termasuk
satu env var lagi yang belum dipakai: `ELASTIC_APM_ENABLED`. Ini
membuktikan bahwa "memasang APM" pada level operasional cukup soal
konfigurasi container, bukan menulis ulang kode aplikasi setiap kali.

**[Terminal] Matikan APM `payment`** (dari direktori `sesi-4-relevance-scoring`):
```bash
docker compose -f docker-compose.yml -f docker-compose.arm64-override.yml \
  -f ../../day-3-analytics-optimization/sesi-6-performance-optimization/docker-compose.load.yml \
  -f ../../day-3-analytics-optimization/sesi-6-performance-optimization/docker-compose.apm-toggle.yml \
  up -d payment
```
Tunggu 3-5 menit (supaya jendela waktu "Last 5 minutes" di Kibana bersih
dari data lama saat `payment` masih ber-APM), lalu buka **Kibana → ☰ →
Observability → APM → Service inventory**, atur rentang waktu ke **Last 5
minutes**:

![Kibana APM Service inventory menampilkan hanya 6 servis (catalogue, cart, shipping, ratings, user, dispatch) -- payment tidak muncul sama sekali karena APM-nya dimatikan](../../../docs/screenshots/sesi-6/06-apm-toggle-before-payment-off.png)

*`payment` HILANG TOTAL dari daftar — bukan menunjukkan angka nol/error,
tapi benar-benar tidak terdaftar, karena APM Server tidak menerima data
apa pun darinya. Servis-nya sendiri tetap hidup dan tetap melayani
request (coba `docker compose ps payment` — statusnya tetap `healthy`) —
yang mati hanya laporan datanya ke APM, bukan servisnya.*

**[Terminal] Nyalakan lagi** (jalankan ulang TANPA file
`docker-compose.apm-toggle.yml` — otomatis kembali ke config normal Sesi 4):
```bash
docker compose -f docker-compose.yml -f docker-compose.arm64-override.yml \
  -f ../../day-3-analytics-optimization/sesi-6-performance-optimization/docker-compose.load.yml \
  up -d payment
```
Tunggu 1-2 menit supaya traffic baru sempat masuk, refresh halaman yang
sama (tetap **Last 5 minutes**):

![Kibana APM Service inventory menampilkan 7 servis, payment sudah muncul kembali dengan latency 623ms dan failed transaction rate 14%](../../../docs/screenshots/sesi-6/07-apm-toggle-after-payment-on.png)

*`payment` MUNCUL KEMBALI, lengkap dengan angka latency dan failed
transaction rate — persis sama seperti sebelum dimatikan. Inilah yang
sebenarnya terjadi tiap kali instrumentasi APM "dipasang" pada servis
baru: bukan mendadak ada di mana-mana, tapi mulai terdaftar begitu agent
aktif mengirim data.*

> **INFORMATION:** angka `failed transaction rate` pada layar Anda boleh
> berbeda (bisa 0%, bisa lebih tinggi dari contoh) — itu bergantung
> apakah `payment` sedang mengembalikan HTTP 429 akibat `NUM_CLIENTS`
> (lihat INFORMATION di bagian d topik 1), bukan indikasi ada yang salah
> dengan toggle APM-nya.

**Kalau Diterapkan ke Aplikasi Anda Sendiri (referensi, bukan latihan)**

Yang baru saja Anda lihat adalah TOGGLE config -- bukan proses pemasangan
awalnya. Pemasangan awal (dilakukan SEKALI oleh instruktur ke
`payment.py`, sebelum image `:v2-apm` ini di-build) mengikuti panduan
bawaan Kibana sendiri (generik, bukan khusus Robot Shop) -- menu ☰ →
Observability → APM → tombol **Add data** di kanan atas → pilih tab
bahasa (mis. **Flask**, bahasa yang dipakai `payment`):

![Kibana APM Agents onboarding guide untuk Flask, menampilkan perintah pip install elastic-apm[flask] dan contoh kode from elasticapm.contrib.flask import ElasticAPM](../../../docs/screenshots/sesi-6/05-apm-onboarding-flask-agent-guide.png)

*Kibana menyediakan perintah install DAN potongan kode siap-pakai untuk
setiap bahasa -- begini alurnya kalau Anda menginstrumentasi aplikasi
Flask Anda SENDIRI (bukan Robot Shop): salin potongan kode dari layar ini
persis apa adanya, tempel ke file utama aplikasi Anda, SEDINI mungkin
(sebelum baris lain memakai `app`):*

```python
# app.py -- kerangka aplikasi Flask Anda sendiri
from flask import Flask

# <-- 1. tempel baris import agent dari panduan Kibana di atas, di sini
#     (untuk Flask: from elasticapm.contrib.flask import ElasticAPM)

app = Flask(__name__)

# <-- 2. tempel konfigurasi + inisialisasi agent dari panduan Kibana, di sini
#     (untuk Flask: app.config['ELASTIC_APM'] = {...}; ElasticAPM(app))
#     WAJIB sedini mungkin -- sebelum route/kode lain memakai `app`
```

*Anda tidak perlu menghafal atau menulis ulang kode ini dari nol -- salin
persis dari panduan Kibana, cukup ganti `SERVICE_NAME` sesuai nama
aplikasi Anda. Begitu agent aktif, SETIAP request yang masuk otomatis
tercatat sebagai **transaction**, tanpa kode tambahan di tiap endpoint.

**Servis lain di Robot Shop pakai bahasa berbeda, jadi caranya juga
sedikit berbeda** -- sekadar referensi (bukan sesuatu yang Anda
praktikkan, sudah terpasang di image `:v2-apm`):

| Servis | Bahasa | Pola instrumentasi | Perlu ubah source code? |
|---|---|---|---|
| `cart`/`catalogue`/`user` | Node.js | `require('elastic-apm-node').start({...})` di baris PALING AWAL file | TIDAK -- sekali require di entry point |
| `shipping` | Java (Spring Boot) | `-javaagent:elastic-apm-agent.jar` di flag start JVM (`CMD` pada `Dockerfile`) | TIDAK -- javaagent meng-instrument bytecode saat runtime |
| `ratings` | PHP (Apache) | Extension `.so` resmi Elastic + installer resmi, dimuat via `php.ini` | TIDAK -- extension level, bukan kode aplikasi |
| `dispatch` | Go | Transaction/span dibuat MANUAL lewat `go.elastic.co/apm/v2` di sekitar kode consumer RabbitMQ | YA -- Go tidak punya auto-instrumentation, satu-satunya servis di sini yang butuh perubahan kode nyata |

> **INFORMATION:** `dispatch` butuh perubahan kode manual karena Go APM
> agent Elastic TIDAK melakukan auto-instrumentation seperti agent
> Node.js/Python/Java/PHP di atas (keterbatasan bahasa Go sendiri, bukan
> keterbatasan Elastic) -- transaction & span harus dibuat eksplisit lewat
> `tracer.StartTransaction()`/`apm.StartSpan()` di titik yang relevan
> (dalam kasus `dispatch`: sekitar fungsi yang memproses pesan dari
> `rabbitmq`, bukan HTTP handler seperti servis lain).

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

![Kibana APM Service inventory menampilkan tujuh servis Robot Shop dengan kolom latency, throughput, failed transaction rate, masing-masing dengan ikon bahasa pemrogramannya](../../../docs/screenshots/sesi-6/01-apm-service-inventory.png)

*Ketujuh service muncul otomatis, masing-masing dengan ikon bahasa yang
benar (Node.js untuk `cart`/`catalogue`/`user`, PHP untuk `ratings`,
Python untuk `payment`, Java untuk `shipping`, Go untuk `dispatch`) —
kolom **Latency (avg.)** menunjukkan dua pola berbeda: `payment` dan
`dispatch` jauh lebih lambat dari `cart`/`catalogue`/`user` (bedanya bisa
puluhan hingga ratusan kali lipat), sementara `shipping` cuma sedikit
lebih lambat (beberapa kali lipat saja, BUKAN puluhan/ratusan kali —
jangan asumsikan semua service "berat" polanya sama). Perhatikan juga
kolom **Failed transaction rate** pada `ratings` — angka yang jauh dari
0% di kolom itu adalah sinyal masalah yang BERBEDA dari sekadar latency
tinggi, dan patut diselidiki terpisah. Angka pasti pada layar Anda akan
berbeda (tergantung berapa lama load generator sudah berjalan — coba
refresh setelah beberapa menit apabila baru mulai), tapi POLA relatifnya
(servis mana yang menonjol, dan MENGAPA — lambat vs sering gagal) akan
konsisten. Ini PERSIS pertanyaan "servis mana yang bermasalah, dan
bermasalah dengan cara apa" yang tidak bisa dijawab hanya dari log biasa.*

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

**(Opsional) Verifikasi Angka Ini Lewat Query** — Service Inventory di
atas sudah cukup untuk menjawab "servis mana yang lambat", bagian ini
HANYA untuk yang penasaran ingin membuktikannya lewat query juga:

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
Expected Output: TUJUH bucket (satu per servis ber-APM) — `cart`/`user`/
`catalogue`/`shipping` dengan `avg_duration_ms` di kisaran satuan
milidetik, `ratings` di kisaran belasan milidetik, `payment` di kisaran
ratusan milidetik, `dispatch` juga di kisaran ratusan milidetik (delay
`time.Sleep` yang sengaja ditanam di kode simulasi pemrosesan order) —
konsisten dengan yang tampil di Service Inventory di atas.

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
