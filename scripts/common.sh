#!/usr/bin/env bash
# Fungsi bantu bersama. Di-source oleh skrip lain (jangan dijalankan langsung).
set -euo pipefail

# Konversi hex (0x...) ke desimal
hex2dec() { printf '%d' "$1"; }

# commitment tanpa garam (v1):  keccak256(abi.encode(nim, ipk100, sks))
commit_v1() { cast keccak "$(cast abi-encode 'f(uint64,uint16,uint16)' "$1" "$2" "$3")"; }

# commitment bergaram (v2):     keccak256(abi.encode(salt, nim, ipk100, sks))
commit_v2() { cast keccak "$(cast abi-encode 'f(bytes32,uint64,uint16,uint16)' "$1" "$2" "$3" "$4")"; }

# Salt acak 32 byte (WAJIB acak untuk data sungguhan; simpan di luar chain)
random_salt() { printf '0x%s' "$(openssl rand -hex 32)"; }

# Alamat dummy untuk "mahasiswa" (hanya untuk uji)
dummy_addr() { printf '0x%040x' $((0x20000 + $1)); }

# gasUsed dari keluaran JSON `cast send --json`
gas_used() { grep -o '"gasUsed":"[^"]*"' | head -1 | cut -d'"' -f4; }

# mean dan simpangan baku sampel dari angka yang dibaca di stdin (satu per baris)
mean_std() {
  awk '{x[NR]=$1; s+=$1} END {m=s/NR; for(i=1;i<=NR;i++){d=x[i]-m; v+=d*d}
       sd=(NR>1)?sqrt(v/(NR-1)):0; printf "%.2f %.2f %d\n", m, sd, NR}'
}

now_ms() { local t=${EPOCHREALTIME/[.,]/}; echo $(( t / 1000 )); }

# Cetak CSV sebagai tabel rapi (tanpa perlu perintah `column`)
pretty_csv() {
  awk -F, '{for(i=1;i<=NF;i++){a[NR,i]=$i; if(length($i)>w[i])w[i]=length($i)} nf=NF}
           END{for(r=1;r<=NR;r++){l="";for(i=1;i<=nf;i++) l=l sprintf("%-" (w[i]+2) "s",a[r,i]); print l}}' "$1"
}
