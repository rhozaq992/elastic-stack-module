# Exercise Sesi 1 — Bulk Index & REST API Dasar

Dua latihan di sesi ini: **Latihan 1** pakai data yang sudah disiapkan
(fokus ke cara kerja `_bulk` API), **Latihan 2** kamu susun sendiri
request-nya dari nol pakai bentuk data yang berbeda (fokus ke transfer
skill dari tabel REST API di `lab/day-1-fundamentals/sesi-1-intro-elk/README.md` bagian c).

## Latihan 1 — Bulk Index Data Monitoring Server (data disiapkan)

### Use Case

Tim infrastruktur mau mulai menyimpan metrik monitoring server (CPU, disk)
ke Elasticsearch, dan butuh cara cepat memasukkan banyak data metrik
sekaligus (bukan satu-satu).

### Tugas

1. Jalankan request `_bulk` di bawah ini apa adanya — ini data yang akan
   kamu pakai (jangan diubah, supaya threshold di langkah 2 pasti ketemu):

```bash
curl -X POST "http://localhost:9200/exercise-server-monitoring/_bulk?refresh=true" \
  -H 'Content-Type: application/x-ndjson' --data-binary '
{"index":{"_id":"1"}}
{"server":"web-01","metric":"cpu_percent","value":45.2,"recorded_at":"2026-08-26T08:00:00Z"}
{"index":{"_id":"2"}}
{"server":"web-01","metric":"cpu_percent","value":92.8,"recorded_at":"2026-08-26T09:00:00Z"}
{"index":{"_id":"3"}}
{"server":"web-02","metric":"cpu_percent","value":38.1,"recorded_at":"2026-08-26T08:00:00Z"}
{"index":{"_id":"4"}}
{"server":"web-02","metric":"cpu_percent","value":96.4,"recorded_at":"2026-08-26T09:00:00Z"}
{"index":{"_id":"5"}}
{"server":"db-01","metric":"disk_percent","value":71.0,"recorded_at":"2026-08-26T08:00:00Z"}
{"index":{"_id":"6"}}
{"server":"db-01","metric":"cpu_percent","value":55.7,"recorded_at":"2026-08-26T09:00:00Z"}
'
```

2. Cari server mana yang `cpu_percent`-nya di atas 90 (threshold alert) —
   susun sendiri query-nya pakai `bool`/`filter`/`range` (lihat tabel
   endpoint di lab Sesi 1 bagian c kalau lupa polanya).
3. Pastikan cluster tetap `yellow`/`green` (bukan `red`) setelah bulk index.

### Kriteria Selesai

- Index `exercise-server-monitoring` ada, 6 dokumen (sama seperti data di atas).
- Kamu bisa tunjukkan hasil query threshold alert — harus menemukan
  **2 dokumen** (`web-01` jam 09:00 dan `web-02` jam 09:00, keduanya di atas 90).
- `curl "http://localhost:9200/_cluster/health"` menunjukkan `status`
  bukan `red`.

<details>
<summary>Petunjuk query threshold (klik kalau stuck)</summary>

```
GET exercise-server-monitoring/_search
{
  "query": {
    "bool": {
      "filter": [
        { "term": { "metric": "cpu_percent" } },
        { "range": { "value": { "gt": 90 } } }
      ]
    }
  }
}
```
</details>

---

## Latihan 2 — Inventory Toko Online (susun sendiri)

### Use Case

Tim toko online mau mulai memindahkan data stok produk mereka ke
Elasticsearch. Bentuk datanya **beda** dari metrik server di Latihan 1 —
ini bukan angka metrik berurutan waktu, tapi katalog produk dengan
campuran tipe data (teks, angka, boolean).

### Tugas

1. Index index baru bernama `exercise-inventory` lewat `_bulk` API — kali
   ini **susun sendiri** request `_bulk`-nya (tidak ada template
   disediakan), berisi **minimal 5 produk** dengan field:
   - `sku` (kode produk, string, mis. `"SKU-001"`)
   - `name` (nama produk, string)
   - `category` (kategori, string, mis. `"elektronik"`/`"pakaian"`)
   - `price` (harga, angka)
   - `in_stock` (boolean, `true`/`false`)

   Pastikan minimal ada 2 produk dengan `in_stock: true` dan harga di
   bawah 500000, supaya query di langkah 2 punya hasil.
2. Susun query pencarian: produk dengan `in_stock: true` DAN `price`
   di bawah 500000.
3. Pastikan cluster tetap `yellow`/`green` (bukan `red`) setelah bulk index.

### Kriteria Selesai

- Index `exercise-inventory` ada, minimal 5 dokumen dengan field di atas.
- Kamu bisa tunjukkan hasil query langkah 2 (minimal 1 hasil).
- `curl "http://localhost:9200/_cluster/health"` menunjukkan `status`
  bukan `red`.

<details>
<summary>Petunjuk kalau benar-benar stuck (coba dulu tanpa buka ini)</summary>

Pola endpoint-nya sama seperti Latihan 1 —
`POST /<index>/_bulk?refresh=true`, header
`Content-Type: application/x-ndjson`, tiap dokumen didahului baris
`{"index":{}}`. Untuk query kombinasi boolean + angka, lihat lagi query
threshold di Latihan 1: `bool.filter` bisa diisi lebih dari satu kondisi
sekaligus (satu `term` untuk boolean, satu `range` untuk angka).
</details>

---

Validasi hasil kerjamu (kedua latihan sekaligus):
```bash
bash exercise/scripts/validate_sesi1.sh
```
