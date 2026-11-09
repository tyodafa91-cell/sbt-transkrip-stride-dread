# Alasan skor DREAD awal (Sesi 4, 21 Okt 2026)

Dasar: DFD, kode, dan literatur, sebelum pengujian. Status: DRAF, dikonsultasikan ke Pak Faldi.

## S-01 — Token tidak terikat ke penerbit terakreditasi (v1); nama kontrak bisa disamakan
Skor: D=8, R=9, E=8, A=9, Di=8 → rata-rata 8.4
- Damage (8): Transkrip palsu bisa diterbitkan dalam jumlah banyak dan merusak kepercayaan sistem.
- Reproducibility (9): Klon kontrak selalu bisa dideploy ulang dengan nama yang sama.
- Exploitability (8): Cukup akun biasa dan skrip deploy pendek.
- Affected users (9): Semua verifier yang hanya melihat nama kontrak ikut tertipu.
- Discoverability (8): Nama dan ABI kontrak terlihat publik di explorer.

## S-02 — Token bisa diterbitkan ke alamat holder yang salah
Skor: D=5, R=6, E=5, A=4, Di=5 → rata-rata 5.0
- Damage (5): Satu transkrip terikat ke alamat yang salah.
- Reproducibility (6): Terjadi bila alamat holder salah input atau sengaja diganti.
- Exploitability (5): Butuh hak issuer atau kesalahan prosedur issuer.
- Affected users (4): Terbatas pada holder yang alamatnya salah.
- Discoverability (5): Terlihat bila alur mint dan verify() dibaca.

## S-03 — Klon kontrak + registry palsu lolos verify() di dirinya sendiri (risiko sisa)
Skor: D=7, R=6, E=6, A=8, Di=4 → rata-rata 6.2
- Damage (7): Verifier bisa menerima transkrip palsu dari sistem tiruan lengkap.
- Reproducibility (6): Berhasil bila verifier tidak memastikan alamat kontrak resmi.
- Exploitability (6): Butuh deploy dua kontrak dan rekayasa sosial ke verifier.
- Affected users (8): Berdampak ke semua verifier yang tidak mengecek alamat resmi.
- Discoverability (4): Butuh pemahaman bahwa verify() hanya benar di kontraknya sendiri.

## S-04 — Kunci privat issuer dicuri sehingga penyerang bertindak sebagai penerbit
Skor: D=9, R=5, E=3, A=10, Di=3 → rata-rata 6.0
- Damage (9): Penyerang bisa menerbitkan banyak transkrip palsu atas nama issuer sah.
- Reproducibility (5): Hanya berhasil bila kunci issuer benar-benar bocor.
- Exploitability (3): Butuh phishing atau malware untuk mencuri kunci (akses istimewa).
- Affected users (10): Semua holder dan verifier terdampak oleh transkrip palsu.
- Discoverability (3): Kebocoran kunci tidak terlihat dari data publik.

## S-05 — Kunci privat holder dicuri; penyerang mengaku sebagai pemilik transkrip
Skor: D=5, R=5, E=4, A=1, Di=3 → rata-rata 3.6
- Damage (5): Satu holder kehilangan kendali atas transkripnya.
- Reproducibility (5): Hanya berhasil bila kunci holder dicuri.
- Exploitability (4): Butuh pencurian kunci, bukan sekadar skrip.
- Affected users (1): Hanya satu holder yang menjadi korban.
- Discoverability (3): Pencurian kunci tidak terlihat dari chain.

## T-01 — Interaksi eksternal (_safeMint) sebelum state dicatat (v1)
Skor: D=6, R=8, E=5, A=4, Di=5 → rata-rata 5.6
- Damage (6): Satu commitment menghasilkan dua token sehingga data transkrip ganda.
- Reproducibility (8): Deterministik setiap kali holder berupa kontrak penyerang.
- Exploitability (5): Butuh keahlian Solidity untuk membuat kontrak penerima jahat.
- Affected users (4): Terbatas pada transkrip yang diterbitkan ke kontrak penyerang.
- Discoverability (5): Terlihat bila urutan _safeMint dan pencatatan state dibaca.

## T-02 — commitment dan tokenURI bisa diubah setelah terbit (v1)
Skor: D=8, R=9, E=5, A=9, Di=6 → rata-rata 7.4
- Damage (8): Isi transkrip bisa diganti diam-diam sehingga integritas seluruh sistem runtuh.
- Reproducibility (9): Fungsi pengubah selalu bisa dipanggil oleh pemegang hak.
- Exploitability (5): Butuh hak owner/issuer (orang dalam atau kunci bocor).
- Affected users (9): Semua transkrip yang sudah terbit bisa diubah.
- Discoverability (6): Fungsi updateRecord terlihat di ABI publik.

