# Sesi 4 — Relevance Scoring & Search Ranking

## a. Tujuan Sesi

Setelah sesi ini, kamu memahami bagaimana Elasticsearch menentukan urutan
hasil pencarian (`_score`), dan mampu menyesuaikan urutan itu supaya
mencerminkan prioritas bisnis nyata (mis. produk rating tinggi tampil
duluan) memakai `function_score` dan `boost`.

## b. Output yang Diharapkan

Sesi ini selesai kalau:
- Robot Shop jalan — 7 servis yang punya healthcheck (`catalogue`, `user`,
  `cart`, `shipping`, `ratings`, `payment`, `web`) berstatus `healthy` di
  `docker compose ps` (5 servis pendukung — `mongodb`, `redis`, `rabbitmq`,
  `mysql`, `dispatch` — tidak punya healthcheck sendiri, cukup pastikan
  statusnya `Up`) — dan index `robot-shop-catalogue` di Elasticsearch
  sudah berisi data produk asli.
- Kamu berhasil menjalankan query pencarian yang hasilnya BERUBAH urutan
  setelah ditambah `function_score`/`boost`, dan bisa jelaskan kenapa.

## c. Teori & Struktur Sistem

Baca [`robot-shop-structure.md`](robot-shop-structure.md) dulu untuk
memahami sistem yang akan kamu observasi sesi ini.

**Relevance & `_score`.** Tiap hasil pencarian Elasticsearch punya `_score`
— angka yang menentukan urutan tampil (semakin tinggi, semakin relevan
menurut Elasticsearch). Secara default, `_score` dihitung dari algoritma
BM25 (seberapa sering & langka kata yang dicari muncul di dokumen). Ini
bagus untuk relevansi TEKS, tapi sering kali kamu ingin urutan juga
mempertimbangkan sinyal BISNIS lain — rating produk, popularitas, stok,
dst. Dua cara utama:

- **`function_score`** — modifikasi `_score` pakai fungsi matematis
  berdasarkan NILAI FIELD lain (mis. `field_value_factor` mengalikan/
  menambah score berdasarkan `avg_rating`).
- **`boost`** — angka pengali pada bagian query tertentu (mis. dalam
  `bool.should`), membuat dokumen yang match bagian itu naik skornya
  lebih tinggi dibanding yang cuma match bagian lain.

## d. Praktik: Instalasi & Konfigurasi

*(Prasyarat: stack Sesi 1 masih jalan untuk Elasticsearch/Kibana.)*

> **Ke mana tiap command di bawah dijalankan?** Sesi ini gabung dua
> tempat — **Terminal** (semua yang diawali `$`/blok berlabel `bash`:
> `docker compose`, `curl`, `python3`) untuk operasi di luar Elasticsearch
> (jalankan Robot Shop, panggil API Robot Shop, transfer data), dan
> **Kibana Dev Tools Console** (blok `GET`/`POST` TANPA `curl` di
> depannya, format sama seperti Sesi 2-3) khusus untuk query ke
> Elasticsearch. Tiap blok di bawah diberi label eksplisit supaya jelas.

**[Terminal] Jalankan Robot Shop** (lihat [`robot-shop-structure.md`](robot-shop-structure.md) untuk detail arsitektur):
```bash
cd lab/day-2-query-relevance/sesi-4-relevance-scoring
docker compose up -d
```
**Kalau laptopmu ARM (Apple Silicon)** — cek dulu lewat
`docker info --format '{{.Architecture}}'` (lihat `prerequisites.md`).
Kalau hasilnya `arm64`, pakai command ini SEBAGAI GANTI yang di atas
(bukan tambahan) — tanpa ini, `mysql` akan jalan lewat emulasi dengan
warning platform-mismatch (tetap jalan, tapi lebih lambat & membingungkan
kalau tidak diberi tahu dulu):
```bash
docker compose -f docker-compose.yml -f docker-compose.arm64-override.yml up -d
```
Tunggu servis yang punya healthcheck jadi `healthy` (`docker compose ps`)
— `catalogue`/`user`/`cart`/`payment`/`web` biasanya cepat, sementara
`shipping`/`ratings` butuh waktu lebih lama saat MySQL inisialisasi
pertama kali. (`mongodb`/`redis`/`rabbitmq`/`mysql`/`dispatch` tidak
punya healthcheck sendiri dan akan selalu tampil tanpa status `healthy`
di `docker compose ps` — itu normal, cukup pastikan statusnya `Up`.)

