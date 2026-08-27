# Exercise Sesi 6 — Profiling Aggregation eCommerce + Analisis APM

Dua bagian: **Bagian 1** lanjutkan agregasi revenue eCommerce dari Sesi 5
(fokus profiling & cache), **Bagian 2** analisis data trace APM `cart`/
`payment` yang sudah mengalir dari load generator sesi ini.

## Bagian 1 Use Case

Lanjutkan agregasi revenue per kategori dari Sesi 5 kali ini fokus ke
performanya: apakah query itu efisien, dan apakah request cache benar-benar bekerja?

## Tugas Bagian 1

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

## Kriteria Bagian 1

- Kamu punya angka `time_in_nanos` dari hasil `_profile`.
- Kamu punya bukti `hit_count` di `_stats/request_cache` naik setelah
  query kedua yang identik.
- Kamu bisa jelaskan kenapa `took` saja tidak selalu cukup untuk
  membuktikan cache bekerja (terutama di dataset kecil).

<details>
<summary>Petunjuk Bagian 1 (klik kalau stuck)</summary>

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

---

## Bagian 2 Use Case

Tim SRE mau tahu, dari dua service yang sudah menerapkan APM (`cart`, `payment`),
service mana yang paling banyak menyumbang latency ke pengalaman
checkout pengguna, dan endpoint SPESIFIK mana di service itu yang paling
lambat.

## Tugas Bagian 2

1. Lewat Kibana APM (Service inventory), catat **Latency (avg.)** untuk
   `cart` dan `payment` bagian mana yang lebih lambat, dan berapa kali lipat?
2. Klik ke service yang lebih lambat → tab **Transactions** → catat nama
   endpoint (`POST /...`) dengan latency tertinggi.
3. Klik endpoint itu → lihat panel **"Time spent by span type"** apakah
   waktunya mayoritas di `app` (kode sendiri) atau di span lain
   (`http`/`db`/dll)? Ini menentukan ke mana optimasi harus diarahkan.
4. Susun query Dev Tools Console SENDIRI (tanpa contoh, pola sama seperti
   di lab bagian e) ke index `traces-apm-default` untuk menghitung
   `avg(transaction.duration.us)` per `service.name` — bandingkan hasilnya
   dengan yang kamu lihat di UI langkah 1.

## Kriteria Bagian 2

- Kamu bisa sebutkan service mana yang lebih lambat dan endpoint
  spesifiknya.
- Kamu bisa jelaskan mengapa lambatnya endpoint itu karena kode aplikasi
  sendiri atau karena panggilan ke sistem lain (berdasarkan "Time spent
  by span type").
- Query aggregation manualmu di `traces-apm-default` menghasilkan angka
  yang KONSISTEN (bukan harus identik persis, tapi service yang sama
  yang muncul sebagai paling lambat) dengan yang tampil di Kibana APM UI.

Validasi hasil kerjamu (Bagian 1):
```bash
bash exercise/scripts/validate_sesi6.sh
```
