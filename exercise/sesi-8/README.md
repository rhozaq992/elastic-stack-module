# Exercise Sesi 8 — Bedakan Anomali Fraud vs Masalah Kapasitas + Parser Manual

Dua bagian: **Bagian 1** analisis anomali payment Robot Shop (agregasi,
tanpa perlu tulis pipeline baru), **Bagian 2** tulis SENDIRI grok pattern
untuk format log custom yang belum pernah kamu temui di lab.

## Bagian 1 — Use Case

Traffic payment Robot Shop bisa menunjukkan dua jenis status "tidak
normal": `http_status: 500` (SELALU ada, disuntik sengaja lewat load
generator) dan `http_status: 429` (MUNGKIN ada, tergantung seberapa kuat
laptopmu menangani beban — lihat catatan Sesi 6/8). Tim finance dan tim
infrastruktur SAMA-SAMA khawatir soal status "tidak normal", tapi butuh
penjelasan yang beda: yang satu butuh investigasi fraud, yang satu lagi
cuma butuh tambah kapasitas server. Tugasmu: pakai data di
`payment-service-parsed-*` untuk membuktikan MANA YANG MANA — jangan cuma
tebak dari nama status code-nya.

**Kalau traffic-mu tidak punya `429` sama sekali** (cek dulu breakdown di
tugas 1) — itu normal, bukan kegagalan. Kerjakan tugas 2, 4, 5 dengan
membandingkan `500` vs `200` saja, dan tugas 3 boleh dilewati (catat di
kesimpulanmu kenapa: "429 tidak muncul karena host saya cukup kuat").

## Tugas Bagian 1

1. Hitung breakdown total transaksi per `http_status` (200, 429, 500).
2. Untuk `http_status: 500`: agregasi per `payment_user.keyword` — apakah
   tersebar merata, atau terkonsentrasi di satu/sedikit user id?
3. Untuk `http_status: 429`: agregasi per `payment_user.keyword` juga —
   bandingkan pola sebarannya dengan poin 2. Sama atau beda?
4. Bandingkan rata-rata `response_time_ms` antara `http_status: 200`
   (normal) vs `500` vs `429` — pola mana yang response-nya jauh lebih
   cepat dari normal (indikasi gagal duluan sebelum diproses penuh)?
5. Tulis kesimpulan: mana yang lebih cocok disebut "anomali/fraud"
   (butuh investigasi keamanan) dan mana yang lebih cocok disebut
   "masalah kapasitas" (butuh scaling/optimasi performa) — dengan alasan
   dari angka di atas, bukan dari nama status code-nya saja.

## Kriteria Bagian 1

- Kamu punya angka pasti untuk breakdown per status dan breakdown per
  `payment_user` untuk status **500** (wajib, selalu ada).
