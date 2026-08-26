# Exercise Sesi 8 — Bedakan Anomali Fraud vs Masalah Kapasitas

## Use Case

Traffic payment Robot Shop bisa menunjukkan dua jenis status "tidak
normal": `http_status: 500` (SELALU ada, disuntik sengaja lewat load
generator) dan `http_status: 429` (MUNGKIN ada, tergantung seberapa kuat
laptopmu menangani beban — lihat catatan Sesi 6/8). Tim finance dan tim
infrastruktur SAMA-SAMA khawatir soal status "tidak normal", tapi butuh
penjelasan yang beda: yang satu butuh investigasi fraud, yang satu lagi
cuma butuh tambah kapasitas server. Tugasmu: pakai data di
`payment-service-parsed-*` untuk membuktikan MANA YANG MANA — jangan cuma
tebak dari nama status code-nya.

**Kalau traffic-mu tidak punya `429` sama sekali** (cek dulu breakdown di
tugas 1) — itu normal, bukan kegagalan. Kerjakan tugas 2, 4, 5 dengan
membandingkan `500` vs `200` saja, dan tugas 3 boleh dilewati (catat di
kesimpulanmu kenapa: "429 tidak muncul karena host saya cukup kuat").

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

- Kamu punya angka pasti untuk breakdown per status dan breakdown per
  `payment_user` untuk status **500** (wajib, selalu ada).
- **Kalau `429` ada di traffic-mu**: kamu juga punya breakdown per user
  untuk 429, dan kesimpulanmu menjelaskan MINIMAL 1 perbedaan pola konkret
  antara 500 dan 429 (mis. "500 terkonsentrasi pada 1 user id, 429
  tersebar ke puluhan user id berbeda").
- **Kalau `429` TIDAK ada**: kesimpulanmu tetap menjelaskan pola 500
  (konsentrasi pada 1 user id + response time abnormal) sebagai bukti
  anomali/fraud, dan mencatat bahwa host-mu tidak menunjukkan gejala
  kapasitas kali ini.

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
