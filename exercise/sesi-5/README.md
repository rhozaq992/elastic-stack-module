# Exercise Sesi 5 — Aggregation pada Data eCommerce

## Use Case

Tim analytics eCommerce ingin mengetahui berapa banyak pelanggan unik yang
pernah berbelanja, serta dari daerah mana saja order tersebut berasal.
Exercise ini menggunakan `kibana_sample_data_ecommerce` (dataset yang
berbeda dari latihan lab, yang menggunakan data log web server).

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
4. **Visualisasikan hasil langkah 3 di Kibana** (bukan hanya lewat query) —
   buat bar chart Lens dari nol (lihat lab Sesi 5 bagian e untuk caranya):
   data view `kibana_sample_data_ecommerce`, Horizontal axis = `order_date`
   (date histogram), Vertical axis = **Sum** dari `taxful_total_price`.
   Ambil screenshot hasilnya, dan tunjukkan bar mana yang paling tinggi —
   harus cocok dengan tanggal yang Anda temukan melalui `max_bucket` pada
   langkah 3.

## Kriteria Selesai

- Anda memiliki angka pasti jumlah pelanggan unik.
- Anda memiliki area geohash dengan order terbanyak.
- Anda dapat menyebutkan tanggal dengan revenue harian tertinggi, hasil
  dari pipeline aggregation `max_bucket` (bukan dihitung manual satu per satu).
- Anda memiliki screenshot bar chart Lens "revenue per hari", dan bar
  tertingginya cocok dengan tanggal dari `max_bucket`.

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
