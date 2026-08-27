# Prasyarat

Sebelum memulai sesi mana pun, pastikan environment berikut telah siap.
Ikuti urutan berikut — khususnya langkah identifikasi arsitektur CPU,
karena hal ini menentukan varian image yang akan diunduh pada sesi-sesi
berikutnya.

Mayoritas peserta menggunakan laptop **Windows**, sehingga panduan pada
dokumen ini disusun dengan Windows sebagai jalur utama. Panduan untuk
**macOS (termasuk Apple Silicon/arm64)** dan **Linux** juga disediakan
sebagai opsi alternatif pada tiap langkah.

## 1. Identifikasi Arsitektur CPU (Wajib, Lakukan Terlebih Dahulu)

Jalankan salah satu perintah berikut pada terminal:

```bash
docker info --format '{{.Architecture}}'
# atau
uname -m
```

- Hasil `aarch64` / `arm64` → perangkat Anda **ARM** (misalnya Apple
  Silicon M1/M2/M3/M4, atau laptop Windows berbasis ARM).
- Hasil `x86_64` / `amd64` → perangkat Anda **x86/amd64** (mayoritas
  laptop Windows/Intel/AMD).

Catat hasilnya. Seluruh image yang digunakan pada lab ini telah disiapkan
untuk **kedua** arsitektur — `docker pull`/`docker compose up` akan
otomatis mengunduh varian yang sesuai dengan arsitektur perangkat Anda
tanpa perlu pengaturan tambahan. Apabila terdapat pengecualian untuk
service tertentu, hal tersebut akan disebutkan secara eksplisit pada
README sesi terkait.

## 2. Instalasi Perangkat Lunak yang Diperlukan

### 2.1 Docker Desktop (Wajib — semua peserta)

Docker Desktop menyediakan Docker Engine beserta Docker Compose v2, yang
dipakai di seluruh sesi lab ini.

