// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Base} from "./Base.t.sol";
import {FakeIssuer, IMintable} from "./mocks/Attackers.sol";
import {SBTTranskripV1} from "../src/v1/SBTTranskripV1.sol";
import {SBTTranskripV2} from "../src/v2/SBTTranskripV2.sol";
import {IssuerRegistry} from "../src/IssuerRegistry.sol";

/// @notice S = Spoofing. Skenario (Tabel 2.4): kontrak penerbit palsu, mint ke alamat salah,
///         verify() harus menolak.
contract AttackSpoofingTest is Base {
    /// S1 (v1): penyerang memasang klon kontrak sendiri sebagai "penerbit palsu".
    /// v1 tidak punya konsep akreditasi, jadi catatan palsunya lolos verify() di klon itu.
    function test_S1_v1_fakeCloneIssuer_forgedRecordVerifies() public {
        bytes32 forged = commitUnsalted(NIM1, 400, SKS1); // IPK palsu 4.00
        vm.startPrank(attacker);
        SBTTranskripV1 fake = new SBTTranskripV1(attacker);
        fake.mint(attacker, forged, "ipfs://palsu");
        vm.stopPrank();

        bool accepted = fake.verify(1, attacker, forged);
        assertTrue(accepted);
        // nama & simbol token palsu persis sama dengan yang asli: nama tidak bisa dijadikan bukti
        assertEq(fake.name(), v1.name());
        assertEq(fake.symbol(), v1.symbol());
        _hasil("S1", "v1", "klon kontrak penerbit palsu (nama sama): transkrip palsu lolos verify()", BERHASIL);
    }

    /// S2 (v2): klon v2 milik penyerang yang menunjuk registry ASLI. Dia admin di klonnya sendiri
    /// dan memberi dirinya ISSUER_ROLE, tetapi mint ditolak karena tidak terakreditasi di registry.
    function test_S2_v2_fakeCloneUsingRealRegistry_mintRejected() public {
        bytes32 forged = commitSalted(SALT1, NIM1, 400, SKS1);
        vm.startPrank(attacker);
        SBTTranskripV2 fake = new SBTTranskripV2(attacker, registry);
        bytes32 role = fake.ISSUER_ROLE();
        fake.grantRole(role, attacker);
        vm.expectRevert(abi.encodeWithSignature("IssuerNotAccredited(address)", attacker));
        fake.mint(attacker, forged, "ipfs://palsu");
        vm.stopPrank();
        _hasil("S2", "v2", "klon v2 + registry asli: mint penerbit tak terakreditasi ditolak", DITOLAK);
    }

    /// S3 (v2): akun biasa dan kontrak "FakeIssuer" memanggil mint() pada kontrak v2 asli.
    function test_S3_v2_fakeIssuerContractAndEOA_mintRejected() public {
        bytes32 role = v2.ISSUER_ROLE();
        bytes32 c = commitSalted(SALT1, NIM1, 400, SKS1);

        // (a) akun biasa
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", attacker, role)
        );
        v2.mint(attacker, c, "ipfs://palsu");

        // (b) kontrak penerbit palsu
        FakeIssuer fake = new FakeIssuer();
        bool ok = fake.tryMint(IMintable(address(v2)), attacker, c);
        assertFalse(ok);
        assertEq(v2.nextId(), 0);
        _hasil("S3", "v2", "akun/kontrak tanpa ISSUER_ROLE mencoba mint: ditolak", DITOLAK);
    }

    /// S4 (v1 & v2): penerbit sah salah mengirim token ke alamat yang salah (atau penyerang
    /// mengaku sebagai mahasiswa lain). verify() dengan alamat mahasiswa yang benar harus FALSE.
    function test_S4_mintToWrongAddress_verifyRejects() public {
        bytes32 c1 = commitUnsalted(NIM1, IPK1, SKS1);
        uint256 id1 = mintV1(attacker, c1); // seharusnya student1
        assertFalse(v1.verify(id1, student1, c1));
        _hasil("S4", "v1", "token salah alamat: verify() dgn alamat mahasiswa benar = false", DITOLAK);

        bytes32 c2 = commitSalted(SALT1, NIM1, IPK1, SKS1);
        uint256 id2 = mintV2(attacker, c2); // seharusnya student1
        assertFalse(v2.verify(id2, student1, c2));
        _hasil("S4", "v2", "token salah alamat: verify() dgn alamat mahasiswa benar = false", DITOLAK);
    }

    /// S5 (v2, RISIKO SISA): penyerang memasang klon v2 DAN registry palsu sendiri. Klon itu
    /// memverifikasi dirinya sendiri sebagai valid. Mitigasinya bukan di kontrak: verifier
    /// WAJIB hanya mempercayai alamat kontrak v2 + registry resmi kampus (address pinning).
    function test_S5_v2_residual_fakeCloneWithFakeRegistry_selfVerifies() public {
        bytes32 forged = commitSalted(SALT1, NIM1, 400, SKS1);
        vm.startPrank(attacker);
        IssuerRegistry fakeReg = new IssuerRegistry(attacker);
        bytes32 accRole = fakeReg.ACCREDITOR_ROLE();
        fakeReg.grantRole(accRole, attacker);
        fakeReg.registerIssuer(attacker);
        SBTTranskripV2 fake = new SBTTranskripV2(attacker, fakeReg);
        bytes32 issRole = fake.ISSUER_ROLE();
        fake.grantRole(issRole, attacker);
        fake.mint(attacker, forged, "ipfs://palsu");
        vm.stopPrank();

        assertTrue(fake.verify(1, attacker, forged)); // lolos di klonnya sendiri
        assertEq(address(fake.registry()) == address(registry), false); // bukan registry resmi
        _hasil("S5", "v2", "klon+registry palsu lolos di dirinya sendiri (verifier harus pin alamat resmi)", TEMUAN);
    }

    /// S6 (v2): akreditasi penerbit dicabut -> semua token yang dia terbitkan gagal verify,
    /// dan dia tidak bisa mint lagi.
    function test_S6_v2_deaccreditedIssuer_verifyRejects() public {
        bytes32 c = commitSalted(SALT1, NIM1, IPK1, SKS1);
        uint256 id = mintV2(student1, c);
        assertTrue(v2.verify(id, student1, c));

        vm.prank(accreditor);
        registry.revokeIssuer(issuer);

        assertFalse(v2.verify(id, student1, c));
        vm.prank(issuer);
        vm.expectRevert(abi.encodeWithSignature("IssuerNotAccredited(address)", issuer));
        v2.mint(student2, commitSalted(SALT1, NIM1 + 1, IPK1, SKS1), "x");
        _hasil("S6", "v2", "penerbit dicabut akreditasinya: verify() menolak & mint ditolak", DITOLAK);
    }
}
