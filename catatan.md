## Sesi 1, 19-10-2026 08:17

forge Version: 1.8.5
v24.22.0
forge test: 36 passed, 0 failed (6 invarian dihitung 1 oleh Foundry 1.8.5)
Titik simpan: Sesi 1 selesai

## Sesi 2 - Kenali kontrak v1 (proposal 2.3.5)

1. Satu owner jadi satu-satunya penerbit (onlyOwner). Kunci dicuri = semua jebol. STRIDE: S dan E.
2. mint(): \_safeMint jalan dulu, commitmentIssued diisi belakangan, jadi bisa reentrancy (1 transkrip jadi 2). STRIDE: T.
3. updateRecord(): isi transkrip bisa diganti setelah terbit. STRIDE: T.
4. revoke(), revokeMany(), updateRecord() tanpa emit event, jadi tidak ada jejak. STRIDE: R.
5. Commitment tanpa salt, data berentropi rendah (NIM, IPK, SKS) bisa di-brute-force. STRIDE: I.
6. revokeMany() loop tanpa batas, bisa kehabisan gas dan macet. STRIDE: D.
7. reissue() tidak cek token terbaru, bisa muncul 2 token aktif (tambahan dari kebutuhan 2.3.2). STRIDE: T.
Catatan: verify() tidak mengecek siapa penerbitnya, jadi kontrak tiruan bisa lolos (dibuktikan di Sesi 5).
SoulboundBase: transferFrom, safeTransferFrom (2 versi), approve, setApprovalForAll selalu revert; locked() = true (proposal 2.3.3). Sama di v1 dan v2.
forge test FunctionalTest: 11 passed, 0 failed
Titik simpan: Sesi 2 selesai, berikutnya Sesi 3 (kenali v2 + IssuerRegistry)

## Sesi 3 - Kenali v2 + IssuerRegistry + reissue (proposal 2.3.2, 2.3.3, 2.3.5)
Kelemahan v1 -> mitigasi v2:
1. Satu owner -> ISSUER_ROLE (token) + ACCREDITOR_ROLE (registry); mint wajib issuer terdaftar.
2. Reentrancy di mint -> checks-effects-interactions (_safeMint paling akhir) + nonReentrant.
3. updateRecord -> dihapus, record tidak bisa diubah setelah terbit.
4. Tanpa event -> emit Issued, Revoked, Reissued, IssuerRegistered, IssuerRevoked (ada pelakunya).
5. Hash tanpa salt -> salted commitment dihitung di luar kontrak (keterbatasan: kontrak tidak bisa memaksa salt).
6. Revokasi tanpa batas -> revokeBatch maks 50 per transaksi (MAX_REVOKE_PER_TX).
7. Reissue dobel -> currentTokenOf, hanya token terbaru yang boleh diterbitkan ulang.
verify() v2: token ada + holder cocok + belum dicabut + commitment cocok + issuer masih terdaftar di registry.
IssuerRegistry: registerIssuer/revokeIssuer hanya ACCREDITOR_ROLE; isActiveIssuer dipanggil oleh mint dan verify (ide ERC-3643 + OnchainID, 2.3.3).
forge test --match-test reissue: 5 passed, 0 failed.
Titik simpan: Sesi 3 selesai, berikutnya Sesi 4 (DFD, daftar ancaman 7 komponen, DREAD awal, siapkan wawancara BAA)

## Sesi 4 - Langkah 1 & 2 (21 Okt 2026)
- DFD selesai: docs/gambar/DFD_SBT_Transkrip.drawio.png (16 aliran data, trust boundary on-chain/off-chain).
- Identifikasi ancaman: 24 ancaman di data/dread_penilaian.csv sudah dicocokkan ke semua elemen DFD, tidak ada yang dihapus.
- Ancaman yang dikenali tapi di luar cakupan penilaian (masuk keterbatasan):
  1. Kunci privat Accreditor dicuri -> penyerang mendaftarkan issuer palsu (P1).
  2. Node RPC jahat memberi jawaban verify() palsu ke verifier (aliran 13-15).
  3. Salt bocor saat holder membagikan data ke verifier (aliran 12).

