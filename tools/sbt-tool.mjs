#!/usr/bin/env node
// sbt-tool.mjs — alat bantu off-chain untuk penelitian SBT transkrip (Node.js LTS, TANPA dependensi npm).
// Dipakai untuk: (1) menyiapkan dokumen transkrip sintetis (hash, salt, commitment, enkripsi untuk IPFS),
// (2) VERIFIER read-only: memeriksa keaslian transkrip lewat RPC publik TANPA wallet/kunci privat.
//
//   node tools/sbt-tool.mjs siapkan <transkrip.json> [--out keluaran]
//   node tools/sbt-tool.mjs hash <transkrip.json> [--salt 0x..]
//   node tools/sbt-tool.mjs dekripsi <file.enc> --key 0x.. [--out file.json]
//   node tools/sbt-tool.mjs verifikasi --rpc <URL> --kontrak <alamat> --token <id> --holder <alamat>
//        --salt 0x.. ( --dok <transkrip.json> | --enc <file.enc> --key 0x.. | --key 0x.. [--gateway URL] ) [--v1]
//
// Skema commitment:
//   docHash        = keccak256(isi file transkrip apa adanya, byte demi byte)
//   commitment v2  = keccak256(abi.encode(salt, docHash))     (salt acak 32 byte, disimpan holder)
//   commitment v1  = keccak256(abi.encode(docHash))           (baseline, TANPA salt)
import { readFileSync, writeFileSync, mkdirSync, existsSync } from "node:fs";
import { randomBytes, createCipheriv, createDecipheriv } from "node:crypto";
import { basename, join } from "node:path";

// ------------------------------- keccak-256 -------------------------------
const MASK = (1n << 64n) - 1n;
const RC = [
  0x0000000000000001n, 0x0000000000008082n, 0x800000000000808an, 0x8000000080008000n,
  0x000000000000808bn, 0x0000000080000001n, 0x8000000080008081n, 0x8000000000008009n,
  0x000000000000008an, 0x0000000000000088n, 0x0000000080008009n, 0x000000008000000an,
  0x000000008000808bn, 0x800000000000008bn, 0x8000000000008089n, 0x8000000000008003n,
  0x8000000000008002n, 0x8000000000000080n, 0x000000000000800an, 0x800000008000000an,
  0x8000000080008081n, 0x8000000000008080n, 0x0000000080000001n, 0x8000000080008008n,
];
const ROT = [[0, 36, 3, 41, 18], [1, 44, 10, 45, 2], [62, 6, 43, 15, 61], [28, 55, 25, 21, 56], [27, 20, 39, 8, 14]];
const rotl = (v, n) => (n === 0 ? v : ((v << BigInt(n)) | (v >> BigInt(64 - n))) & MASK);
function keccakF(s) {
  const C = new Array(5), B = new Array(25);
  for (let r = 0; r < 24; r++) {
    for (let x = 0; x < 5; x++) C[x] = s[x] ^ s[x + 5] ^ s[x + 10] ^ s[x + 15] ^ s[x + 20];
    for (let x = 0; x < 5; x++) {
      const D = C[(x + 4) % 5] ^ rotl(C[(x + 1) % 5], 1);
      for (let y = 0; y < 25; y += 5) s[x + y] ^= D;
    }
    for (let x = 0; x < 5; x++)
      for (let y = 0; y < 5; y++) B[y + 5 * ((2 * x + 3 * y) % 5)] = rotl(s[x + 5 * y], ROT[x][y]);
    for (let x = 0; x < 5; x++)
      for (let y = 0; y < 5; y++)
        s[x + 5 * y] = B[x + 5 * y] ^ (~B[((x + 1) % 5) + 5 * y] & MASK & B[((x + 2) % 5) + 5 * y]);
    s[0] ^= RC[r];
  }
}
export function keccak256(bytes) {
  const rate = 136;
  const padLen = rate - (bytes.length % rate);
  const msg = new Uint8Array(bytes.length + padLen);
  msg.set(bytes);
  msg[bytes.length] ^= 0x01;
  msg[msg.length - 1] ^= 0x80;
  const s = new Array(25).fill(0n);
  for (let off = 0; off < msg.length; off += rate) {
    for (let i = 0; i < rate / 8; i++) {
      let lane = 0n;
      for (let b = 7; b >= 0; b--) lane = (lane << 8n) | BigInt(msg[off + i * 8 + b]);
      s[i] ^= lane;
    }
    keccakF(s);
  }
  const out = new Uint8Array(32);
  for (let i = 0; i < 4; i++) for (let b = 0; b < 8; b++) out[i * 8 + b] = Number((s[i] >> BigInt(8 * b)) & 0xffn);
  return out;
}

