# Exercise Sesi 6 — Profiling Aggregation eCommerce + Analisis APM

Dua bagian: **Bagian 1** menggunakan data eCommerce yang sudah Anda muat
sejak Sesi 3 untuk latihan aggregation baru (per kategori), kali ini
fokus pada performanya. **Bagian 2** praktik mengelola data trace APM
`cart`/`payment` secara langsung lewat query — bukan sekadar membaca
panel Kibana APM UI — untuk menemukan akar penyebab latency, satu
tingkat lebih dalam dari yang diajarkan pada lab.

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

Tim SRE sudah tahu dari lab bahwa `payment` jauh lebih lambat daripada
`cart` secara keseluruhan. Tapi "servis X lambat" belum actionable —
tim yang berbeda perlu ditugaskan tergantung PENYEBABNYA: kalau
penyebabnya kode `payment` sendiri, tim dev `payment` yang menindaklanjuti;
kalau penyebabnya panggilan ke sistem/pihak LAIN, tim infra atau bahkan
vendor pihak ketiga yang perlu dihubungi. Tugas Anda: mengelola data
trace level SPAN (bukan sekadar transaction) lewat query untuk menemukan
akar penyebabnya sendiri.

## Tugas Bagian 2

1. Query `traces-apm-default` untuk transaksi (`processor.event:
   transaction`) pada `service.name: payment`, breakdown per
   `transaction.name` — endpoint mana yang paling lambat?
2. Untuk endpoint paling lambat itu, query span-level data
   (`processor.event: span`, `service.name: payment`), breakdown per
   `span.type`/`span.subtype` — catat hasilnya (Kibana APM UI menampilkan
   breakdown yang sama lewat panel "Time spent by span type").
3. **Perhatikan baik-baik hasil langkah 2** — apabila seluruh span
   berbeda hanya bertipe SATU jenis yang sama (mis. semuanya
   `external`/`http`), breakdown level type/subtype ITU SAJA TIDAK CUKUP
   untuk menunjuk dependency SPESIFIK mana yang bermasalah, karena semua
   panggilan keluar disamaratakan jadi satu kategori. Turunkan lagi
   granularitasnya: breakdown per `span.destination.service.resource` —
   dependency mana yang jauh lebih lambat dari yang lain?
4. Bandingkan durasi rata-rata dependency tersebut dengan durasi
   rata-rata dependency lain pada service yang sama — berapa kali lipat
   perbedaannya?

## Kriteria Bagian 2

- Anda dapat menyebutkan endpoint `payment` yang paling lambat, dengan
  angka durasi rata-ratanya.
- Anda dapat menjelaskan MENGAPA breakdown per `span.type`/`span.subtype`
  saja tidak selalu cukup untuk menemukan akar penyebab (dengan bukti
  konkret dari data Anda sendiri, bukan hanya berdasarkan penjelasan ini).
- Anda dapat menyebutkan dependency SPESIFIK (`span.destination.service.resource`)
  yang menjadi penyebab utama, dengan angka durasi rata-ratanya, dan
  berapa kali lipat lebih lambat dibanding dependency lain pada service
  yang sama.
- Anda dapat menyimpulkan: apakah tim `payment` perlu memperbaiki kode
  mereka sendiri, atau berkoordinasi dengan pihak/servis lain soal
  performanya — dengan alasan dari angka di atas.

<details>
<summary>Petunjuk Bagian 2 (klik apabila mengalami kesulitan)</summary>

```
GET traces-apm-default/_search
{
  "size": 0,
  "query": { "bool": { "filter": [
    { "term": { "service.name": "payment" } },
    { "term": { "processor.event": "transaction" } }
  ] } },
  "aggs": {
    "by_transaction": {
      "terms": { "field": "transaction.name" },
      "aggs": { "avg_ms": { "avg": { "field": "transaction.duration.us", "script": "_value / 1000" } } }
    }
  }
}
```
Breakdown span per type/subtype (langkah 2):
```
GET traces-apm-default/_search
{
  "size": 0,
  "query": { "bool": { "filter": [
    { "term": { "service.name": "payment" } },
    { "term": { "processor.event": "span" } }
  ] } },
  "aggs": {
    "by_type": {
      "terms": { "field": "span.type" },
      "aggs": { "by_subtype": { "terms": { "field": "span.subtype" } } }
    }
  }
}
```
Breakdown per dependency spesifik (langkah 3 — dijalankan HANYA apabila
langkah 2 menunjukkan seluruh span bertipe sama):
```
GET traces-apm-default/_search
{
  "size": 0,
  "query": { "bool": { "filter": [
    { "term": { "service.name": "payment" } },
    { "term": { "processor.event": "span" } }
  ] } },
  "aggs": {
    "by_destination": {
      "terms": { "field": "span.destination.service.resource" },
      "aggs": { "avg_ms": { "avg": { "field": "span.duration.us", "script": "_value / 1000" } } }
    }
  }
}
```
</details>

> **INFORMATION:** Kibana APM UI memiliki tab **Dependencies** pada
> halaman detail service yang menampilkan breakdown per dependency
> secara visual — dapat dipakai untuk memverifikasi hasil query Anda,
> tetapi tugas ini meminta Anda menyusun query-nya sendiri terlebih
> dahulu, sesuai tema sesi ini (mengelola data secara langsung).

Validasi hasil kerja Anda (Bagian 1):
```bash
bash exercise/scripts/validate_sesi6.sh
```
