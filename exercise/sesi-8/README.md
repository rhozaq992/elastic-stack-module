# Exercise Sesi 8 — Bedakan Anomali Fraud vs Masalah Kapasitas

## Use Case

Traffic payment Robot Shop menunjukkan dua jenis status "tidak normal":
`http_status: 500` dan `http_status: 429`. Tim finance dan tim
infrastruktur SAMA-SAMA khawatir, tapi butuh penjelasan yang beda: yang
satu mungkin butuh investigasi fraud, yang satu lagi mungkin cuma butuh
tambah kapasitas server. Tugasmu: pakai data di `payment-service-parsed-*`
untuk membuktikan MANA YANG MANA — jangan cuma tebak dari nama status code-nya.

## Tugas

1. Hitung breakdown total transaksi per `http_status` (200, 429, 500).
2. Untuk `http_status: 500`: agregasi per `payment_user.keyword` — apakah
   tersebar merata, atau terkonsentrasi di satu/sedikit user id?
3. Untuk `http_status: 429`: agregasi per `payment_user.keyword` juga —
   bandingkan pola sebarannya dengan poin 2. Sama atau beda?
4. Bandingkan rata-rata `response_time_ms` antara `http_status: 200`
   (normal) vs `500` vs `429` — pola mana yang response-nya jauh lebih
   cepat dari normal (indikasi gagal duluan sebelum diproses penuh)?
5. Tulis kesimpulan: mana yang lebih cocok disebut "anomali/fraud"
   (butuh investigasi keamanan) dan mana yang lebih cocok disebut
   "masalah kapasitas" (butuh scaling/optimasi performa) — dengan alasan
   dari angka di atas, bukan dari nama status code-nya saja.

## Kriteria Selesai

- Kamu punya angka pasti untuk breakdown per status, breakdown per
  `payment_user` untuk status 500 DAN 429 secara terpisah, dan
  perbandingan `avg response_time_ms` ketiganya.
- Kesimpulanmu menjelaskan MINIMAL 1 perbedaan pola konkret antara 500 dan
  429 (mis. "500 terkonsentrasi pada 1 user id, 429 tersebar ke puluhan
  user id berbeda") — bukan cuma menyimpulkan dari nama status HTTP-nya.

## Petunjuk (buka kalau stuck)

<details>
<summary>Klik untuk lihat petunjuk query</summary>

Breakdown per status:
```
GET payment-service-parsed-*/_search
{ "size": 0, "aggs": { "by_status": { "terms": { "field": "http_status" } } } }
```

Breakdown per user untuk satu status tertentu + rata-rata response time
(ganti `500` dengan `429` untuk perbandingan):
```
GET payment-service-parsed-*/_search
{
  "size": 0,
  "query": { "term": { "http_status": 500 } },
  "aggs": {
    "by_user": { "terms": { "field": "payment_user.keyword", "size": 10 } },
    "avg_response_time": { "avg": { "field": "response_time_ms" } }
  }
}
```
</details>

Validasi hasil kerjamu:
```bash
bash exercise/scripts/validate_sesi8.sh
```
