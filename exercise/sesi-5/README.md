# Exercise Sesi 5 — Aggregation pada Data eCommerce & Penerbangan

**Topik yang dilatih (dari Silabus Sesi 5):** Using Aggregations for
Data Analysis, Pipeline Aggregations, Geo-based Aggregations, dan
Visualisasi geo aggregation dengan Kibana Maps.

## Use Case

Tim analytics eCommerce ingin mengetahui berapa banyak pelanggan unik yang
pernah berbelanja, serta dari daerah mana saja order tersebut berasal
(langkah 1-3, `kibana_sample_data_ecommerce`). Terpisah dari itu, tim
operasional maskapai ingin dashboard ringkas soal harga tiket & pola
keterlambatan penerbangan (langkah 4, `kibana_sample_data_flights`) —
dataset yang berbeda lagi dari latihan lab (log web server).

**Soal data:** exercise ini menggunakan index `kibana_sample_data_ecommerce`
yang SAMA dengan yang sudah Anda muat pada lab Sesi 3 — **tidak perlu
memuat ulang** apabila Anda telah mengerjakan Sesi 3 secara berurutan.
Apabila data tersebut belum ada (`curl
http://localhost:9200/kibana_sample_data_ecommerce/_count` mengembalikan
404), muat terlebih dahulu:
```bash
curl -X POST "http://localhost:5601/api/sample_data/ecommerce" \
  -H "kbn-xsrf: true" -H "x-elastic-internal-origin: kibana"
```

## Tugas

1. Hitung jumlah pelanggan UNIK (`cardinality` aggregation pada field `customer_id`).
2. Buat geo aggregation (`geohash_grid`) pada field `geoip.location` — area
   mana yang order-nya paling banyak?
3. Kombinasikan: `date_histogram` per hari + `sum` dari `taxful_total_price`
   di tiap bucket-nya (total revenue harian) — lalu tambahkan pipeline
   aggregation `max_bucket` di atasnya untuk mencari HARI dengan revenue tertinggi.
4. **Bangun dashboard 5 visualisasi memakai data PENERBANGAN**
   (`kibana_sample_data_flights` — dataset berbeda lagi dari langkah 1-3,
   supaya Anda berlatih pada 3 dataset berbeda dalam satu sesi). Muat
   dulu apabila belum ada:
   ```bash
   curl -X POST "http://localhost:5601/api/sample_data/flights" \
     -H "kbn-xsrf: true" -H "x-elastic-internal-origin: kibana"
   ```
   Buat KELIMA visualisasi berikut lewat Lens/Maps (lihat lab Sesi 5
   bagian d topik 2 untuk cara memakai editor Lens), **beri nama PERSIS diawali
   `sesi-5-`** saat Save, lalu kumpulkan semuanya jadi SATU dashboard:
   - `sesi-5-avg-ticket-price` — Metric, fungsi **Average** pada
     `AvgTicketPrice`.
   - `sesi-5-flights-per-carrier` — Bar chart, Horizontal axis **Top
     values** pada `Carrier`, Vertical axis **Count**.
   - `sesi-5-delay-per-carrier` — Bar chart, Horizontal axis **Top
     values** pada `Carrier`, Vertical axis fungsi **Average** pada
     `FlightDelayMin` — maskapai mana yang PALING SERING delay?
   - `sesi-5-flights-per-day` — Bar chart, Horizontal axis **Date
     histogram** pada `timestamp`, Vertical axis **Count**.
   - `sesi-5-origin-map` — Kibana Maps, layer **Documents** pada data
     view Kibana Sample Data Flights, geospatial field `OriginLocation`.

> **INFORMATION:** validasi exercise ini memeriksa Visualize
> Library/Maps LEWAT NAMA (pola `sesi-5-*`) — bukan screenshot. Pastikan
> tiap visualisasi benar-benar di-**Save** (bukan cuma dibuat di editor
> lalu ditinggal), dan nama-nya diawali persis `sesi-5-` (huruf kecil,
> pakai tanda hubung).

> **INFORMATION:** `kibana_sample_data_flights` JUGA time-relative
> (sama seperti dataset sample data lain) — atur rentang waktu di kanan
> atas agar mencakup seluruh data (mis. rentang lebar beberapa bulan ke
> depan/belakang dari hari ini), supaya chart tidak kosong karena
> defaultnya cuma "Last 15 minutes".

## Kriteria Selesai

- Anda memiliki angka pasti jumlah pelanggan unik.
- Anda memiliki area geohash dengan order terbanyak.
- Anda dapat menyebutkan tanggal dengan revenue harian tertinggi, hasil
  dari pipeline aggregation `max_bucket` (bukan dihitung manual satu per satu).
- Ada TEPAT 5 visualisasi/map tersimpan dengan nama berpola `sesi-5-*`,
  tergabung dalam satu dashboard.
- Anda dapat menyebutkan maskapai dengan rata-rata `FlightDelayMin`
  tertinggi, berdasarkan visualisasi `sesi-5-delay-per-carrier` yang
  sudah Anda buat.

## Petunjuk (Buka Apabila Mengalami Kendala)

<details>
<summary>Klik untuk lihat contoh query</summary>

```
GET kibana_sample_data_ecommerce/_search
{ "size": 0, "aggs": { "unique_customers": { "cardinality": { "field": "customer_id" } } } }

GET kibana_sample_data_ecommerce/_search
{ "size": 0, "aggs": { "grid": { "geohash_grid": { "field": "geoip.location", "precision": 3 } } } }

GET kibana_sample_data_ecommerce/_search
{
  "size": 0,
  "aggs": {
    "revenue_per_day": {
      "date_histogram": { "field": "order_date", "calendar_interval": "day" },
      "aggs": { "total_revenue": { "sum": { "field": "taxful_total_price" } } }
    },
    "busiest_day": { "max_bucket": { "buckets_path": "revenue_per_day>total_revenue" } }
  }
}
```
</details>

Validasi hasil pekerjaan Anda:
```bash
bash exercise/scripts/validate_sesi5.sh
```
