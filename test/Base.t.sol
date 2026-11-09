// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {IssuerRegistry} from "../src/IssuerRegistry.sol";
import {SBTTranskripV1} from "../src/v1/SBTTranskripV1.sol";
import {SBTTranskripV2} from "../src/v2/SBTTranskripV2.sol";

/// @notice Dasar semua tes: menyiapkan v1 dan v2 dengan aktor yang sama.
///         SEMUA DATA DI SINI SINTETIS (NIM karangan), bukan data mahasiswa asli.
abstract contract Base is Test {
    // Aktor
    address internal admin = makeAddr("admin"); // admin kontrak v2 (DEFAULT_ADMIN_ROLE)
    address internal accreditor = makeAddr("accreditor"); // pemegang ACCREDITOR_ROLE
    address internal issuer = makeAddr("issuer"); // penerbit sah (v1: owner; v2: ISSUER_ROLE)
    address internal student1 = makeAddr("student1");
    address internal student2 = makeAddr("student2");
    address internal attacker = makeAddr("attacker");

    SBTTranskripV1 internal v1;
    IssuerRegistry internal registry;
    SBTTranskripV2 internal v2;

    // Data sintetis: NIM karangan 2311100001.., IPK x100, total SKS
    uint64 internal constant NIM1 = 2311100001;
    uint16 internal constant IPK1 = 345; // 3.45
    uint16 internal constant SKS1 = 144;
    bytes32 internal constant SALT1 = keccak256("salt-acak-mahasiswa-1"); // contoh saja

    function setUp() public virtual {
        // v1: owner = issuer (satu-satunya penerbit)
        v1 = new SBTTranskripV1(issuer);

        // v2: registry + token, peran dipisah
        registry = new IssuerRegistry(admin);
        v2 = new SBTTranskripV2(admin, registry);
        vm.startPrank(admin);
        registry.grantRole(registry.ACCREDITOR_ROLE(), accreditor);
        v2.grantRole(v2.ISSUER_ROLE(), issuer);
        vm.stopPrank();
        vm.prank(accreditor);
        registry.registerIssuer(issuer);
    }

    // ---- commitment helper (sama persis dengan yang dihitung off-chain pakai `cast`) ----
    function commitUnsalted(uint64 nim, uint16 ipk100, uint16 sks) internal pure returns (bytes32) {
        return keccak256(abi.encode(nim, ipk100, sks));
    }

    function commitSalted(bytes32 salt, uint64 nim, uint16 ipk100, uint16 sks)
        internal
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(salt, nim, ipk100, sks));
    }

    /// Baris hasil yang bisa dikumpulkan scripts/rekap_serangan.sh -> data/hasil_serangan.csv
    /// Format: HASIL|ID|versi|deskripsi|status
    function _hasil(string memory id, string memory versi, string memory desc, string memory status)
        internal
        pure
    {
        console.log(string.concat("HASIL|", id, "|", versi, "|", desc, "|", status));
    }

    string internal constant BERHASIL = "SERANGAN_BERHASIL";
    string internal constant DITOLAK = "SERANGAN_DITOLAK";
    string internal constant TEMUAN = "TEMUAN_RISIKO_SISA";
    string internal constant LULUS = "KONTROL_BERFUNGSI";

    // Mint cepat (penerbit sah)
    function mintV1(address to, bytes32 c) internal returns (uint256 id) {
        vm.prank(issuer);
        id = v1.mint(to, c, "ipfs://contoh");
    }

    function mintV2(address to, bytes32 c) internal returns (uint256 id) {
        vm.prank(issuer);
        id = v2.mint(to, c, "ipfs://contoh");
    }
}