// --------------------------------- util ---------------------------------
const hex = (u8) => "0x" + Buffer.from(u8).toString("hex");
const unhex = (h) => {
  const s = h.startsWith("0x") ? h.slice(2) : h;
  if (!/^[0-9a-fA-F]*$/.test(s) || s.length % 2) throw new Error(`hex tidak valid: ${h}`);
  return new Uint8Array(Buffer.from(s, "hex"));
};
const word = (h) => { const b = unhex(h); if (b.length !== 32) throw new Error(`harus 32 byte: ${h}`); return b; };
const concat = (...a) => { const o = new Uint8Array(a.reduce((n, x) => n + x.length, 0)); let p = 0; for (const x of a) { o.set(x, p); p += x.length; } return o; };
const u256 = (n) => { const b = new Uint8Array(32); let v = BigInt(n); for (let i = 31; i >= 0; i--) { b[i] = Number(v & 0xffn); v >>= 8n; } return b; };
const addrWord = (a) => { const b = unhex(a); if (b.length !== 20) throw new Error(`alamat tidak valid: ${a}`); return concat(new Uint8Array(12), b); };
const selector = (sig) => keccak256(new TextEncoder().encode(sig)).slice(0, 4);

export const docHash = (fileBytes) => keccak256(fileBytes);
export const commitV2 = (salt, dh) => keccak256(concat(word(salt), dh));
export const commitV1 = (dh) => keccak256(dh);

function args(argv) {
  const o = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    if (argv[i].startsWith("--")) { const k = argv[i].slice(2); const v = argv[i + 1] && !argv[i + 1].startsWith("--") ? argv[++i] : true; o[k] = v; }
    else o._.push(argv[i]);
  }
  return o;
}

// ------------------------------ enkripsi -------------------------------
// Format file .enc: "SBTENC1" (7 byte) | iv (12) | tag (16) | ciphertext. AES-256-GCM.
function encrypt(plain, key) {
  const iv = randomBytes(12);
  const c = createCipheriv("aes-256-gcm", key, iv);
  const ct = Buffer.concat([c.update(plain), c.final()]);
  return Buffer.concat([Buffer.from("SBTENC1"), iv, c.getAuthTag(), ct]);
}
function decrypt(blob, key) {
  const b = Buffer.from(blob);
  if (b.subarray(0, 7).toString() !== "SBTENC1") throw new Error("bukan file .enc dari sbt-tool");
  const d = createDecipheriv("aes-256-gcm", key, b.subarray(7, 19));
  d.setAuthTag(b.subarray(19, 35));
  return Buffer.concat([d.update(b.subarray(35)), d.final()]);
}

// ------------------------------- RPC -------------------------------
async function ethCall(rpc, to, data) {
  const res = await fetch(rpc, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ jsonrpc: "2.0", id: 1, method: "eth_call", params: [{ to, data: hex(data) }, "latest"] }),
  });
  const j = await res.json();
  if (j.error) throw new Error(`eth_call gagal: ${j.error.message}`);
  return unhex(j.result);
}
const readWord = (b, i) => b.slice(32 * i, 32 * i + 32);
const toBig = (w) => BigInt(hex(w));
function decodeString(b) {
  const off = Number(toBig(readWord(b, 0)));
  const len = Number(toBig(b.slice(off, off + 32)));
  return new TextDecoder().decode(b.slice(off + 32, off + 32 + len));
}

// ------------------------------ perintah ------------------------------
function cmdHash(o) {
  const file = o._[1];
  if (!file) throw new Error("pakai: hash <transkrip.json> [--salt 0x..]");
  const dh = docHash(readFileSync(file));
  const salt = typeof o.salt === "string" ? o.salt : hex(randomBytes(32));
  console.log(JSON.stringify({ file, docHash: hex(dh), salt, commitment_v2: hex(commitV2(salt, dh)), commitment_v1: hex(commitV1(dh)) }, null, 2));
}

function cmdSiapkan(o) {
  const file = o._[1];
  if (!file) throw new Error("pakai: siapkan <transkrip.json> [--out keluaran]");
  const out = typeof o.out === "string" ? o.out : "keluaran";
  if (!existsSync(out)) mkdirSync(out, { recursive: true });
  const plain = readFileSync(file);
  const dh = docHash(plain);
  const salt = hex(randomBytes(32));
  const key = randomBytes(32);
  const encName = basename(file) + ".enc";
  writeFileSync(join(out, encName), encrypt(plain, key));
  const rahasia = {
    PERINGATAN: "RAHASIA HOLDER. Jangan diunggah ke IPFS/GitHub. Dibagikan ke verifier hanya saat verifikasi.",
    file_asli: file, docHash: hex(dh), salt, kunci_enkripsi: hex(key),
    commitment_v2: hex(commitV2(salt, dh)), commitment_v1_tanpa_salt: hex(commitV1(dh)),
    file_untuk_ipfs: join(out, encName),
  };
  writeFileSync(join(out, basename(file) + ".rahasia.json"), JSON.stringify(rahasia, null, 2));
  console.log(JSON.stringify(rahasia, null, 2));
  console.log(`\nLangkah berikut: unggah ${join(out, encName)} ke IPFS, lalu mint dengan commitment_v2 dan URI ipfs://<CID>.`);
}

