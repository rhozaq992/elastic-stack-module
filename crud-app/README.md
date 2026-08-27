# Task Tracker — CRUD Demo App

Aplikasi CRUD sederhana (Node.js/Express, in-memory, tanpa database) —
dipakai sebagai bahan latihan **exercise Sesi 8** (parsing log manual).
Bukan bagian dari `lab/` — hanya target observasi untuk exercise.

## Menjalankan

```bash
cd crud-app
docker compose up -d --build
```

Cek jalan: `curl http://localhost:3000/health` → `OK`.

## API

| Method | Path | Body | Keterangan |
|---|---|---|---|
| `GET` | `/tasks` | - | daftar semua task |
| `GET` | `/tasks/:id` | - | satu task |
| `POST` | `/tasks` | `{"title": "..."}` | buat task baru |
| `PUT` | `/tasks/:id` | `{"title": "...", "done": true}` | update task |
| `DELETE` | `/tasks/:id` | - | hapus task |

## Format Log

Aplikasi ini **SENGAJA TIDAK** pakai JSON atau Combined Log Format
standar — formatnya custom, pipe-delimited:
```
ts=<ISO8601>|method=<HTTP method>|path=<path>|status=<HTTP status>|duration_ms=<int>|id=<resource id atau ->
```
Contoh nyata:
```
ts=2026-08-26T18:40:44.770Z|method=POST|path=/tasks|status=201|duration_ms=8|id=1
```
Lihat log-nya: `docker compose logs -f task-tracker`.

> **INFORMATION:** format ini sengaja dibuat berbeda dari yang sudah
> Anda jumpai di lab (JSON `cart`, plain-text `payment`, Combined Log
> Format `web`) — dipakai untuk latihan menyusun grok pattern dari NOL
> di [`exercise/sesi-8/README.md`](../exercise/sesi-8/README.md) Bagian 2.
