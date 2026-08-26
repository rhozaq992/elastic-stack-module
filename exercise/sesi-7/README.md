# Exercise Sesi 7 — Backup Data Nyata di Cluster Multi-Node

## Use Case

Kamu sudah belajar snapshot/restore pakai index demo kosong di lab. Kali
ini praktikkan ke data yang benar-benar berisi (bukan cuma 1 dokumen
kosong) — simulasi backup rutin yang beneran dilakukan di produksi.

**Kerjakan exercise ini SELAGI cluster Sesi 7 masih jalan** (sebelum kamu
matikan untuk lanjut ke Sesi 8).

## Tugas

1. Bulk-index minimal 10 dokumen baru ke index `exercise-cluster-backup`
   (bebas isinya — bisa reuse pola data dari exercise Sesi 1).
2. Snapshot index itu ke repository `lab-fs-repo` (nama snapshot BEBAS,
   asal tidak bentrok dengan `snapshot-1` yang sudah dipakai di lab).
3. Hapus index-nya.
4. Restore dari snapshot, buktikan jumlah dokumen identik sebelum & sesudah.
5. Matikan 1 node (simulasi failure) SELAMA proses restore berlangsung —
   apa yang terjadi? Restore tetap selesai, atau gagal?

## Kriteria Selesai

- Kamu punya bukti nyata: count dokumen SEBELUM hapus dan SETELAH restore
  identik.
- Kamu tahu jawaban eksperimen poin 5 dari percobaan nyata, bukan tebakan.

## Petunjuk (buka kalau stuck)

<details>
<summary>Klik untuk lihat command</summary>

```bash
curl -X POST "http://localhost:9200/exercise-cluster-backup/_bulk?refresh=true" \
  -H 'Content-Type: application/x-ndjson' --data-binary '
{"index":{"_id":"1"}}
{"item":"contoh-1","value":100}
{"index":{"_id":"2"}}
{"item":"contoh-2","value":200}
'
```
```
PUT _snapshot/lab-fs-repo/snapshot-exercise-7?wait_for_completion=true
{ "indices": "exercise-cluster-backup", "ignore_unavailable": true }

DELETE exercise-cluster-backup

POST _snapshot/lab-fs-repo/snapshot-exercise-7/_restore?wait_for_completion=true
{ "indices": "exercise-cluster-backup", "include_global_state": false }
```
</details>

Validasi hasil kerjamu (jalankan SELAGI cluster Sesi 7 masih up):
```bash
bash exercise/scripts/validate_sesi7.sh
```