> **[Terminal] WAJIB dilakukan dulu — isi rating awal.** Robot Shop yang BARU pertama
> kali dijalankan punya `avg_rating: 0` untuk SEMUA produk (belum pernah
> ada yang kasih rating) — kalau langsung lanjut ke contoh `function_score`
> di bawah tanpa langkah ini, query-nya akan jalan tanpa error, TAPI
> urutan hasilnya TIDAK BERUBAH sama sekali (boost dari rating 0 selalu 0),
> bertentangan dengan Expected Output yang didokumentasikan. Kirim
> beberapa rating dulu:
> ```bash
> curl -s -X PUT "http://localhost:8080/api/ratings/api/rate/Watson/5" -o /dev/null
> curl -s -X PUT "http://localhost:8080/api/ratings/api/rate/Watson/4" -o /dev/null
> curl -s -X PUT "http://localhost:8080/api/ratings/api/rate/HPTD/5" -o /dev/null
> curl -s -X PUT "http://localhost:8080/api/ratings/api/rate/HPTD/5" -o /dev/null
> curl -s -X PUT "http://localhost:8080/api/ratings/api/rate/HPTD/3" -o /dev/null
> curl -s -X PUT "http://localhost:8080/api/ratings/api/rate/UHJ/2" -o /dev/null
> curl -s -X PUT "http://localhost:8080/api/ratings/api/rate/RMC/5" -o /dev/null
> curl -s -X PUT "http://localhost:8080/api/ratings/api/rate/RMC/5" -o /dev/null
> curl -s -X PUT "http://localhost:8080/api/ratings/api/rate/STAN-1/5" -o /dev/null
> ```
> (SKU: `Watson`, `HPTD`=High-Powered Travel Droid, `UHJ`=Ultimate
> Harvesting Juggernaut, `RMC`=Robotic Mining Cyborg, `STAN-1`=Stan — lihat
> daftar lengkap lewat `GET /api/catalogue/products`.)

**[Terminal] Ambil data produk asli dari Robot Shop, gabung dengan data rating, index ke Elasticsearch:**
```bash
python3 << 'PYEOF'
import json, urllib.request

products = json.loads(urllib.request.urlopen("http://localhost:8080/api/catalogue/products").read())

bulk_lines = []
for p in products:
    rating = json.loads(urllib.request.urlopen(f"http://localhost:8080/api/ratings/api/fetch/{p['sku']}").read())
    doc = {
        "sku": p["sku"], "name": p["name"], "description": p["description"],
        "price": p["price"], "instock": p["instock"], "categories": p["categories"],
        "avg_rating": rating["avg_rating"], "rating_count": rating["rating_count"],
    }
    bulk_lines.append(json.dumps({"index": {"_index": "robot-shop-catalogue", "_id": p["sku"]}}))
    bulk_lines.append(json.dumps(doc))

with open("/tmp/catalogue_bulk.ndjson", "w") as f:
    f.write("\n".join(bulk_lines) + "\n")
print(f"Wrote {len(products)} products")
PYEOF

curl -s -X POST "http://localhost:9200/robot-shop-catalogue/_bulk?refresh=true" \
  -H 'Content-Type: application/x-ndjson' --data-binary @/tmp/catalogue_bulk.ndjson
```
Expected Output: `"errors":false`, 11 item — 11 produk asli
Robot Shop (nama, deskripsi, harga, stok, kategori, rating) sekarang ada di
index `robot-shop-catalogue`.

> **Kenapa harus ambil data ini secara manual?** Robot Shop sendiri
> menyimpan produknya di MongoDB (dipakai oleh service `catalogue`), bukan
> di Elasticsearch. Langkah di atas menyalin data itu ke Elasticsearch
> supaya bisa kamu pakai untuk latihan Query DSL/relevance — pola ini
> mirip proses **ETL (Extract-Transform-Load)** sederhana yang umum di
> dunia nyata sebelum data bisa dicari lewat Elasticsearch.

**[Dev Tools Console] Coba search dulu tanpa scoring khusus** — buka
`http://localhost:5601/app/dev_tools#/console`, cari produk kategori "Robot":
```
GET robot-shop-catalogue/_search
{ "query": { "match": { "categories": "Robot" } } }
```
Expected Output: **9 hits**, tapi perhatikan `_score`-nya —
hampir semua dokumen dapat skor **SAMA** (`0.262`), karena `match` cuma
menilai relevansi teks "Robot" di field `categories`, tidak tahu mana
produk yang sebenarnya lebih baik/populer.

