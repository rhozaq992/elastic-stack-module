# Sesi 2 — Document Management & Data Model

## a. Tujuan Sesi

Setelah mengikuti sesi ini, Anda memahami struktur data Elasticsearch
(index/document/field/mapping), memahami perbedaan tipe field `text` dan
`keyword` beserta kapan menggunakan masing-masing, serta mampu melakukan
operasi CRUD (Create, Read, Update, Delete) pada dokumen melalui Kibana
Dev Tools Console.

## b. Output yang Diharapkan

Sesi ini dinyatakan selesai apabila:
- Index `lab-mapping-demo` berhasil dibuat dengan mapping eksplisit (field
  `text` dan `keyword`), dan Anda dapat menjelaskan mengapa hasil query
  terhadap keduanya berbeda.
- Anda berhasil melakukan INDEX, GET, UPDATE, dan DELETE terhadap satu
  dokumen pada index `lab-demo`, serta memahami makna `_version` yang
  bertambah setiap kali dokumen berubah.

## c. Teori & Struktur Sistem

**Index, Document, Field.** Satu *index* berisi banyak *document* (setara satu
baris data), dan setiap document tersusun dari beberapa *field* (setara satu
kolom). Berbeda dengan database relasional, document dalam satu index tidak
wajib memiliki field yang sama persis (skema fleksibel), meskipun dalam
praktiknya biasanya diseragamkan.

**Mapping** adalah definisi tipe data setiap field dalam sebuah index (mirip
skema tabel). Apabila tidak didefinisikan secara eksplisit, Elasticsearch
akan menebak tipe field secara otomatis (*dynamic mapping*) saat dokumen
pertama masuk.

**`text` vs `keyword` — dua tipe field yang paling sering digunakan:**
- `text` di-*tokenize* (dipecah menjadi kata-kata, huruf kecil, dst.) agar
  dapat di-*full-text search* berdasarkan sebagian kata.
- `keyword` disimpan utuh apa adanya, hanya dapat dicari dengan nilai yang
  **PERSIS** sama, sehingga field seperti status, kategori, ID, atau field
  yang digunakan untuk agregasi/sorting sebaiknya bertipe `keyword`.

**Cara menjalankan query di lab ini — Kibana Dev Tools Console.**

![Kibana halaman utama, klik ikon menu hamburger di kiri atas](../../../docs/screenshots/sesi-2/01-kibana-home.png)

*1. Buka Kibana, klik ikon ☰ (menu) di kiri atas.*

![Sidebar menu Kibana terbuka menampilkan Analytics, Elasticsearch, Observability](../../../docs/screenshots/sesi-2/02-klik-menu-hamburger.png)

*2. Menu sidebar terbuka — Dev Tools ada di bagian bawah menu Elasticsearch/Management.*

![Kibana Dev Tools Console kosong, siap diisi query](../../../docs/screenshots/sesi-2/03-dev-tools-console-kosong.png)

*3. Halaman Dev Tools Console — panel kiri untuk menulis query, panel kanan untuk hasil.*

Mulai sesi ini, Anda akan melihat blok seperti:
```
GET lab-mapping-demo/_search
{ "query": { ... } }
```
Ini **BUKAN** perintah bash/curl, melainkan syntax khusus **Kibana Dev
Tools Console** (menu ☰ → Dev Tools → Console, atau buka langsung
`http://localhost:5601/app/dev_tools#/console`). Baris pertama adalah
method + path, sedangkan badan JSON di bawahnya adalah request body.
**Apabila ditempel (paste) ke terminal biasa, perintah ini akan
menghasilkan error** (`GET: command not found`) — buka Dev Tools Console
terlebih dahulu, tempelkan ke sana, lalu jalankan (klik ikon ▶ di sebelah
kiri baris, atau `Cmd+Enter`/`Ctrl+Enter`).

## d. Praktik: Instalasi & Konfigurasi

*(Prasyarat: pastikan stack Sesi 1 masih berjalan — jalankan
`docker compose up -d` di `lab/day-1-fundamentals/sesi-1-intro-elk/`
apabila belum.)*

**Buat index dengan mapping eksplisit** (2 field berisi teks yang sama, tipe berbeda):
```
PUT lab-mapping-demo
{
  "mappings": {
    "properties": {
      "jabatan_text": { "type": "text" },
      "jabatan_keyword": { "type": "keyword" }
    }
  }
}
```
Expected Output: `{"acknowledged":true,"shards_acknowledged":true,"index":"lab-mapping-demo"}`

**Index 2 dokumen contoh:**
```
PUT lab-mapping-demo/_doc/1
{ "jabatan_text": "Security Operations Analyst", "jabatan_keyword": "Security Operations Analyst" }

PUT lab-mapping-demo/_doc/2?refresh=true
{ "jabatan_text": "Network Security Engineer", "jabatan_keyword": "Network Security Engineer" }
```

**Cobalah query paling sederhana terlebih dahulu** (`match_all`,
menampilkan semua dokumen) agar Anda terbiasa dengan alur
ketik-jalankan-baca hasil di Console:

![Query match_all diketik di Dev Tools Console, siap dijalankan](../../../docs/screenshots/sesi-2/04-dev-tools-query-diketik.png)

*4. Ketik query di panel kiri (perhatikan tombol ▶ biru muncul di ujung baris pertama).*

![Hasil response query match_all di Dev Tools Console, menampilkan 2 dokumen](../../../docs/screenshots/sesi-2/05-dev-tools-hasil-response.png)

*5. Klik ▶ (atau `Cmd+Enter`/`Ctrl+Enter`) — hasil akan muncul di panel kanan: 2 dokumen `lab-mapping-demo`.*

