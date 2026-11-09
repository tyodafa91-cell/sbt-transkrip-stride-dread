#!/usr/bin/env bash
# Menerbitkan SBT untuk satu dokumen transkrip SINTETIS yang sudah disiapkan sbt-tool.
#   1) node tools/sbt-tool.mjs siapkan data/transkrip_sintetis_contoh.json
#   2) unggah keluaran/transkrip_sintetis_contoh.json.enc ke IPFS -> dapat CID
#   3) ./scripts/terbitkan_dokumen.sh keluaran/transkrip_sintetis_contoh.json.rahasia.json <CID> [v2|v1]
# Token diterbitkan oleh ISSUER ke HOLDER_ADDRESS. Hasilnya: perintah verifikasi tanpa wallet.
cd "$(dirname "$0")/.."
set -euo pipefail
source scripts/akun.sh
RAHASIA="${1:?file .rahasia.json dari sbt-tool siapkan}"
CID="${2:?CID IPFS dari file .enc}"
VER="${3:-v2}"
RPC="${RPC_URL:-http://127.0.0.1:8545}"
CHAIN=$(cast chain-id --rpc-url "$RPC")
akun_siapkan "$CHAIN"
# shellcheck disable=SC1090
source "deployments/$CHAIN.env"
if [ "$VER" = "v1" ]; then ADDR="$V1"; KEY=commitment_v1_tanpa_salt; else ADDR="$V2"; KEY=commitment_v2; fi
C=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))[sys.argv[2]])" "$RAHASIA" "$KEY")
SALT=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['salt'])" "$RAHASIA")
KUNCI=$(python3 -c "import json,sys;print(json.load(open(sys.argv[1]))['kunci_enkripsi'])" "$RAHASIA")
echo ">> mint $VER ke holder $HOLDER_ADDRESS, commitment $C, URI ipfs://$CID"
cast send "$ADDR" "mint(address,bytes32,string)" "$HOLDER_ADDRESS" "$C" "ipfs://$CID" --rpc-url "$RPC" --private-key "$ISSUER_KEY" >/dev/null
ID=$(cast call "$ADDR" "nextId()(uint256)" --rpc-url "$RPC")
echo ">> token id: $ID"
EXTRA="--salt $SALT"; [ "$VER" = "v1" ] && EXTRA="--v1"
echo
echo "Verifikasi tanpa wallet (unduh dari IPFS lalu dekripsi):"
echo "  node tools/sbt-tool.mjs verifikasi --rpc \"$RPC\" --kontrak $ADDR --token $ID --holder $HOLDER_ADDRESS $EXTRA --key $KUNCI"
echo "Kalau gateway IPFS lambat, pakai file lokal: tambahkan  --enc ${RAHASIA%.rahasia.json}.enc"
