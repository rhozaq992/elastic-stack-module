# Sesi 8 — Data Ingestion with Logstash & Beats

## a. Tujuan Sesi

Setelah sesi ini, Anda mampu membangun pipeline ingestion data dari sumber
nyata (log container Robot Shop) ke Elasticsearch menggunakan Filebeat dan
Logstash, termasuk melakukan parsing terhadap tiga format log yang berbeda
(grok manual, JSON, dan format standar industri), serta memahami cara
**menginstal Filebeat & Logstash langsung di Linux (VM/bare-metal)**,
sehingga keterampilan ini dapat diterapkan pada server nyata di luar
lingkungan lab ini.

## b. Output yang Diharapkan

Sesi ini dinyatakan selesai apabila index `payment-service-parsed-*`,
`cart-service-parsed-*`, dan `web-service-parsed-*` telah terisi dokumen
nyata dari log Robot Shop (dengan field yang benar ter-extract, bukan
`null`), dan Anda berhasil menginstal serta menjalankan Filebeat &
Logstash secara manual (bukan melalui image Docker Elastic) pada sebuah
container Linux polos, serta memverifikasi sendiri bahwa data mengalir
dari Filebeat → Logstash → parsed output.

## c. Teori & Struktur Sistem

**Mengapa Filebeat DAN Logstash, bukan salah satu saja?** Logstash secara
desain **menolak dijalankan sebagai root** (`Logstash cannot be run as
superuser`), sementara direktori log container di host
(`/var/lib/docker/containers`) hanya bisa dibaca oleh root. Filebeat, di
sisi lain, memang didesain agar bisa berjalan sebagai root dengan aman.
Solusinya: **Filebeat (root) membaca file log** → mengirim lewat network
(port beats 5044) → **Logstash (non-root) yang melakukan parsing** →
Elasticsearch. Logstash sendiri tidak pernah menyentuh filesystem host.

```
Filebeat (root, baca /var/lib/docker/containers)
  --output.logstash-->  Logstash (non-root, port 5044)
    --filter (grok/json per service)-->  Elasticsearch (single-node Sesi 1)
```

**Grok** adalah filter Logstash untuk mengekstrak field terstruktur dari
teks bebas menggunakan named-pattern (`%{PATTERN:nama_field}`, opsional
`:tipe` untuk cast, misalnya `%{NUMBER:amount:float}`). Dokumen yang gagal
di-match grok ditandai lewat `tag_on_failure` (lihat masing-masing file
`.conf`) — periksa field `tags` di ES apabila field yang diharapkan
kosong.

**Tiga teknik parsing berbeda dipakai pada sesi ini** (lihat 3 file
`.conf` di `logstash/pipeline/`):
- `payment-service.conf` — log plain-text tidak terstruktur → **grok manual**.
- `cart-service.conf` — log sudah berbentuk JSON dari aplikasinya sendiri → **JSON filter**.
- `web-service.conf` — log format standar Apache/Nginx Combined Log Format
  → **grok pattern bawaan** (`%{COMBINEDAPACHELOG}`), tidak perlu menulis regex sendiri.

## d. Praktik: Instalasi & Konfigurasi

**Prasyarat:** stack single-node Sesi 1 dan Robot Shop Sesi 6 masih
berjalan. Apabila Anda baru saja menyelesaikan Sesi 7, cluster 3-node
pada sesi tersebut memakai port `9200` yang sama dengan Sesi 1 —
pastikan sudah dimatikan lebih dahulu:
```bash
cd lab/day-4-administration-ingestion/sesi-7-administration-scaling
docker compose down
```
Nyalakan ulang stack yang diperlukan:
```bash
cd lab/day-1-fundamentals/sesi-1-intro-elk && docker compose up -d
cd ../../day-3-analytics-optimization/sesi-6-performance-optimization && docker compose up -d
```
*(Traffic dari load generator Sesi 6 sebaiknya masih mengalir supaya ada
log untuk di-parsing.)*

