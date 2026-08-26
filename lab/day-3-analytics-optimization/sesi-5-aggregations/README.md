# Sesi 5 — Data Aggregations and Analytics

## a. Tujuan Sesi

Setelah sesi ini, kamu mampu melakukan analisis data agregat di
Elasticsearch — mulai dari agregasi dasar (rata-rata, grup per kategori),
agregasi bertingkat (pipeline), sampai agregasi berbasis lokasi geografis
(geo) — dan memahami bagaimana hasilnya bisa divisualisasikan di Kibana.

## b. Output yang Diharapkan

Sesi ini selesai kalau kamu berhasil menjalankan dan menjelaskan hasil dari
4 jenis agregasi: metric+bucket dasar, `terms`+`avg` bertingkat, pipeline
aggregation (`avg_bucket`), dan geo aggregation (`geohash_grid`).

## c. Teori & Struktur Sistem

**Aggregation** adalah cara Elasticsearch merangkum banyak dokumen jadi
statistik (mirip `GROUP BY` di SQL, tapi jauh lebih fleksibel — bisa
bertingkat/nested). Dua kategori utama:
- **Metric aggregation** — hitung satu angka dari sekumpulan dokumen
  (`avg`, `sum`, `min`, `max`, `cardinality`, dst.).
- **Bucket aggregation** — kelompokkan dokumen jadi beberapa "ember"
  berdasarkan kriteria (`terms` per nilai field, `date_histogram` per
  rentang waktu, `geohash_grid` per area geografis).

Bucket dan metric bisa **digabung bertingkat** — mis. "rata-rata bytes,
DIKELOMPOKKAN per response code" (metric di dalam bucket).

**Pipeline aggregation** adalah agregasi yang inputnya BUKAN dokumen
mentah, tapi HASIL agregasi lain (bucket aggregation lain) — makanya
disebut "pipeline", hasil satu aggregation jadi input aggregation
berikutnya. Contoh: "rata-rata dari total-bytes-per-hari" (`avg_bucket` di
atas `date_histogram`).

**Geo aggregation** mengelompokkan dokumen berdasarkan lokasi geografis
(field bertipe `geo_point`) — `geohash_grid` membagi peta jadi grid
segi-enam/kotak, tiap dokumen masuk ke grid sesuai koordinatnya.

## d. Praktik: Instalasi & Konfigurasi

*(Prasyarat: stack Sesi 1 masih jalan.)*

**Load sample data logs** (dataset access-log web server, punya field waktu & geo):
```bash
curl -X POST "http://localhost:5601/api/sample_data/logs" \
  -H "kbn-xsrf: true" -H "x-elastic-internal-origin: kibana"
```
Expected Output (aktual): `{"elasticsearchIndicesCreated":{"kibana_sample_data_logs":14074},"kibanaSavedObjectsLoaded":8}`

**Agregasi dasar bertingkat** — breakdown response code + rata-rata ukuran response:
```
GET kibana_sample_data_logs/_search
{
  "size": 0,
  "aggs": {
    "by_response": {
      "terms": { "field": "response.keyword" },
      "aggs": { "avg_bytes": { "avg": { "field": "bytes" } } }
    }
  }
}
```
Expected Output (aktual):
```
200: count=12832, avg_bytes=5897.9
404: count=801,   avg_bytes=5049.2
503: count=441,   avg_bytes=0.0     <- wajar, response error biasanya tidak ada body
```

## e. Contoh Implementasi

**Pipeline aggregation** — rata-rata total bytes PER HARI (agregasi di
atas hasil `date_histogram`, bukan dokumen mentah):
```
GET kibana_sample_data_logs/_search
{
  "size": 0,
  "aggs": {
    "requests_per_day": {
      "date_histogram": { "field": "@timestamp", "calendar_interval": "day" },
      "aggs": { "total_bytes": { "sum": { "field": "bytes" } } }
    },
    "avg_daily_bytes": {
      "avg_bucket": { "buckets_path": "requests_per_day>total_bytes" }
    }
  }
}
```
Expected Output (aktual): 61 bucket harian (mis. `2026-08-16: 1,531,493
bytes`), dan `avg_daily_bytes: 1,306,978.5` — rata-rata dari SEMUA total
harian itu, dihitung oleh `avg_bucket` tanpa perlu ambil data mentah lagi.
Perhatikan `buckets_path: "requests_per_day>total_bytes"` — sintaks untuk
"ambil hasil agregasi `total_bytes` di dalam tiap bucket `requests_per_day`".

**Geo aggregation** — kelompokkan traffic berdasarkan lokasi (grid geografis):
```
GET kibana_sample_data_logs/_search
{
  "size": 0,
  "aggs": {
    "grid": {
      "geohash_grid": { "field": "geo.coordinates", "precision": 3 }
    }
  }
}
```
Expected Output (aktual): 595 grid cell terisi, terpadat mis. `c1c: 135
dokumen`. `precision: 3` mengatur seberapa detail grid-nya (angka lebih
besar = grid lebih kecil/detail, cocok untuk zoom level peta yang berbeda).

**Visualisasi di Kibana.** Hasil agregasi seperti ini adalah dasar dari
visualisasi Kibana — `geohash_grid` misalnya langsung dipetakan ke
visualisasi **Maps**, `date_histogram` ke bar chart/line chart time-series.

![Kibana Visualize Library menampilkan daftar visualisasi tersimpan](../../../docs/screenshots/sesi-5/01-visualize-library.png)

*1. Buka menu ☰ → Analytics → Visualize Library.*

![Modal Create visualization menampilkan pilihan Visualization, Maps, Vega](../../../docs/screenshots/sesi-5/02-pilih-tipe-visualisasi.png)

*2. Klik "Create visualization" — pilih tipe "Visualization" (editor
point-and-click) untuk bikin bar chart "Count per day" (X-axis:
`@timestamp` date histogram, Y-axis: Count) dari `kibana_sample_data_logs`
— hasilnya langsung mencerminkan angka `requests_per_day` yang barusan kamu hitung lewat query.*

**Referensi — dashboard eCommerce bawaan Kibana** (contoh dashboard
lengkap dengan banyak visualisasi digabung, ship otomatis bareng Kibana
Sample Data eCommerce):

![Kibana Dashboard eCommerce Revenue menampilkan metric sum of revenue $77,218.02, breakdown kategori, transaksi per hari](../../../docs/screenshots/sesi-5/05-dashboard-ecommerce-jadi.png)

*Buka Dashboards → "[eCommerce] Revenue Dashboard" untuk lihat contoh
dashboard jadi — gabungan metric, bar chart, dan breakdown kategori,
semuanya interaktif (klik filter Manufacturer/Category di atas).*

## f. Referensi Exercise

Lanjutkan latihan mandiri di [`exercise/sesi-5/README.md`](../../../exercise/sesi-5/README.md).
