# Exercise Sesi 3 — Query DSL pada Data Penerbangan

## Use Case

Tim operasional maskapai butuh laporan cepat soal penerbangan bermasalah
— pakai dataset penerbangan (beda use case dari data toko online yang
dipakai di lab) untuk latihan Query DSL.

## Tugas

1. Load sample data flights.
2. Cari total penerbangan yang DIBATALKAN (`Cancelled: true`).
3. Cari penerbangan maskapai tertentu (pilih salah satu `Carrier` yang ada
   di data) yang delay-nya di atas 60 menit.
4. Cek mapping field `OriginCityName` (`GET
   kibana_sample_data_flights/_mapping/field/OriginCityName`), lalu coba
   `match` dan `match_phrase` di field itu dengan nama kota yang sama —
   **bandingkan hasilnya**. Ternyata jumlah hits-nya SELALU SAMA PERSIS,
   berapa pun kota yang kamu coba — kenapa? (Petunjuk: cek tipe field-nya,
   lalu bandingkan dengan field `category` yang dipakai di lab Sesi 3 —
   tipe field-nya apa?)

## Kriteria Selesai

- Kamu punya angka pasti untuk jumlah penerbangan dibatalkan.
- Kamu punya angka pasti untuk delay >60 menit per carrier pilihanmu.
- Kamu bisa jelaskan KENAPA `match` dan `match_phrase` di `OriginCityName`
  SELALU menghasilkan angka yang identik (bukan mencari kota yang "pas"
  supaya beda — field ini memang tidak akan pernah menunjukkan
  perbedaan, dan itu sendiri poin pembelajarannya) — sebutkan tipe field
  `OriginCityName` vs tipe field `category` di lab sebagai alasannya.

## Petunjuk (buka kalau stuck)

<details>
<summary>Klik untuk lihat command</summary>

```bash
curl -X POST "http://localhost:5601/api/sample_data/flights" \
  -H "kbn-xsrf: true" -H "x-elastic-internal-origin: kibana"
```
```
GET kibana_sample_data_flights/_search
{ "query": { "term": { "Cancelled": true } } }

GET kibana_sample_data_flights/_search
{
  "query": {
    "bool": {
      "filter": [
        { "term": { "Carrier": "Logstash Airways" } },
        { "range": { "FlightDelayMin": { "gt": 60 } } }
      ]
    }
  }
}
```
**Catatan:** kalau query barusan setelah load data menunjukkan 0 hasil,
tunggu 1-2 detik dan coba lagi — Elasticsearch butuh waktu singkat
("refresh", default ~1 detik) sebelum dokumen yang baru masuk bisa
langsung dicari (lihat penjelasan lengkap soal `_bulk`+refresh di Sesi 1).
</details>

Validasi hasil kerjamu:
```bash
bash exercise/scripts/validate_sesi3.sh
```