```bash
cd lab/day-4-administration-ingestion/sesi-8-data-ingestion
docker compose up -d
```

**Generate traffic** (apabila load generator Sesi 6 belum berjalan):
```bash
docker start sesi-6-performance-optimization-load-1
```

**Cek data masuk** (tunggu beberapa menit supaya ada cukup log):
```bash
curl "http://localhost:9200/payment-service-parsed-*/_count"
curl "http://localhost:9200/cart-service-parsed-*/_count"
curl "http://localhost:9200/web-service-parsed-*/_count"
```
Expected Output (satu pengukuran nyata — angka Anda akan berbeda,
tergantung berapa lama traffic sudah mengalir):
```
payment-service-parsed-*: 322
cart-service-parsed-*: 2206
web-service-parsed-*: 3138
```

### Instalasi Manual Filebeat & Logstash (VM / Bare-Metal)

Seluruh Filebeat/Logstash yang Anda gunakan sepanjang lab ini berjalan
lewat **image Docker resmi Elastic** — praktis untuk lab, tetapi di dunia
nyata Anda akan sering menjumpai server (VM cloud, bare-metal on-prem)
yang TIDAK menggunakan Docker sama sekali. Bagian ini melatih keterampilan
tersebut: menginstal Filebeat & Logstash **langsung di OS Linux**
menggunakan package manager, bukan hanya `docker pull`.

**Siapkan "VM" percobaan** (container Ubuntu polos — pada server
sungguhan, ini langsung menjadi VM/bare-metal Linux Anda, langkah-langkah
di bawah PERSIS SAMA):
```bash
docker run -d --name native-vm ubuntu:22.04 sleep infinity
docker exec -it native-vm bash
```
Sisa langkah pada bagian ini dijalankan **DI DALAM** `native-vm` (prompt shell-nya).

**1. Tambahkan repository resmi Elastic** (APT, untuk Debian/Ubuntu —
versi RHEL/CentOS menggunakan `yum`/`dnf` dengan repo `.repo` setara, pola sama):
```bash
apt-get update -qq && apt-get install -y curl gnupg apt-transport-https

curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elastic.gpg
echo "deb [signed-by=/usr/share/keyrings/elastic.gpg] https://artifacts.elastic.co/packages/9.x/apt stable main" > /etc/apt/sources.list.d/elastic-9.x.list
apt-get update -qq
```

**2. Install Filebeat & Logstash** (pin versi sama dengan stack lab ini,
9.5.2 — supaya kompatibel):
```bash
apt-get install -y filebeat=9.5.2 logstash=1:9.5.2-1
```
Expected Output: kedua paket berhasil diunduh & terinstal lewat
`dpkg`, sama persis seperti instalasi package Linux lain (`apt-get install
nginx`, dst.) — TIDAK ada langkah spesial. Verifikasi:
```bash
/usr/share/filebeat/bin/filebeat version
/usr/share/logstash/bin/logstash --version
```
Expected Output: `filebeat version 9.5.2 (arm64)...` dan
`logstash 9.5.2`.

**3. Buat config Logstash** — pipeline sederhana, membaca file, melakukan
parsing `%{COMBINEDAPACHELOG}` (pattern bawaan Logstash, sama seperti
`web-service.conf` yang Anda gunakan untuk Robot Shop), output ke `stdout`
terlebih dahulu (supaya hasilnya langsung terlihat tanpa perlu setup
Elasticsearch di container percobaan ini):
```bash
mkdir -p /etc/logstash/conf.d
cat > /etc/logstash/conf.d/native-demo.conf << 'EOF'
input {
  beats { port => 5044 }
}
filter {
  grok { match => { "message" => "%{COMBINEDAPACHELOG}" } }
}
output {
  stdout { codec => rubydebug }
}
EOF
chown logstash:logstash /etc/logstash/conf.d/native-demo.conf
```

