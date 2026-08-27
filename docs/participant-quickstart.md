# Panduan Peserta — Mulai di Sini

## 1. Cek Prerequisites

Sebelum mulai, baca [`prerequisites.md`](prerequisites.md) — terutama
langkah **identifikasi arsitektur CPU** (langkah pertama di sana) dan
**catatan Windows** apabila perangkat Anda Windows (wajib menggunakan
terminal WSL2, bukan Command Prompt/PowerShell biasa).

## 2. Clone Repo

Instruktur akan membagikan link repo. Clone langsung:

```bash
git clone <link-dari-instruktur>
cd <nama-repo>
```

## 3. Ikuti Materi per Sesi

Materi ada di folder `lab/`, dikelompokkan per hari lalu per sesi:

```
lab/day-1-fundamentals/sesi-1-intro-elk/
lab/day-1-fundamentals/sesi-2-document-management/
lab/day-2-query-relevance/sesi-3-query-dsl/
lab/day-2-query-relevance/sesi-4-relevance-scoring/
lab/day-3-analytics-optimization/sesi-5-aggregations/
lab/day-3-analytics-optimization/sesi-6-performance-optimization/
lab/day-4-administration-ingestion/sesi-7-data-ingestion/
lab/day-4-administration-ingestion/sesi-8-administration-scaling/
```

Tiap `README.md` sesi memiliki struktur yang sama:

| Bagian | Isinya |
|---|---|
| a. Tujuan Sesi | apa yang akan Anda mampu lakukan setelah sesi ini |
| b. Output yang Diharapkan | kriteria "sesi ini sudah selesai apabila..." |
| c. Teori & Struktur Sistem | konsep yang perlu Anda pahami SEBELUM praktik |
| d. Praktik | instalasi/konfigurasi step-by-step + Expected Output nyata |
| e. Contoh Implementasi | satu contoh lengkap end-to-end |
| f. Referensi Exercise | pointer ke latihan mandiri di folder `exercise/` |

Ikuti urutan (a) sampai (f) — jangan langsung ke praktik sebelum membaca
teorinya.

> **INFORMATION:** urutan ini penting supaya perintah yang Anda jalankan
> pada bagian praktik benar-benar Anda pahami maksudnya, bukan sekadar
> disalin.

## 4. Kerjakan Exercise Setelah Tiap Sesi

Setelah selesai satu sesi di `lab/`, lanjutkan ke
`exercise/sesi-N/README.md` — latihan mandiri dengan use case yang
berbeda dari yang dipakai di lab, dengan kriteria selesai yang jelas.

> **INFORMATION:** use case exercise sengaja dibuat berbeda dari lab
> supaya Anda tidak sekadar copy-paste jawaban lab ke exercise.

Jalankan validasi di akhir tiap exercise:
```bash
bash exercise/scripts/validate_sesiN.sh
```
Perintah ini mencetak hasil PASS/FAIL langsung ke terminal.

> **INFORMATION:** cara melaporkan progres Anda ke instruktur
> (screenshot, chat, dsb.) akan dijelaskan instruktur saat sesi
> berlangsung.

## 5. Kalau Ada Kendala

Tanyakan langsung ke instruktur/rekan di kelas.

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
kerjakan exercise/sesi-N/ setelah tiap sesi, validasi hasil Anda
```
