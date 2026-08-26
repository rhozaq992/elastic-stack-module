# Sesi 2 — Document Management & Data Model

## a. Tujuan Sesi

Setelah sesi ini, kamu memahami struktur data Elasticsearch (index/document/
field/mapping), tahu perbedaan tipe field `text` vs `keyword` dan kapan
memakai yang mana, serta mampu melakukan operasi CRUD (Create, Read,
Update, Delete) dokumen lewat Kibana Dev Tools Console.

## b. Output yang Diharapkan

Sesi ini selesai kalau:
- Index `lab-mapping-demo` berhasil dibuat dengan mapping eksplisit (field
  `text` dan `keyword`), dan kamu bisa jelaskan kenapa hasil query terhadap
  keduanya berbeda.
- Kamu berhasil INDEX, GET, UPDATE, dan DELETE satu dokumen di index
  `lab-demo`, dan mengerti arti `_version` yang naik tiap kali dokumen berubah.

## c. Teori & Struktur Sistem

**Index, Document, Field.** Satu *index* berisi banyak *document* (setara 1
baris data), dan tiap document tersusun dari beberapa *field* (setara 1
kolom). Beda dengan database relasional: document dalam 1 index tidak
wajib punya field yang sama persis (skema fleksibel), meski praktiknya
biasanya diseragamkan.

**Mapping** adalah definisi tipe data tiap field dalam sebuah index (mirip
skema tabel). Kalau tidak didefinisikan eksplisit, Elasticsearch menebak
tipe field secara otomatis (*dynamic mapping*) saat dokumen pertama masuk.

**`text` vs `keyword` — dua tipe field paling sering dipakai:**
- `text` di-*tokenize* (dipecah jadi kata-kata, lowercase, dst.) supaya
  bisa di-*full-text search* sebagian kata.
- `keyword` disimpan utuh apa adanya, hanya bisa dicari dengan nilai yang
  **PERSIS** sama — makanya field seperti status, kategori, ID, atau field
  yang dipakai untuk agregasi/sorting sebaiknya bertipe `keyword`.

**Cara menjalankan query di lab ini — Kibana Dev Tools Console.** Mulai
sesi ini, kamu akan melihat blok seperti:
```
GET lab-mapping-demo/_search
{ "query": { ... } }
```
Ini **BUKAN** perintah bash/curl — ini syntax khusus **Kibana Dev Tools
Console** (menu ☰ → Dev Tools → Console, atau buka langsung
`http://localhost:5601/app/dev_tools#/console`). Baris pertama adalah
method + path, badan JSON di bawahnya adalah request body. **Kalau di-paste
ke terminal biasa akan error** (`GET: command not found`) — buka Dev Tools
Console dulu, paste ke sana, lalu jalankan (klik ikon ▶ di sebelah kiri
baris, atau `Cmd+Enter`/`Ctrl+Enter`).

## d. Praktik: Instalasi & Konfigurasi

*(Prasyarat: stack Sesi 1 masih jalan — `docker compose up -d` di
`lab/day-1-fundamentals/sesi-1-intro-elk/` kalau belum.)*

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
Expected Output (aktual): `{"acknowledged":true,"shards_acknowledged":true,"index":"lab-mapping-demo"}`

**Index 2 dokumen contoh:**
```
POST lab-mapping-demo/_doc/1
{ "jabatan_text": "Security Operations Analyst", "jabatan_keyword": "Security Operations Analyst" }

POST lab-mapping-demo/_doc/2?refresh=true
{ "jabatan_text": "Network Security Engineer", "jabatan_keyword": "Network Security Engineer" }
```

**Query 1** — `match` di field `text` dengan kata `"Security"` (partial match):
```
GET lab-mapping-demo/_search
{ "query": { "match": { "jabatan_text": "Security" } } }
```
Expected Output (aktual): **2 hits** (kedua dokumen match — `match`
men-tokenize "Security" dan mencari token itu, cocok di keduanya).

**Query 2** — `term` di field `keyword` dengan kata `"Security"` saja (bukan nilai lengkap):
```
GET lab-mapping-demo/_search
{ "query": { "term": { "jabatan_keyword": "Security" } } }
```
Expected Output (aktual): **0 hits** — `term` mencari nilai `keyword` yang
PERSIS sama, dan tidak ada dokumen yang nilai `jabatan_keyword`-nya cuma
`"Security"` (nilainya adalah kalimat lengkap).

**Query 3** — `term` di field `keyword` dengan nilai LENGKAP:
```
GET lab-mapping-demo/_search
{ "query": { "term": { "jabatan_keyword": "Security Operations Analyst" } } }
```
Expected Output (aktual): **1 hit** (dokumen `_id: 1`) — sekarang nilainya
persis sama, `term` berhasil match.

## e. Contoh Implementasi

CRUD dokumen lewat Dev Tools Console, pakai index baru `lab-demo`:

**1. INDEX (create):**
```
POST lab-demo/_doc/1
{ "nama": "Budi Santoso", "jabatan": "Security Analyst", "level": "L1" }
```
Expected Output (aktual): `"result":"created"`, `"_version":1`, `"_seq_no":0`, `"_primary_term":1`.

**2. GET:**
```
GET lab-demo/_doc/1
```
Expected Output (aktual): `"found":true`, `_source` berisi data yang barusan di-index.

**3. UPDATE (partial — cuma field `level`):**
```
POST lab-demo/_update/1
{ "doc": { "level": "L2" } }
```
Expected Output (aktual): `"result":"updated"`, `"_version":2` (naik dari 1).
`GET` ulang menunjukkan `"level": "L2"` sementara field lain tidak berubah.

**4. DELETE:**
```
DELETE lab-demo/_doc/1
```
Expected Output (aktual): `"result":"deleted"`, `"_version":3`.

**5. GET setelah delete:** Expected Output (aktual): HTTP 404, `"found":false`.

## f. Referensi Exercise

Lanjutkan latihan mandiri di [`exercise/sesi-2/README.md`](../../../exercise/sesi-2/README.md).
