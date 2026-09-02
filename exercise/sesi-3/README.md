# Exercise Sesi 3 — Query DSL pada Data Penerbangan

**Topik yang dilatih (dari Silabus Sesi 3):** Term Queries, Boolean
Queries, Full-text Search (`match`/`match_phrase`), dan Advanced Search
Techniques (relative date math pada `range`).

## Use Case

Tim operasional maskapai membutuhkan laporan cepat soal penerbangan
bermasalah — gunakan dataset penerbangan (berbeda use case dari data
toko online yang dipakai di lab) untuk latihan Query DSL.

## Tugas

Disarankan: eksplorasi dahulu lewat **Kibana Discover** (pilih data view
"Kibana Sample Data Flights", gunakan filter KQL — sama seperti yang
dipelajari pada lab Sesi 3 bagian d) untuk melihat sendiri polanya
sebelum menuliskan query Query DSL yang setara di bawah.

> **INFORMATION:** jawaban akhir tetap perlu dalam bentuk Query DSL
> (bukan hanya filter KQL di Discover), karena `validate_sesi3.sh`
> memeriksa hasilnya secara terprogram lewat API — proses eksplorasi
> lewat UI hanya mempermudah Anda memastikan polanya benar sebelum
> menuliskan query-nya.

1. Load sample data flights.
2. Cari total penerbangan yang DIBATALKAN (`Cancelled: true`).
3. Cari penerbangan maskapai tertentu (pilih salah satu `Carrier` yang ada
   di data) yang delay-nya di atas 60 menit.
4. Periksa mapping field `OriginCityName` (`GET
   kibana_sample_data_flights/_mapping/field/OriginCityName`), lalu coba
   `match` dan `match_phrase` pada field tersebut dengan nama kota yang
   sama — **bandingkan hasilnya**. Ternyata jumlah hits-nya SELALU SAMA
   PERSIS, kota apa pun yang Anda coba — kenapa? (Petunjuk: periksa tipe
   field-nya, lalu bandingkan dengan field `category` yang dipakai di lab
   Sesi 3 — tipe field-nya apa?)
5. Cari penerbangan yang DIBATALKAN **HANYA dalam 7 hari terakhir** (bukan
   seluruh dataset seperti langkah 2) — gunakan `range` query pada field
   `timestamp` dikombinasikan dengan `Cancelled: true`. Field `timestamp`
   bertipe `date`, sehingga Anda dapat menggunakan **relative date math**
   Elasticsearch (`now-7d`) alih-alih tanggal tetap.

> **INFORMATION:** penggunaan relative date math (`now-7d`) pada langkah 5
> penting karena data sample selalu ter-generate ulang relatif terhadap
> waktu sekarang setiap kali dimuat, sehingga tanggal tetap (hardcoded)
> akan keliru di lain waktu.

## Kriteria Selesai

- Anda memiliki angka pasti untuk jumlah penerbangan yang dibatalkan.
- Anda memiliki angka pasti untuk delay >60 menit per carrier pilihan Anda.
- Anda dapat menjelaskan KENAPA `match` dan `match_phrase` pada
  `OriginCityName` SELALU menghasilkan angka yang identik (bukan karena
  kebetulan menemukan kota yang "pas" supaya sama — field ini memang
  tidak akan pernah menunjukkan perbedaan, dan hal itu sendiri adalah
  poin pembelajarannya) — sebutkan tipe field `OriginCityName` vs tipe
  field `category` di lab sebagai alasannya.
- Anda memiliki angka pasti untuk penerbangan yang dibatalkan dalam 7 hari
  terakhir (query menggunakan `now-7d`, bukan tanggal hardcoded).

## Petunjuk (buka apabila mengalami kendala)

<details>
<summary>Klik untuk melihat perintah</summary>

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
GET kibana_sample_data_flights/_search
{
  "query": {
    "bool": {
      "filter": [
        { "term": { "Cancelled": true } },
        { "range": { "timestamp": { "gte": "now-7d/d", "lte": "now" } } }
      ]
    }
  }
}
```
**Catatan:** apabila query barusan setelah load data menunjukkan 0 hasil,
tunggu 1-2 detik dan coba lagi — Elasticsearch membutuhkan waktu singkat
("refresh", default ±1 detik) sebelum dokumen yang baru masuk dapat
langsung dicari (lihat penjelasan lengkap soal `_bulk`+refresh di Sesi 1).
</details>

Validasi hasil pekerjaan Anda:
```bash
bash exercise/scripts/validate_sesi3.sh
```
