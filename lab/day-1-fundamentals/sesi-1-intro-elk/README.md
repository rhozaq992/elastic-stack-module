# Sesi 1 — Introduction to Elasticsearch & ELK Stack

## a. Tujuan Sesi

Setelah sesi ini, kamu memahami apa itu Elasticsearch dan bagaimana
posisinya di dalam ELK Stack (Elasticsearch, Logstash, Kibana), mengenal
istilah-istilah dasar (cluster, node, index, shard, replikasi), dan
berhasil menjalankan environment lab (ketiga komponen ELK) di laptopmu sendiri.

## b. Output yang Diharapkan

Sesi ini selesai kalau:
- `docker compose ps` menunjukkan 3 container (`elk-lab-elasticsearch`,
  `elk-lab-kibana`, `elk-lab-logstash`) berstatus `Up`/`healthy`.
- `curl http://localhost:9200` mengembalikan info cluster Elasticsearch (bukan error koneksi).
- `curl http://localhost:5601/api/status` mengembalikan `level: available`.
- Kamu bisa menjelaskan dengan kata-katamu sendiri apa bedanya index, shard, dan replika.

## c. Teori & Struktur Sistem

**Apa itu Elasticsearch?** Mesin pencari & analitik terdistribusi, dibangun
di atas Apache Lucene. Data disimpan sebagai dokumen JSON, bukan baris
tabel seperti database relasional — cocok untuk pencarian teks, log,
metrik, dan data semi-terstruktur dalam volume besar.

**ELK Stack** adalah tiga komponen yang biasa dipakai bersama:
- **Elasticsearch** — penyimpanan & mesin pencari.
- **Logstash** — pipeline untuk menarik, memproses (parsing/transform), dan
  mengirim data ke Elasticsearch (dipakai mendalam di Sesi 8).
- **Kibana** — antarmuka web untuk eksplorasi, visualisasi, dan administrasi
  data di Elasticsearch.

**Istilah dasar (dipakai terus sepanjang lab ini):**
- **Cluster** — kumpulan satu atau lebih node Elasticsearch yang berbagi
  nama cluster dan menyimpan data secara terdistribusi. Lab ini pakai
  **single-node** (1 anggota saja), tapi konsep cluster tetap berlaku.
- **Node** — satu instance Elasticsearch yang berjalan (di lab ini: 1 container).
- **Index** — kumpulan dokumen dengan struktur/skema serupa (mirip "tabel"
  di database relasional, tapi jauh lebih fleksibel skemanya).
- **Shard** — index dipecah jadi beberapa bagian (shard) supaya data & beban
  bisa didistribusikan ke banyak node. Tiap shard punya 1 **primary** + 0
  atau lebih **replica**.
- **Replikasi** — salinan shard (replica) untuk ketahanan kalau sebuah node
  gagal. Di single-node, replica **tidak bisa** ditempatkan di node lain
  (karena cuma ada 1 node) — makanya status cluster **normalnya `yellow`**,
  bukan `green`, di lab ini (baru `green` kalau ada node lain untuk
  menampung replica-nya).

Elasticsearch expose REST API-nya di port **9200**, Kibana (antarmuka web)
di port **5601** — dua port ini dipakai terus sepanjang lab.

## d. Praktik: Instalasi & Konfigurasi

```bash
cd lab/day-1-fundamentals/sesi-1-intro-elk
docker compose up -d
```

Kibana baru mulai setelah Elasticsearch berstatus `healthy` (diatur lewat
`depends_on: condition: service_healthy` di `docker-compose.yml`), jadi
wajar kalau butuh puluhan detik lagi sampai ketiganya `healthy`/`running`.

**Cek status container:**
```bash
docker compose ps
```
Expected Output (aktual):
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
Expected Output (aktual):
```json
{
  "name" : "ec388c5aafb6",
  "cluster_name" : "docker-cluster",
  "cluster_uuid" : "GGMebYUJTSOyI4rbY8qstA",
  "version" : { "number" : "9.5.2", "build_flavor" : "default", "..." : "..." },
  "tagline" : "You Know, for Search"
}
```
(`name` dan `cluster_uuid` di layarmu akan beda — itu identifier acak per
instance, normal.)

**Verifikasi Kibana (port 5601):**
```bash
curl http://localhost:5601/api/status
```
Expected Output (aktual): `{"status":{"overall":{"level":"available"}}}`

Kalau belum `available`, tunggu ~20-30 detik lagi (Kibana butuh waktu
inisialisasi setelah container start) lalu coba ulang.

**Cek status cluster:**
```bash
curl "http://localhost:9200/_cluster/health?pretty"
```
Expected Output (aktual):
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
Status **`yellow`** itu **normal** untuk single-node (lihat penjelasan
Replikasi di atas) — bukan berarti ada yang rusak. Yang harus diperhatikan:
**`unassigned_primary_shards` harus 0**. Kalau bukan nol, baru itu tanda
ada masalah nyata.

## e. Contoh Implementasi

Buka Kibana di browser: `http://localhost:5601`. Ini yang akan kamu pakai
sepanjang lab untuk eksplorasi data (Discover), membuat visualisasi, dan
administrasi cluster — mulai dipakai aktif dari Sesi 2 seterusnya.

## f. Referensi Exercise

Lanjutkan latihan mandiri di [`exercise/sesi-1/README.md`](../../../exercise/sesi-1/README.md).
