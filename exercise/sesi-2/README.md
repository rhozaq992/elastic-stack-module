# Exercise Sesi 2 — CRUD & Mapping Data Inventory

## Use Case

Tim gudang **ATK (Alat Tulis Kantor)** mau mulai catat data inventory
barang di Elasticsearch butuh index dengan mapping yang benar (nama
barang bisa dicari sebagian kata, tapi juga bisa dicari persis untuk
laporan), dan kemampuan update stok saat barang keluar/masuk.

## Tugas

1. Buat index `exercise-inventory` dengan mapping eksplisit, **minimal 4
   field**:
   - `item_name_text` (`text`) nama barang, bisa dicari sebagian kata.
   - `item_name_keyword` (`keyword`) nama barang sama persis, dipakai
     untuk laporan/agregasi.
   - `stock` (`integer`) jumlah stok.
   - `kategori` (`keyword`) mis. `"kertas"`, `"tulis"`, `"printer"`.
2. INDEX **3 dokumen barang ATK** (contoh: pulpen, kertas A4, tinta
   printer — atau barang ATK lain, bebas asal jelas jenisnya), nama
   beda-beda, stock awal beda-beda, kategori diisi sesuai jenis barangnya.
3. UPDATE salah satu dokumen (kurangi stock-nya, simulasi barang keluar).
4. Buktikan `_version` naik setelah update.
5. DELETE satu dokumen, buktikan GET setelahnya HTTP 404.

## Kriteria Selesai

- Index `exercise-inventory` ada dengan mapping minimal 4 field sesuai
  daftar di atas (2 tipe teks + `stock` + `kategori`).
- Ada bukti nyata (output `_version` sebelum/sesudah update) bahwa update
  benar-benar mengubah dokumen.
- Ada bukti HTTP 404 setelah delete.

## Petunjuk (buka kalau stuck)

<details>
<summary>Klik untuk lihat contoh mapping & command</summary>

```
PUT exercise-inventory
{
  "mappings": {
    "properties": {
      "item_name_text": { "type": "text" },
      "item_name_keyword": { "type": "keyword" },
      "stock": { "type": "integer" },
      "kategori": { "type": "keyword" }
    }
  }
}

PUT exercise-inventory/_doc/1
{ "item_name_text": "Pulpen Standard AE7", "item_name_keyword": "Pulpen Standard AE7", "stock": 50, "kategori": "tulis" }

POST exercise-inventory/_update/1
{ "doc": { "stock": 45 } }
```
</details>

Validasi hasil kerjamu:
```bash
bash exercise/scripts/validate_sesi2.sh
```