function cmdDekripsi(o) {
  const f = o._[1];
  if (!f || typeof o.key !== "string") throw new Error("pakai: dekripsi <file.enc> --key 0x.. [--out file.json]");
  const plain = decrypt(readFileSync(f), Buffer.from(word(o.key)));
  if (typeof o.out === "string") writeFileSync(o.out, plain); else process.stdout.write(plain);
}

async function cmdVerifikasi(o) {
  for (const k of ["rpc", "kontrak", "token", "holder"]) if (typeof o[k] !== "string") throw new Error(`--${k} wajib diisi`);
  const v1 = o.v1 === true;
  if (!v1 && typeof o.salt !== "string") throw new Error("--salt wajib untuk v2");
  const id = BigInt(o.token);
  const laporan = { kontrak: o.kontrak, token: id.toString(), holder: o.holder, versi: v1 ? "v1" : "v2" };

  // 1) ambil URI dari kontrak
  const uri = decodeString(await ethCall(o.rpc, o.kontrak, concat(selector("tokenURI(uint256)"), u256(id))));
  laporan.tokenURI = uri;

  // 2) dapatkan isi dokumen: file lokal, file .enc lokal, atau unduh dari IPFS gateway lalu dekripsi
  let plain;
  if (typeof o.dok === "string") { plain = readFileSync(o.dok); laporan.sumber_dokumen = o.dok; }
  else {
    if (typeof o.key !== "string") throw new Error("butuh --dok, atau --key (untuk mendekripsi file dari IPFS / --enc)");
    let blob;
    if (typeof o.enc === "string") { blob = readFileSync(o.enc); laporan.sumber_dokumen = o.enc; }
    else {
      if (!uri.startsWith("ipfs://")) throw new Error(`tokenURI bukan ipfs:// (${uri}); pakai --enc atau --dok`);
      const gw = (typeof o.gateway === "string" ? o.gateway : "https://ipfs.io/ipfs/").replace(/\/?$/, "/");
      const url = gw + uri.slice("ipfs://".length);
      const r = await fetch(url);
      if (!r.ok) throw new Error(`gagal mengunduh ${url}: HTTP ${r.status}`);
      blob = new Uint8Array(await r.arrayBuffer());
      laporan.sumber_dokumen = url;
    }
    plain = decrypt(blob, Buffer.from(word(o.key)));
  }

  // 3) hitung commitment dari dokumen yang dibawa holder
  const dh = docHash(plain);
  const c = v1 ? commitV1(dh) : commitV2(o.salt, dh);
  laporan.docHash = hex(dh);
  laporan.commitment_dihitung = hex(c);

  // 4) tanya kontrak (read-only, tanpa wallet)
  const ok = await ethCall(o.rpc, o.kontrak, concat(selector("verify(uint256,address,bytes32)"), u256(id), addrWord(o.holder), c));
  laporan.verify = toBig(ok) === 1n;
  if (!v1) {
    try {
      const rec = await ethCall(o.rpc, o.kontrak, concat(selector("recordOf(uint256)"), u256(id)));
      laporan.record = {
        commitment_onchain: hex(readWord(rec, 0)),
        issuer: "0x" + Buffer.from(readWord(rec, 1).slice(12)).toString("hex"),
        issuedAt: Number(toBig(readWord(rec, 2))),
        revoked: toBig(readWord(rec, 3)) === 1n,
      };
    } catch (e) { laporan.record = `tidak terbaca: ${e.message}`; }
  }
  laporan.HASIL = laporan.verify ? "VALID" : "TIDAK VALID";
  console.log(JSON.stringify(laporan, null, 2));
  process.exitCode = laporan.verify ? 0 : 2;
}

async function main() {
  const o = args(process.argv.slice(2));
  const cmd = o._[0];
  if (cmd === "hash") return cmdHash(o);
  if (cmd === "siapkan") return cmdSiapkan(o);
  if (cmd === "dekripsi") return cmdDekripsi(o);
  if (cmd === "verifikasi") return cmdVerifikasi(o);
  if (cmd === "uji-keccak") { console.log(hex(keccak256(new TextEncoder().encode(o._[1] ?? "")))); return; }
  console.log(readFileSync(new URL(import.meta.url)).toString().split("\n").slice(1, 18).join("\n"));
}
if (process.argv[1] && new URL(import.meta.url).pathname === new URL("file://" + process.argv[1]).pathname) {
  main().catch((e) => { console.error("ERROR:", e.message); process.exitCode = 1; });
}
