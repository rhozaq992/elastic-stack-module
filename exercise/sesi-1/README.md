# Exercise Sesi 1 — Bulk Index Data Monitoring Server

## Use Case

Tim infrastruktur mau mulai menyimpan metrik monitoring server (CPU, disk)
ke Elasticsearch, dan butuh cara cepat memasukkan banyak data metrik
sekaligus (bukan satu-satu).

## Tugas

1. Index index baru `exercise-server-monitoring` menggunakan `_bulk` API,
   berisi minimal 5 dokumen metrik server (field: `server`, `metric`,
   `value`, `recorded_at`) — buat data sendiri, boleh contoh CPU/disk usage
   beberapa server.
2. Cari server mana yang `cpu_percent`-nya di atas 90 (threshold alert).
3. Pastikan cluster tetap `yellow`/`green` (bukan `red`) setelah bulk index.

## Kriteria Selesai

- Index `exercise-server-monitoring` ada, minimal 5 dokumen.
- Kamu bisa tunjukkan hasil query threshold alert (server mana saja yang
  kena, atau kosong kalau memang tidak ada — tunjukkan buktinya).
- `curl "http://localhost:9200/_cluster/health"` menunjukkan `status`
  bukan `red`.

## Petunjuk (buka kalau stuck)

<details>
<summary>Klik untuk lihat contoh format bulk</summary>

```bash
curl -X POST "http://localhost:9200/exercise-server-monitoring/_bulk?refresh=true" \
  -H 'Content-Type: application/x-ndjson' --data-binary '
{"index":{"_id":"1"}}
{"server":"web-01","metric":"cpu_percent","value":45.2,"recorded_at":"2026-08-26T08:00:00Z"}
{"index":{"_id":"2"}}
{"server":"web-01","metric":"cpu_percent","value":92.8,"recorded_at":"2026-08-26T09:00:00Z"}
'
```
Query threshold:
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

Validasi hasil kerjamu:
```bash
bash exercise/scripts/validate_sesi1.sh
```
