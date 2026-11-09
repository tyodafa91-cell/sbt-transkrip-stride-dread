#!/usr/bin/env bash
# Deploy v1 + IssuerRegistry + v2 dengan akun terpisah per peran.
#   Anvil  : ./scripts/deploy.sh
#   Sepolia: set -a; source .env; set +a; RPC_URL=$SEPOLIA_RPC_URL VERIFY=1 ./scripts/deploy.sh
#            (VERIFY=1 = sekalian verifikasi source code di Etherscan, butuh ETHERSCAN_API_KEY)
cd "$(dirname "$0")/.."
set -euo pipefail
source scripts/akun.sh
RPC="${RPC_URL:-http://127.0.0.1:8545}"
CHAIN=$(cast chain-id --rpc-url "$RPC")
akun_siapkan "$CHAIN"
EXTRA=()
if [ "${VERIFY:-0}" = "1" ]; then
  : "${ETHERSCAN_API_KEY:?isi ETHERSCAN_API_KEY}"
  EXTRA=(--verify --etherscan-api-key "$ETHERSCAN_API_KEY")
fi
[ "$CHAIN" = "31337" ] || EXTRA+=(--slow)
forge script script/DeployAll.s.sol --rpc-url "$RPC" --broadcast "${EXTRA[@]}"
echo
cat "deployments/$CHAIN.env"
