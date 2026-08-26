# Exercise Sesi 4 — Boost Ketersediaan Stok

## Use Case

Tim marketing Robot Shop mau hasil pencarian selalu mengutamakan produk
yang MASIH ADA STOK-nya di atas produk yang habis — beda kriteria boost
dari latihan lab (yang pakai rating & kategori).

## Tugas

1. Pakai index `robot-shop-catalogue` (sudah ada dari Sesi 4 lab).
2. Buat query `bool` dengan `must: match_all` (semua produk tetap muncul)
   dan `should` yang boost produk dengan `instock > 0`.
3. Bandingkan urutan hasilnya dengan query `match_all` polos (tanpa boost)
   — apa yang berubah?
4. Coba variasi: pakai `function_score` dengan `field_value_factor` pada
   field `price` (mis. produk lebih murah dapat skor lebih tinggi) —
   gimana urutannya sekarang?

## Kriteria Selesai

- Kamu punya bukti (screenshot/output) urutan hasil SEBELUM dan SESUDAH
  boost stok diterapkan, dan bisa tunjukkan produk mana yang naik/turun
  posisinya.
- Kamu mencoba MINIMAL 1 kriteria boost lain selain stok (mis. harga) dan
  bisa jelaskan bedanya dengan boost stok.

## Petunjuk (buka kalau stuck)

<details>
<summary>Klik untuk lihat contoh query</summary>

```
GET robot-shop-catalogue/_search
{
  "query": {
    "bool": {
      "must": { "match_all": {} },
      "should": [ { "range": { "instock": { "gt": 0, "boost": 5 } } } ]
    }
  }
}
```
</details>

Validasi hasil kerjamu:
```bash
bash exercise/scripts/validate_sesi4.sh
```
