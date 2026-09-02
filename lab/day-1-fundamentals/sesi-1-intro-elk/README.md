# Sesi 1 — Introduction to Elasticsearch & ELK Stack

## a. Tujuan Sesi

Setelah sesi ini, Anda memahami apa itu Elasticsearch dan bagaimana
posisinya di dalam ELK Stack (Elasticsearch, Logstash, Kibana), mengenal
istilah-istilah dasar (cluster, node, index, shard, replikasi), dan
berhasil menjalankan environment lab (ketiga komponen ELK) pada
perangkat masing-masing.

## b. Output yang Diharapkan

Sesi ini selesai apabila:
- `docker compose ps` menunjukkan 3 container (`elk-lab-elasticsearch`,
  `elk-lab-kibana`, `elk-lab-logstash`) berstatus `Up`/`healthy`.
- `curl http://localhost:9200` mengembalikan info cluster Elasticsearch (bukan error koneksi).
- `curl http://localhost:5601/api/status` mengembalikan `level: available`.
- Anda dapat menjelaskan dengan kata-kata sendiri perbedaan index, shard, dan replika.

## c. Teori & Struktur Sistem

**Apa itu Elasticsearch?** Mesin pencari & analitik terdistribusi, dibangun
di atas Apache Lucene. Data disimpan sebagai dokumen JSON, bukan baris
tabel seperti database relasional — cocok untuk pencarian teks, log,
metrik, dan data semi-terstruktur dalam volume besar.

Tiga kasus pemakaian yang paling umum di lapangan (dan yang akan Anda
sentuh langsung pada lab ini):
- **Log & event analytics** — kumpulkan log aplikasi/server, cari pola,
  hitung frekuensi error (Sesi 7).
- **Full-text search** — pencarian produk/dokumen yang relevan, bukan
  cuma cocok persis (Sesi 3-4).
- **Observability & monitoring** — metrik performa, deteksi anomali
  traffic (Sesi 5-7).

Bedanya dengan database relasional (RDBMS) yang mungkin sudah Anda kenal:

| | RDBMS (MySQL/PostgreSQL) | Elasticsearch |
|---|---|---|
| Unit data | baris (row) dalam tabel dengan skema tetap | dokumen JSON, skema fleksibel per index |
| Bahasa query | SQL | REST API + JSON (Query DSL, lihat di bawah) |
| Kekuatan utama | transaksi konsisten (ACID), relasi antar tabel | pencarian teks & agregasi cepat di volume besar |
| Skema | wajib didefinisikan di awal (`CREATE TABLE`) | bisa longgar (dynamic mapping) atau ketat (lihat Sesi 2) |

**ELK Stack** adalah tiga komponen yang biasa dipakai bersama, ditambah
satu keluarga komponen pendukung yang sering disebut berdampingan:
- **Elasticsearch** — penyimpanan & mesin pencari.
- **Logstash** — pipeline untuk menarik, memproses (parsing/transform), dan
  mengirim data ke Elasticsearch.
- **Kibana** — antarmuka web untuk eksplorasi, visualisasi, dan administrasi
  data di Elasticsearch.
- **Beats** — kumpulan agen pengirim data berukuran ringan (satu binary
  kecil per jenis sumber data, contoh: **Filebeat** untuk file log).
  Tugasnya membaca data dari sumbernya lalu mengirimkannya ke Logstash
  atau langsung ke Elasticsearch — dibahas mendalam pada Sesi 7.

![Alur data ELK Stack: Sumber Data ke Beats/Logstash ke Elasticsearch ke Kibana](../../../docs/diagrams/elk-dataflow.svg)

