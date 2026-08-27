# Sesi 8 — Data Ingestion with Logstash & Beats

## a. Tujuan Sesi

Setelah sesi ini, kamu mampu membangun pipeline ingestion data dari sumber
nyata (log container Robot Shop) ke Elasticsearch memakai Filebeat +
Logstash, termasuk parsing 3 format log yang berbeda (grok manual, JSON,
dan format standar industri) selain itu anda mengerti cara **install Filebeat &
Logstash langsung di Linux (VM/bare-metal)**.

## b. Output yang Diharapkan

Sesi ini selesai kalau index `payment-service-parsed-*`,
`cart-service-parsed-*`, dan `web-service-parsed-*` terisi dokumen nyata
dari log Robot Shop (dengan field yang benar ter-extract, bukan `null`),
dan kamu berhasil install + jalankan Filebeat & Logstash secara manual
(bukan image Docker Elastic) di sebuah container Linux polos, memverifikasi
sendiri datanya mengalir Filebeat → Logstash → parsed output.

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

*(Prasyarat: stack single-node Sesi 1 dan Robot Shop Sesi 6 masih jalan.
Kalau sudah kamu matikan, nyalakan lagi dulu:
`cd lab/day-3-analytics-optimization/sesi-6-performance-optimization && docker compose up -d`.
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
Expected Output (satu pengukuran nyata angkamu akan beda,
tergantung berapa lama traffic sudah mengalir):
```
payment-service-parsed-*: 322
cart-service-parsed-*: 2206
web-service-parsed-*: 3138
```

### Instalasi Manual Filebeat & Logstash (VM / Bare-Metal)

Semua Filebeat/Logstash yang kamu pakai sepanjang lab ini jalan lewat
**image Docker resmi Elastic** — praktis untuk lab, tapi di dunia nyata
kamu akan sering ketemu server (VM cloud, bare-metal on-prem) yang TIDAK
pakai Docker sama sekali. Bagian ini melatih skill itu: install Filebeat
& Logstash **langsung di OS Linux** pakai package manager, bukan cuma
`docker pull`.

**Siapkan "VM" percobaan** (container Ubuntu polos — di server sungguhan,
ini langsung jadi VM/bare-metal Linux-mu, langkah-langkah di bawah PERSIS
SAMA):
```bash
docker run -d --name native-vm ubuntu:22.04 sleep infinity
docker exec -it native-vm bash
```
Sisa langkah di bagian ini dijalankan **DI DALAM** `native-vm` (prompt shell-nya).

**1. Tambahkan repository resmi Elastic** (APT, untuk Debian/Ubuntu — versi
RHEL/CentOS pakai `yum`/`dnf` dengan repo `.repo` setara, pola sama):
```bash
apt-get update -qq && apt-get install -y curl gnupg apt-transport-https

curl -fsSL https://artifacts.elastic.co/GPG-KEY-elasticsearch | gpg --dearmor -o /usr/share/keyrings/elastic.gpg
echo "deb [signed-by=/usr/share/keyrings/elastic.gpg] https://artifacts.elastic.co/packages/9.x/apt stable main" > /etc/apt/sources.list.d/elastic-9.x.list
apt-get update -qq
```

**2. Install Filebeat & Logstash** :
```bash
apt-get install -y filebeat=9.5.2 logstash=1:9.5.2-1
```
Expected Output: kedua paket ke-download & ter-install lewat
`dpkg`, sama persis seperti install package Linux lain (`apt-get install
nginx`, dst.) — TIDAK ada langkah spesial. Verifikasi:
```bash
/usr/share/filebeat/bin/filebeat version
/usr/share/logstash/bin/logstash --version
```
Expected Output: `filebeat version 9.5.2 (arm64)...` dan
`logstash 9.5.2`.

**3. Buat config Logstash** pipeline sederhana, baca file, parsing
`%{COMBINEDAPACHELOG}` (pattern bawaan Logstash, sama seperti
`web-service.conf` yang kamu pakai untuk Robot Shop), output ke `stdout`
dulu (supaya hasilnya langsung kelihatan tanpa perlu setup Elasticsearch
di container percobaan ini):
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

**4. Buat config Filebeat** baca file log contoh, kirim ke Logstash
(pola arsitektur seperti bagian d di atas, Filebeat baca file,
kirim ke Logstash lewat port beats):
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
format standar yang sama seperti yang kamu temukan di dokumentasi resmi
Apache/Nginx atau tutorial mana pun di internet soal Combined Log Format):
```bash
cat > /tmp/sample-access.log << 'EOF'
203.0.113.42 - - [12/Mar/2026:08:14:23 +0000] "GET /index.html HTTP/1.1" 200 4523 "-" "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
198.51.100.17 - - [12/Mar/2026:08:14:25 +0000] "GET /images/logo.png HTTP/1.1" 200 1820 "http://example.com/index.html" "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
203.0.113.99 - - [12/Mar/2026:08:14:31 +0000] "POST /api/login HTTP/1.1" 401 512 "-" "curl/8.4.0"
198.51.100.5 - - [12/Mar/2026:08:14:40 +0000] "GET /favicon.ico HTTP/1.1" 404 209 "-" "Mozilla/5.0 (X11; Linux x86_64)"
203.0.113.7 - - [12/Mar/2026:08:15:02 +0000] "GET /products?category=shoes HTTP/1.1" 200 8877 "-" "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)"
EOF
```

