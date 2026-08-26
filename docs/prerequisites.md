# Prerequisites

Sebelum memulai sesi mana pun, pastikan environment berikut sudah siap.
Ikuti urutan di bawah ini — terutama langkah identifikasi arsitektur CPU,
karena itu menentukan image mana yang akan ditarik di sesi-sesi berikutnya.

## 1. Identifikasi Arsitektur CPU (WAJIB, lakukan ini duluan)

Jalankan salah satu command berikut:

```bash
docker info --format '{{.Architecture}}'
# atau
uname -m
```

- Hasil `aarch64` / `arm64` → laptop kamu **ARM** (mis. Apple Silicon M1/M2/M3/M4).
- Hasil `x86_64` / `amd64` → laptop kamu **x86/amd64** (mayoritas laptop Windows/Intel/AMD).

Catat hasilnya. Image yang dipakai lab ini (Elasticsearch/Kibana/Logstash
resmi, dan image Robot Shop) sudah disiapkan untuk **kedua** arsitektur —
`docker pull`/`docker compose up` akan otomatis menarik varian yang sesuai
dengan arsitektur laptopmu tanpa perlu setting tambahan. Kalau ada
pengecualian untuk service tertentu, itu akan disebutkan eksplisit di
README sesi terkait (jangan asumsikan semua service otomatis kompatibel
tanpa dicek).

## 2. Wajib

- **Docker Desktop** — terinstal dan berjalan (`docker ps` harus berhasil tanpa error).
- **Docker Compose v2** — sudah termasuk di Docker Desktop modern (`docker compose version`,
  bukan `docker-compose` versi lama).
- **RAM minimal 8GB** dialokasikan ke Docker Desktop (Settings → Resources → Memory)
  untuk sesi single-node (Hari 1–3). **Sesi 7 (Hari 4, cluster multi-node)
  butuh RAM lebih besar** — angka pastinya akan disebutkan di README Sesi 7
  setelah diverifikasi lewat pengujian nyata, jangan asumsikan 8GB cukup untuk sesi itu.
- **Koneksi internet** untuk pull image Docker.
- **Git** — untuk clone repo.

## 3. Terminal — WAJIB Diperhatikan Kalau Pakai Windows

Seluruh command di lab ini ditulis dalam sintaks **bash**. Kalau laptopmu
**Windows**:

- **WAJIB** jalankan semua command DI DALAM **WSL2** (Windows Subsystem for
  Linux) — BUKAN di Command Prompt atau PowerShell native. Docker Desktop
  for Windows sendiri sudah butuh WSL2 sebagai backend, tapi itu tidak
  otomatis berarti terminalmu bash — kamu harus **membuka terminal WSL2
  secara eksplisit** (mis. lewat aplikasi "Ubuntu" atau `wsl` di Windows
  Terminal) sebelum menjalankan command apa pun di lab ini.
- **Alternatif**: **Git Bash** (ikut terinstal bareng Git for Windows) —
  cukup untuk command yang tidak butuh akses langsung ke Docker socket
  native Linux, tapi WSL2 lebih direkomendasikan untuk konsistensi penuh.
- Kalau kamu jalankan command bash di PowerShell/cmd biasa, sebagian besar
  akan **gagal** (`bash: command not found`, error sintaks `$(...)`, dst.)
  — ini bukan bug lab, tapi memang command-nya tidak ditulis untuk shell itu.

macOS dan Linux tidak perlu langkah tambahan — terminal bawaan sudah bash-compatible.

## 4. Opsional

- **Python 3** — hanya kalau ada script exercise tertentu yang membutuhkannya
  (akan disebutkan eksplisit di README exercise terkait kalau relevan).

## 5. Cek Cepat

```bash
docker info --format '{{.Architecture}}'   # catat hasilnya, lihat langkah 1
docker --version
docker compose version
docker ps                 # harus berhasil, bukan "Cannot connect to the Docker daemon"
git --version
```

Kalau `docker ps` gagal, buka Docker Desktop terlebih dahulu dan tunggu sampai
status "Running" di menu bar sebelum lanjut.