*Alur data ELK Stack secara umum. Data mentah masuk lewat Beats/Logstash,
disimpan & diindeks di Elasticsearch, lalu dieksplorasi lewat Kibana —
namun Anda juga dapat berkomunikasi langsung dengan Elasticsearch lewat
REST API tanpa melalui Kibana sama sekali (lihat bagian "Struktur REST
API" di bawah).*

**Istilah dasar:**
- **Cluster** — kumpulan satu atau lebih node Elasticsearch yang berbagi
  nama cluster dan menyimpan data secara terdistribusi. Lab ini
  menggunakan **single-node** (1 anggota saja), namun konsep cluster
  tetap berlaku.
- **Node** — satu instance Elasticsearch yang berjalan.
- **Index** — kumpulan dokumen dengan struktur/skema serupa (mirip "tabel"
  pada database relasional, namun jauh lebih fleksibel skemanya).
- **Shard** — index dipecah menjadi beberapa bagian (shard) agar data dan
  beban dapat didistribusikan ke banyak node. Tiap shard memiliki 1
  **primary** ditambah 0 atau lebih **replica**.
- **Replikasi** — salinan shard (replica) untuk ketahanan apabila sebuah
  node gagal. Pada single-node, replica **tidak dapat** ditempatkan pada
  node lain (karena hanya ada 1 node) — sehingga status cluster
  **normalnya `yellow`**, bukan `green`, pada lab ini (baru `green`
  apabila ada node lain untuk menampung replica-nya).

Elasticsearch mengekspos REST API-nya pada port **9200**, Kibana
(antarmuka web) pada port **5601**.

**Struktur REST API Elasticsearch.** Seluruh interaksi dengan
Elasticsearch — baik lewat `curl` pada terminal maupun lewat Dev Tools
Console pada Kibana — mengikuti pola URL yang sama:

```
<METHOD> http://<host>:9200/<index>/_<endpoint>
```

| Method | Kegunaan | Contoh |
|---|---|---|
| `GET` | baca/cari data, tidak mengubah apa pun | `GET /_cluster/health` |
| `PUT` | buat/replace resource dengan ID yang ditentukan sendiri | `PUT /myindex/_doc/1` |
| `POST` | buat resource (ID di-generate otomatis) atau jalankan aksi | `POST /myindex/_search` |
| `DELETE` | hapus resource | `DELETE /myindex` |

Endpoint yang akan digunakan pada lab ini:

| Endpoint | Fungsi |
|---|---|
| `GET /_cluster/health` | status kesehatan cluster (dipakai di bawah) |
| `GET /_cat/indices?v` | daftar semua index dalam bentuk tabel ringkas |
| `PUT /<index>/_doc/<id>` | simpan satu dokumen dengan ID tertentu |
| `GET /<index>/_search` | cari dokumen (pakai Query DSL, JSON pada body — detail Sesi 3) |
| `POST /<index>/_bulk` | kirim banyak dokumen sekaligus dalam satu request (dipakai pada exercise sesi ini) |

Response selalu berupa **JSON**, dan HTTP status code mengikuti konvensi
umum (`200` sukses, `404` index/dokumen tidak ada, `400` request salah
format). `curl` pada terminal dan Dev Tools Console pada Kibana memanggil
API yang **persis sama** — Console hanya menyingkat penulisannya
(host/port otomatis, format `GET index/_search` tanpa perlu `curl -X GET
"http://localhost:9200/index/_search"` lengkap). Anda akan menggunakan
kedua caranya secara bergantian sepanjang lab: `curl` untuk hal yang
perlu dijalankan dari terminal/script (termasuk exercise sesi ini), Dev
Tools Console untuk eksplorasi interaktif mulai Sesi 2.

**Sekilas sidebar Kibana** (menu utama dapat diakses lewat ikon ☰ pada
pojok kiri atas):
- **Discover** — menjelajahi dokumen mentah per index, filter & search bebas.
- **Dashboard** & **Visualize Library** — menyusun dan membuat chart/grafik dari data.
- **Dev Tools** — Console untuk menjalankan request Elasticsearch langsung dari browser.
- **Stack Management** — administrasi: index, ILM policy, snapshot, dan sejenisnya.
- **Observability** — APM, log monitoring.
- Menu lain (Security, Integrations, dan sebagainya) berada di luar cakupan lab ini.

## d. Praktik: Instalasi & Konfigurasi

### 1. Instalasi & Verifikasi Environment ELK Stack

```bash
cd lab/day-1-fundamentals/sesi-1-intro-elk
docker compose up -d
```

Tunggu hingga ketiga container berstatus `healthy`/`running` sebelum
melanjutkan.

> **INFORMATION:** Kibana baru mulai setelah Elasticsearch berstatus
> `healthy` (diatur lewat `depends_on: condition: service_healthy` pada
> `docker-compose.yml`) — jeda beberapa saat sebelum ketiganya `Up` adalah
> normal.

**Periksa status container:**
```bash
docker compose ps
```
> **INFORMATION:** output pada layar Anda juga akan memiliki kolom
> `COMMAND`/`SERVICE`/`CREATED`/`PORTS` selain yang ditampilkan pada
> ringkasan Expected Output di bawah — hal tersebut normal, fokus pada
> kolom `STATUS`.

Expected Output (ringkasan kolom yang penting):
```
NAME                    IMAGE                                                 STATUS
elk-lab-elasticsearch   docker.elastic.co/elasticsearch/elasticsearch:9.5.2  Up (healthy)
elk-lab-kibana          docker.elastic.co/kibana/kibana:9.5.2                Up
elk-lab-logstash        docker.elastic.co/logstash/logstash:9.5.2            Up
```

**Verifikasi Elasticsearch (port 9200):**
```bash
curl http://localhost:9200
```
Expected Output:
```json
{
  "name" : "ec388c5aafb6",
  "cluster_name" : "docker-cluster",
  "cluster_uuid" : "GGMebYUJTSOyI4rbY8qstA",
  "version" : { "number" : "9.5.2", "build_flavor" : "default", "..." : "..." },
  "tagline" : "You Know, for Search"
}
```
> **INFORMATION:** `name` dan `cluster_uuid` pada layar Anda akan berbeda
> — nilai tersebut adalah identifier acak per instance, hal ini normal.

**Verifikasi Kibana (port 5601):**
```bash
curl http://localhost:5601/api/status
```
Expected Output: `{"status":{"overall":{"level":"available"}}}`

Apabila belum `available`, tunggu ±20-30 detik lagi (Kibana membutuhkan
waktu inisialisasi setelah container start) lalu coba kembali.

**Periksa status cluster:**
```bash
curl "http://localhost:9200/_cluster/health?pretty"
```
Expected Output:
```json
{
  "cluster_name" : "docker-cluster",
  "status" : "yellow",
  "number_of_nodes" : 1,
  "active_primary_shards" : 49,
  "unassigned_primary_shards" : 0,
  "active_shards_percent_as_number" : 96.07843137254902
}
```
> **INFORMATION:** angka `active_primary_shards` dan
> `active_shards_percent_as_number` pada tampilan Anda **boleh berbeda**
> — jumlahnya tergantung index sistem internal Kibana yang dibuat
> otomatis (dapat sedikit berbeda tiap versi). Status **`yellow`** adalah
> **normal** untuk single-node (lihat penjelasan Replikasi di atas) —
> bukan berarti ada yang rusak.

Periksa **`unassigned_primary_shards`** — nilainya **WAJIB 0**. Apabila
bukan nol, itu menjadi tanda adanya masalah nyata yang perlu ditelusuri
sebelum melanjutkan.

**Contoh Implementasi — Instalasi & Verifikasi:** buka Kibana pada
browser: `http://localhost:5601`. Halaman ini akan Anda gunakan
sepanjang lab untuk eksplorasi data (Discover), membuat visualisasi, dan
administrasi cluster — mulai digunakan secara aktif dari Sesi 2 dan
seterusnya.

![Kibana halaman utama setelah instalasi berhasil](../../../docs/screenshots/sesi-1/01-kibana-home.png)

*Tampilan Kibana Home kalau instalasi berhasil — kartu Elasticsearch,
Observability, Security, Analytics, dan tombol "Add integrations" di
sidebar kiri bawah.*

### 2. Operasi Dasar Lewat REST API (PUT/GET/DELETE)

**Contoh Implementasi — Round-trip API sederhana** — praktikkan langsung
tabel method/endpoint pada bagian (c) lewat terminal (Dev Tools Console
baru diperkenalkan pada Sesi 2):

```bash
# PUT -- simpan satu dokumen dengan ID yang ditentukan sendiri ("1")
curl -X PUT "http://localhost:9200/lab-intro-demo/_doc/1" \
  -H 'Content-Type: application/json' -d '{"pesan": "halo elasticsearch", "sesi": 1}'
```
Expected Output: `{"_index":"lab-intro-demo","_id":"1","result":"created", ...}`

```bash
# GET -- ambil kembali dokumen yang baru saja disimpan, dengan ID yang sama
curl "http://localhost:9200/lab-intro-demo/_doc/1?pretty"
```
Expected Output: `"_source" : { "pesan" : "halo elasticsearch", "sesi" : 1 }`

```bash
# DELETE -- bersihkan index demo, tidak dipakai lagi setelah ini
curl -X DELETE "http://localhost:9200/lab-intro-demo"
```
Expected Output: `{"acknowledged":true}`

Tiga perintah di atas mengikuti pola `<METHOD>
http://host:9200/<index>/_<endpoint>` yang dijelaskan pada bagian (c) —
pola ini akan terus digunakan (baik lewat `curl` maupun Dev Tools
Console) hingga sesi terakhir.

## e. Referensi Exercise

Lanjutkan latihan mandiri pada [`exercise/sesi-1/README.md`](../../../exercise/sesi-1/README.md).