**4. Buat config Filebeat** — membaca file log contoh, mengirim ke
Logstash (pola arsitektur SAMA seperti bagian d di atas — Filebeat
membaca file, mengirim ke Logstash lewat port beats):
```bash
mkdir -p /etc/filebeat
cat > /etc/filebeat/filebeat.yml << 'EOF'
filebeat.inputs:
  - type: filestream
    id: native-demo
    paths:
      - /tmp/sample-access.log

output.logstash:
  hosts: ["localhost:5044"]
EOF
```

**5. Siapkan data contoh** (mensimulasikan log Apache/Nginx access —
format standar yang sama seperti yang Anda temukan pada dokumentasi resmi
Apache/Nginx atau tutorial mana pun di internet mengenai Combined Log Format):
```bash
cat > /tmp/sample-access.log << 'EOF'
203.0.113.42 - - [12/Mar/2026:08:14:23 +0000] "GET /index.html HTTP/1.1" 200 4523 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
198.51.100.17 - - [12/Mar/2026:08:14:25 +0000] "GET /images/logo.png HTTP/1.1" 200 1820 "http://example.com/index.html" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
203.0.113.99 - - [12/Mar/2026:08:14:31 +0000] "POST /api/login HTTP/1.1" 401 512 "-" "curl/8.4.0"
198.51.100.5 - - [12/Mar/2026:08:14:40 +0000] "GET /favicon.ico HTTP/1.1" 404 209 "-" "Mozilla/5.0 (X11; Linux x86_64)"
203.0.113.7 - - [12/Mar/2026:08:15:02 +0000] "GET /products?category=shoes HTTP/1.1" 200 8877 "-" "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)"
EOF
```

**6. Jalankan Logstash** (di background, sebagai non-root user `logstash`
— pada server sungguhan ini biasanya dijalankan lewat `systemctl enable
--now logstash`, tetapi container percobaan ini tidak memiliki systemd,
sehingga dijalankan secara manual). User `logstash` yang dibuat oleh
package APT memiliki login shell `/usr/sbin/nologin` (memang disengaja —
best practice service account tidak boleh login interaktif) — karena itu
diperlukan `su -s /bin/bash` (memaksa penggunaan bash untuk command ini
saja), `su logstash` biasa akan ditolak dengan error
`This account is currently not available`:
```bash
mkdir -p /tmp/ls-data /tmp/ls-logs && chown logstash:logstash /tmp/ls-data /tmp/ls-logs
su -s /bin/bash logstash -c "/usr/share/logstash/bin/logstash -f /etc/logstash/conf.d/native-demo.conf --path.settings /etc/logstash --path.data /tmp/ls-data --path.logs /tmp/ls-logs &"
```
`--path.settings /etc/logstash` WAJIB disebutkan secara eksplisit di
sini — berbeda dari apabila Anda menjalankannya lewat `systemctl` (yang
otomatis mengetahui lokasi config), invocation manual seperti ini tidak
otomatis menemukan `log4j2.properties`/`jvm.options` milik paket APT
(lokasinya di `/etc/logstash`, bukan `/usr/share/logstash/config` yang
justru tidak ada) — tanpa flag ini Logstash tetap berjalan, tetapi
fallback ke logging konsol saja, dan
`/tmp/ls-logs/logstash-plain.log` pada langkah verifikasi berikut tidak
akan pernah terbentuk.

Tunggu sampai muncul log `Pipelines running` (sekitar 30-40 detik, JVM
startup) sebelum melanjutkan ke langkah 7 — periksa dengan
`tail -f /tmp/ls-logs/logstash-plain.log`.

