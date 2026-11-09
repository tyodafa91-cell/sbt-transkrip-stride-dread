#!/usr/bin/env bash
# Gas transaksi nyata (receipt) mint/revoke + estimasi verify, v1 vs v2, di Sepolia.
# Logika sama dengan gas_anvil.sh (putaran 0 = pemanasan dibuang), tetapi:
# tanpa deploy ulang, retry 3x per transaksi, timeout 300 s, data mentah disimpan per transaksi.
#   set -a; source .env; set +a; RPC_URL=$SEPOLIA_RPC_URL RUNS=5 ./scripts/gas_sepolia.sh
cd "$(dirname "$0")/.."
source scripts/common.sh
set +e +o pipefail
source scripts/akun.sh
RPC="${RPC_URL:?isi RPC_URL}"; RUNS="${RUNS:-5}"; PRIO="${PRIO:-10000000}"
NIM0="${NIM0:-2311400001}"; ADDR0="${ADDR0:-3001}"
URI="ipfs://QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG"
CHAIN=$(cast chain-id --rpc-url "$RPC"); akun_siapkan "$CHAIN"
PK="$ISSUER_KEY"; source "deployments/$CHAIN.env"; ME="$HOLDER_ADDRESS"
RAW=data/gas_sepolia_mentah.csv; [ -f "$RAW" ] || echo "putaran,operasi,versi,gas,nim,tujuan" > "$RAW"
echo ">> chain-id $CHAIN, V1=$V1 V2=$V2 (tanpa deploy ulang), NIM mulai $NIM0"
kirim() {  # kirim tx, cetak gasUsed (desimal) bila status sukses; retry 3x
  local out t
  for t in 1 2 3; do
    out=$(cast send "$@" --rpc-url "$RPC" --private-key "$PK" --json --priority-gas-price "$PRIO" --timeout 300 2>&1)
    if echo "$out" | grep -q '"status":"0x1"'; then hex2dec "$(echo "$out" | gas_used)"; return 0; fi
    echo "   ! gagal percobaan $t: $(echo "$out" | grep -oE '(message|status)":"[^"]{0,140}' | head -2 | tr '\n' ' ' | sed -E 's/0x[0-9a-fA-F]{64}/0x[64HEX]/g')" >&2
    sleep 8
  done; return 1
}
for i in $(seq 0 "$RUNS"); do
  TO=$(dummy_addr "$((i + ADDR0))"); NIM=$((NIM0 + i))
  C1=$(commit_v1 "$NIM" 345 144); C2=$(commit_v2 "$(random_salt)" "$NIM" 345 144)
  G=$(kirim "$V1" "mint(address,bytes32,string)" "$TO" "$C1" "$URI") || { echo "putaran $i: mint v1 gagal, lanjut"; continue; }
  echo "$i,mint,v1,$G,$NIM,$TO" >> "$RAW"
  ID=$(cast call "$V1" "nextId()(uint256)" --rpc-url "$RPC")
  G=$(cast estimate "$V1" "verify(uint256,address,bytes32)(bool)" "$ID" "$TO" "$C1" --from "$ME" --rpc-url "$RPC") && echo "$i,verify,v1,$G,$NIM,$TO" >> "$RAW"
  G=$(kirim "$V1" "revoke(uint256)" "$ID") && echo "$i,revoke,v1,$G,$NIM,$TO" >> "$RAW"
  G=$(kirim "$V2" "mint(address,bytes32,string)" "$TO" "$C2" "$URI") || { echo "putaran $i: mint v2 gagal, lanjut"; continue; }
  echo "$i,mint,v2,$G,$NIM,$TO" >> "$RAW"
  ID=$(cast call "$V2" "nextId()(uint256)" --rpc-url "$RPC")
  G=$(cast estimate "$V2" "verify(uint256,address,bytes32)(bool)" "$ID" "$TO" "$C2" --from "$ME" --rpc-url "$RPC") && echo "$i,verify,v2,$G,$NIM,$TO" >> "$RAW"
  G=$(kirim "$V2" "revoke(uint256,bytes32)" "$ID" 0x0000000000000000000000000000000000000000000000000000000000000000) && echo "$i,revoke,v2,$G,$NIM,$TO" >> "$RAW"
  echo "putaran $i/$RUNS selesai$( [ "$i" -eq 0 ] && echo ' (pemanasan, dibuang)')"
done
python3 - "$RAW" "$NIM0" << 'PY'
import csv,sys,statistics as st
raw,nim0=sys.argv[1],int(sys.argv[2])
rows=[r for r in csv.DictReader(open(raw)) if int(r['nim'])>=nim0 and int(r['putaran'])>0]
out=open('data/gas_sepolia.csv','w'); out.write('operasi,versi,n,rata2_gas,simpangan_baku\n')
m={}
for op in ['mint','revoke','verify']:
  for v in ['v1','v2']:
    g=[int(r['gas']) for r in rows if r['operasi']==op and r['versi']==v]
    if not g: continue
    m[(op,v)]=st.mean(g); sd=st.stdev(g) if len(g)>1 else 0
    out.write(f'{op},{v},{len(g)},{m[(op,v)]:.2f},{sd:.2f}\n')
out.close(); print('\n== Gas Sepolia (rata-rata) ==\n'+open('data/gas_sepolia.csv').read())
ov=open('data/gas_sepolia_overhead.txt','w')
for op in ['mint','revoke','verify']:
  if (op,'v1') in m and (op,'v2') in m:
    a,b=m[(op,'v1')],m[(op,'v2')]; s=f'{op:<7} v1={a:.0f} v2={b:.0f}  selisih={(b-a)/a*100:+.2f}%'; print(s); ov.write(s+'\n')
PY
