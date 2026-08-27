# Exercise Sesi 7 — Backup Data Nyata di Cluster Multi-Node

## Use Case

Anda telah mempelajari snapshot/restore menggunakan index demo kosong
pada lab. Kali ini praktikkan pada data yang benar-benar berisi (bukan
hanya 1 dokumen kosong) — simulasi backup rutin yang dilakukan pada
lingkungan produksi.

**Kerjakan exercise ini SELAGI cluster Sesi 7 masih berjalan** (sebelum
Anda matikan untuk melanjutkan ke Sesi 8).

Seluruh perintah pada exercise ini dijalankan lewat **terminal**
(`curl`) — Kibana tidak aktif pada sesi ini (lihat catatan pada lab
Sesi 7 bagian c).

## Tugas

1. Bulk-index minimal 10 dokumen baru ke index `exercise-cluster-backup`.
2. Snapshot index tersebut ke repository `lab-fs-repo`.
3. Hapus index-nya.
4. Restore dari snapshot, buktikan jumlah dokumen identik sebelum dan
   sesudah.
5. Hapus index tersebut sekali lagi, lalu ulangi restore — kali ini
   matikan 1 node (simulasi failure) SELAMA proses restore berlangsung,
   lalu amati: apakah restore tetap selesai, atau gagal? **Catatan
   praktis:** dengan data sekecil ini, restore sinkron (`wait_for_completion=true`
   seperti pada langkah 4) selesai dalam hitungan milidetik — tidak ada
   waktu untuk mematikan node di terminal lain sebelum proses selesai.
   Jalankan restore secara ASINKRON (tanpa `wait_for_completion`, atau
   dengan nilainya `false`) supaya perintah langsung kembali tanpa
   menunggu, baru kemudian matikan node dan periksa progres restore lewat
   Recovery API (`GET exercise-cluster-backup/_recovery?human`, bukan
   API status snapshot — API tersebut untuk memantau proses PEMBUATAN
   snapshot, bukan restore).

> **INFORMATION:** isi dokumen pada langkah 1 bebas — dapat
> menggunakan kembali pola data dari exercise Sesi 1. Nama snapshot
> pada langkah 2 juga bebas, asalkan tidak bentrok dengan `snapshot-1`
> yang sudah dipakai pada lab.

## Kriteria Selesai

- Anda memiliki bukti nyata: jumlah dokumen SEBELUM hapus dan SETELAH
  restore identik.
- Anda mengetahui jawaban eksperimen poin 5 dari percobaan nyata, bukan
  dari dugaan.

## Petunjuk (buka apabila mengalami kendala)

<details>
<summary>Klik untuk melihat perintah</summary>

```bash
curl -X POST "http://localhost:9200/exercise-cluster-backup/_bulk?refresh=true" \
  -H 'Content-Type: application/x-ndjson' --data-binary '
{"index":{"_id":"1"}}
{"item":"contoh-1","value":100}
{"index":{"_id":"2"}}
{"item":"contoh-2","value":200}
'
```
```bash
curl -X PUT "http://localhost:9200/_snapshot/lab-fs-repo/snapshot-exercise-7?wait_for_completion=true" \
  -H 'Content-Type: application/json' \
  -d '{ "indices": "exercise-cluster-backup", "ignore_unavailable": true }'

curl -X DELETE "http://localhost:9200/exercise-cluster-backup"

curl -X POST "http://localhost:9200/_snapshot/lab-fs-repo/snapshot-exercise-7/_restore?wait_for_completion=true" \
  -H 'Content-Type: application/json' \
  -d '{ "indices": "exercise-cluster-backup", "include_global_state": false }'
```

Untuk langkah 5 (restore + matikan node), ulangi delete lalu restore
TANPA `wait_for_completion` supaya sempat mematikan node sebelum restore
selesai:
```bash
curl -X DELETE "http://localhost:9200/exercise-cluster-backup"

curl -X POST "http://localhost:9200/_snapshot/lab-fs-repo/snapshot-exercise-7/_restore" \
  -H 'Content-Type: application/json' \
  -d '{ "indices": "exercise-cluster-backup", "include_global_state": false }'

docker stop elk-lab-es-node3

curl "http://localhost:9200/exercise-cluster-backup/_recovery?human"
```
</details>

Validasi hasil pekerjaan Anda (jalankan SELAGI cluster Sesi 7 masih aktif):
```bash
bash exercise/scripts/validate_sesi7.sh
```