**7. Jalankan Filebeat** (root, pada server sungguhan `systemctl enable --now filebeat`):
```bash
/usr/share/filebeat/bin/filebeat -e -c /etc/filebeat/filebeat.yml \
  --path.home /usr/share/filebeat --path.config /etc/filebeat \
  --path.data /tmp/fb-data --path.logs /tmp/fb-logs
```
Expected Output — pada terminal Logstash (langkah 6), 5 dokumen
ter-parse, tiap dokumen berisi `response.status_code`, `url.original`,
`source.address`, `user_agent.original` — PERSIS field yang sama seperti
hasil parsing `web-service.conf` terhadap log Robot Shop, membuktikan
instalasi manual ini menghasilkan pipeline yang fungsinya identik dengan
versi Docker:
```
{
    "url" => { "original" => "/products?category=shoes" },
    "http" => {
        "response" => { "status_code" => 200, "body" => { "bytes" => 8877 } }
    },
    "source" => { "address" => "203.0.113.7" },
    "user_agent" => { "original" => "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)" }
}
```

**Bersihkan** container percobaan setelah selesai (bukan bagian dari lab
utama, hanya latihan keterampilan instalasi):
```bash
exit                    # keluar dari native-vm
docker rm -f native-vm
```

## e. Contoh Implementasi

**Cek hasil parsing payment** (grok manual):
```
GET payment-service-parsed-*/_search
{ "query": { "exists": { "field": "http_status" } }, "size": 1 }
```
Expected Output — field `payment_user`, `http_status`,
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

**Cari transaksi anomali.** Traffic Robot Shop pada sesi ini memiliki SATU
pola "tidak normal" yang PASTI ada (500, disuntik secara sengaja), dan
SATU pola yang MUNGKIN ada tergantung performa host Anda (429, kapasitas):
```
GET payment-service-parsed-*/_search
{ "size": 0, "aggs": { "by_status": { "terms": { "field": "http_status" } } } }
```
Expected Output (dari salah satu pengukuran nyata — angka Anda bisa
berbeda totalnya): `429: 133`, `200: 14`, `500: 13`. **Apabila pada
layar Anda tidak terdapat `429` sama sekali dan hampir seluruhnya
`200`**, hal tersebut normal juga, yang berarti host Anda cukup kuat
menangani `NUM_CLIENTS: 6` tanpa `payment` kewalahan (lihat catatan Sesi
6). Yang PASTI selalu ada (tidak tergantung performa host): field `500`.

Breakdown per `payment_user` untuk status `500` menunjukkan pola yang jelas:
```
GET payment-service-parsed-*/_search
{ "size": 0, "query": { "term": { "http_status": 500 } },
  "aggs": { "by_user": { "terms": { "field": "payment_user.keyword" } } } }
```
Expected Output: **SEMUA dokumen `http_status: 500` berasal
dari SATU user id yang sama, `partner-57`** — bukan pola `anonymous-N`
yang normal. Ini adalah transaksi yang sengaja disuntikkan (fitur
`ERROR=1` pada load generator, lihat Sesi 6) — pola KONSENTRASI pada satu
identitas mencurigakan merupakan tanda anomali/fraud.

**Apabila `429` MUNCUL pada traffic Anda**, breakdown per user-nya akan
menunjukkan pola yang SANGAT berbeda dari 500 — tersebar ke banyak user id
`anonymous-N` yang berbeda-beda (masing-masing hanya 1-2 kejadian), bukan
terkonsentrasi pada satu id. Hal itu menandakan BUKAN anomali/fraud,
melainkan **kapasitas service yang kewalahan** (lihat Sesi 6): banyak
user LEGITIMATE yang kebetulan sama-sama gagal karena `payment` tidak
sanggup menampung request secara bersamaan. Dua pola yang sama-sama
"tidak normal" ini membutuhkan respons yang berbeda — 500 membutuhkan
investigasi keamanan, sedangkan 429 (apabila muncul) membutuhkan
perbaikan kapasitas/scaling.

## f. Referensi Exercise

Lanjutkan latihan mandiri di [`exercise/sesi-8/README.md`](../../../exercise/sesi-8/README.md)
— Bagian 1 deteksi transaksi anomali, Bagian 2 menyusun grok pattern
sendiri untuk format log custom aplikasi [`crud-app/`](../../../crud-app/README.md).
