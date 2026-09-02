# Exercise Sesi 2 — CRUD & Mapping Data Inventory

**Topik yang dilatih (dari Silabus Sesi 2):** Fields & Mappings, `text`
vs `keyword`, dan Document Operations (CRUD).

## Use Case

Tim gudang **ATK (Alat Tulis Kantor)** hendak mulai mencatat data
inventaris barang di Elasticsearch. Untuk itu, diperlukan index dengan
mapping yang benar (nama barang dapat dicari berdasarkan sebagian kata,
tetapi juga dapat dicari secara persis untuk keperluan laporan), serta
kemampuan memperbarui stok saat barang keluar/masuk.

## Tugas

1. Buat index `exercise-inventory` dengan mapping eksplisit, **minimal 4
   field**:
   - `item_name_text` (`text`): nama barang, dapat dicari berdasarkan
     sebagian kata.
   - `item_name_keyword` (`keyword`): nama barang secara persis, digunakan
     untuk laporan/agregasi.
   - `stock` (`integer`): jumlah stok.
   - `kategori` (`keyword`): mis. `"kertas"`, `"tulis"`, `"printer"`.
2. INDEX **3 dokumen barang ATK** (contoh: pulpen, kertas A4, tinta
   printer — atau barang ATK lain, asalkan jelas jenisnya), dengan nama,
   stok awal, dan kategori yang berbeda-beda sesuai jenis barangnya.
3. UPDATE salah satu dokumen (kurangi stoknya, sebagai simulasi barang keluar).
4. Buktikan `_version` bertambah setelah update.
5. DELETE satu dokumen, buktikan GET setelahnya menghasilkan HTTP 404.

## Kriteria Selesai

- Index `exercise-inventory` telah dibuat dengan mapping minimal 4 field
  sesuai daftar di atas (2 tipe teks + `stock` + `kategori`).
- Ada bukti nyata (output `_version` sebelum/sesudah update) bahwa update
  benar-benar mengubah dokumen.
- Ada bukti HTTP 404 setelah delete.

## Petunjuk (buka apabila mengalami kendala)

<details>
<summary>Klik untuk melihat contoh mapping dan perintah</summary>

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

Validasi hasil kerja Anda:
```bash
bash exercise/scripts/validate_sesi2.sh
```
