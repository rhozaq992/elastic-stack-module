# Sesi 7 — Elasticsearch Administration & Scaling

## a. Tujuan Sesi

Setelah sesi ini, kamu mampu mengelola cluster Elasticsearch multi-node
(bukan cuma single-node seperti sesi-sesi sebelumnya), memahami snapshot &
restore untuk backup, mengatur Index Lifecycle Management (ILM), dan
melihat langsung bagaimana cluster tetap tersedia (high availability)
walau satu node mati.

## b. Output yang Diharapkan

Sesi ini selesai kalau cluster 3-node kamu berstatus `green`, kamu berhasil
melakukan snapshot+restore penuh (data identik sebelum/sesudah), dan
berhasil mensimulasikan 1 node mati lalu melihat cluster tetap available
(data tidak hilang, status `yellow` bukan `red`).

## c. Teori & Struktur Sistem

Sesi 1-6 kamu pakai Elasticsearch **single-node** — sekarang kita pindah
ke **cluster 3-node** untuk melihat konsep yang tidak bisa didemonstrasikan
di single-node:

- **Scaling** — menambah node ke cluster untuk menampung lebih banyak
  data/traffic. Tiap node menjalankan instance Elasticsearch sendiri,
  saling terhubung lewat `discovery.seed_hosts`.
- **`cluster.initial_master_nodes`** — daftar node yang jadi kandidat
  master saat cluster PERTAMA KALI dibentuk (cuma dipakai sekali di awal,
  bukan konfigurasi permanen).
- **Kenapa sekarang bisa `green`, bukan `yellow` terus** — ingat dari Sesi
  1: replica shard butuh node LAIN untuk ditempati. Dengan 3 node, replica
  akhirnya punya tempat, jadi status bisa `green` (semua primary DAN
  replica ter-assign) — kontras langsung dengan single-node yang
  mentok `yellow` selamanya.
- **High Availability (HA)** — kalau 1 node mati, cluster (dengan replica
  yang tersebar di node lain) tetap bisa melayani baca/tulis data,
  meski statusnya turun ke `yellow` sampai node itu kembali atau
  Elasticsearch realokasi shard ke node yang tersisa.

![Diagram High Availability cluster 3-node: normal semua node hidup vs 1 node mati tapi tetap melayani](../../../docs/diagrams/sesi7-ha-cluster.svg)

*Perbandingan langsung: di kondisi normal (kiri) primary (P) dan replica
(R) tersebar di 3 node berbeda. Kalau `es-node3` mati (kanan), primary
`P0`/`P1` yang tersisa di `es-node1`/`es-node2` masih utuh — cluster
turun status jadi `yellow` (bukan `red`) dan TETAP melayani baca/tulis.
Ini yang akan kamu buktikan sendiri di bagian "Simulasi Failure" nanti.*

**Data Retention — hubungannya dengan storage.** "Retention" adalah
kebijakan berapa lama data disimpan sebelum dihapus otomatis. Ini bukan
soal disiplin administratif semata — ada hubungan matematis langsung ke
kapasitas disk:

```
kebutuhan storage ≈ (rata-rata data masuk per hari) × (jumlah hari retensi) × (1 + jumlah replica)
```

Index yang tidak pernah dihapus akan tumbuh TANPA BATAS sampai disk
penuh (lihat catatan `disk_threshold` di bagian d) — makin lama retensi,
makin besar storage yang dibutuhkan, dan faktor replica (tiap replica =
salinan penuh data) melipatgandakannya lagi. Inilah kenapa `delete` phase
di ILM (dibahas di bagian e) bukan fitur opsional untuk data
log/metrik/trace bervolume tinggi — tanpa retensi, cluster produksi biasa
akan kehabisan disk dalam hitungan minggu/bulan, bukan tahun. Kebijakan
retensi yang umum: log aplikasi 7-30 hari, metrik 30-90 hari, data
compliance/audit bisa tahunan (biasanya dipindah ke tier storage lebih
murah, bukan disimpan penuh di hot tier — di luar cakupan lab ini).

## d. Praktik: Instalasi & Konfigurasi

**Sebelum mulai — cek kapasitas host** (dilakukan PROAKTIF, sebelum
`docker compose up`, supaya tidak ketemu masalah storage/memory di
tengah jalan seperti catatan `disk_threshold` di bawah):
```bash
docker system df                                    # cek disk terpakai Docker
docker info --format '{{.MemTotal}}'                 # cek RAM total dialokasikan ke Docker Desktop
```
Kalau `docker system df` menunjukkan banyak image/build cache menumpuk
dari sesi-sesi sebelumnya (wajar setelah mengerjakan Sesi 1-6 di host
yang sama), bersihkan DULU sebelum lanjut: `docker builder prune -f`
(aman, cuma build cache). Kalau RAM Docker Desktop di bawah 12GB (lihat
catatan RAM di bawah), naikkan dulu lewat Docker Desktop → Settings →
Resources → Memory, SEBELUM `docker compose up` — jauh lebih mudah
dibanding mendiagnosis cluster yang gagal `green` di tengah sesi.

> **RAM:** cluster 3-node ini makan RAM jauh lebih banyak dari single-node
> Sesi 1-6 — dites nyata, tiap node pakai **~1.4GB RAM** (total **~4.2GB**
> cuma untuk Elasticsearch, di luar overhead Docker Desktop sendiri).
> Pastikan Docker Desktop dialokasikan **minimal 12GB** (lebih dari 8GB
> yang cukup untuk single-node) sebelum lanjut.

```bash
cd lab/day-4-administration-ingestion/sesi-7-administration-scaling
docker compose up -d
```

