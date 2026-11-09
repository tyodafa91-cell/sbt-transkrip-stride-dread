#!/usr/bin/env bash
# Gas kasar dari Foundry (10 kali). Untuk angka resmi di laporan, pakai scripts/gas_anvil.sh.
cd "$(dirname "$0")/.."
source scripts/common.sh
OUT=$(forge test --match-contract GasBench -vv 2>&1)
echo "operasi,versi,n,rata2_gas,simpangan_baku" > data/gas_forge.csv
for op in mint verify revoke; do
  for v in v1 v2; do
    read -r M S N <<<"$(echo "$OUT" | grep "GAS|$op|$v|" | sed 's/^ *//' | cut -d'|' -f4 | tail -n +2 | mean_std)"
    echo "$op,$v,$N,$M,$S" >> data/gas_forge.csv
  done
done
pretty_csv data/gas_forge.csv
echo
echo "Catatan: run ke-1 (pemanasan, slot storage masih 'dingin') dibuang; n=10 dihitung dari run ke-2 dst."