**6. Jalankan Logstash** (background, non-root user `logstash` — di
server sungguhan ini biasanya `systemctl enable --now logstash`, tapi
container percobaan ini tidak punya systemd, jadi jalankan manual). User
`logstash` yang dibuat package APT punya login shell `/usr/sbin/nologin`
(memang sengaja — best practice service account tidak boleh login
interaktif) — makanya perlu `su -s /bin/bash` (paksa pakai bash untuk
command ini saja), `su logstash` polos akan ditolak dengan error
`This account is currently not available`:
```bash
mkdir -p /tmp/ls-data /tmp/ls-logs && chown logstash:logstash /tmp/ls-data /tmp/ls-logs
su -s /bin/bash logstash -c "/usr/share/logstash/bin/logstash -f /etc/logstash/conf.d/native-demo.conf --path.settings /etc/logstash --path.data /tmp/ls-data --path.logs /tmp/ls-logs &"
```
`--path.settings /etc/logstash` disebutkan eksplisit di sini berbeda
dari kalau kamu jalankan lewat `systemctl` (yang otomatis tahu lokasi
config), invocation manual seperti ini tidak otomatis menemukan
`log4j2.properties`/`jvm.options` paket APT (lokasinya di `/etc/logstash`,
bukan `/usr/share/logstash/config` yang malah tidak ada) — tanpa flag ini
Logstash tetap jalan, tapi fallback ke logging konsol-saja dan
`/tmp/ls-logs/logstash-plain.log` di langkah verifikasi berikut tidak
akan pernah dibuat.

Tunggu sampai muncul log `Pipelines running` (~30-40 detik, JVM startup)
sebelum lanjut ke langkah 7 — cek dengan `tail -f /tmp/ls-logs/logstash-plain.log`.

**7. Jalankan Filebeat** (root, di server sungguhan `systemctl enable --now filebeat`):
```bash
/usr/share/filebeat/bin/filebeat -e -c /etc/filebeat/filebeat.yml \
  --path.home /usr/share/filebeat --path.config /etc/filebeat \
  --path.data /tmp/fb-data --path.logs /tmp/fb-logs
```
Expected Output di terminal Logstash (langkah 6), 5 dokumen
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
utama, cuma latihan skill install):
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

**Cari transaksi anomali.** Traffic Robot Shop di sesi ini punya SATU pola
"tidak normal" yang PASTI ada (500, disuntik sengaja), dan SATU pola yang
MUNGKIN ada tergantung performa host-mu (429, kapasitas):
```
GET payment-service-parsed-*/_search
{ "size": 0, "aggs": { "by_status": { "terms": { "field": "http_status" } } } }
```
Expected Output (dari SALAH SATU pengukuran nyata milikmu bisa
beda total): `429: 133`, `200: 14`, `500: 13`. **Kalau di layarmu tidak ada
`429` sama sekali dan hampir semua `200`** hal itu normal juga, artinya host-mu
cukup kuat menangani `NUM_CLIENTS: 6` tanpa `payment` kewalahan (lihat
catatan Sesi 6). Yang PASTI selalu ada (tidak tergantung performa host):
field `500`.

Breakdown per `payment_user` untuk status `500` menunjukkan pola yang jelas:
```
GET payment-service-parsed-*/_search
{ "size": 0, "query": { "term": { "http_status": 500 } },
  "aggs": { "by_user": { "terms": { "field": "payment_user.keyword" } } } }
```
Expected Output: **SEMUA dokumen `http_status: 500` berasal
dari SATU user id yang sama, `partner-57`** — bukan pola `anonymous-N`
normal. Ini transaksi yang sengaja disuntik (fitur `ERROR=1` load
generator, lihat Sesi 6) — pola KONSENTRASI pada satu identitas
mencurigakan adalah tanda anomali/fraud.

**Kalau `429` MUNCUL di traffic-mu**, breakdown per user-nya akan
menunjukkan pola yang SANGAT berbeda dari 500. tersebar ke banyak user id
`anonymous-N` yang berbeda-beda (masing-masing cuma 1-2 kejadian), bukan
terkonsentrasi di satu id. Itu tandanya BUKAN anomali/fraud, tapi
**kapasitas service kewalahan** (lihat Sesi 6): banyak user LEGITIMATE
yang kebetulan sama-sama gagal karena `payment` tidak sanggup menampung
request bersamaan. Dua pola yang sama-sama "tidak normal" tapi butuh
respons berbeda. 500 butuh investigasi keamanan, 429 (kalau muncul)
butuh perbaikan kapasitas/scaling.

## f. Referensi Exercise

Lanjutkan latihan mandiri di [`exercise/sesi-8/README.md`](../../../exercise/sesi-8/README.md)
— Bagian 1 deteksi transaksi anomali, Bagian 2 menyusun grok pattern
sendiri untuk format log custom aplikasi [`crud-app/`](../../../crud-app/README.md).