## e. Contoh Implementasi

**[Dev Tools Console] Boost berdasarkan rating** (`function_score` + `field_value_factor`):
```
GET robot-shop-catalogue/_search
{
  "query": {
    "function_score": {
      "query": { "match": { "categories": "Robot" } },
      "field_value_factor": {
        "field": "avg_rating",
        "modifier": "ln1p",
        "missing": 0
      },
      "boost_mode": "sum"
    }
  }
}
```
Expected Output — urutan sekarang berubah total, produk rating
tinggi naik ke atas:
```
2.054  Robotic Mining Cyborg     (rating 5)
1.948  Stan                      (rating 5)
1.872  High-Powered Travel Droid (rating 4.33)
1.361  Ultimate Harvesting Juggernaut (rating 2)
0.262  ... (sisanya, rating 0 — skor tidak berubah dari baseline)
```
(Angka desimal ke-2/3 di belakang koma bisa sedikit beda tiap kali index
dibangun ulang — bagian `match` dari skor ikut bergantung pada statistik
korpus (jumlah dokumen, panjang field rata-rata), bukan cuma
`avg_rating`. Urutan dan pola naik/turunnya tetap konsisten.)

`modifier: "ln1p"` (log(1+x)) dipakai supaya rating 5 tidak "meledak"
dibanding rating 4 — pola umum untuk field yang skalanya kecil (1-5).
`missing: 0` menangani produk yang belum punya rating sama sekali.

**[Dev Tools Console] Boosting kategori tertentu** (`bool.should` dengan `boost`):
```
GET robot-shop-catalogue/_search
{
  "query": {
    "bool": {
      "must": { "match_all": {} },
      "should": [
        { "match": { "categories": { "query": "Artificial Intelligence", "boost": 3 } } }
      ]
    }
  }
}
```
Expected Output — SEMUA produk tetap muncul (`must: match_all`),
tapi yang kategorinya "Artificial Intelligence" melonjak ke atas:
```
7.208  Watson   (kategori: Artificial Intelligence)
7.208  Ewooid   (kategori: Artificial Intelligence)
5.959  Stan     (kategori: Robot + Artificial Intelligence, dapat boost parsial)
1.000  ... (sisanya, cuma kategori Robot, skor dasar match_all)
```
Ini pola umum e-commerce nyata: "tampilkan semua produk, tapi utamakan
kategori promosi/prioritas di atas."

**[Kibana UI] Query yang sama, lewat Discover** (tanpa nulis Query DSL
sama sekali):

**1. Buat Data View** untuk `robot-shop-catalogue` (index custom, sama
seperti langkah di Sesi 2 untuk `lab-mapping-demo`): buka menu ☰ →
Discover, klik data view aktif → **Create a data view** → Name & Index
pattern isi `robot-shop-catalogue` → **Save data view to Kibana**.

![Discover menampilkan 11 dokumen robot-shop-catalogue setelah data view dibuat](../../../docs/screenshots/sesi-4/01-discover-data-view-dibuat.png)

*Data view `robot-shop-catalogue` aktif — 11 produk Robot Shop yang
di-index di bagian (d) muncul di tabel.*

**2. Tambah kolom `name`, `avg_rating`, `price`** (hover field di
sidebar kiri → klik ikon **+**, lihat Sesi 3 kalau lupa caranya), lalu
ketik filter KQL yang setara dengan query `bool.should` di atas:
`categories: "Artificial Intelligence"`

![Discover dengan filter kategori Artificial Intelligence, kolom name avg_rating price](../../../docs/screenshots/sesi-4/02-discover-search-ai-category.png)

*3 produk kategori "Artificial Intelligence" — Watson, Ewooid, Stan —
persis sama dengan yang lolos filter di query Dev Tools Console di atas.
Bedanya: di sini kamu TIDAK dapat kontrol `_score`/`boost` numerik seperti
Query DSL (KQL cuma filter ya/tidak) — untuk kebutuhan RANKING numerik
seperti boost rating, tetap perlu Query DSL lewat Dev Tools Console atau
lewat API dari aplikasi. Discover paling pas untuk eksplorasi cepat,
bukan pengganti Query DSL untuk relevance tuning.*

## f. Referensi Exercise

Lanjutkan latihan mandiri di [`exercise/sesi-4/README.md`](../../../exercise/sesi-4/README.md).
