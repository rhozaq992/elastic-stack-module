# Exercise Sesi 6 — Profiling Aggregation eCommerce

## Use Case

Lanjutkan agregasi revenue per kategori dari Sesi 5 — kali ini fokus ke
performanya: apakah query itu efisien, dan apakah request cache benar-benar bekerja?

## Tugas

1. Jalankan query aggregation `terms` (per `category.keyword`) + `avg` (
   `taxful_total_price`) pada `kibana_sample_data_ecommerce`, dengan
   `"profile": true`.
2. Dari hasil profile, cari `time_in_nanos` di bagian aggregation —
   berapa milidetik?
3. Jalankan query YANG SAMA PERSIS 2x. Cek `_stats/request_cache` sebelum
   dan sesudah — apakah `hit_count` naik?
4. **Catatan penting:** di dataset sekecil ini (4675 dokumen), perbedaan
   `took` sebelum/sesudah cache mungkin TIDAK terlihat jelas (sama-sama
   sudah sangat cepat) — beda dengan `kibana_sample_data_logs` (14074
   dokumen) yang dipakai di lab. Ini justru pelajaran penting: **cache
   paling terasa manfaatnya pada dataset besar/query berat**, bukan
   selalu terlihat di data kecil. Buktikan pakai `_stats/request_cache`
   (hit_count), bukan cuma `took`.

## Kriteria Selesai

- Kamu punya angka `time_in_nanos` dari hasil `_profile`.
- Kamu punya bukti `hit_count` di `_stats/request_cache` naik setelah
  query kedua yang identik.
- Kamu bisa jelaskan kenapa `took` saja tidak selalu cukup untuk
  membuktikan cache bekerja (terutama di dataset kecil).

## Petunjuk (buka kalau stuck)

<details>
<summary>Klik untuk lihat command</summary>

```
GET kibana_sample_data_ecommerce/_search
{
  "profile": true,
  "size": 0,
  "aggs": {
    "by_category": {
      "terms": { "field": "category.keyword", "size": 10 },
      "aggs": { "avg_price": { "avg": { "field": "taxful_total_price" } } }
    }
  }
}
```
Cek cache:
```bash
curl "http://localhost:9200/kibana_sample_data_ecommerce/_stats/request_cache?pretty"
```
</details>

Validasi hasil kerjamu:
```bash
bash exercise/scripts/validate_sesi6.sh
```
