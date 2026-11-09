#!/usr/bin/env bash
# Menjalankan semua tes serangan (S,T,R,I,D,E) lalu merangkum hasilnya ke data/hasil_serangan.csv
cd "$(dirname "$0")/.."
OUT=$(forge test --match-path 'test/Attack_*' -vv 2>&1) || { echo "$OUT" | tail -40; echo "ADA TES GAGAL. Periksa dulu."; exit 1; }
echo "id,versi,deskripsi,status" > data/hasil_serangan.csv
echo "$OUT" | grep 'HASIL|' | sed 's/^ *//' | sort -s -t'|' -k2,2 | awk -F'|' '{printf "%s,%s,\"%s\",%s\n", $2, $3, $4, $5}' >> data/hasil_serangan.csv
echo "$OUT" | grep -E '^Ran |Suite result' | head -20
echo
source scripts/common.sh; pretty_csv data/hasil_serangan.csv | cut -c1-190
echo
echo "Disimpan: data/hasil_serangan.csv"
