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
4. Pakai `match_phrase` untuk cari `OriginCityName` kota tertentu (pilih
   salah satu kota yang ada di data) — bandingkan hasilnya dengan `match`
   biasa di field yang sama.

## Kriteria Selesai

- Kamu punya angka pasti untuk jumlah penerbangan dibatalkan.
- Kamu punya angka pasti untuk delay >60 menit per carrier pilihanmu.
- Kamu bisa jelaskan (dengan contoh nyata dari hasil query) beda hasil
  `match` vs `match_phrase` di field yang sama.

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
tunggu 1-2 detik dan coba lagi — index baru butuh waktu refresh sebelum
bisa dicari (lihat penjelasan near-real-time search di Sesi 1).
</details>

Validasi hasil kerjamu:
```bash
bash exercise/scripts/validate_sesi3.sh
```