## T-03 — Urutan transaksi bisa diserobot (front-running) saat mint/registerIssuer
Skor: D=4, R=4, E=5, A=5, Di=6 → rata-rata 4.8
- Damage (4): Dampak terbatas pada urutan transaksi, bukan isi transkrip.
- Reproducibility (4): Hanya pada kondisi mempool dan gas tertentu.
- Exploitability (5): Butuh bot pemantau mempool.
- Affected users (5): Berdampak ke sebagian transaksi yang sedang tertunda.
- Discoverability (6): Mempool bisa dipantau publik.

## T-04 — Isi dokumen off-chain diganti atau tidak cocok dengan commitment
Skor: D=6, R=8, E=8, A=3, Di=6 → rata-rata 6.2
- Damage (6): Satu transkrip off-chain dipalsukan, misalnya IPK dinaikkan.
- Reproducibility (8): Mengedit dokumen selalu bisa dilakukan.
- Exploitability (8): Cukup mengedit file tanpa keahlian khusus.
- Affected users (3): Terbatas pada dokumen yang dipalsukan.
- Discoverability (6): Terlihat bila verifier tidak mencocokkan commitment.

## T-05 — Terbit ulang dua kali dari token lama menghasilkan 2 token aktif untuk 1 commitment (v1; temuan fuzzing)
Skor: D=6, R=8, E=4, A=4, Di=3 → rata-rata 5.0
- Damage (6): Dua token aktif untuk satu transkrip membingungkan status kepemilikan.
- Reproducibility (8): Deterministik bila reissue dipanggil dua kali dari token lama.
- Exploitability (4): Butuh hak issuer.
- Affected users (4): Terbatas pada holder yang diterbitkan ulang.
- Discoverability (3): Sulit terlihat; baru ditemukan lewat fuzzing.

## R-01 — mint/revoke/reissue/updateRecord tanpa event yang memadai (v1)
Skor: D=5, R=9, E=5, A=7, Di=7 → rata-rata 6.6
- Damage (5): Tidak ada jejak audit, sehingga sengketa tidak bisa dibuktikan.
- Reproducibility (9): Tidak adanya event berlaku di setiap pemanggilan.
- Exploitability (5): Butuh hak issuer untuk melakukan aksi lalu menyangkalnya.
- Affected users (7): Semua holder yang transkripnya dicabut atau diubah terdampak.
- Discoverability (7): Terlihat dari tidak adanya event di explorer.

## I-01 — Hash tanpa salt pada data berentropi rendah
Skor: D=6, R=9, E=7, A=9, Di=9 → rata-rata 8.0
- Damage (6): Data akademik pribadi (NIM, IPK) bisa terbongkar.
- Reproducibility (9): Brute-force data berentropi rendah selalu berhasil.
- Exploitability (7): Cukup skrip pendek untuk mencoba kombinasi NIM/IPK.
- Affected users (9): Semua holder yang commitment-nya tanpa salt terdampak.
- Discoverability (9): Commitment terbaca langsung dari storage publik.

## I-02 — Data akademik mentah ikut terkirim ke chain lewat calldata/storage
Skor: D=7, R=8, E=8, A=9, Di=8 → rata-rata 8.0
- Damage (7): Data akademik mentah tersebar permanen di chain.
- Reproducibility (8): Terjadi setiap kali issuer mengirim data mentah.
- Exploitability (8): Cukup membaca calldata di explorer.
- Affected users (9): Semua holder yang datanya dikirim mentah terdampak.
- Discoverability (8): Calldata dan storage terlihat publik.

## I-03 — Keterkaitan alamat holder dengan kepemilikan transkrip terbuka untuk publik
Skor: D=4, R=10, E=9, A=7, Di=9 → rata-rata 7.8
- Damage (4): Hanya membuka keterkaitan alamat dengan kepemilikan transkrip, bukan isi transkrip.
- Reproducibility (10): Event selalu terbaca publik.
- Exploitability (9): Cukup membaca event di explorer.
- Affected users (7): Berdampak ke holder yang alamatnya bisa dikaitkan dengan identitas.
- Discoverability (9): Event Issued/Transfer publik.

## I-04 — Dokumen di IPFS publik terbaca siapa pun yang tahu CID bila tidak dienkripsi
Skor: D=7, R=9, E=9, A=9, Di=7 → rata-rata 8.2
- Damage (7): Isi transkrip lengkap terbaca bila tidak dienkripsi.
- Reproducibility (9): Unduhan dari gateway IPFS selalu berhasil bila CID diketahui.
- Exploitability (9): Cukup membuka gateway IPFS dengan CID.
- Affected users (9): Semua dokumen tanpa enkripsi terdampak.
- Discoverability (7): CID terlihat dari tokenURI publik.