- **Kalau `429` ada di traffic-mu**: kamu juga punya breakdown per user
  untuk 429, dan kesimpulanmu menjelaskan MINIMAL 1 perbedaan pola konkret
  antara 500 dan 429 (mis. "500 terkonsentrasi pada 1 user id, 429
  tersebar ke puluhan user id berbeda").
- **Kalau `429` TIDAK ada**: kesimpulanmu tetap menjelaskan pola 500
  (konsentrasi pada 1 user id + response time abnormal) sebagai bukti
  anomali/fraud, dan mencatat bahwa host-mu tidak menunjukkan gejala
  kapasitas kali ini.

<details>
<summary>Petunjuk Bagian 1 (klik kalau stuck)</summary>

Breakdown per status:
```
GET payment-service-parsed-*/_search
{ "size": 0, "aggs": { "by_status": { "terms": { "field": "http_status" } } } }
```

Breakdown per user untuk satu status tertentu + rata-rata response time
(ganti `500` dengan `429` untuk perbandingan):
```
GET payment-service-parsed-*/_search
{
  "size": 0,
  "query": { "term": { "http_status": 500 } },
  "aggs": {
    "by_user": { "terms": { "field": "payment_user.keyword", "size": 10 } },
    "avg_response_time": { "avg": { "field": "response_time_ms" } }
  }
}
```
</details>

---

## Bagian 2 — Use Case

Tim platform baru saja deploy layanan internal baru, **Task Tracker**
(`crud-app/` di root repo ini) — log akses-nya BUKAN JSON, BUKAN Combined
Log Format seperti yang sudah kamu tangani di lab, tapi format custom
pipe-delimited buatan tim itu sendiri. Kamu diminta bikin pipeline
parsing-nya dari NOL — situasi realistis: di dunia nyata, tiap tim
sering punya format log sendiri-sendiri.

### Tugas Bagian 2

1. Jalankan Task Tracker: `cd crud-app && docker compose up -d --build`.
2. Generate traffic contoh (bikin, update, hapus beberapa task) — lihat
   `crud-app/README.md` untuk daftar endpoint-nya.
3. Lihat langsung format log-nya: `docker compose logs task-tracker`.
   Perhatikan strukturnya SEBELUM coba bikin grok pattern — jangan
   asumsikan formatnya sama dengan yang sudah kamu temui di lab.
4. Buat file pipeline BARU di
   `lab/day-4-administration-ingestion/sesi-8-data-ingestion/logstash/pipeline/task-tracker.conf`
   (Logstash sesi 8 otomatis me-load semua file `.conf` di folder itu) —
   filter berdasarkan isi pesan (lihat pola di `payment-service.conf`
   untuk contoh `if [message] =~ "..."`, atau `web-service.conf` untuk
   contoh output ke index baru), grok pattern kamu susun sendiri dari
   struktur yang kamu amati di langkah 3.
5. Reload Logstash — **balik dulu ke folder Sesi 8** (`docker compose
   restart` butuh dijalankan dari folder yang punya `docker-compose.yml`
   dengan service itu, bukan dari `crud-app/` tempat kamu terakhir `cd`
   di langkah 1):
   ```bash
   cd lab/day-4-administration-ingestion/sesi-8-data-ingestion
   docker compose restart logstash-sesi8
   ```
   Lalu generate traffic baru lagi (langkah 2, dari `crud-app/`), lalu verifikasi field ter-extract benar
   (bukan `null`, dan field angka seperti `status`/`duration_ms` benar-benar
   bertipe angka, bukan string — cek lewat `_mapping`).

### Kriteria Bagian 2

- Index baru (nama bebas, sarankan `task-tracker-parsed-*`) berisi
  dokumen dari log Task Tracker dengan field method/path/status ter-extract.
- Field `status` dan `duration_ms` bertipe numerik di mapping (bukan `text`/`keyword`).
- Kamu bisa jelaskan MENGAPA kamu memilih named-pattern tertentu (mis.
  `%{NUMBER:status:int}` vs `%{WORD:...}`) untuk tiap bagian pesan.

<details>
<summary>Petunjuk Bagian 2 (klik kalau BENAR-BENAR stuck — coba susun sendiri dulu)</summary>

Format pesannya:
```
ts=2026-08-26T18:53:16.807Z|method=GET|path=/tasks/999|status=404|duration_ms=1|id=999
```
Field terakhir (`id=...`) sampai akhir baris — pakai `%{NOTSPACE:...}`
(berhenti di whitespace/akhir baris), BUKAN `%{GREEDYDATA:...}` (akan
ikut menangkap karakter newline di akhir pesan, bikin field-nya kotor).

```
filter {
  if [message] =~ "^ts=" {
    grok {
      match => { "message" => "ts=%{TIMESTAMP_ISO8601:timestamp}\|method=%{WORD:http_method}\|path=%{DATA:path}\|status=%{NUMBER:status:int}\|duration_ms=%{NUMBER:duration_ms:int}\|id=%{NOTSPACE:task_id}" }
      tag_on_failure => ["_grok_tasktracker_failed"]
    }
    if "_grok_tasktracker_failed" not in [tags] {
      mutate { add_field => { "log_type" => "task_tracker_access" } }
    }
  }
}

output {
  if [log_type] == "task_tracker_access" {
    elasticsearch {
      hosts => ["http://elasticsearch:9200"]
      index => "task-tracker-parsed-%{+YYYY.MM.dd}"
    }
  }
}
```
</details>

Validasi hasil kerjamu (Bagian 1):
```bash
bash exercise/scripts/validate_sesi8.sh
```
