# Exercise Sesi 5 — Aggregation pada Data eCommerce

## Use Case

Tim analytics eCommerce mau tahu berapa banyak pelanggan unik yang pernah
belanja, dan dari daerah mana saja order-nya berasal, gunakan
`kibana_sample_data_ecommerce` (beda dataset dari latihan lab yang pakai
data log web server).

**Soal data:** exercise ini pakai index `kibana_sample_data_ecommerce`
yang SAMA dengan yang sudah kamu load di lab Sesi 3 **tidak perlu load
ulang** kalau kamu sudah mengerjakan Sesi 3 secara berurutan. Kalau belum
ada (`curl http://localhost:9200/kibana_sample_data_ecommerce/_count`
mengembalikan 404), load dulu:
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
   aggregation `max_bucket` di atasnya untuk cari HARI dengan revenue tertinggi.
4. **Visualisasikan hasil langkah 3 di Kibana** (bukan cuma lewat query) —
   buat bar chart Lens dari nol (lihat lab Sesi 5 bagian e untuk caranya):
   data view `kibana_sample_data_ecommerce`, Horizontal axis = `order_date`
   (date histogram), Vertical axis = **Sum** dari `taxful_total_price`.
   Ambil screenshot hasilnya, dan tunjukkan bar mana yang paling tinggi —
   harus cocok dengan tanggal yang kamu temukan lewat `max_bucket` di
   langkah 3.

## Kriteria Selesai

- Kamu punya angka pasti jumlah pelanggan unik.
- Kamu punya area geohash dengan order terbanyak.
- Kamu bisa sebutkan tanggal dengan revenue harian tertinggi, hasil dari
  pipeline aggregation `max_bucket` (bukan dihitung manual satu-satu).
- Kamu punya screenshot bar chart Lens "revenue per hari", dan bar
  tertingginya cocok dengan tanggal dari `max_bucket`.

## Petunjuk (buka kalau stuck)

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

Validasi hasil kerjamu:
```bash
bash exercise/scripts/validate_sesi5.sh
```