## D-01 — Revokasi massal dengan loop tanpa batas melewati batas gas blok (v1)
Skor: D=5, R=9, E=5, A=7, Di=6 → rata-rata 6.4
- Damage (5): Revokasi massal gagal, tetapi tidak ada kredensial yang hilang.
- Reproducibility (9): Selalu gagal bila jumlah token melewati batas gas blok.
- Exploitability (5): Butuh hak issuer untuk memanggil revokasi massal.
- Affected users (7): Sebagian holder yang seharusnya dicabut tetap aktif.
- Discoverability (6): Terlihat bila loop revokeBatch dibaca.

## D-02 — Verifikasi bergantung pada endpoint RPC dan gateway IPFS
Skor: D=4, R=5, E=4, A=9, Di=8 → rata-rata 6.0
- Damage (4): Verifikasi tertunda, tetapi tidak ada data yang rusak.
- Reproducibility (5): Hanya saat RPC atau gateway sedang tidak tersedia.
- Exploitability (4): Butuh gangguan layanan pihak ketiga.
- Affected users (9): Semua verifier yang memakai endpoint yang sama terdampak.
- Discoverability (8): Ketergantungan pada RPC/IPFS terlihat dari arsitektur.

## D-03 — Kunci holder hilang sehingga holder tidak bisa menunjukkan transkrip
Skor: D=5, R=5, E=2, A=1, Di=8 → rata-rata 4.2
- Damage (5): Satu holder tidak bisa menunjukkan transkripnya sampai diterbitkan ulang.
- Reproducibility (5): Terjadi bila holder kehilangan dompet.
- Exploitability (2): Bukan serangan; kehilangan kunci adalah kejadian tak disengaja.
- Affected users (1): Hanya satu holder.
- Discoverability (8): Risiko kehilangan kunci sudah umum diketahui.

## E-01 — Akun tanpa peran memanggil mint/revoke/reissue/registerIssuer/grantRole
Skor: D=9, R=4, E=8, A=10, Di=8 → rata-rata 7.8
- Damage (9): Akun tanpa peran bisa menerbitkan atau mencabut transkrip siapa saja.
- Reproducibility (4): Hanya berhasil bila kontrol akses tidak ada atau salah pasang.
- Exploitability (8): Cukup akun biasa dan satu pemanggilan fungsi.
- Affected users (10): Semua holder dan verifier terdampak.
- Discoverability (8): Fungsi admin terlihat di ABI publik.

## E-02 — Upaya melewati sifat non-transferable
Skor: D=7, R=2, E=7, A=9, Di=9 → rata-rata 6.8
- Damage (7): Transkrip bisa berpindah tangan sehingga sifat soulbound hilang.
- Reproducibility (2): Hampir mustahil karena semua fungsi transfer dibuat revert.
- Exploitability (7): Cukup akun biasa untuk mencoba memanggil transfer.
- Affected users (9): Semua holder terdampak bila berhasil.
- Discoverability (9): Fungsi transfer ERC-721 terlihat di ABI.

## E-03 — Konfigurasi role keliru (mis. satu akun memegang semua peran)
Skor: D=9, R=4, E=3, A=10, Di=3 → rata-rata 5.8
- Damage (9): Satu kunci bisa menguasai seluruh sistem.
- Reproducibility (4): Hanya terjadi bila deploy dikonfigurasi keliru.
- Exploitability (3): Butuh kesalahan admin dan kunci yang bocor.
- Affected users (10): Semua holder dan verifier terdampak.
- Discoverability (3): Butuh pemeriksaan role per alamat.

## E-04 — Satu owner menjadi satu titik gagal (v1)
Skor: D=9, R=6, E=3, A=10, Di=7 → rata-rata 7.0
- Damage (9): Kunci owner bocor berarti terbit palsu, ubah data, dan cabut milik orang lain.
- Reproducibility (6): Berhasil setiap kali kunci owner bocor.
- Exploitability (3): Butuh pencurian kunci owner.
- Affected users (10): Semua holder dan verifier terdampak.
- Discoverability (7): Pola owner tunggal terlihat jelas di kode v1.

## N-01 — Eclipse attack: node korban hanya terhubung ke node penyerang
Skor: D=7, R=2, E=2, A=4, Di=2 → rata-rata 3.4
- Damage (7): Verifier korban bisa melihat rantai palsu.
- Reproducibility (2): Sangat sulit dilakukan di jaringan publik besar (dasar: literatur).
- Exploitability (2): Butuh banyak node dan kendali atas koneksi korban.
- Affected users (4): Hanya verifier yang node-nya diisolasi.
- Discoverability (2): Butuh analisis jaringan mendalam.

## N-02 — Reorganisasi blok mengubah urutan/riwayat transaksi
Skor: D=5, R=3, E=1, A=8, Di=3 → rata-rata 4.0
- Damage (5): Transaksi mint/revoke bisa terbalik sementara.
- Reproducibility (3): Jarang terjadi di Ethereum setelah finality (dasar: literatur).
- Exploitability (1): Di luar kendali penyerang biasa.
- Affected users (8): Semua transaksi di blok yang terkena reorg terdampak.
- Discoverability (3): Butuh pemantauan jaringan.
