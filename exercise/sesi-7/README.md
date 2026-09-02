# Exercise Sesi 7 — Bedakan Anomali Fraud vs Masalah Kapasitas + Parser Manual

**Topik yang dilatih (dari Silabus Sesi 7):** analisis lanjutan atas
hasil Data Ingestion (Bagian 1), dan Parsing, Transforming, Filtering
Data — menulis grok pattern sendiri (Bagian 2).

Dua bagian: **Bagian 1** analisis anomali payment Robot Shop (agregasi,
tanpa perlu menulis pipeline baru), **Bagian 2** menulis SENDIRI grok
pattern untuk format log custom yang belum pernah Anda temui di lab.

## Bagian 1 — Use Case

Traffic payment Robot Shop dapat menunjukkan dua jenis status "tidak
normal": `http_status: 500` (SELALU ada, disuntikkan secara sengaja lewat
load generator) dan `http_status: 429` (MUNGKIN ada, tergantung seberapa
kuat laptop Anda menangani beban — lihat catatan Sesi 6/8). Tim finance
dan tim infrastruktur SAMA-SAMA khawatir terhadap status "tidak normal"
tersebut, tetapi membutuhkan penjelasan yang berbeda: yang satu
membutuhkan investigasi fraud, yang lain hanya membutuhkan penambahan
kapasitas server. Tugas Anda: gunakan data pada `payment-service-parsed-*`
untuk membuktikan mana yang mana — jangan hanya menebak dari nama status
code-nya.

> **INFORMATION:** apabila traffic Anda tidak memiliki `429` sama sekali
> (periksa dulu breakdown pada tugas 1) — hal itu normal, bukan kegagalan.

