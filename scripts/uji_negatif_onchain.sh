#!/usr/bin/env bash
# Uji negatif di jaringan nyata (Anvil atau Sepolia) dengan akun terpisah, TANPA biaya gas untuk penyerang:
# setiap percobaan dijalankan sebagai simulasi eth_call (`cast call --from <akun>`). Yang membayar gas hanya
# satu transaksi mint oleh Issuer untuk menyiapkan token milik Holder.
#   Anvil  : ./scripts/uji_negatif_onchain.sh
#   Sepolia: set -a; source .env; set +a; RPC_URL=$SEPOLIA_RPC_URL ./scripts/uji_negatif_onchain.sh
# Keluaran: data/uji_negatif_<chainId>.csv
cd "$(dirname "$0")/.."
set -uo pipefail
source scripts/common.sh
source scripts/akun.sh
set +e   # percobaan yang revert memang diharapkan; jangan hentikan skrip
RPC="${RPC_URL:-http://127.0.0.1:8545}"
CHAIN=$(cast chain-id --rpc-url "$RPC")
akun_siapkan "$CHAIN"
# shellcheck disable=SC1090
source "deployments/$CHAIN.env"
H="$HOLDER_ADDRESS"; A="$ATTACKER_ADDRESS"
ISSUER_ROLE=$(cast keccak "ISSUER_ROLE")
ZERO=0x0000000000000000000000000000000000000000000000000000000000000000
CSV="data/uji_negatif_$CHAIN.csv"
echo "versi,kategori,pelaku,percobaan,harapan,hasil,status,pesan" > "$CSV"

coba() { # versi kategori pelaku percobaan harapan(REVERT|true|false) alamat signature args...
  local ver=$1 kat=$2 pel=$3 desc=$4 hrp=$5 to=$6 sig=$7; shift 7
  local from; case $pel in holder) from=$H;; attacker) from=$A;; issuer) from=$ISSUER;; *) from=$A;; esac
  local out rc hasil status
  out=$(cast call "$to" "$sig" "$@" --from "$from" --rpc-url "$RPC" 2>&1); rc=$?
  if [ $rc -ne 0 ]; then hasil=REVERT; else hasil=$(echo "$out" | tail -1); fi
  [ "$hasil" = "$hrp" ] && status=SESUAI || status=TIDAK_SESUAI
  local msg; msg=$(echo "$out" | grep -o 'custom error [^,]*\|revert[^"]*\|[A-Za-z]*Unauthorized[A-Za-z]*\|Soulbound[A-Za-z]*\|^true$\|^false$' | head -1 | tr ',' ';')
  echo "$ver,$kat,$pel,\"$desc\",$hrp,$hasil,$status,\"$msg\"" >> "$CSV"
  printf '%-3s %s %-8s %-55s -> %-6s %s\n' "$ver" "$kat" "$pel" "$desc" "$hasil" "$status"
}

for VER in v1 v2; do
  if [ $VER = v1 ]; then T=$V1; C=$(commit_v1 $((2311100000 + RANDOM)) 345 144); else T=$V2; C=$(commit_v2 "$(random_salt)" $((2311100000 + RANDOM)) 345 144); fi
  cast send "$T" "mint(address,bytes32,string)" "$H" "$C" "ipfs://contoh" --rpc-url "$RPC" --private-key "$ISSUER_KEY" >/dev/null
  ID=$(cast call "$T" "nextId()(uint256)" --rpc-url "$RPC")
  echo "== $VER: token #$ID milik holder $H =="
  coba $VER S attacker "verify() dgn alamat penyerang sebagai pemegang"   false  "$T" "verify(uint256,address,bytes32)(bool)" "$ID" "$A" "$C"
  coba $VER S holder   "verify() dgn alamat holder yang benar"            true   "$T" "verify(uint256,address,bytes32)(bool)" "$ID" "$H" "$C"
  coba $VER E attacker "mint() tanpa peran"                               REVERT "$T" "mint(address,bytes32,string)" "$A" 0x$(openssl rand -hex 32) "x"
  if [ $VER = v1 ]; then
    coba $VER E attacker "revoke() tanpa peran"                           REVERT "$T" "revoke(uint256)" "$ID"
    coba $VER E attacker "transferOwnership() ambil alih"                  REVERT "$T" "transferOwnership(address)" "$A"
    coba $VER E attacker "reissue() ke alamat penyerang"                   REVERT "$T" "reissue(uint256,address)" "$ID" "$A"
  else
    coba $VER E attacker "revoke() tanpa peran"                           REVERT "$T" "revoke(uint256,bytes32)" "$ID" "$ZERO"
    coba $VER E attacker "reissue() ke alamat penyerang"                   REVERT "$T" "reissue(uint256,address,bytes32)" "$ID" "$A" "$ZERO"
    coba $VER E attacker "grantRole(ISSUER_ROLE) ke diri sendiri"          REVERT "$T" "grantRole(bytes32,address)" "$ISSUER_ROLE" "$A"
    coba $VER E attacker "registerIssuer() diri sendiri di registry"       REVERT "$REG" "registerIssuer(address)" "$A"
    coba $VER E issuer   "issuer daftarkan dirinya lagi / naikkan hak"     REVERT "$REG" "registerIssuer(address)" "$ISSUER"
  fi
  coba $VER E holder   "transferFrom() oleh holder sendiri"               REVERT "$T" "transferFrom(address,address,uint256)" "$H" "$A" "$ID"
  coba $VER E holder   "safeTransferFrom(a,b,id)"                         REVERT "$T" "safeTransferFrom(address,address,uint256)" "$H" "$A" "$ID"
  coba $VER E holder   "safeTransferFrom(a,b,id,data)"                    REVERT "$T" "safeTransferFrom(address,address,uint256,bytes)" "$H" "$A" "$ID" 0x
  coba $VER E holder   "approve()"                                        REVERT "$T" "approve(address,uint256)" "$A" "$ID"
  coba $VER E holder   "setApprovalForAll()"                              REVERT "$T" "setApprovalForAll(address,bool)" "$A" true
done
echo
grep -c ",SESUAI," "$CSV" | xargs echo "SESUAI harapan:"; grep -c "TIDAK_SESUAI" "$CSV" | xargs echo "TIDAK sesuai :"
echo "Disimpan: $CSV"