| Platform | Unduh | Catatan |
|---|---|---|
| **Windows** | [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/) | Wajib mengaktifkan backend **WSL2** saat instalasi (lihat bagian 2.2) |
| **macOS (Apple Silicon / Intel)** | [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/) | Pilih installer sesuai chip (Apple Silicon atau Intel) |
| **Linux** | Docker Engine native, bukan Docker Desktop — ikuti [docs.docker.com/engine/install](https://docs.docker.com/engine/install/) sesuai distro (Ubuntu/Debian/Fedora/dst.), lalu install [Docker Compose plugin](https://docs.docker.com/compose/install/linux/) terpisah | Tidak ada batas memori virtual seperti Docker Desktop — Docker langsung memakai resource host |

Verifikasi instalasi setelah selesai:
```bash
docker --version
docker compose version
```

### 2.2 WSL2 (Wajib — khusus Windows)

Docker Desktop for Windows membutuhkan WSL2 (Windows Subsystem for
Linux) sebagai backend. Jalankan pada **PowerShell sebagai
Administrator**:
```powershell
wsl --install
```
Perintah ini menginstal WSL2 beserta distribusi Ubuntu secara default.
Restart perangkat apabila diminta. Dokumentasi resmi (apabila
menemukan kendala): [learn.microsoft.com/windows/wsl/install](https://learn.microsoft.com/en-us/windows/wsl/install).

Setelah instalasi selesai, **seluruh perintah pada lab ini dijalankan DI
DALAM terminal WSL2** (buka lewat aplikasi "Ubuntu" pada Start Menu, atau
ketik `wsl` pada Windows Terminal) — **bukan** pada Command Prompt atau
PowerShell biasa, karena seluruh perintah pada lab ini ditulis dalam
sintaks bash dan membutuhkan akses langsung ke Docker socket gaya Linux.
Docker Desktop for Windows sendiri sudah membutuhkan WSL2 sebagai
backend, tetapi hal tersebut tidak otomatis berarti terminal Anda bash
— WSL2 tetap harus dibuka secara eksplisit sebagaimana dijelaskan di atas.

**Alternatif**: **Git Bash** (ikut terpasang bersama Git for Windows,
lihat bagian 2.3) cukup untuk perintah yang tidak membutuhkan akses
langsung ke Docker socket gaya Linux, namun WSL2 tetap lebih disarankan
untuk konsistensi penuh di seluruh sesi lab ini. Apabila perintah bash
dijalankan pada PowerShell/Command Prompt biasa (bukan WSL2/Git Bash),
sebagian besar akan **gagal** (`bash: command not found`, error sintaks
`$(...)`, dan sejenisnya) — ini bukan galat pada modul, melainkan karena
perintah tersebut memang tidak ditulis untuk shell tersebut.

macOS dan Linux tidak memerlukan langkah tambahan — terminal bawaan
sudah kompatibel dengan bash.

### 2.3 Git (Wajib — semua peserta)

Dipakai untuk clone repository lab ini.

| Platform | Unduh |
|---|---|
| **Windows** | [git-scm.com/download/win](https://git-scm.com/download/win) — install di dalam WSL2 lebih disarankan: jalankan `sudo apt-get update && sudo apt-get install -y git` di terminal WSL2 |
| **macOS** | Sudah terpasang bawaan (Command Line Tools) — apabila belum, jalankan `git --version` dan ikuti prompt instalasi, atau unduh dari [git-scm.com/download/mac](https://git-scm.com/download/mac) |
| **Linux** | `sudo apt-get install -y git` (Debian/Ubuntu) atau setara sesuai distro |

Verifikasi:
```bash
git --version
```

### 2.4 Python 3 (Wajib mulai Hari 2 — Sesi 4)

Sesi 4 menjalankan script Python untuk memindahkan data Robot Shop ke
Elasticsearch — **bukan opsional**, dibutuhkan pada langkah praktik inti
sesi tersebut (bukan hanya exercise).

| Platform | Unduh |
|---|---|
| **Windows (WSL2)** | `sudo apt-get update && sudo apt-get install -y python3` |
| **macOS** | Sudah terpasang bawaan pada versi macOS terkini. Apabila perlu versi lebih baru: [python.org/downloads/macos](https://www.python.org/downloads/macos/) |
| **Linux** | `sudo apt-get install -y python3` (Debian/Ubuntu) atau setara sesuai distro |

Verifikasi (minimal Python 3.8):
```bash
python3 --version
```

## 3. Spesifikasi RAM

- **RAM minimal 8GB** dialokasikan untuk Docker (Hari 1–3, sesi
  single-node). Pada Windows/macOS, atur lewat Docker Desktop →
  **Settings → Resources → Memory** (geser slider, klik **Apply &
  Restart**). Pada Linux, Docker Engine memakai RAM host secara langsung
  — pastikan tersedia minimal 8GB RAM bebas pada host.
- **Sesi 7 (Hari 4, cluster 3-node) membutuhkan minimal 12GB** — hasil
  pengujian menunjukkan tiap node Elasticsearch memakai ±1,4GB RAM
  (±4,2GB total hanya untuk Elasticsearch, di luar overhead Docker
  Desktop dan aplikasi lain yang mungkin masih berjalan dari sesi
  sebelumnya). Naikkan alokasi memori SEBELUM memulai Sesi 7 lewat
  langkah Docker Desktop di atas.

## 4. Koneksi Internet

Diperlukan untuk mengunduh image Docker pada setiap sesi. Ukuran
unduhan bervariasi per sesi (image Elasticsearch/Kibana/Logstash resmi
berukuran ±1-2GB masing-masing) — disarankan mengunduh lebih awal pada
koneksi yang stabil apabila memungkinkan.

## 5. Pemeriksaan Cepat

Jalankan seluruh perintah berikut untuk memastikan environment sudah
siap sebelum memulai Sesi 1:

```bash
docker info --format '{{.Architecture}}'   # catat hasilnya, lihat bagian 1
docker --version
docker compose version
docker ps                 # harus berhasil, bukan "Cannot connect to the Docker daemon"
git --version
python3 --version          # dibutuhkan mulai Sesi 4
```

Apabila `docker ps` gagal, buka aplikasi Docker Desktop terlebih dahulu
dan tunggu hingga status menunjukkan "Running" pada menu bar sebelum
melanjutkan.