## Sesi 4 - Langkah 3 (21 Okt 2026)
- DREAD awal 24 ancaman terisi (draf, alasan per skor di docs/ALASAN_DREAD_AWAL.md).
- Hasil awal: 8 Tinggi, 14 Sedang, 2 Rendah. Tertinggi S-01 (8,4), I-04 (8,2), I-01/I-02 (8,0).
- Pola: semua ancaman Information Disclosure tinggi karena data on-chain publik & permanen.
- Status: menunggu ditinjau sendiri dan dikonsultasikan ke Pak Faldi (2.3.4).
- Langkah 4: daftar pertanyaan wawancara BAA disimpan di docs/PERTANYAAN_WAWANCARA_BAA.md
- Arahan (21 Okt 2026): penguji membolehkan penelitian tetap jalan bila BAA belum bisa memberi data (disesuaikan, masuk keterbatasan); Pak Faldi membebaskan penentuan skor DREAD, disesuaikan oleh peneliti.
- SESI 4 SELESAI: DFD, 24 ancaman terpetakan, DREAD awal terisi, pertanyaan BAA siap. Berikutnya Sesi 5 (uji serangan v1).

## Sesi 5 (22 Okt 2026)
- Attack_S: 6 passed. S1 v1 BERHASIL (klon kontrak lolos verify). S2, S3, S6 v2 DITOLAK (cek registry/ISSUER_ROLE). S4 v1 & v2 DITOLAK (verify cek alamat holder). S5 v2 RISIKO SISA: klon + registry palsu lolos di dirinya sendiri -> verifier wajib pakai alamat resmi kampus.
- Attack_T: 5 passed. T1 v1 BERHASIL (reentrancy: _safeMint sebelum commitmentIssued dicatat -> 1 commitment jadi 2 token; asumsi issuer = contract wallet). T2 v2 DITOLAK (ReentrancyGuard + CEI). T3 v1 BERHASIL (updateRecord ubah commitment/URI tanpa event). T4 v2 DITOLAK (tidak ada fungsi ubah). T5 v2 DITOLAK (commitment yang dicabut tidak bisa terbit ulang).
- SESI 5 SELESAI.
- PR BRAINSTORMING (sebelum semhas): kenapa T1 berhasil tapi T2 tidak; kenapa S5 jadi risiko sisa; kenapa hash tanpa salt tidak cukup.

## Sesi 6 (22 Okt 2026)
- Attack_R: 2 passed. R1 v1 RISIKO SISA (revoke/updateRecord/reissue tanpa event, tak bisa diaudit). R2 v2 KONTROL BERFUNGSI (semua aksi penting ada event + pelaku).
- Attack_I: 3 passed. I1 v1 BERHASIL (hash tanpa salt dibongkar dalam 1.165 dari 80.400 tebakan). I2 v2 DITOLAK (salt 32 byte). I3 lulus (calldata tanpa data akademik mentah).
- Inspeksi storage Anvil: commitment dikirim = dibaca dari storage (0x7d159f37...6b861129). "private" di Solidity bukan berarti rahasia.
- SESI 6 SELESAI.

