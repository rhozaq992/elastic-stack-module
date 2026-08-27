# Robot Shop — Struktur Sistem

Mulai sesi ini, Anda akan menggunakan **Robot Shop**, aplikasi e-commerce
berbasis microservice, sebagai studi kasus data nyata untuk sesi-sesi
berikutnya (Sesi 4, 6, dan 8). Anda tidak perlu mengetahui bagaimana
sistem ini dibangun — cukup pahami strukturnya, supaya mengetahui sistem
apa yang sedang Anda observasi lewat Elasticsearch/Kibana.

## Topologi

![Diagram topologi Robot Shop: web sebagai entry point ke enam servis, masing-masing dengan backing store-nya, dan dispatch sebagai consumer asinkron dari RabbitMQ](../../../docs/diagrams/sesi4-robot-shop-topology.svg)

*Semua servis pada baris tengah (`catalogue`, `user`, `cart`, `shipping`,
`ratings`, `payment`) diakses lewat `web` — satu pintu masuk untuk semua
request. `dispatch` berbeda: ia bukan API yang diakses lewat `web`,
melainkan consumer asinkron yang mengambil pesan dari `rabbitmq` setelah
`payment` selesai memproses transaksi (lihat legenda pada diagram untuk
perbedaan panggilan sinkron vs asinkron).*

## Daftar Service

| Service | Fungsi | Bahasa | Backing Store |
|---|---|---|---|
| `web` | Reverse proxy / entry point (port 8080) | Nginx | — |
| `catalogue` | Data produk (nama, harga, stok, kategori) | Node.js | MongoDB |
| `user` | Akun & sesi pengguna | Node.js | MongoDB + Redis |
| `cart` | Keranjang belanja | Node.js | Redis |
| `shipping` | Kalkulasi & konfirmasi pengiriman | Java | MySQL |
| `ratings` | Rating & ulasan produk | PHP | MySQL |
| `payment` | Proses pembayaran | Python | RabbitMQ |
| `dispatch` | Pemrosesan order setelah bayar | Go | RabbitMQ (consumer) |

Service pendukung (`mongodb`, `redis`, `mysql`, `rabbitmq`) adalah database/
message-queue standar, bukan bagian dari aplikasi Robot Shop sendiri.

## API yang Dipakai di Lab Ini

Semua lewat `http://localhost:8080` (service `web`):

- `GET /api/catalogue/products` — daftar semua produk.
- `GET /api/catalogue/product/<sku>` — detail satu produk.
- `GET /api/ratings/api/fetch/<sku>` — rating rata-rata & jumlah rating produk.
- `PUT /api/ratings/api/rate/<sku>/<1-5>` — kirim rating baru.

## Menjalankan

```bash
cd lab/day-2-query-relevance/sesi-4-relevance-scoring
docker compose up -d
```

**Apabila perangkat Anda ARM (Apple Silicon)** — tambahkan file override
(lihat [`docker-compose.arm64-override.yml`](docker-compose.arm64-override.yml)
untuk penjelasannya):
```bash
docker compose -f docker-compose.yml -f docker-compose.arm64-override.yml up -d
```

Semua image sudah pre-built (multi-arch untuk 10 dari 11 service) — Anda
cukup pull & jalankan, tidak ada proses build/compile.

> **Catatan startup:** `shipping` dan `ratings` connect ke MySQL saat
> startup. MySQL butuh waktu (~1-2 menit di volume baru) untuk selesai
> import data awal — kedua service itu bisa terlihat `unhealthy` sesaat,
> tapi **akan pulih sendiri otomatis** tanpa perlu restart manual begitu
> MySQL selesai. Tunggu saja.