**Query 1** — `match` di field `text` dengan kata `"Security"` (partial match):
```
GET lab-mapping-demo/_search
{ "query": { "match": { "jabatan_text": "Security" } } }
```
Expected Output: **2 hits** (kedua dokumen match, karena `match`
men-*tokenize* "Security" dan mencari token tersebut, yang cocok pada
keduanya).

**Query 2** — `term` di field `keyword` dengan kata `"Security"` saja (bukan nilai lengkap):
```
GET lab-mapping-demo/_search
{ "query": { "term": { "jabatan_keyword": "Security" } } }
```
Expected Output: **0 hits** — `term` mencari nilai `keyword` yang
PERSIS sama, dan tidak ada dokumen dengan nilai `jabatan_keyword` yang
hanya berupa `"Security"` (nilainya merupakan kalimat lengkap).

**Query 3** — `term` di field `keyword` dengan nilai LENGKAP:
```
GET lab-mapping-demo/_search
{ "query": { "term": { "jabatan_keyword": "Security Operations Analyst" } } }
```
Expected Output: **1 hit** (dokumen `_id: 1`) — kini nilainya persis
sama, sehingga `term` berhasil melakukan match.

## e. Contoh Implementasi

CRUD dokumen melalui Dev Tools Console, menggunakan index baru `lab-demo`:

**1. INDEX (create):**
```
PUT lab-demo/_doc/1
{ "nama": "Budi Santoso", "jabatan": "Security Analyst", "level": "L1" }
```
Expected Output: `"result":"created"`, `"_version":1`, `"_seq_no":0`, `"_primary_term":1`.

**2. GET:**
```
GET lab-demo/_doc/1
```
Expected Output: `"found":true`, `_source` berisi data yang baru saja diindeks.

**3. UPDATE (partial — cuma field `level`):**
```
POST lab-demo/_update/1
{ "doc": { "level": "L2" } }
```
Expected Output: `"result":"updated"`, `"_version":2` (bertambah dari 1).
Menjalankan `GET` kembali menunjukkan `"level": "L2"`, sementara field
lain tidak berubah.

**4. DELETE:**
```
DELETE lab-demo/_doc/1
```
Expected Output: `"result":"deleted"`, `"_version":3`.

**5. GET setelah delete:** Expected Output: HTTP 404, `"found":false`.

### Preview: Lihat & Export Data Lewat Discover

Sejauh ini, Anda selalu melihat data melalui Dev Tools Console (respons
JSON mentah). Kibana juga menyediakan fitur **Discover**, yaitu tampilan
tabel untuk menjelajahi dokumen tanpa perlu menulis query JSON (fitur ini
akan digunakan secara penuh mulai Sesi 3). Bagian ini mencoba sekilas
penggunaannya dengan data `lab-mapping-demo` yang baru saja Anda buat.

**1. Buat Data View** (index custom seperti `lab-mapping-demo` perlu
didaftarkan terlebih dahulu agar muncul di Discover): buka menu ☰ →
Discover, klik nama data view aktif di kiri atas → **"Create a data
view"** → isi **Name** dan **Index pattern** dengan `lab-mapping-demo`
(index ini tidak memiliki field tanggal, sehingga field **Timestamp**
dibiarkan kosong) → **Save data view to Kibana**.

**2. Filter data menggunakan KQL** (Kibana Query Language — search bar di
atas tabel, dengan syntax yang berbeda dari Query DSL Dev Tools Console):

![Discover menampilkan 2 dokumen lab-mapping-demo setelah data view dibuat](../../../docs/screenshots/sesi-2/06-discover-lab-mapping-demo.png)

*Discover dengan data view `lab-mapping-demo` aktif — 2 dokumen yang Anda indeks di bagian (d) muncul di tabel.*

Ketik di search bar: `jabatan_keyword: "Security Operations Analyst"`, lalu Enter.

![Discover dengan filter KQL aktif, menampilkan 1 dokumen hasil filter](../../../docs/screenshots/sesi-2/07-discover-filter-kql.png)

*Filter KQL — hanya 1 dokumen yang cocok, kata yang match di-highlight kuning.*

**3. Export hasil filter ke CSV**: klik ikon **⋮** (More, di sebelah
kanan "Query in ES|QL") → **Export tab results** → **CSV**:

![Modal Export Discover session as CSV dengan tombol Generate CSV](../../../docs/screenshots/sesi-2/08-export-csv-modal.png)

*Modal export — klik **Generate CSV** untuk memproses hasil filter menjadi file CSV.*

Setelah **Generate CSV**, akan muncul notifikasi "Queued report for
search" — proses pembuatannya bersifat **async** (tidak langsung
terunduh), sehingga perlu membuka **Stack Management → Reporting** untuk
mengambil hasilnya:

![Halaman Stack Management Reporting menampilkan laporan CSV siap diunduh](../../../docs/screenshots/sesi-2/09-reporting-download.png)

*Status **Done** — klik ikon download di kolom Actions untuk mengunduh file CSV-nya.*

Expected Output (isi file CSV):
```csv
"_id","_ignored","_index","_score","jabatan_keyword","jabatan_text"
1,"-","lab-mapping-demo",0.693,"Security Operations Analyst","Security Operations Analyst"
```
CSV berisi PERSIS dokumen yang lolos filter — cara ini digunakan apabila
Anda perlu membagikan hasil pencarian kepada orang lain dalam bentuk
spreadsheet, tanpa mereka perlu mengakses Kibana.

## f. Referensi Exercise

Lanjutkan latihan mandiri di [`exercise/sesi-2/README.md`](../../../exercise/sesi-2/README.md).
