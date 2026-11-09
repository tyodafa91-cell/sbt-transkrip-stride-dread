# Alasan skor DREAD setelah uji dan setelah mitigasi (Sesi 8)

Status: DRAF, disesuaikan peneliti (arahan Pak Faldi).

## S-01 — Token tidak terikat ke penerbit terakreditasi (v1); nama kontrak bisa disamakan
- Setelah uji (v1): (8, 10, 8, 9, 8) → rata-rata 8.6. Tes S1: klon kontrak bernama sama lolos verify() di v1 setiap kali dicoba (R naik ke 10).
- Setelah mitigasi (v2): (8, 3, 5, 4, 4) → rata-rata 4.8. S2, S3, S6 ditolak di v2; sisa risiko = S5 (klon + registry palsu) yang hanya berhasil bila verifier tidak memakai alamat resmi.
- Rekomendasi: IssuerRegistry + verify() wajib cek issuer terdaftar; umumkan alamat kontrak resmi kampus (OWASP SC01).

## S-02 — Token bisa diterbitkan ke alamat holder yang salah
- Setelah uji (v1): (5, 3, 5, 4, 5) → rata-rata 4.4. Tes S4: verify() dengan alamat mahasiswa yang benar = false di v1, jadi serangan tidak berguna (R turun).
- Setelah mitigasi (v2): (5, 3, 5, 4, 4) → rata-rata 4.2. Sama dengan v1; kontrol sudah ada sejak v1. Sisa: kesalahan input alamat oleh issuer.
- Rekomendasi: Cocokkan alamat holder saat mint; perbaiki dengan revoke + reissue bila salah.

## S-03 — Klon kontrak + registry palsu lolos verify() di dirinya sendiri (risiko sisa)
- Setelah uji (v1): (7, 9, 6, 8, 4) → rata-rata 6.8. Tes S5: sistem tiruan lengkap selalu lolos di dirinya sendiri (R naik).
- Setelah mitigasi (v2): (7, 4, 6, 4, 4) → rata-rata 5.0. Risiko sisa: hanya berhasil bila verifier tidak memakai alamat resmi; dampak terbatas pada verifier yang lalai.
- Rekomendasi: Verifier wajib memakai alamat kontrak & registry resmi (pin alamat); daftar alamat resmi di situs kampus.

## S-04 — Kunci privat issuer dicuri sehingga penyerang bertindak sebagai penerbit
- Setelah uji (v1): (9, 7, 3, 10, 3) → rata-rata 6.4. Tes E4: kunci owner v1 (= issuer) bocor berarti pengambilalihan penuh.
- Setelah mitigasi (v2): (5, 7, 3, 5, 3) → rata-rata 4.6. Tes E5: di v2 kunci issuer bocor masih bisa menerbitkan, tetapi accreditor bisa memutus issuer sehingga dampak dibatasi.
- Rekomendasi: Pisahkan peran Admin/Accreditor/Issuer; simpan kunci di hardware wallet/multisig; revokeIssuer cepat (OWASP SC01).

## S-05 — Kunci privat holder dicuri; penyerang mengaku sebagai pemilik transkrip
- Setelah uji (v1): (5, 5, 4, 1, 3) → rata-rata 3.6. Tidak diuji (analisis desain); skor awal ditinjau ulang, tetap.
- Setelah mitigasi (v2): (3, 5, 4, 1, 3) → rata-rata 3.2. Reissue ke alamat baru memutus token lama, dampak berkurang.
- Rekomendasi: Reissue setelah verifikasi identitas off-chain oleh issuer; edukasi keamanan wallet holder.

## T-01 — Interaksi eksternal (_safeMint) sebelum state dicatat (v1)
- Setelah uji (v1): (6, 10, 5, 4, 5) → rata-rata 6.0. Tes T1: reentrancy selalu menghasilkan 2 token dari 1 commitment di v1 (dengan asumsi issuer berupa contract wallet).
- Setelah mitigasi (v2): (2, 1, 2, 1, 2) → rata-rata 1.6. Tes T2: panggilan ulang ditolak ReentrancyGuard + urutan CEI.
- Rekomendasi: Checks-effects-interactions + nonReentrant (SWC-107, OWASP SC05).

## T-02 — commitment dan tokenURI bisa diubah setelah terbit (v1)
- Setelah uji (v1): (8, 10, 5, 9, 7) → rata-rata 7.8. Tes T3: commitment dan URI selalu bisa diubah setelah terbit tanpa event.
- Setelah mitigasi (v2): (2, 1, 1, 1, 2) → rata-rata 1.4. Tes T4: v2 tidak punya fungsi ubah record; isi tetap.
- Rekomendasi: Hapus fungsi pengubah; koreksi hanya lewat revoke + reissue yang mengeluarkan event.

