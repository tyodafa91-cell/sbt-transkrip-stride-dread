#!/usr/bin/env bash
# Di-source skrip lain. Menyiapkan akun per peran.
# - Di Anvil (chain-id 31337): kalau variabel belum diisi, pakai akun bawaan Anvil (KUNCI PUBLIK, hanya lokal).
# - Di Sepolia: WAJIB isi sendiri lewat .env (lihat .env.example). Tidak ada nilai bawaan.
akun_siapkan() {
  local chain="$1"
  if [ "$chain" = "31337" ]; then
    : "${PRIVATE_KEY:=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80}"    # Anvil #0 Admin
    : "${ACCREDITOR_KEY:=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d}" # Anvil #1 Accreditor
    : "${ISSUER_KEY:=0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a}"     # Anvil #2 Issuer
    : "${HOLDER_ADDRESS:=0x90F79bf6EB2c4f870365E785982E1f101E93b906}"                           # Anvil #3 Holder
    : "${ATTACKER_ADDRESS:=0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65}"                         # Anvil #4 Attacker
  fi
  : "${PRIVATE_KEY:?isi PRIVATE_KEY (Admin) di .env}"
  : "${ACCREDITOR_KEY:?isi ACCREDITOR_KEY di .env}"
  : "${ISSUER_KEY:?isi ISSUER_KEY di .env}"
  : "${HOLDER_ADDRESS:?isi HOLDER_ADDRESS di .env}"
  : "${ATTACKER_ADDRESS:?isi ATTACKER_ADDRESS di .env}"
  export PRIVATE_KEY ACCREDITOR_KEY ISSUER_KEY HOLDER_ADDRESS ATTACKER_ADDRESS
}
