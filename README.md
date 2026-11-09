# Penelitian: Pemodelan Ancaman Sistem Transkrip Nilai Berbasis SBT Ethereum (STRIDE + DREAD)

Kode pendukung penelitian Tyo Daffa Sukardi (S1 Teknik Informatika UMKT). **Semua data sintetis.**
Jangan pernah memasukkan data mahasiswa asli ke blockchain atau IPFS.

## Peta proposal → file di project ini
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
| 2.3.7 | Gas mint/revoke/verify + % overhead, latensi ≥10× (mean ± std), Slither/Mythril/Echidna | `scripts/gas_anvil.sh`, `scripts/latency_sepolia.sh`, `data/` |
| 2.3.4 + 2.3.8 | DREAD awal → setelah uji → setelah mitigasi; tabel model ancaman akhir | `scripts/hitung_dread.sh` → `data/model_ancaman_akhir.csv` |

## Perintah inti
```bash
forge build
forge test                                   # 41 tes (termasuk fuzzing invarian v2, ±10 detik)
./scripts/rekap_serangan.sh                  # -> data/hasil_serangan.csv
# terminal lain: anvil --gas-limit 30000000
./scripts/deploy.sh                          # deploy dengan akun terpisah per peran
./scripts/uji_negatif_onchain.sh             # uji negatif S/E di jaringan -> data/uji_negatif_<chainId>.csv
./scripts/gas_anvil.sh                       # gas transaksi nyata -> data/gas_anvil.csv
node tools/sbt-tool.mjs siapkan data/transkrip_sintetis_contoh.json   # hash + salt + enkripsi untuk IPFS
./scripts/terbitkan_dokumen.sh keluaran/<file>.rahasia.json <CID>     # mint dokumen ke holder
node tools/sbt-tool.mjs verifikasi ...       # verifier read-only tanpa wallet
./scripts/latency_sepolia.sh                 # latensi (Sepolia)
./scripts/hitung_dread.sh                    # setelah skor DREAD diisi
```
Skema commitment: `docHash = keccak256(isi file)`, v2 `commitment = keccak256(abi.encode(salt, docHash))`,
v1 `commitment = keccak256(abi.encode(docHash))` (tanpa salt). File di IPFS dienkripsi AES-256-GCM;
salt + kunci dipegang holder (`keluaran/*.rahasia.json`, sudah masuk `.gitignore`).
Tes brute-force (I1/I2) memakai field berentropi rendah (NIM, IPK, SKS) sesuai Tabel 2.4 "brute-force hash data sintetis".

Prasyarat: Foundry, Node.js LTS (≥18), `openssl`, `python3`, GNU `date` (Linux/WSL).

## Yang SUDAH diverifikasi saat dibuat, dan yang BELUM
Sudah dijalankan di lingkungan pembuat (Foundry 1.5.1, solc 0.8.24, Node 22): `forge test` 41 lulus;
`deploy.sh`, `uji_negatif_onchain.sh` (24/24 sesuai harapan), `gas_anvil.sh`, `latency_sepolia.sh`,
`terbitkan_dokumen.sh`, dan `sbt-tool.mjs` (keccak dicocokkan dengan `cast keccak`; VALID/TIDAK VALID untuk
dokumen asli, diubah, salah holder, dicabut) terhadap **Anvil lokal**. Harness Echidna dijalankan lewat fuzzer
Foundry (v1: properti pecah sesuai harapan; v2: semua lulus, setelah satu bug `reissue` yang ditemukan fuzzer diperbaiki).

BELUM dijalankan: **Echidna asli, Slither, Mythril, Sepolia, verifikasi Etherscan, unggah IPFS sungguhan**.
Angka dan temuan untuk skripsi harus berasal dari proses yang kamu jalankan sendiri. Folder `data/` hanya berisi
template dan contoh transkrip sintetis.

## Keamanan
- Semua kunci privat = akun testnet khusus. Jangan dikirim ke siapa pun, jangan di-commit (`.env`, `keluaran/` sudah di `.gitignore`).
- Kunci Anvil di `scripts/akun.sh` adalah kunci publik bawaan Anvil, hanya untuk jaringan lokal.