## T-03 — Urutan transaksi bisa diserobot (front-running) saat mint/registerIssuer
- Setelah uji (v1): (4, 4, 5, 5, 6) → rata-rata 4.8. Tidak diuji (analisis desain); skor awal ditinjau ulang, tetap.
- Setelah mitigasi (v2): (3, 3, 4, 3, 6) → rata-rata 3.8. Fungsi sensitif dibatasi peran dan commitment bergaram, sehingga menyerobot transaksi tidak memberi keuntungan berarti.
- Rekomendasi: Batasi fungsi sensitif dengan peran; jangan bergantung pada urutan transaksi (SWC-114).

## T-04 — Isi dokumen off-chain diganti atau tidak cocok dengan commitment
- Setelah uji (v1): (6, 3, 8, 3, 6) → rata-rata 5.2. sbt-tool: dokumen yang diubah langsung TIDAK VALID karena tidak cocok dengan commitment (R turun).
- Setelah mitigasi (v2): (5, 2, 6, 3, 4) → rata-rata 4.0. Commitment bergaram + verifier read-only membuat pemalsuan dokumen makin sulit.
- Rekomendasi: Verifier wajib mencocokkan dokumen dengan commitment lewat sbt-tool sebelum menerima transkrip.

## T-05 — Terbit ulang dua kali dari token lama menghasilkan 2 token aktif untuk 1 commitment (v1; temuan fuzzing)
- Setelah uji (v1): (6, 10, 4, 4, 3) → rata-rata 5.4. Tes reissue: v1 menghasilkan 2 token aktif bila reissue dipanggil dua kali dari token lama.
- Setelah mitigasi (v2): (1, 1, 4, 1, 3) → rata-rata 2.0. currentTokenOf menolak reissue dari token lama (test_v2_reissue_twiceFromOldToken_reverts).
- Rekomendasi: Lacak token terbaru (currentTokenOf); uji dengan fuzzing/invariant Echidna.

## R-01 — mint/revoke/reissue/updateRecord tanpa event yang memadai (v1)
- Setelah uji (v1): (5, 10, 5, 7, 8) → rata-rata 7.0. Tes R1: revoke/updateRecord/reissue v1 tidak mengeluarkan event, tidak bisa diaudit.
- Setelah mitigasi (v2): (2, 1, 5, 2, 3) → rata-rata 2.6. Tes R2: semua aksi penting v2 mengeluarkan event lengkap beserta pelakunya.
- Rekomendasi: Emit event Issued/Revoked/Reissued/IssuerRegistered/IssuerRevoked untuk setiap aksi kritis.

## I-01 — Hash tanpa salt pada data berentropi rendah
- Setelah uji (v1): (6, 10, 9, 9, 10) → rata-rata 8.8. Tes I1: hash tanpa salt dibongkar dalam 1.165 dari 80.400 tebakan; commitment terbaca dari storage Anvil.
- Setelah mitigasi (v2): (6, 1, 2, 1, 4) → rata-rata 2.8. Tes I2: dengan salt 32 byte, brute-force pada ruang tebakan yang sama gagal.
- Rekomendasi: Salted commitment 32 byte dihitung off-chain (SWC-136).

## I-02 — Data akademik mentah ikut terkirim ke chain lewat calldata/storage
- Setelah uji (v1): (7, 2, 8, 9, 8) → rata-rata 6.8. Tes I3: calldata v1 dan v2 tidak memuat data akademik mentah (R turun).
- Setelah mitigasi (v2): (7, 1, 3, 2, 3) → rata-rata 3.2. Hanya commitment yang dikirim on-chain; data mentah tetap off-chain terenkripsi.
- Rekomendasi: Jangan kirim data mentah ke chain; simpan off-chain terenkripsi (SWC-136).

## I-03 — Keterkaitan alamat holder dengan kepemilikan transkrip terbuka untuk publik
- Setelah uji (v1): (4, 10, 9, 7, 9) → rata-rata 7.8. Tidak diuji (analisis desain); event dan kepemilikan memang publik.
- Setelah mitigasi (v2): (4, 10, 9, 7, 9) → rata-rata 7.8. Risiko sisa: sifat blockchain publik tidak berubah oleh mitigasi kontrak.
- Rekomendasi: Holder memakai alamat khusus kredensial; dicatat sebagai keterbatasan privasi.

## I-04 — Dokumen di IPFS publik terbaca siapa pun yang tahu CID bila tidak dienkripsi
- Setelah uji (v1): (7, 9, 9, 9, 7) → rata-rata 8.2. Desain v1: metadata off-chain tanpa enkripsi bisa diunduh siapa pun yang tahu CID.
- Setelah mitigasi (v2): (7, 1, 2, 1, 5) → rata-rata 3.2. sbt-tool: dekripsi tanpa kunci gagal (AES-256-GCM).
- Rekomendasi: Enkripsi metadata AES-256-GCM sebelum diunggah ke IPFS; kunci dipegang holder.