## Sesi 7 (22 Okt 2026)
- Attack_D: 2 passed. D1 v1: revokeMany ~25.000 gas/token; N=100/500/1000 muat, N=1500 ~30,5 jt gas DOS (lewat batas 30 jt). Titik gagal ~1.190 token. D2 v2 DITOLAK: maks 50/tx, 120 token dalam 3 tx, gas maks ~516.638.
- Attack_E: 5 passed. E1, E2, E3 (v1 & v2) DITOLAK. E4 v1 RISIKO SISA: kunci owner bocor = ambil alih penuh. E5 v2 RISIKO SISA: kunci issuer bocor, dampak dibatasi karena accreditor bisa memutus issuer.
- Uji negatif on-chain (Anvil, akun terpisah): 24/24 SESUAI, 0 tidak sesuai (data/uji_negatif_31337.csv).
- Gas Anvil (resmi, n=10, run 1 & 2 identik): mint v1 193.184 vs v2 248.166 (+28,46%); revoke v1 48.130 vs v2 33.581 (-30,23%); verify v1 29.027 vs v2 34.620 (+19,27%). Simpangan baku 0-5,8 gas (deterministik; beda kecil karena byte nol/non-nol di calldata).
- Gas Foundry (pembanding, gas eksekusi tanpa biaya dasar 21.000): pola persen sama.
- Mitigasi tidak selalu menambah biaya: revoke v2 lebih murah karena v1 menulis ke slot kosong, v2 mengubah slot yang sudah terisi.
- SESI 7 SELESAI.

## Sesi 8 (28 Okt 2026) - Bagian A: DREAD setelah uji & setelah mitigasi
- Skor _uji (hasil tes v1) dan _mitigasi (risiko sisa v2) + rekomendasi_mitigasi terisi untuk 24 ancaman; alasan di docs/ALASAN_DREAD_UJI_MITIGASI.md.
- Ringkasan: awal 8 Tinggi/14 Sedang/2 Rendah (rata2 6,17) -> uji 7/15/2 (6,11) -> mitigasi 1/10/13 (3,90). Rata-rata risiko turun ~36%.
- Penurunan terbesar: T-02 (6,4), I-01 (6,0), I-04 (5,0), T-01 & R-01 (4,4), D-01 (4,2).
- Risiko sisa (tidak turun): I-03 keterkaitan alamat holder publik (7,8 Tinggi, sifat blockchain publik); E-02 transfer SBT (5,4, kontrol sudah ada sejak v1).
- Tabel akhir proposal 2.3.8: data/model_ancaman_akhir.csv.
- Bagian B (28 Okt 2026): 4 akun Sepolia dibuat dengan cast wallet new, kunci langsung ke .env (chmod 600, ada di .gitignore). Alamat di alamat_sepolia.txt.
  Admin 0x2667E67E60D8c58E72EBfB8951662e3996E6C270 | Accreditor 0xcc26f10eC7b2c95c26C7235A718dD72Bde8a036C | Issuer 0x68861A91D291410b893bEc6ac56cf5D578BdF979 | Attacker 0x7CaD603E40d16091Ba3f55af9Da3329d20b218e9
- Holder (MetaMask): 0xC4C24Ca92B6eDB4cae16ee35627158bbAaBf7894

## Sesi 8 Bagian B (28 Okt 2026, 13.58 WITA)
- 5 akun Sepolia siap (Admin, Accreditor, Issuer, Holder MetaMask, Attacker); alamat di alamat_sepolia.txt
- Infura RPC tersambung: chain-id 11155111 (Sepolia)
- API key Etherscan valid (Etherscan API V2, chainid 11155111)
- Semua kunci disimpan di .env (chmod 600, tidak di-commit)
- Menunggu: SepoliaETH ke Admin 0x2667E67E60D8c58E72EBfB8951662e3996E6C270 (dari Pak Faldi)

## Sesi 8 SELESAI (2 Nov 2026)
- SepoliaETH dari Pak Faldi masuk ke Admin: 1.000000000000000000 ETH

## Sesi 9 - Slither (2 Nov 2026)
- Versi: slither 0.11.6, solc 0.8.24, forge 1.8.5 (dijalankan per file, --exclude-dependencies)
- V1: 6 temuan (Medium 1 reentrancy-no-eth, Low 2 reentrancy-benign, Low 2 reentrancy-events, Info 1 pragma)
- V2: 1 temuan (Info pragma) | IssuerRegistry: 1 temuan (Info pragma)
- Reentrancy hanya di V1, hilang di V2 -> konfirmasi Tampering & mitigasi CEI+ReentrancyGuard
- Tidak terdeteksi Slither: hash tanpa salt, metadata mutable, revoke tanpa event, loop tanpa batas (terbukti lewat uji manual Sesi 5-7)

