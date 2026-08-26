# Sesi 4 — Relevance Scoring & Search Ranking

## a. Tujuan Sesi

Setelah sesi ini, kamu memahami bagaimana Elasticsearch menentukan urutan
hasil pencarian (`_score`), dan mampu menyesuaikan urutan itu supaya
mencerminkan prioritas bisnis nyata (mis. produk rating tinggi tampil
duluan) memakai `function_score` dan `boost`.

## b. Output yang Diharapkan

Sesi ini selesai kalau:
- Robot Shop jalan (`docker compose ps` semua `healthy`) dan index
  `robot-shop-catalogue` di Elasticsearch sudah berisi data produk asli.
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

**Jalankan Robot Shop** (lihat [`robot-shop-structure.md`](robot-shop-structure.md) untuk detail arsitektur):
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
Tunggu semua service `healthy` (`docker compose ps`) — termasuk `shipping`/
`ratings` yang butuh waktu lebih lama saat MySQL inisialisasi pertama kali.

> **WAJIB dilakukan dulu — isi rating awal.** Robot Shop yang BARU pertama
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

**Ambil data produk asli dari Robot Shop, gabung dengan data rating, index ke Elasticsearch:**
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
Expected Output (aktual): `"errors":false`, 11 item — 11 produk asli
Robot Shop (nama, deskripsi, harga, stok, kategori, rating) sekarang ada di
index `robot-shop-catalogue`.

> **Kenapa harus ambil data ini secara manual?** Robot Shop sendiri
> menyimpan produknya di MongoDB (dipakai oleh service `catalogue`), bukan
> di Elasticsearch. Langkah di atas menyalin data itu ke Elasticsearch
> supaya bisa kamu pakai untuk latihan Query DSL/relevance — pola ini
> mirip proses **ETL (Extract-Transform-Load)** sederhana yang umum di
> dunia nyata sebelum data bisa dicari lewat Elasticsearch.

**Coba search dulu tanpa scoring khusus** — cari produk kategori "Robot":
```
GET robot-shop-catalogue/_search
{ "query": { "match": { "categories": "Robot" } } }
```
Expected Output (aktual): **9 hits**, tapi perhatikan `_score`-nya —
hampir semua dokumen dapat skor **SAMA** (`0.262`), karena `match` cuma
menilai relevansi teks "Robot" di field `categories`, tidak tahu mana
produk yang sebenarnya lebih baik/populer.

## e. Contoh Implementasi

**Boost berdasarkan rating** (`function_score` + `field_value_factor`):
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
Expected Output (aktual) — urutan sekarang berubah total, produk rating
tinggi naik ke atas:
```
2.054  Robotic Mining Cyborg     (rating 5)
1.948  Stan                      (rating 5)
1.936  High-Powered Travel Droid (rating 4.33)
1.361  Ultimate Harvesting Juggernaut (rating 2)
0.262  ... (sisanya, rating 0 — skor tidak berubah dari baseline)
```
`modifier: "ln1p"` (log(1+x)) dipakai supaya rating 5 tidak "meledak"
dibanding rating 4 — pola umum untuk field yang skalanya kecil (1-5).
`missing: 0` menangani produk yang belum punya rating sama sekali.

**Boosting kategori tertentu** (`bool.should` dengan `boost`):
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
Expected Output (aktual) — SEMUA produk tetap muncul (`must: match_all`),
tapi yang kategorinya "Artificial Intelligence" melonjak ke atas:
```
7.208  Watson   (kategori: Artificial Intelligence)
7.208  Ewooid   (kategori: Artificial Intelligence)
5.959  Stan     (kategori: Robot + Artificial Intelligence, dapat boost parsial)
1.000  ... (sisanya, cuma kategori Robot, skor dasar match_all)
```
Ini pola umum e-commerce nyata: "tampilkan semua produk, tapi utamakan
kategori promosi/prioritas di atas."

## f. Referensi Exercise

Lanjutkan latihan mandiri di [`exercise/sesi-4/README.md`](../../../exercise/sesi-4/README.md).
