# Exercise Sesi 6 — Profiling Aggregation eCommerce + Analisis APM

Dua bagian: **Bagian 1** menggunakan data eCommerce yang sudah Anda muat
sejak Sesi 3 untuk latihan aggregation baru (per kategori), kali ini
fokus pada performanya. **Bagian 2** analisis data trace APM `cart`/
`payment` yang sudah mengalir dari load generator sesi ini.

## Bagian 1 — Use Case

Data `kibana_sample_data_ecommerce` yang sudah Anda muat sejak lab Sesi 3
dipakai kembali di sini — kali ini untuk agregasi revenue **per
kategori** (`terms` + `avg`, kombinasi yang belum pernah dicoba
sebelumnya; Sesi 5 melatih `date_histogram` + pipeline aggregation pada
data lain), dengan fokus pada performanya: apakah query tersebut efisien,
dan apakah request cache benar-benar bekerja?

## Tugas Bagian 1

1. Jalankan query aggregation `terms` (per `category.keyword`) + `avg` (
   `taxful_total_price`) pada `kibana_sample_data_ecommerce`, dengan
   `"profile": true`.
2. Dari hasil profile, cari `time_in_nanos` pada bagian aggregation —
   berapa milidetik?
3. Jalankan query YANG SAMA PERSIS sebanyak 2 kali. Periksa
   `_stats/request_cache` sebelum dan sesudahnya — apakah `hit_count` naik?

> **INFORMATION:** pada dataset sekecil ini (4675 dokumen), perbedaan
> `took` sebelum/sesudah cache mungkin TIDAK terlihat jelas (sama-sama
> sudah sangat cepat) — berbeda dengan `kibana_sample_data_logs` (14074
> dokumen) yang dipakai pada lab. Ini justru pelajaran penting: **cache
> paling terasa manfaatnya pada dataset besar/query berat**, bukan selalu
> terlihat pada data kecil — buktikan lewat `_stats/request_cache`
> (hit_count), bukan sekadar `took`.

## Kriteria Bagian 1

- Anda memiliki angka `time_in_nanos` dari hasil `_profile`.
- Anda memiliki bukti `hit_count` pada `_stats/request_cache` naik setelah
  query kedua yang identik.
- Anda dapat menjelaskan mengapa `took` saja tidak selalu cukup untuk
  membuktikan cache bekerja (terutama pada dataset kecil).

<details>
<summary>Petunjuk Bagian 1 (klik apabila mengalami kesulitan)</summary>

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
Periksa cache:
```bash
curl "http://localhost:9200/kibana_sample_data_ecommerce/_stats/request_cache?pretty"
```
</details>

---

## Bagian 2 — Use Case

Tim SRE ingin mengetahui, dari dua service yang sudah menerapkan APM
(`cart`, `payment`), service mana yang paling banyak menyumbang latency
terhadap pengalaman checkout pengguna, dan endpoint SPESIFIK mana pada
service tersebut yang paling lambat.

## Tugas Bagian 2

1. Lewat Kibana APM (Service inventory), catat **Latency (avg.)** untuk
   `cart` dan `payment` — mana yang lebih lambat, dan berapa kali lipat?
2. Klik ke service yang lebih lambat → tab **Transactions** → catat nama
   endpoint (`POST /...`) dengan latency tertinggi.
3. Klik endpoint tersebut → lihat panel **"Time spent by span type"** —
   apakah waktunya mayoritas berada di `app` (kode sendiri) atau di span
   lain (`http`/`db`/dll)? Ini menentukan ke mana optimasi harus diarahkan.
4. Susun query Dev Tools Console SENDIRI (tanpa contoh, pola sama seperti
   pada lab bagian e) ke index `traces-apm-default` untuk menghitung
   `avg(transaction.duration.us)` per `service.name` — bandingkan hasilnya
   dengan yang Anda lihat pada UI di langkah 1.

## Kriteria Bagian 2

- Anda dapat menyebutkan service mana yang lebih lambat dan endpoint
  spesifiknya.
- Anda dapat menjelaskan apakah lambatnya endpoint tersebut disebabkan
  oleh kode aplikasi sendiri atau oleh panggilan ke sistem lain
  (berdasarkan "Time spent by span type").
- Query aggregation mandiri Anda pada `traces-apm-default` menghasilkan
  angka yang KONSISTEN (tidak harus identik persis, tetapi service yang
  sama yang muncul sebagai paling lambat) dengan yang tampil pada Kibana
  APM UI.

Validasi hasil kerja Anda (Bagian 1):
```bash
bash exercise/scripts/validate_sesi6.sh
```
