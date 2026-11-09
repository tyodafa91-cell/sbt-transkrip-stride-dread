# Penelitian: Pemodelan Ancaman Sistem Transkrip Nilai Berbasis SBT Ethereum (STRIDE + DREAD)

Kode dan data penelitian Tyo Daffa Sukardi (S1 Teknik Informatika UMKT). **Semua data sintetis.**
Jangan pernah memasukkan data mahasiswa asli ke blockchain atau IPFS.

Catatan kerja per sesi (19 Oktober sampai 9 November 2026), termasuk percobaan yang gagal, ada di `catatan.md`.

## Status eksperimen
| Bagian | Hasil | File |
|---|---|---|
| DFD | 4 entitas eksternal, 5 proses, 2 penyimpanan data (D1, D2), 16 aliran data, 1 trust boundary | `docs/gambar/DFD_SBT_Transkrip.drawio.png`, `docs/gambar/DFD_SBT_Transkrip_v2.drawio` |
| STRIDE | 24 ancaman pada 7 komponen (S 6, T 6, R 1, I 4, D 3, E 4) | `data/dread_penilaian.csv` |
| DREAD | Awal 8 Tinggi / 14 Sedang / 2 Rendah (rata-rata 6,18); setelah uji 7/15/2 (6,11); setelah mitigasi 1/10/13 (3,90) | `data/dread_hasil.csv`, `docs/ALASAN_DREAD_*.md`, `docs/RUBRIK_DREAD.md` |
| Model ancaman akhir dan korelasi | 20 dari 24 ancaman punya bukti uji; 7 terbukti di v1 dan tertutup di v2 | `data/model_ancaman_akhir.csv`, `data/korelasi_stride_empiris.csv` |
| `forge test` | 36 lulus (23 skenario serangan, 11 fungsional, 1 gas, 1 kelompok invarian) | `test/` |
| Uji negatif Anvil | 24/24 sesuai harapan | `data/uji_negatif_31337.csv` |
| Slither 0.11.6 | v1: 6 temuan (1 Medium, 4 Low, 1 Info); v2: 1 Info; IssuerRegistry: 1 Info | `hasil/slither/` |
| Mythril 0.24.8 | 0 SWC di v1 dan v2 (berhenti di batas waktu 600 s); kontrak jebakan: SWC-107 x2, SWC-114, SWC-115 | `hasil/mythril/` |
| Echidna 2.3.3 | v1: 2 dari 5 properti dilanggar; v2: 6/6 lulus | `hasil/echidna/` |
| Rekap alat ke STRIDE | Slither, Mythril, Echidna | `hasil/rekap_alat_stride.csv` |
| Gas Anvil (n = 10) | v2 vs v1: mint +28,46%, revoke -30,23%, verify +19,27% | `data/gas_anvil.csv` |
| Gas Sepolia (n = 5) | v2 vs v1: mint +28,53%, revoke -73,28%, verify +25,70% | `data/gas_sepolia.csv`, `data/gas_sepolia_mentah.csv` |
| Latency v2 Sepolia (n = 10) | mint 12.622 ± 4.103 ms, verify 2.019 ± 47 ms, revoke 9.514 ± 4.574 ms | `data/latency_11155111.csv` |
| Deploy dan verifikasi Etherscan | V1, IssuerRegistry, V2: Pass - Verified | `hasil/sepolia/deploy.log`, `hasil/sepolia/verify.log` |
| IPFS dan verifier tanpa wallet | Token 21 (v2): salt benar VALID, salt salah TIDAK VALID, dokumen dipalsukan (uji T-04) TIDAK VALID | `hasil/sepolia/*.txt` |

Belum dilakukan: wawancara BAA (dicatat sebagai keterbatasan).

