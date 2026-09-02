# Exercise Sesi 4 — Boost Ketersediaan Stok

**Topik yang dilatih (dari Silabus Sesi 4):** Customizing Scoring
(Function Score) dan Boosting.

## Use Case

Tim marketing Robot Shop ingin hasil pencarian selalu mengutamakan produk
yang MASIH ADA STOK-nya di atas produk yang habis — kriteria boost yang
berbeda dari latihan lab (yang menggunakan rating & kategori). Dua
varian: **Varian A** lewat Query DSL (Dev Tools Console), **Varian B**
lewat Kibana UI (Discover) — kerjakan KEDUANYA, masing-masing melatih
skill yang berbeda.

## Varian A — Query DSL (Dev Tools Console)

### Tugas

1. Gunakan index `robot-shop-catalogue` (sudah ada dari Sesi 4 lab).
2. Buat query `bool` dengan `must: match_all` (semua produk tetap muncul)
   dan `should` yang meng-boost produk dengan `instock > 0`.
3. Bandingkan urutan hasilnya dengan query `match_all` polos (tanpa boost)
   — apa yang berubah?
4. Coba variasi: gunakan `function_score` dengan `field_value_factor` pada
   field `price`, DENGAN `"modifier": "reciprocal"` (menghitung `1/price`,
   sehingga produk lebih MURAH mendapat skor lebih tinggi) — bagaimana
   urutannya sekarang?

> **INFORMATION:** `modifier: "reciprocal"` pada langkah 4 WAJIB
> disertakan — tanpa itu, `field_value_factor` justru mengalikan skor
> dengan nilai field apa adanya, sehingga produk yang lebih MAHAL yang
> naik, kebalikan dari yang diinginkan tim marketing.

### Kriteria Selesai

- Anda memiliki bukti (screenshot/output) urutan hasil SEBELUM dan
  SESUDAH boost stok diterapkan, dan dapat menunjukkan produk mana yang
  naik/turun posisinya.
- Anda mencoba MINIMAL 1 kriteria boost lain selain stok (mis. harga) dan
  dapat menjelaskan bedanya dengan boost stok.

<details>
<summary>Petunjuk Varian A (klik apabila mengalami kendala)</summary>

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

Query DSL dapat melakukan boost/ranking numerik, sedangkan Discover/KQL
**tidak bisa** (hanya filter ya/tidak) — Varian B ini melatih apa yang
Discover BISA lakukan: filter + sort tanpa menulis query sama sekali.

### Tugas

1. Buka Discover, pastikan data view `robot-shop-catalogue` aktif (buat
   terlebih dahulu apabila belum ada — lihat lab Sesi 4 bagian d topik 5).
2. Filter produk yang MASIH ADA stok: ketik KQL `instock > 0` di search bar.
3. Tambahkan kolom `name`, `price`, `instock` (hover field di sidebar,
   klik ikon **+**).
4. **Urutkan berdasarkan `price`**: klik nama kolom `price` di header
   tabel, klik ikon panah yang muncul untuk mengurutkan naik/turun.
5. **Simpan Discover session ini** — klik **Save** (kanan atas), beri
   nama **diawali `sesi-4-`** (mis. `sesi-4-instock-price`), klik
   **Save**.

> **INFORMATION:** validasi exercise ini TIDAK cukup dengan "data sudah
> ter-load" — yang dinilai adalah Discover session TERSIMPAN dengan nama
> spesifik berpola `sesi-4-*`, DAN jumlah dokumen hasil filternya (angka
> "Documents (N)" di atas tabel). Simpan session-nya, bukan cuma
> screenshot tanpa menyimpan.

### Kriteria Selesai

- Ada Discover session tersimpan dengan nama berpola `sesi-4-*`, berisi
  filter `instock > 0` dan kolom `name`/`price`/`instock` terurut
  berdasarkan `price`.
- Anda mencatat berapa jumlah dokumen ("Documents (N)") yang muncul untuk
  session tersimpan itu.
- Anda dapat menjelaskan KENAPA cara ini (Discover) tidak dapat dipakai
  untuk kasus boost rating seperti di lab (petunjuk: KQL tidak memiliki
  konsep `_score`/`boost` numerik, hanya dapat memfilter benar/salah).

Validasi hasil pekerjaan Anda (Varian A dan B):
```bash
bash exercise/scripts/validate_sesi4.sh
```
