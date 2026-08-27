# Panduan Peserta — Mulai di Sini

## 1. Cek Prerequisites

Sebelum mulai, baca [`prerequisites.md`](prerequisites.md) — terutama
langkah **identifikasi arsitektur CPU**  dan
**catatan Windows** kalau laptopmu Windows (wajib pakai terminal WSL2).

## 2. Ikuti Materi per Sesi

Materi ada di folder `lab/`, dikelompokkan per hari lalu per sesi:

```
lab/day-1-fundamentals/sesi-1-intro-elk/
lab/day-1-fundamentals/sesi-2-document-management/
lab/day-2-query-relevance/sesi-3-query-dsl/
lab/day-2-query-relevance/sesi-4-relevance-scoring/
lab/day-3-analytics-optimization/sesi-5-aggregations/
lab/day-3-analytics-optimization/sesi-6-performance-optimization/
lab/day-4-administration-ingestion/sesi-7-administration-scaling/
lab/day-4-administration-ingestion/sesi-8-data-ingestion/
```

Tiap `README.md` sesi punya struktur yang sama:

| Bagian | Isinya |
|---|---|
| a. Tujuan Sesi | apa yang akan kamu bisa lakukan setelah sesi ini |
| b. Output yang Diharapkan | kriteria "sesi ini sudah selesai kalau..." |
| c. Teori & Struktur Sistem | konsep yang perlu kamu pahami SEBELUM praktik |
| d. Praktik | instalasi/konfigurasi step-by-step + Expected Output nyata |
| e. Contoh Implementasi | satu contoh lengkap end-to-end |
| f. Referensi Exercise | pointer ke latihan mandiri di folder `exercise/` |


## 3. Kerjakan Exercise Setelah Tiap Sesi

Setelah selesai satu sesi di `lab/`, lanjut ke `exercise/sesi-N/README.md` —
latihan mandiri dengan use case yang telah disediakan.

Jalankan validasi di akhir tiap exercise:
```bash
bash exercise/scripts/validate_sesiN.sh
```
hasil dari proses ini akan menunjukan PASS/FAIL pada terminal.

## 4. Kalau Ada Kendala

Tanya langsung ke instruktur/rekan di kelas.

## Ringkasan Alur

```
clone repo instruktur
      │
      ▼
cek prerequisites.md (arsitektur CPU + terminal WSL2 kalau Windows)
      │
      ▼
ikuti lab/day-N/sesi-N/README.md (a → f) untuk tiap sesi, sesuai jadwal
      │
      ▼
kerjakan exercise/sesi-N/ setelah tiap sesi, validasi hasilmu
```