Kerjakan tugas 2, 4, 5 dengan membandingkan `500` vs `200` saja, dan tugas 3 boleh
dilewati (catat pada kesimpulan Anda alasannya: "429 tidak muncul karena
host saya cukup kuat").

## Tugas Bagian 1

1. Hitung breakdown total transaksi per `http_status` (200, 429, 500).
2. Untuk `http_status: 500`: agregasi per `payment_user.keyword` — apakah
   tersebar merata, atau terkonsentrasi pada satu/sedikit user id?
3. Untuk `http_status: 429`: agregasi per `payment_user.keyword` juga —
   bandingkan pola sebarannya dengan poin 2. Sama atau berbeda?
4. Bandingkan rata-rata `response_time_ms` antara `http_status: 200`
   (normal) vs `500` vs `429` — pola mana yang response-nya jauh lebih
   cepat dari normal (indikasi gagal lebih dulu sebelum diproses penuh)?
5. Tulis kesimpulan: mana yang lebih tepat disebut "anomali/fraud"
   (membutuhkan investigasi keamanan) dan mana yang lebih tepat disebut
   "masalah kapasitas" (membutuhkan scaling/optimasi performa) — dengan
   alasan dari angka di atas, bukan hanya dari nama status code-nya.

## Kriteria Bagian 1

- Anda memiliki angka pasti untuk breakdown per status dan breakdown per
  `payment_user` untuk status **500** (wajib, selalu ada).
- **Apabila `429` ada pada traffic Anda**: Anda juga memiliki breakdown
  per user untuk 429, dan kesimpulan Anda menjelaskan MINIMAL 1 perbedaan
  pola konkret antara 500 dan 429 (misalnya "500 terkonsentrasi pada 1
  user id, 429 tersebar ke puluhan user id berbeda").
- **Apabila `429` TIDAK ada**: kesimpulan Anda tetap menjelaskan pola 500
  (konsentrasi pada 1 user id + response time abnormal) sebagai bukti
  anomali/fraud, dan mencatat bahwa host Anda tidak menunjukkan gejala
  kapasitas kali ini.

<details>
<summary>Petunjuk Bagian 1 (klik apabila mengalami kesulitan)</summary>

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

Tim platform baru saja men-deploy layanan internal baru, **Task Tracker**
(`crud-app/` di root repo ini) — log aksesnya BUKAN JSON, BUKAN Combined
Log Format seperti yang sudah Anda tangani di lab, melainkan format
custom pipe-delimited buatan tim itu sendiri. Anda diminta membuat
pipeline parsing-nya dari NOL.

> **INFORMATION:** situasi ini realistis, karena di dunia nyata tiap tim
> sering memiliki format log sendiri-sendiri.

### Tugas Bagian 2

1. Jalankan Task Tracker: `cd crud-app && docker compose up -d --build`.
2. Generate traffic contoh (buat, perbarui, hapus beberapa task) — lihat
   `crud-app/README.md` untuk daftar endpoint-nya.
3. Lihat langsung format log-nya: `docker compose logs task-tracker`.
   Perhatikan strukturnya SEBELUM mencoba membuat grok pattern — jangan
   asumsikan formatnya sama dengan yang sudah Anda temui di lab.
4. Buat file pipeline BARU di
   `lab/day-2-query-relevance/sesi-4-relevance-scoring/logstash/pipeline/task-tracker.conf` —
   filter berdasarkan isi pesan (lihat pola pada `payment-service.conf`
   untuk contoh `if [message] =~ "..."`, atau `web-service.conf` untuk
   contoh output ke index baru), grok pattern Anda susun sendiri dari
   struktur yang Anda amati pada langkah 3. Uji dulu pattern Anda lewat
   Kibana Grok Debugger (lihat lab Sesi 7 bagian (d) topik 2) sebelum
   menyalinnya ke file ini.

   > **INFORMATION:** Logstash (`logstash-rs`, berjalan sejak Sesi 4)
   > otomatis memuat semua file `.conf` pada folder tersebut.
5. Reload Logstash — **kembali dulu ke folder Sesi 4**:
   ```bash
   cd lab/day-2-query-relevance/sesi-4-relevance-scoring
   docker compose restart logstash-rs
   ```
   > **INFORMATION:** `docker compose restart` harus dijalankan dari
   > folder yang memiliki `docker-compose.yml` dengan service tersebut,
   > bukan dari `crud-app/` tempat Anda terakhir melakukan `cd` pada
   > langkah 1.

   Lalu generate traffic baru lagi (langkah 2, dari `crud-app/`), kemudian
   verifikasi field ter-extract dengan benar (bukan `null`, dan field
   angka seperti `status`/`duration_ms` benar-benar bertipe angka, bukan
   string — periksa lewat `_mapping`).

### Kriteria Bagian 2

- Index baru bernama `task-tracker-parsed-*` (nama ini WAJIB dipakai
  persis, bukan sekadar saran — `validate_sesi7.sh` memeriksa index
  dengan nama ini secara spesifik) berisi dokumen dari log Task Tracker
  dengan field method/path/status ter-extract.
- Field `status` dan `duration_ms` bertipe numerik pada mapping (bukan `text`/`keyword`).
- Anda dapat menjelaskan MENGAPA Anda memilih named-pattern tertentu (misalnya
  `%{NUMBER:status:int}` vs `%{WORD:...}`) untuk tiap bagian pesan.

<details>
<summary>Petunjuk Bagian 2 (klik apabila BENAR-BENAR mengalami kesulitan — coba susun sendiri dulu)</summary>

Format pesannya:
```
ts=2026-08-26T18:53:16.807Z|method=GET|path=/tasks/999|status=404|duration_ms=1|id=999
```
Field terakhir (`id=...`) sampai akhir baris — gunakan `%{NOTSPACE:...}`
(berhenti pada whitespace/akhir baris), BUKAN `%{GREEDYDATA:...}` (akan
ikut menangkap karakter newline di akhir pesan, sehingga field-nya kotor).

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

Validasi hasil kerja Anda (Bagian 1):
```bash
bash exercise/scripts/validate_sesi7.sh
```
