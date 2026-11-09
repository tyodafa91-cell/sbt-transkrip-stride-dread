# Sesi 8 — DRAF skor DREAD setelah uji (v1) dan setelah mitigasi (v2), plus rekomendasi mitigasi.
# Dasar: hasil tes Sesi 5–7 (Attack_S/T/R/I/D/E, Functional, uji_negatif_onchain) di laptop Tyok.
# Ini DRAF: ubah angka di tabel S kalau tidak setuju, lalu jalankan ulang.
import csv, os
os.chdir(os.path.dirname(os.path.abspath(__file__)) + "/..")
# id: (uji D,R,E,A,Di), (mitigasi D,R,E,A,Di), alasan_uji, alasan_mitigasi, rekomendasi
S = {
"S-01": ((8,10,8,9,8),(8,3,5,4,4),"Tes S1: klon kontrak bernama sama lolos verify() di v1 setiap kali dicoba (R naik ke 10).","S2, S3, S6 ditolak di v2; sisa risiko = S5 (klon + registry palsu) yang hanya berhasil bila verifier tidak memakai alamat resmi.","IssuerRegistry + verify() wajib cek issuer terdaftar; umumkan alamat kontrak resmi kampus (OWASP SC01)."),
"S-02": ((5,3,5,4,5),(5,3,5,4,4),"Tes S4: verify() dengan alamat mahasiswa yang benar = false di v1, jadi serangan tidak berguna (R turun).","Sama dengan v1; kontrol sudah ada sejak v1. Sisa: kesalahan input alamat oleh issuer.","Cocokkan alamat holder saat mint; perbaiki dengan revoke + reissue bila salah."),
"S-03": ((7,9,6,8,4),(7,4,6,4,4),"Tes S5: sistem tiruan lengkap selalu lolos di dirinya sendiri (R naik).","Risiko sisa: hanya berhasil bila verifier tidak memakai alamat resmi; dampak terbatas pada verifier yang lalai.","Verifier wajib memakai alamat kontrak & registry resmi (pin alamat); daftar alamat resmi di situs kampus."),
"S-04": ((9,7,3,10,3),(5,7,3,5,3),"Tes E4: kunci owner v1 (= issuer) bocor berarti pengambilalihan penuh.","Tes E5: di v2 kunci issuer bocor masih bisa menerbitkan, tetapi accreditor bisa memutus issuer sehingga dampak dibatasi.","Pisahkan peran Admin/Accreditor/Issuer; simpan kunci di hardware wallet/multisig; revokeIssuer cepat (OWASP SC01)."),
"S-05": ((5,5,4,1,3),(3,5,4,1,3),"Tidak diuji (analisis desain); skor awal ditinjau ulang, tetap.","Reissue ke alamat baru memutus token lama, dampak berkurang.","Reissue setelah verifikasi identitas off-chain oleh issuer; edukasi keamanan wallet holder."),
"T-01": ((6,10,5,4,5),(2,1,2,1,2),"Tes T1: reentrancy selalu menghasilkan 2 token dari 1 commitment di v1 (dengan asumsi issuer berupa contract wallet).","Tes T2: panggilan ulang ditolak ReentrancyGuard + urutan CEI.","Checks-effects-interactions + nonReentrant (SWC-107, OWASP SC05)."),
"T-02": ((8,10,5,9,7),(2,1,1,1,2),"Tes T3: commitment dan URI selalu bisa diubah setelah terbit tanpa event.","Tes T4: v2 tidak punya fungsi ubah record; isi tetap.","Hapus fungsi pengubah; koreksi hanya lewat revoke + reissue yang mengeluarkan event."),
"T-03": ((4,4,5,5,6),(3,3,4,3,6),"Tidak diuji (analisis desain); skor awal ditinjau ulang, tetap.","Fungsi sensitif dibatasi peran dan commitment bergaram, sehingga menyerobot transaksi tidak memberi keuntungan berarti.","Batasi fungsi sensitif dengan peran; jangan bergantung pada urutan transaksi (SWC-114)."),
"T-04": ((6,3,8,3,6),(5,2,6,3,4),"sbt-tool: dokumen yang diubah langsung TIDAK VALID karena tidak cocok dengan commitment (R turun).","Commitment bergaram + verifier read-only membuat pemalsuan dokumen makin sulit.","Verifier wajib mencocokkan dokumen dengan commitment lewat sbt-tool sebelum menerima transkrip."),
"T-05": ((6,10,4,4,3),(1,1,4,1,3),"Tes reissue: v1 menghasilkan 2 token aktif bila reissue dipanggil dua kali dari token lama.","currentTokenOf menolak reissue dari token lama (test_v2_reissue_twiceFromOldToken_reverts).","Lacak token terbaru (currentTokenOf); uji dengan fuzzing/invariant Echidna."),
"R-01": ((5,10,5,7,8),(2,1,5,2,3),"Tes R1: revoke/updateRecord/reissue v1 tidak mengeluarkan event, tidak bisa diaudit.","Tes R2: semua aksi penting v2 mengeluarkan event lengkap beserta pelakunya.","Emit event Issued/Revoked/Reissued/IssuerRegistered/IssuerRevoked untuk setiap aksi kritis."),
"I-01": ((6,10,9,9,10),(6,1,2,1,4),"Tes I1: hash tanpa salt dibongkar dalam 1.165 dari 80.400 tebakan; commitment terbaca dari storage Anvil.","Tes I2: dengan salt 32 byte, brute-force pada ruang tebakan yang sama gagal.","Salted commitment 32 byte dihitung off-chain (SWC-136)."),
"I-02": ((7,2,8,9,8),(7,1,3,2,3),"Tes I3: calldata v1 dan v2 tidak memuat data akademik mentah (R turun).","Hanya commitment yang dikirim on-chain; data mentah tetap off-chain terenkripsi.","Jangan kirim data mentah ke chain; simpan off-chain terenkripsi (SWC-136)."),
"I-03": ((4,10,9,7,9),(4,10,9,7,9),"Tidak diuji (analisis desain); event dan kepemilikan memang publik.","Risiko sisa: sifat blockchain publik tidak berubah oleh mitigasi kontrak.","Holder memakai alamat khusus kredensial; dicatat sebagai keterbatasan privasi."),
"I-04": ((7,9,9,9,7),(7,1,2,1,5),"Desain v1: metadata off-chain tanpa enkripsi bisa diunduh siapa pun yang tahu CID.","sbt-tool: dekripsi tanpa kunci gagal (AES-256-GCM).","Enkripsi metadata AES-256-GCM sebelum diunggah ke IPFS; kunci dipegang holder."),
"D-01": ((5,10,5,7,7),(2,1,5,2,3),"Tes D1: revokeMany v1 gagal di N = 1.500 (~30,5 juta gas, melewati batas blok); titik gagal ~1.190 token.","Tes D2: maksimal 50 token per transaksi; 120 token dicabut dalam 3 transaksi.","Batasi jumlah iterasi per transaksi (SWC-128, OWASP SC10)."),
"D-02": ((4,5,4,9,8),(4,4,4,6,8),"Belum diuji; latensi Sepolia diukur di Sesi 10. Skor awal ditinjau ulang, tetap.","Risiko sisa: verifikasi tetap bergantung pada RPC/gateway; berkurang bila memakai cadangan.","Sediakan beberapa endpoint RPC dan gateway IPFS cadangan."),
"D-03": ((5,5,2,1,8),(2,5,2,1,8),"Tes reissue: penerbitan ulang ke alamat baru bisa dilakukan.","Reissue v2 aman (token lama otomatis tidak berlaku), dampak kehilangan dompet berkurang.","Prosedur reissue dengan verifikasi identitas off-chain oleh issuer."),
"E-01": ((9,1,2,10,8),(9,1,1,10,6),"Tes E1: semua fungsi admin v1 revert untuk non-owner; serangan gagal (R dan E turun).","Tes E2: tanpa peran semua ditolak, termasuk registerIssuer dan grantRole; skor tetap Sedang karena D dan A secara desain tinggi.","AccessControl per peran + separation of duty (OWASP SC01)."),
"E-02": ((7,1,1,9,9),(7,1,1,9,9),"Tes E3: transferFrom, kedua safeTransferFrom, approve, setApprovalForAll revert di v1.","Sama dengan v1 (SoulboundBase dipakai kedua versi); kontrol sudah berfungsi sejak awal.","Pertahankan semua fungsi transfer/approval selalu revert (ERC-5192 locked)."),
"E-03": ((9,4,3,10,3),(9,1,3,10,3),"Tidak diuji langsung; skor awal ditinjau ulang, tetap.","DeployAll menolak satu akun memegang semua peran.","Validasi konfigurasi peran saat deploy; dokumentasikan pemegang tiap peran."),
"E-04": ((9,8,3,10,7),(5,8,3,4,7),"Tes E4: kunci owner v1 bocor = terbit palsu, ubah data, dan cabut milik orang lain.","Tes E5: owner tunggal diganti peran terpisah; issuer bocor bisa diputus accreditor.","Ganti owner tunggal dengan AccessControl multi-peran; gunakan multisig untuk admin."),
"N-01": ((7,2,2,4,2),(7,2,2,2,2),"Kajian literatur (tidak diuji, batasan 1.5); skor awal tetap.","Verifier memakai lebih dari satu node/RPC tepercaya.","Bandingkan hasil dari beberapa RPC berbeda."),
"N-02": ((5,3,1,8,3),(3,3,1,8,3),"Kajian literatur (tidak diuji, batasan 1.5); skor awal tetap.","Menunggu konfirmasi/finality sebelum menerima hasil verifikasi.","Terima mint/revoke setelah blok final."),
}
P=("D","R","E","A","Di")
path="data/dread_penilaian.csv"
rows=list(csv.DictReader(open(path,encoding="utf-8"))); fields=list(rows[0].keys())
assert {r["id"] for r in rows}==set(S), "ID di CSV beda dari draf"
for r in rows:
    u,m,_,_,rek=S[r["id"]]
    for p,v in zip(P,u): r[f"{p}_uji"]=str(v)
    for p,v in zip(P,m): r[f"{p}_mitigasi"]=str(v)
    r["rekomendasi_mitigasi"]=rek
with open(path,"w",newline="",encoding="utf-8") as f:
    w=csv.DictWriter(f,fieldnames=fields); w.writeheader(); w.writerows(rows)
with open("docs/ALASAN_DREAD_UJI_MITIGASI.md","w",encoding="utf-8") as f:
    f.write("# Alasan skor DREAD setelah uji dan setelah mitigasi (Sesi 8)\n\nStatus: DRAF, disesuaikan peneliti (arahan Pak Faldi).\n")
    for r in rows:
        u,m,au,am,rek=S[r["id"]]
        f.write(f"\n## {r['id']} — {r['deskripsi_teknis']}\n- Setelah uji (v1): {u} → rata-rata {sum(u)/5:.1f}. {au}\n- Setelah mitigasi (v2): {m} → rata-rata {sum(m)/5:.1f}. {am}\n- Rekomendasi: {rek}\n")
print("OK: kolom _uji, _mitigasi, dan rekomendasi_mitigasi 24 ancaman terisi; alasan di docs/ALASAN_DREAD_UJI_MITIGASI.md")