## Sesi 9 - Mythril (2 Nov 2026)
- Versi: Mythril v0.24.8 (uv, Python 3.11 + setuptools<81), solc lokal 0.8.24, -t 2, execution-timeout 600s
- V1: 0 temuan SWC (07.32-07.42, berhenti di batas timeout) | V2: 0 temuan SWC (07.42-07.53, batas timeout)
- Catatan: reentrancy _safeMint di V1 (ditemukan Slither & terbukti uji manual) tidak terdeteksi Mythril -> keterbatasan analisis simbolik (path explosion OZ, butuh kontrak penerima jahat)
- Validasi alat: Mythril pada kontrak jebakan menemukan 4 isu (SWC-107 x2, SWC-114, SWC-115) -> alat berfungsi normal

## Sesi 9 - Echidna (2 Nov 2026) -> SESI 9 SELESAI
- Versi: Echidna 2.3.3 (x86_64), testLimit 100000, seqLen 50 (echidna.yaml)
- V1: 2 failed (record_immutable, unique_commitment), 3 passing (outsider_cannot_mint, soulbound, revoked_cannot_verify)
- V2: 6/6 passing (+ deaccredited_cannot_mint)
- Rekap tiga alat -> STRIDE: hasil/rekap_alat_stride.csv
- Kesimpulan: tiap alat punya titik buta; Slither tangkap reentrancy, Echidna tangkap celah logika, Mythril 0 temuan (timeout); celah lain hanya terbukti lewat uji manual -> mendukung pendekatan gabungan STRIDE + manual + otomatis
- Bukti urutan: unique_commitment dibobol via setReenter(true)+doMint -> 2 token 1 commitment (reentrancy, konfirmasi temuan Slither); record_immutable dibobol via doMint+doUpdate

## Sesi 10 - Deploy Sepolia (2 Nov 2026)
- Percobaan 1 gagal: tx deploy V1 OutOfGas (gas used 1.807.002) saat menyimpan bytecode; estimasi gas forge (multiplier default 130%) kurang. Tx lain belum terkirim, biaya hanya gas tx gagal.
- Percobaan 2: --gas-estimate-multiplier 200
- Percobaan 2 gagal: V1 OutOfGas lagi (batas 2.780.004).
- Diagnosis: cast estimate di node Sepolia -> V1 9.613.912 / REG 2.772.899 / V2 13.156.062 gas, sedangkan estimasi forge 1.8.5 (aturan lama) V1 1.390.002 / REG 421.553 / V2 1.889.927 (+-7x). Sepolia memakai aturan gas baru (biaya simpan kode lebih mahal) -> gas Anvil tidak setara biaya jaringan publik (catat sbg keterbatasan Bab IV).
- Percobaan 3: --gas-estimate-multiplier 800 (V2 +-15,1 juta < batas 16,7 juta gas per tx)
- Percobaan 3: tx 1-5 SUKSES (V1, REG, V2 terdeploy; grantRole x2). Tx 6 (kirim 0,01 ETH ke Accreditor, akun baru) gagal OutOfGas (batas 178.496). Estimasi node: transfer ke akun baru 207.391 gas (normal 21.000, +-10x).
- Tx sisa (2 transfer modal + registerIssuer) dikirim manual via cast send.
- Manual: modal Accreditor (gas 204.600), modal Issuer (gas 204.600), registerIssuer (gas 130.111) -> semua status 1
- Alamat Sepolia: V1=0x9adEE1e0B506538d651654F6DEF614008ff346CE REG=0x6b6693e93a6D643F19983ED84cD099F66A48e5e7 V2=0x1391f73af1Cc5C6da639fe969F3Be30e725773Ed
- Verifikasi Etherscan: V1, REG, V2 -> Pass - Verified (log: hasil/sepolia/verify.log)
- Latency percobaan 1 TIDAK VALID: now_ms() memakai 'date +%s%3N', tetapi date di Ubuntu baru (uutils/Rust) tidak menghormati %3N -> angka ms kacau/negatif. Data dipindah ke hasil/sepolia/latency_INVALID_percobaan1.csv. Perbaikan: now_ms() memakai $EPOCHREALTIME bash (common.sh.bak = asli).
- Latency percobaan 2 (VALID, jam EPOCHREALTIME): lihat hasil/sepolia/latency.log & data/latency_11155111_ringkasan.txt
- IPFS (Pinata, public): transkrip_sintetis_contoh.json.enc (953 B) CID=bafkreiflh26czthq2zsfyy4kzfaeeyxmiof5emun77bwuodte4ko2voiam; mint V2 ke Holder via terbitkan_dokumen.sh
- Verifier tanpa wallet (sbt-tool verifikasi, RPC publik publicnode tanpa API key, gateway Pinata /ipfs): token 21 V2
  - salt benar -> verify true, HASIL VALID (hasil/sepolia/verifikasi_valid.txt)
  - salt salah -> commitment beda, verify false, HASIL TIDAK VALID (hasil/sepolia/verifikasi_salt_salah.txt)
