# Exercise Sesi 2 — CRUD & Mapping Data Inventory

## Use Case

Tim gudang mau mulai catat data inventory barang di Elasticsearch —
butuh index dengan mapping yang benar (nama barang bisa dicari sebagian
kata, tapi juga bisa dicari persis untuk laporan), dan kemampuan
update stok saat barang keluar/masuk.

## Tugas

1. Buat index `exercise-inventory` dengan mapping eksplisit: field nama
   barang dalam DUA tipe (`text` dan `keyword`, seperti latihan
   `jabatan_text`/`jabatan_keyword` di Sesi 2), plus field `stock` (angka).
2. INDEX 3 dokumen barang (nama beda-beda, stock awal beda-beda).
3. UPDATE salah satu dokumen (kurangi stock-nya, simulasi barang keluar).
4. Buktikan `_version` naik setelah update.
5. DELETE satu dokumen, buktikan GET setelahnya HTTP 404.

## Kriteria Selesai

- Index `exercise-inventory` ada dengan mapping 2 tipe field yang benar.
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
      "stock": { "type": "integer" }
    }
  }
}

POST exercise-inventory/_doc/1
{ "item_name_text": "Wireless Mouse Logitech", "item_name_keyword": "Wireless Mouse Logitech", "stock": 50 }

POST exercise-inventory/_update/1
{ "doc": { "stock": 45 } }
```
</details>

Validasi hasil kerjamu:
```bash
bash exercise/scripts/validate_sesi2.sh
```
