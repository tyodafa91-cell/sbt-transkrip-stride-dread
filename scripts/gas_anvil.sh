#!/usr/bin/env bash
# Mengukur gas TRANSAKSI NYATA (receipt) untuk mint, revoke, verify di v1 dan v2.
# Pakai Anvil lokal (anvil di terminal lain) atau RPC lain lewat RPC_URL.
#   RUNS=10 ./scripts/gas_anvil.sh
# Keluaran: data/gas_anvil.csv  (operasi, versi, n, rata-rata, simpangan_baku) + persen overhead
cd "$(dirname "$0")/.."
source scripts/common.sh
source scripts/akun.sh

RPC="${RPC_URL:-http://127.0.0.1:8545}"
RUNS="${RUNS:-10}"
URI="ipfs://QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG"

CHAIN=$(cast chain-id --rpc-url "$RPC")
akun_siapkan "$CHAIN"
PK="$ISSUER_KEY"          # mint/revoke dikirim oleh Issuer (v1: owner; v2: ISSUER_ROLE)
echo ">> chain-id $CHAIN, mendeploy kontrak ..."
forge script script/DeployAll.s.sol --rpc-url "$RPC" --broadcast -q >/dev/null
# shellcheck disable=SC1090
source "deployments/$CHAIN.env"
ME="$HOLDER_ADDRESS"      # verify = panggilan baca; pengirim bebas (di sini alamat holder)
echo ">> V1=$V1  V2=$V2"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
: > "$TMP/mint_v1"; : > "$TMP/revoke_v1"; : > "$TMP/verify_v1"
: > "$TMP/mint_v2"; : > "$TMP/revoke_v2"; : > "$TMP/verify_v2"

# i=0 = pemanasan (dibuang): transaksi pertama selalu lebih mahal karena slot storage baru (nextId 0->1 dst.)
rec() { if [ "$i" -gt 0 ]; then cat >> "$TMP/$1"; else cat > /dev/null; fi; }
for i in $(seq 0 "$RUNS"); do
  TO=$(dummy_addr "$((i + 1))"); NIM=$((2311100001 + i))
  C1=$(commit_v1 "$NIM" 345 144)
  C2=$(commit_v2 "$(random_salt)" "$NIM" 345 144)

  # ---- v1 ----
  OUT=$(cast send "$V1" "mint(address,bytes32,string)" "$TO" "$C1" "$URI" --rpc-url "$RPC" --private-key "$PK" --json)
  { hex2dec "$(echo "$OUT" | gas_used)"; echo; } | rec mint_v1
  ID=$(cast call "$V1" "nextId()(uint256)" --rpc-url "$RPC")
  # verify = panggilan baca; gas diperkirakan dengan eth_estimateGas (sudah termasuk 21.000 dasar)
  cast estimate "$V1" "verify(uint256,address,bytes32)(bool)" "$ID" "$TO" "$C1" --from "$ME" --rpc-url "$RPC" | rec verify_v1
  OUT=$(cast send "$V1" "revoke(uint256)" "$ID" --rpc-url "$RPC" --private-key "$PK" --json)
  { hex2dec "$(echo "$OUT" | gas_used)"; echo; } | rec revoke_v1

  # ---- v2 ----
  OUT=$(cast send "$V2" "mint(address,bytes32,string)" "$TO" "$C2" "$URI" --rpc-url "$RPC" --private-key "$PK" --json)
  { hex2dec "$(echo "$OUT" | gas_used)"; echo; } | rec mint_v2
  ID=$(cast call "$V2" "nextId()(uint256)" --rpc-url "$RPC")
  cast estimate "$V2" "verify(uint256,address,bytes32)(bool)" "$ID" "$TO" "$C2" --from "$ME" --rpc-url "$RPC" | rec verify_v2
  OUT=$(cast send "$V2" "revoke(uint256,bytes32)" "$ID" 0x0000000000000000000000000000000000000000000000000000000000000000 --rpc-url "$RPC" --private-key "$PK" --json)
  { hex2dec "$(echo "$OUT" | gas_used)"; echo; } | rec revoke_v2
done

CSV=data/gas_anvil.csv
echo "operasi,versi,n,rata2_gas,simpangan_baku" > "$CSV"
for op in mint revoke verify; do
  for v in v1 v2; do
    read -r M S N <<<"$(sed '/^$/d' "$TMP/${op}_$v" | mean_std)"
    echo "$op,$v,$N,$M,$S" >> "$CSV"
  done
done
echo
echo "== Hasil (gas rata-rata) =="
pretty_csv "$CSV"
echo
echo "== Overhead mitigasi v2 terhadap v1 =="
for op in mint revoke verify; do
  A=$(grep "^$op,v1," "$CSV" | cut -d, -f4); B=$(grep "^$op,v2," "$CSV" | cut -d, -f4)
  awk -v op="$op" -v a="$A" -v b="$B" 'BEGIN{printf "%-7s v1=%.0f v2=%.0f  selisih=%+.2f%%\n", op, a, b, (b-a)/a*100}'
done | tee data/gas_anvil_overhead.txt
echo
echo "Disimpan: $CSV"
