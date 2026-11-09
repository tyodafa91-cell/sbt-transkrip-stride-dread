#!/usr/bin/env bash
# Mengukur latensi (ms) mint, revoke, verify pada v2 di jaringan apa pun (mis. Sepolia). Min. 10 kali.
#   export RPC_URL="https://sepolia.infura.io/v3/<API_KEY_KAMU>"
#   (isi .env dulu: ISSUER_KEY dll. Kunci akun TESTNET khusus, JANGAN akun berisi uang asli)
#   set -a; source .env; set +a; export RPC_URL=$SEPOLIA_RPC_URL
#   RUNS=10 ./scripts/latency_sepolia.sh
# Prasyarat: sudah ./scripts/deploy.sh sehingga deployments/<chainId>.env ada.
# Mint & revoke = waktu dari kirim transaksi sampai receipt diterima (cast send menunggu 1 konfirmasi).
# Verify = waktu panggilan baca (eth_call), tanpa transaksi.
cd "$(dirname "$0")/.."
source scripts/common.sh
source scripts/akun.sh

: "${RPC_URL:?isi RPC_URL dulu}"
RUNS="${RUNS:-10}"
URI="ipfs://QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG"
CHAIN=$(cast chain-id --rpc-url "$RPC_URL")
akun_siapkan "$CHAIN"
[ -f "deployments/$CHAIN.env" ] || { echo "deployments/$CHAIN.env belum ada. Jalankan ./scripts/deploy.sh dulu."; exit 1; }
# shellcheck disable=SC1090
source "deployments/$CHAIN.env"
ZERO=0x0000000000000000000000000000000000000000000000000000000000000000

CSV="data/latency_$CHAIN.csv"
echo "operasi,run,ms" > "$CSV"
M=(); R=(); V=()
for i in $(seq 1 "$RUNS"); do
  TO=$(dummy_addr "$i"); NIM=$((2311100000 + i))
  C=$(commit_v2 "$(random_salt)" "$NIM" 345 144)

  T0=$(now_ms)
  cast send "$V2" "mint(address,bytes32,string)" "$TO" "$C" "$URI" --rpc-url "$RPC_URL" --private-key "$ISSUER_KEY" >/dev/null
  T1=$(now_ms); M+=($((T1 - T0))); echo "mint,$i,$((T1 - T0))" >> "$CSV"

  ID=$(cast call "$V2" "nextId()(uint256)" --rpc-url "$RPC_URL")

  T0=$(now_ms)
  cast call "$V2" "verify(uint256,address,bytes32)(bool)" "$ID" "$TO" "$C" --rpc-url "$RPC_URL" >/dev/null
  T1=$(now_ms); V+=($((T1 - T0))); echo "verify,$i,$((T1 - T0))" >> "$CSV"

  T0=$(now_ms)
  cast send "$V2" "revoke(uint256,bytes32)" "$ID" "$ZERO" --rpc-url "$RPC_URL" --private-key "$ISSUER_KEY" >/dev/null
  T1=$(now_ms); R+=($((T1 - T0))); echo "revoke,$i,$((T1 - T0))" >> "$CSV"
  echo "run $i/$RUNS: mint=${M[-1]}ms verify=${V[-1]}ms revoke=${R[-1]}ms"
done
echo
echo "== Ringkasan latensi (ms), n=$RUNS =="
for op in mint verify revoke; do
  read -r MN SD N <<<"$(grep "^$op," "$CSV" | cut -d, -f3 | mean_std)"
  echo "$op: rata-rata=$MN  simpangan_baku=$SD  n=$N"
done | tee "data/latency_${CHAIN}_ringkasan.txt"
echo "Data mentah: $CSV"