**Cek cluster health:**
```bash
curl "http://localhost:9200/_cluster/health?pretty"
```
Expected Output:
```json
{
  "cluster_name" : "elk-lab-cluster",
  "status" : "green",
  "number_of_nodes" : 3,
  "number_of_data_nodes" : 3,
  "unassigned_shards" : 0,
  "active_shards_percent_as_number" : 100.0
}
```
**`green`** — beda dari single-node yang selalu `yellow` (lihat penjelasan di atas).

> **Kalau cluster tetap `yellow` lebih dari ~1 menit** (bukan langsung
> `green`), cek dulu penyebabnya sebelum curiga ada yang rusak:
> ```bash
> curl "http://localhost:9200/_cluster/allocation/explain?pretty"
> ```
> Kalau alasannya `disk_threshold` — itu bukan masalah cluster, itu disk
> Docker Desktop-mu yang penuh (default watermark ES: 85% terpakai baru
> menahan alokasi shard). Ini kemungkinan besar terjadi kalau kamu sudah
> mengerjakan banyak sesi sebelumnya di host yang sama (image/volume
> menumpuk). Solusi: `docker system df` untuk cek pemakaian, lalu
> `docker builder prune -f` (aman, cuma build cache) atau
> `docker system prune` (lebih agresif, hapus image tak terpakai) — cluster
> akan otomatis re-cek disk dan pindah ke `green` dalam ~30 detik setelah
> ruang cukup.

**Lihat daftar node:**
```bash
curl "http://localhost:9200/_cat/nodes?v"
```
Expected Output: 3 baris (`es-node1`, `es-node2`, `es-node3`),
salah satunya ditandai `*` di kolom `master` (node yang sedang jadi elected master).

## e. Contoh Implementasi

### Snapshot & Restore

**Setup repository** (`path.repo` sudah di-set saat startup container di
`docker-compose.yml`, volume snapshot-nya juga sudah disiapkan otomatis
saat `docker compose up` — tidak ada langkah manual tambahan):
```
PUT _snapshot/lab-fs-repo
{ "type": "fs", "settings": { "location": "/usr/share/elasticsearch/snapshots/lab-fs-repo" } }
```
Expected Output: `{"acknowledged":true}`. Verifikasi:
```
POST _snapshot/lab-fs-repo/_verify
```
Expected Output: `{"nodes":{...3 entry, satu per node...}}`.

**Index data contoh, lalu snapshot:**
```
POST lab-cluster-demo/_doc?refresh=true
{ "msg": "test before failure" }

PUT _snapshot/lab-fs-repo/snapshot-1?wait_for_completion=true
{ "indices": "lab-cluster-demo", "ignore_unavailable": true }
```
Expected Output: `"state":"SUCCESS"`.

**Uji restore penuh (hapus lalu kembalikan):**
```
GET lab-cluster-demo/_count                          # -> count: 1
DELETE lab-cluster-demo
POST _snapshot/lab-fs-repo/snapshot-1/_restore?wait_for_completion=true
{ "indices": "lab-cluster-demo", "include_global_state": false }
GET lab-cluster-demo/_count                          # -> count: 1 lagi
```
Expected Output: count SEBELUM dan SESUDAH restore identik (**1**
di kedua sisi) — restore benar-benar mengembalikan data persis sama, di
cluster 3-node sekalipun.

Semua langkah di atas juga bisa dilakukan lewat UI: **Stack Management →
Snapshot and Restore**:

![Kibana Snapshot and Restore, halaman awal sebelum repository didaftarkan](../../../docs/screenshots/sesi-7/02-snapshot-restore.png)

*Stack Management → Snapshot and Restore — kalau belum ada repository
terdaftar, tampilannya seperti ini ("Start by registering a repository").
Setelah kamu register lewat API di atas, tab "Repositories" dan
"Snapshots" akan menampilkan `lab-fs-repo` dan `snapshot-1`.*

### Simulasi Failure (High Availability)

```bash
docker stop elk-lab-es-node3
curl "http://localhost:9200/_cluster/health?pretty"
```
Expected Output: status turun ke **`yellow`** (BUKAN `red`),
`number_of_nodes: 2`, `unassigned_primary_shards: 0` — **data tetap utuh
dan tetap bisa dibaca**:
```bash
curl "http://localhost:9200/lab-cluster-demo/_search"
```
Expected Output: dokumen tetap muncul normal, walau 1 dari 3 node mati.

**Kembalikan node:**
```bash
docker start elk-lab-es-node3
```
Tunggu beberapa detik, cluster otomatis kembali `green` begitu node
bergabung lagi dan shard ter-realokasi.

### ILM (Index Lifecycle Management)

Sama seperti prinsip yang berlaku di single-node — ILM tidak bergantung
pada jumlah node. Buat policy contoh:
```
PUT _ilm/policy/lab-cluster-policy
{
  "policy": {
    "phases": {
      "hot": { "actions": { "rollover": { "max_age": "1d", "max_primary_shard_size": "5gb" } } },
      "delete": { "min_age": "7d", "actions": { "delete": {} } }
    }
  }
}
```
Terapkan lewat index template ke pattern index yang kamu mau kelola
otomatis (lihat Sesi 8 untuk contoh index hasil pipeline Logstash yang
cocok dipasangi ILM ini).

Cek lewat UI: **Stack Management → Index Lifecycle Policies**:

![Kibana Index Lifecycle Policies menampilkan lab-cluster-policy dalam daftar policy](../../../docs/screenshots/sesi-7/01-ilm-policies.png)

*Stack Management → Index Lifecycle Policies — `lab-cluster-policy` yang
barusan kamu buat lewat API muncul di sini bersama policy sistem bawaan
Elasticsearch/Kibana lainnya.*

## f. Referensi Exercise

Lanjutkan latihan mandiri di [`exercise/sesi-7/README.md`](../../../exercise/sesi-7/README.md).