## D-01 — Revokasi massal dengan loop tanpa batas melewati batas gas blok (v1)
- Setelah uji (v1): (5, 10, 5, 7, 7) → rata-rata 6.8. Tes D1: revokeMany v1 gagal di N = 1.500 (~30,5 juta gas, melewati batas blok); titik gagal ~1.190 token.
- Setelah mitigasi (v2): (2, 1, 5, 2, 3) → rata-rata 2.6. Tes D2: maksimal 50 token per transaksi; 120 token dicabut dalam 3 transaksi.
- Rekomendasi: Batasi jumlah iterasi per transaksi (SWC-128, OWASP SC10).

## D-02 — Verifikasi bergantung pada endpoint RPC dan gateway IPFS
- Setelah uji (v1): (4, 5, 4, 9, 8) → rata-rata 6.0. Belum diuji; latensi Sepolia diukur di Sesi 10. Skor awal ditinjau ulang, tetap.
- Setelah mitigasi (v2): (4, 4, 4, 6, 8) → rata-rata 5.2. Risiko sisa: verifikasi tetap bergantung pada RPC/gateway; berkurang bila memakai cadangan.
- Rekomendasi: Sediakan beberapa endpoint RPC dan gateway IPFS cadangan.

## D-03 — Kunci holder hilang sehingga holder tidak bisa menunjukkan transkrip
- Setelah uji (v1): (5, 5, 2, 1, 8) → rata-rata 4.2. Tes reissue: penerbitan ulang ke alamat baru bisa dilakukan.
- Setelah mitigasi (v2): (2, 5, 2, 1, 8) → rata-rata 3.6. Reissue v2 aman (token lama otomatis tidak berlaku), dampak kehilangan dompet berkurang.
- Rekomendasi: Prosedur reissue dengan verifikasi identitas off-chain oleh issuer.

## E-01 — Akun tanpa peran memanggil mint/revoke/reissue/registerIssuer/grantRole
- Setelah uji (v1): (9, 1, 2, 10, 8) → rata-rata 6.0. Tes E1: semua fungsi admin v1 revert untuk non-owner; serangan gagal (R dan E turun).
- Setelah mitigasi (v2): (9, 1, 1, 10, 6) → rata-rata 5.4. Tes E2: tanpa peran semua ditolak, termasuk registerIssuer dan grantRole; skor tetap Sedang karena D dan A secara desain tinggi.
- Rekomendasi: AccessControl per peran + separation of duty (OWASP SC01).

## E-02 — Upaya melewati sifat non-transferable
- Setelah uji (v1): (7, 1, 1, 9, 9) → rata-rata 5.4. Tes E3: transferFrom, kedua safeTransferFrom, approve, setApprovalForAll revert di v1.
- Setelah mitigasi (v2): (7, 1, 1, 9, 9) → rata-rata 5.4. Sama dengan v1 (SoulboundBase dipakai kedua versi); kontrol sudah berfungsi sejak awal.
- Rekomendasi: Pertahankan semua fungsi transfer/approval selalu revert (ERC-5192 locked).

## E-03 — Konfigurasi role keliru (mis. satu akun memegang semua peran)
- Setelah uji (v1): (9, 4, 3, 10, 3) → rata-rata 5.8. Tidak diuji langsung; skor awal ditinjau ulang, tetap.
- Setelah mitigasi (v2): (9, 1, 3, 10, 3) → rata-rata 5.2. DeployAll menolak satu akun memegang semua peran.
- Rekomendasi: Validasi konfigurasi peran saat deploy; dokumentasikan pemegang tiap peran.

## E-04 — Satu owner menjadi satu titik gagal (v1)
- Setelah uji (v1): (9, 8, 3, 10, 7) → rata-rata 7.4. Tes E4: kunci owner v1 bocor = terbit palsu, ubah data, dan cabut milik orang lain.
- Setelah mitigasi (v2): (5, 8, 3, 4, 7) → rata-rata 5.4. Tes E5: owner tunggal diganti peran terpisah; issuer bocor bisa diputus accreditor.
- Rekomendasi: Ganti owner tunggal dengan AccessControl multi-peran; gunakan multisig untuk admin.

## N-01 — Eclipse attack: node korban hanya terhubung ke node penyerang
- Setelah uji (v1): (7, 2, 2, 4, 2) → rata-rata 3.4. Kajian literatur (tidak diuji, batasan 1.5); skor awal tetap.
- Setelah mitigasi (v2): (7, 2, 2, 2, 2) → rata-rata 3.0. Verifier memakai lebih dari satu node/RPC tepercaya.
- Rekomendasi: Bandingkan hasil dari beberapa RPC berbeda.

## N-02 — Reorganisasi blok mengubah urutan/riwayat transaksi
- Setelah uji (v1): (5, 3, 1, 8, 3) → rata-rata 4.0. Kajian literatur (tidak diuji, batasan 1.5); skor awal tetap.
- Setelah mitigasi (v2): (3, 3, 1, 8, 3) → rata-rata 3.6. Menunggu konfirmasi/finality sebelum menerima hasil verifikasi.
- Rekomendasi: Terima mint/revoke setelah blok final.
