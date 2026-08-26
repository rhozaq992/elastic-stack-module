# Exercise Sesi 4 — Boost Ketersediaan Stok

## Use Case

Tim marketing Robot Shop mau hasil pencarian selalu mengutamakan produk
yang MASIH ADA STOK-nya di atas produk yang habis — beda kriteria boost
dari latihan lab (yang pakai rating & kategori). Dua varian: **Varian A**
lewat Query DSL (Dev Tools Console), **Varian B** lewat Kibana UI
(Discover) — kerjakan DUA-DUANYA, keduanya melatih skill yang berbeda.

## Varian A — Query DSL (Dev Tools Console)

### Tugas

1. Pakai index `robot-shop-catalogue` (sudah ada dari Sesi 4 lab).
2. Buat query `bool` dengan `must: match_all` (semua produk tetap muncul)
   dan `should` yang boost produk dengan `instock > 0`.
3. Bandingkan urutan hasilnya dengan query `match_all` polos (tanpa boost)
   — apa yang berubah?
4. Coba variasi: pakai `function_score` dengan `field_value_factor` pada
   field `price` (mis. produk lebih murah dapat skor lebih tinggi) —
   gimana urutannya sekarang?

### Kriteria Selesai

- Kamu punya bukti (screenshot/output) urutan hasil SEBELUM dan SESUDAH
  boost stok diterapkan, dan bisa tunjukkan produk mana yang naik/turun
  posisinya.
- Kamu mencoba MINIMAL 1 kriteria boost lain selain stok (mis. harga) dan
  bisa jelaskan bedanya dengan boost stok.

<details>
<summary>Petunjuk Varian A (klik kalau stuck)</summary>

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

## Varian B — Kibana UI (Discover)

Query DSL bisa boost/ranking numerik, Discover/KQL **tidak bisa**
(cuma filter ya/tidak) — Varian B ini melatih apa yang Discover BISA
lakukan: filter + sort tanpa nulis query sama sekali.

### Tugas

1. Buka Discover, pastikan data view `robot-shop-catalogue` aktif (buat
   dulu kalau belum ada — lihat lab Sesi 4 bagian e).
2. Filter produk yang MASIH ADA stok: ketik KQL `instock > 0` di search bar.
3. Tambah kolom `name`, `price`, `instock` (hover field di sidebar → klik **+**).
4. **Sort berdasarkan `price`**: klik nama kolom `price` di header tabel,
   klik ikon panah yang muncul untuk urutkan naik/turun.

### Kriteria Selesai

- Kamu punya screenshot Discover menampilkan hasil filter `instock > 0`
  dengan kolom `name`/`price`/`instock`, terurut berdasarkan `price`.
- Kamu bisa jelaskan KENAPA cara ini (Discover) tidak bisa dipakai untuk
  kasus boost rating seperti di lab (petunjuk: KQL tidak punya konsep
  `_score`/`boost` numerik, cuma bisa filter benar/salah).

Validasi hasil kerjamu (Varian A):
```bash
bash exercise/scripts/validate_sesi4.sh
```
