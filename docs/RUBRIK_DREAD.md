# Rubrik skor DREAD tertulis (skala 1–10)

Sesuai proposal (subbab 1.1, 2.3.4, 2.3.8): DREAD dinilai dengan rubrik tertulis, skor akhir adalah
rata-rata lima parameter, **7 ke atas = Tinggi, 4–6 = Sedang, di bawah 4 = Rendah**, penilaian
**dikonsultasikan dengan pembimbing** dan **dihitung ulang setelah pengujian**. Efektivitas mitigasi
dilihat dari **turunnya skor setelah mitigasi**.

Catatan pembulatan: rata-rata bisa desimal (mis. 6,6). Skrip memakai aturan: ≥ 7,0 Tinggi;
4,0 sampai < 7,0 Sedang; < 4,0 Rendah. Sebutkan aturan ini di Bab IV.

## Tiga tahap penilaian (kolom di `data/dread_penilaian.csv`)
| Tahap | Kolom | Kapan | Dasar penilaian |
|---|---|---|---|
| Awal | `D_awal … Di_awal` | Sesi 4, sebelum menjalankan tes | DFD, kode, literatur |
| Setelah pengujian | `D_uji … Di_uji` | Sesi 8 | Hasil tes pada **v1** (serangan berhasil/tidak, seberapa mudah) |
| Setelah mitigasi | `D_mitigasi … Di_mitigasi` | Sesi 8 | Risiko sisa pada **v2** |

## Patokan tiap parameter
| Parameter | 1–3 | 4–6 | 7–10 |
|---|---|---|---|
| **D**amage | Gangguan kecil tanpa kehilangan kredensial *(patokan proposal)* | Satu kredensial terdampak *(patokan proposal)* | Banyak transkrip nilai atau integritas sistem terganggu *(patokan proposal)* |
| **R**eproducibility | Hanya pada kondisi langka | Butuh kondisi tertentu (mis. issuer berupa contract wallet) | Berhasil setiap kali dicoba (deterministik di tes) |
| **E**xploitability | Butuh akses istimewa dan keahlian tinggi | Butuh keahlian Solidity/tooling dasar atau satu hak istimewa | Cukup akun biasa dan skrip pendek |
| **A**ffected users | Satu pengguna | Sebagian pengguna / satu penerbit | Semua holder atau semua verifier |
| **Di**scoverability | Butuh analisis mendalam / akses non-publik | Terlihat bila kode dibaca | Terlihat dari storage/ABI/event publik |

Patokan D diambil langsung dari proposal (2.3.4). Patokan R, E, A, Di adalah usulan; kalau Pak Faldi
meminta patokan lain, ubah tabel ini SEBELUM mulai memberi skor, lalu pakai konsisten.

## Cara mengisi
1. Satu baris = satu ancaman. Beri skor 1–10 untuk kelima parameter pada tahap yang sedang dikerjakan.
2. Tulis **satu kalimat alasan per parameter** di `catatan.md` (penguji akan bertanya "kenapa 7, bukan 5?").
3. Jalankan `./scripts/hitung_dread.sh`. Hasil: `data/dread_hasil.csv` dan `data/model_ancaman_akhir.csv`.
4. Ancaman yang hanya dikaji lewat literatur (N-01, N-02) tetap diberi skor, tetapi tulis bahwa dasarnya
   literatur, bukan pengujian. Skor `_uji` untuk baris seperti itu = skor awal yang ditinjau ulang.

## Contoh cara berpikir (BUKAN jawaban)
T-01 (reentrancy saat mint, v1). Bukti: tes T1, 1 commitment menghasilkan 2 token.
R tinggi karena tes selalu berhasil; E sedang karena butuh issuer berupa contract wallet; Di sedang karena
terlihat bila kode dibaca. D dan A tergantung argumenmu tentang berapa banyak transkrip yang bisa rusak.
