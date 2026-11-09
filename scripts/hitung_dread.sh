#!/usr/bin/env bash
# Menghitung skor DREAD tiga tahap dari data/dread_penilaian.csv (sesuai proposal 1.1, 2.3.4, 2.3.8):
#   _awal     = penilaian awal dari desain/DFD, SEBELUM pengujian (Sesi 4)
#   _uji      = dihitung ulang SETELAH pengujian, ancaman pada v1 (Sesi 8)
#   _mitigasi = risiko sisa SETELAH mitigasi, pada v2 (Sesi 8)
# Rata-rata = (D+R+E+A+Di)/5.  >= 7 Tinggi | 4 s.d. < 7 Sedang | < 4 Rendah
# Keluaran: data/dread_hasil.csv (semua kolom) dan data/model_ancaman_akhir.csv (format tabel proposal 2.3.8)
cd "$(dirname "$0")/.."
IN="${1:-data/dread_penilaian.csv}"
python3 - "$IN" <<'PY'
import csv, sys
rows = list(csv.DictReader(open(sys.argv[1], encoding="utf-8")))
P = ("D", "R", "E", "A", "Di")
def tingkat(x): return "Tinggi" if x >= 7 else ("Sedang" if x >= 4 else "Rendah")
kurang = {"awal": [], "uji": [], "mitigasi": []}
for r in rows:
    for t in kurang:
        try:
            sk = [float(r[f"{p}_{t}"]) for p in P]
            if not all(1 <= x <= 10 for x in sk): raise ValueError
            avg = sum(sk) / 5
            r[f"rata2_{t}"] = f"{avg:.1f}"; r[f"tingkat_{t}"] = tingkat(avg)
        except (ValueError, TypeError, KeyError):
            r[f"rata2_{t}"] = ""; r[f"tingkat_{t}"] = ""; kurang[t].append(r["id"])
    if r["rata2_uji"] and r["rata2_mitigasi"]:
        r["penurunan"] = f"{float(r['rata2_uji']) - float(r['rata2_mitigasi']):.1f}"
    else:
        r["penurunan"] = ""
fields = list(rows[0].keys())
with open("data/dread_hasil.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.DictWriter(f, fieldnames=fields); w.writeheader(); w.writerows(rows)
akhir = sorted(rows, key=lambda r: -(float(r["rata2_uji"]) if r["rata2_uji"] else -1))
with open("data/model_ancaman_akhir.csv", "w", newline="", encoding="utf-8") as f:
    w = csv.writer(f)
    w.writerow(["id_ancaman", "komponen", "kategori_stride", "deskripsi_teknis", "skenario_serangan",
                "skor_dread", "tingkat_risiko", "skor_setelah_mitigasi", "rekomendasi_mitigasi"])
    for r in akhir:
        w.writerow([r["id"], r["komponen"], r["kategori_stride"], r["deskripsi_teknis"], r["skenario_serangan"],
                    r["rata2_uji"], r["tingkat_uji"], r["rata2_mitigasi"], r["rekomendasi_mitigasi"]])
for t, ids in kurang.items():
    if ids: print(f"BELUM diisi/valid ({t}): {', '.join(ids)}")
print(f"\n{'id':6} {'awal':>5} {'uji':>5} {'mitig':>5} {'turun':>5}  tingkat(uji)  kategori")
for r in akhir:
    print(f'{r["id"]:6} {r["rata2_awal"]:>5} {r["rata2_uji"]:>5} {r["rata2_mitigasi"]:>5} {r["penurunan"]:>5}  {r["tingkat_uji"]:12}  {r["kategori_stride"]}')
print("\nDisimpan: data/dread_hasil.csv dan data/model_ancaman_akhir.csv")
PY