- Catatan: gateway harus format https://<gw>/ipfs (tanpa /ipfs -> HTTP 400)
## SESI 10 SELESAI (2 Nov 2026): deploy+verifikasi Etherscan, latency n=10, IPFS, verifier read-only

## Sesi 11 - Data (9 Nov 2026)
- Uji T-04 di Sepolia: dokumen asli VALID; dokumen dipalsukan (IPK 3,50->3,99) docHash berubah, verify false, TIDAK VALID (hasil/sepolia/T04_dok_*.txt)
- Koreksi label T-05 di model_ancaman_akhir.csv: 'temuan fuzzing' -> 'temuan telaah kode Sesi 2' (asli di .bak)
- Tabel korelasi 24 ancaman vs bukti uji: data/korelasi_stride_empiris.csv
- Korelasi diperbarui: T-05 terbukti uji (test_v1_reissue_twiceFromOldToken_createsTwoActiveTokens vs test_v2_..._reverts) -> 7 ancaman terkonfirmasi v1 & dimitigasi v2
- Gas Sepolia percobaan 1 berhenti di putaran 5: saldo Issuer habis (0,00999 -> 0,00092 ETH) karena tip default cast send besar. Perbaikan: Admin isi 0,1 ETH ke Issuer; tip diatur 0,001 gwei (tidak memengaruhi gasUsed).
- Gas Sepolia percobaan 2 gagal di mint v1 pertama: revert 'sudah terbit' (NIM 2311200001+ sudah dimint di percobaan 1; v1 menolak commitment ganda via commitmentIssued). Percobaan 3: NIM 2311300001+, alamat dummy 2001+.
- Gas Sepolia percobaan 3 berhenti setelah putaran 1 (skrip rapuh: set -e, data di folder sementara). Skrip ditulis ulang: retry 3x, timeout 300 s, tip 0,01 gwei, data mentah per tx di data/gas_sepolia_mentah.csv; NIM 2311400001+, alamat 3001+ (versi lama: scripts/gas_sepolia_v1.sh.bak).
- GAS SEPOLIA (percobaan 4, VALID, n=5, NIM 2311400001+): mint v1 810.735 / v2 1.042.060 (+28,53%); revoke v1 130.150 / v2 34.781 (-73,28%); verify v1 23.374 / v2 29.382 (+25,70%). Rasio Sepolia/Anvil: mint 4,2x (v1&v2), revoke v1 2,7x / v2 1,04x, verify 0,8x. Overhead mint v2 stabil (+28,46% Anvil vs +28,53% Sepolia). File: hasil/sepolia/perbandingan_gas_anvil_sepolia.csv
- Persiapan repo: git init (main); hasil/slither/semua.* diganti nama jadi INVALID_mode_project_0temuan.* + BACA_DULU.txt