## Kontrak di Sepolia (chain-id 11155111)
| Kontrak | Alamat |
|---|---|
| SBTTranskripV1 (baseline, sengaja rentan) | [0x9adEE1e0B506538d651654F6DEF614008ff346CE](https://sepolia.etherscan.io/address/0x9adEE1e0B506538d651654F6DEF614008ff346CE#code) |
| IssuerRegistry | [0x6b6693e93a6D643F19983ED84cD099F66A48e5e7](https://sepolia.etherscan.io/address/0x6b6693e93a6D643F19983ED84cD099F66A48e5e7#code) |
| SBTTranskripV2 (mitigasi) | [0x1391f73af1Cc5C6da639fe969F3Be30e725773Ed](https://sepolia.etherscan.io/address/0x1391f73af1Cc5C6da639fe969F3Be30e725773Ed#code) |

Alamat akun per peran ada di `alamat_sepolia.txt`.

## Peta proposal ke file
| Bagian proposal | Isi | File |
|---|---|---|
| 2.1 tujuh komponen | K1 kontrak SBT, K2 IssuerRegistry, K3 issuance, K4 verifikasi, K5 wallet holder, K6 off-chain, K7 jaringan | `data/dread_penilaian.csv` (kolom `komponen`) |
| Tabel 2.1 | Struktur transkrip (field 1–10 off-chain; 11–12 on-chain) | `data/transkrip_sintetis_contoh.json`, `src/v2/SBTTranskripV2.sol` (`Record`) |
| Tabel 2.2 no. 1 | SBT ERC-5192, Solidity 0.8.24, 4 fungsi transfer/approve selalu revert, v1 & v2 | `src/v1/`, `src/v2/`, `src/common/SoulboundBase.sol` |
| Tabel 2.2 no. 2 | IssuerRegistry dengan peran Accreditor | `src/IssuerRegistry.sol` (`registerIssuer`, `revokeIssuer`) |
| Tabel 2.2 no. 3 | Foundry, Node.js LTS, OpenZeppelin | `foundry.toml`, `lib/` (OZ 5.4.0), `tools/sbt-tool.mjs` |
| Tabel 2.2 no. 4–5 | Slither, Mythril, Echidna, skrip serangan + kontrak attacker | `slither.config.json`, `mythril.json`, `echidna.yaml`, `test/echidna/`, `test/Attack_*`, `test/mocks/` |
| Tabel 2.2 no. 6 | Akun terpisah Accreditor, Issuer, Holder, Verifier, Attacker | `script/DeployAll.s.sol`, `scripts/akun.sh`, `.env.example` |
| Tabel 2.2 no. 7–8 | Infura (Sepolia), Etherscan API | `scripts/deploy.sh` (`VERIFY=1`) |
| Tabel 2.2 no. 9 | IPFS + verifikasi read-only via RPC publik | `tools/sbt-tool.mjs` (`siapkan`, `verifikasi`), `scripts/terbitkan_dokumen.sh` |
| Tabel 2.2 no. 11 | Rubrik DREAD tertulis 1–10 | `docs/RUBRIK_DREAD.md` |
| 2.3.2 kebutuhan | daftar penerbit, batasi penerbitan, non-transferable, verifikasi tanpa wallet, cabut dengan event, salted hash off-chain, **terbit ulang bila dompet hilang** | `registerIssuer`, `ISSUER_ROLE`+registry, `SoulboundBase`, `verify`+`sbt-tool`, `Revoked`, `commitment`, `reissue` |
| 2.3.3 spesifikasi | `registerIssuer()`, `mint()`, `revoke()`, `verify()`, `tokenURI()`, `locked()` | v2 + registry |
| 2.3.5 | Kelemahan v1 dan mitigasi v2 | komentar di atas tiap kontrak |
| Tabel 2.4 (S–E) | Skenario serangan | `test/Attack_*.t.sol` (Anvil/Foundry), `scripts/uji_negatif_onchain.sh` (Anvil/Sepolia) |
| 2.3.7 | Gas mint/revoke/verify + % overhead, latensi ≥10× (mean ± std), Slither/Mythril/Echidna | `scripts/gas_anvil.sh`, `scripts/gas_sepolia.sh`, `scripts/latency_sepolia.sh`, `data/`, `hasil/` |
| 2.3.4 + 2.3.8 | DREAD awal → setelah uji → setelah mitigasi; tabel model ancaman akhir; korelasi | `scripts/hitung_dread.sh` → `data/model_ancaman_akhir.csv`, `data/korelasi_stride_empiris.csv` |

## Perintah inti
```bash
forge build
forge test                                   # 36 tes (Foundry 1.8.5 menghitung 6 invarian sebagai satu)
./scripts/rekap_serangan.sh                  # rekap hasil skenario serangan
# terminal lain: anvil --gas-limit 30000000
./scripts/deploy.sh                          # deploy dengan akun terpisah per peran
./scripts/uji_negatif_onchain.sh             # uji negatif S/E -> data/uji_negatif_<chainId>.csv
./scripts/gas_anvil.sh                       # gas transaksi nyata di Anvil -> data/gas_anvil.csv
RPC_URL=$SEPOLIA_RPC_URL RUNS=5 ./scripts/gas_sepolia.sh   # gas di Sepolia -> data/gas_sepolia*.csv
node tools/sbt-tool.mjs siapkan data/transkrip_sintetis_contoh.json   # hash + salt + enkripsi untuk IPFS
./scripts/terbitkan_dokumen.sh keluaran/<file>.rahasia.json <CID>     # mint dokumen ke holder
node tools/sbt-tool.mjs verifikasi ...       # verifier read-only tanpa wallet
RUNS=10 ./scripts/latency_sepolia.sh         # latensi (Sepolia)
./scripts/hitung_dread.sh                    # hitung rata-rata dan tingkat DREAD
```
Skema commitment: `docHash = keccak256(isi file)`, v2 `commitment = keccak256(abi.encode(salt, docHash))`,
v1 `commitment = keccak256(abi.encode(docHash))` (tanpa salt). File di IPFS dienkripsi AES-256-GCM;
salt + kunci dipegang holder (`keluaran/*.rahasia.json`, sudah masuk `.gitignore`).
Tes brute-force (I1/I2) memakai field berentropi rendah (NIM, IPK, SKS) sesuai Tabel 2.4 "brute-force hash data sintetis".

## Lingkungan yang dipakai
Ubuntu (WSL) di Windows; Foundry 1.8.5; solc 0.8.24 (evm cancun, optimizer 200); OpenZeppelin 5.4.0;
Node.js 24.22.0; Slither 0.11.6; Mythril 0.24.8 (Python 3.11); Echidna 2.3.3 (x86_64).

Prasyarat: Foundry, Node.js LTS (≥18), `openssl`, `python3`, bash 5+ (Linux/WSL).

## Catatan membaca hasil
- Gas Anvil dan gas Sepolia tidak setara sebagai biaya. Sepolia sudah memakai aturan gas upgrade Glamsterdam
  (EIP-8037, biaya pembuatan state baru lebih mahal), sedangkan Anvil/forge 1.8.5 masih memakai aturan lama.
  Yang dibandingkan adalah selisih v2 terhadap v1 di jaringan yang sama.
- `hasil/slither/INVALID_mode_project_0temuan.*` tidak dipakai (lihat `hasil/slither/BACA_DULU.txt`).
  Hasil Slither yang dipakai adalah analisis per file.
- `hasil/sepolia/latency_INVALID_percobaan1.csv` tidak dipakai (masalah format waktu `date`, lihat `catatan.md`).

## Keamanan
- Semua kunci privat = akun testnet khusus. Jangan dikirim ke siapa pun, jangan di-commit (`.env`, `keluaran/` sudah di `.gitignore`).
- Kunci Anvil di `scripts/akun.sh` adalah kunci publik bawaan Anvil, hanya untuk jaringan lokal.
