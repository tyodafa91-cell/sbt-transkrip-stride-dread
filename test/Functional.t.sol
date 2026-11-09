// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Base} from "./Base.t.sol";
import {IERC5192} from "../src/interfaces/IERC5192.sol";

/// @notice Tes fungsional dasar (bukan serangan): memastikan v1 dan v2 berfungsi normal.
contract FunctionalTest is Base {
    function test_interfaceIds() public view {
        assertEq(type(IERC5192).interfaceId, bytes4(0xb45a3c0e));
        assertTrue(v1.supportsInterface(0xb45a3c0e)); // ERC-5192
        assertTrue(v1.supportsInterface(0x80ac58cd)); // ERC-721
        assertTrue(v2.supportsInterface(0xb45a3c0e));
        assertTrue(v2.supportsInterface(0x80ac58cd));
        assertTrue(v2.supportsInterface(0x7965db0b)); // IAccessControl
    }

    function test_v1_mint_verify_revoke() public {
        bytes32 c = commitUnsalted(NIM1, IPK1, SKS1);
        uint256 id = mintV1(student1, c);
        assertEq(id, 1);
        assertEq(v1.ownerOf(id), student1);
        assertTrue(v1.locked(id));
        assertEq(v1.tokenURI(id), "ipfs://contoh");
        assertTrue(v1.verify(id, student1, c));
        assertFalse(v1.verify(id, student2, c)); // pemegang salah
        assertFalse(v1.verify(id, student1, bytes32(uint256(1)))); // commitment salah
        assertFalse(v1.verify(99, student1, c)); // token tidak ada
        vm.prank(issuer);
        v1.revoke(id);
        assertFalse(v1.verify(id, student1, c));
    }

    function test_v2_mint_verify_revoke() public {
        bytes32 c = commitSalted(SALT1, NIM1, IPK1, SKS1);
        uint256 id = mintV2(student1, c);
        assertEq(id, 1);
        assertEq(v2.ownerOf(id), student1);
        assertTrue(v2.locked(id));
        assertEq(v2.tokenURI(id), "ipfs://contoh");
        assertEq(v2.recordOf(id).issuer, issuer);
        assertTrue(v2.verify(id, student1, c));
        assertFalse(v2.verify(id, student2, c));
        assertFalse(v2.verify(id, student1, bytes32(uint256(1))));
        assertFalse(v2.verify(99, student1, c));
        vm.prank(issuer);
        v2.revoke(id, keccak256("salah-input"));
        assertFalse(v2.verify(id, student1, c));
    }

    function test_locked_revertsForNonexistentToken() public {
        vm.expectRevert();
        v1.locked(1);
        vm.expectRevert();
        v2.locked(1);
    }

    function test_duplicateCommitmentRejected_bothVersions() public {
        bytes32 c = commitUnsalted(NIM1, IPK1, SKS1);
        mintV1(student1, c);
        vm.prank(issuer);
        vm.expectRevert(bytes("sudah terbit"));
        v1.mint(student2, c, "x");

        bytes32 c2 = commitSalted(SALT1, NIM1, IPK1, SKS1);
        mintV2(student1, c2);
        vm.prank(issuer);
        vm.expectRevert(abi.encodeWithSignature("CommitmentAlreadyIssued(bytes32)", c2));
        v2.mint(student2, c2, "x");
    }

    function test_v2_revokeOnlyByTokenIssuer_andNotTwice() public {
        bytes32 c = commitSalted(SALT1, NIM1, IPK1, SKS1);
        uint256 id = mintV2(student1, c);
        // penerbit lain (terakreditasi + punya role) tidak boleh mencabut token penerbit lain
        address issuer2 = makeAddr("issuer2");
        bytes32 role = v2.ISSUER_ROLE(); // dibaca dulu: vm.prank hanya berlaku untuk 1 panggilan berikutnya
        vm.prank(admin);
        v2.grantRole(role, issuer2);
        vm.prank(accreditor);
        registry.registerIssuer(issuer2);
        vm.prank(issuer2);
        vm.expectRevert(abi.encodeWithSignature("NotTokenIssuer(uint256,address)", id, issuer2));
        v2.revoke(id, bytes32(0));
        // pencabutan ganda ditolak
        vm.startPrank(issuer);
        v2.revoke(id, bytes32(0));
        vm.expectRevert(abi.encodeWithSignature("AlreadyRevoked(uint256)", id));
        v2.revoke(id, bytes32(0));
        vm.stopPrank();
    }

    // ---- Kebutuhan 2.3.2: terbit ulang ke dompet baru bila dompet holder hilang ----
    function test_v2_reissue_toNewWallet() public {
        bytes32 c = commitSalted(SALT1, NIM1, IPK1, SKS1);
        uint256 oldId = mintV2(student1, c);
        address newWallet = makeAddr("student1-dompet-baru");

        vm.prank(issuer);
        uint256 newId = v2.reissue(oldId, newWallet, keccak256("dompet-hilang"));

        assertEq(newId, 2);
        assertEq(v2.ownerOf(newId), newWallet);
        assertFalse(v2.verify(oldId, student1, c)); // token lama tidak valid lagi
        assertTrue(v2.verify(newId, newWallet, c)); // token baru valid, commitment sama
        assertTrue(v2.recordOf(oldId).revoked);
        assertEq(v2.tokenURI(newId), v2.tokenURI(oldId));
    }

    function test_v2_reissue_onlyOriginalActiveIssuer_andValidHolder() public {
        bytes32 c = commitSalted(SALT1, NIM1, IPK1, SKS1);
        uint256 oldId = mintV2(student1, c);
        address newWallet = makeAddr("baru");
        bytes32 role = v2.ISSUER_ROLE();

        // tanpa peran
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", attacker, role)
        );
        v2.reissue(oldId, attacker, bytes32(0));

        // alamat baru tidak sah
        vm.startPrank(issuer);
        vm.expectRevert(abi.encodeWithSignature("InvalidNewHolder(address)", address(0)));
        v2.reissue(oldId, address(0), bytes32(0));
        vm.expectRevert(abi.encodeWithSignature("InvalidNewHolder(address)", student1));
        v2.reissue(oldId, student1, bytes32(0));
        vm.stopPrank();

        // penerbit yang dicabut registrasinya tidak bisa terbit ulang
        vm.prank(accreditor);
        registry.revokeIssuer(issuer);
        vm.prank(issuer);
        vm.expectRevert(abi.encodeWithSignature("IssuerNotAccredited(address)", issuer));
        v2.reissue(oldId, newWallet, bytes32(0));
    }

    function test_v1_reissue_works() public {
        bytes32 c = commitUnsalted(NIM1, IPK1, SKS1);
        uint256 oldId = mintV1(student1, c);
        address newWallet = makeAddr("baru");
        vm.prank(issuer);
        uint256 newId = v1.reissue(oldId, newWallet);
        assertFalse(v1.verify(oldId, student1, c));
        assertTrue(v1.verify(newId, newWallet, c));
    }

    /// Ditemukan oleh fuzzing (harness Echidna v2): terbit ulang dua kali dari token LAMA yang
    /// sama tidak boleh menghasilkan dua token aktif untuk satu commitment.
    function test_v2_reissue_twiceFromOldToken_reverts() public {
        bytes32 c = commitSalted(SALT1, NIM1, IPK1, SKS1);
        uint256 oldId = mintV2(student1, c);
        vm.startPrank(issuer);
        uint256 newId = v2.reissue(oldId, makeAddr("baru-1"), bytes32(0));
        vm.expectRevert(abi.encodeWithSignature("NotCurrentToken(uint256,uint256)", oldId, newId));
        v2.reissue(oldId, makeAddr("baru-2"), bytes32(0));
        // dari token terbaru tetap boleh (dompet hilang lagi)
        uint256 newer = v2.reissue(newId, makeAddr("baru-3"), bytes32(0));
        vm.stopPrank();
        assertEq(v2.currentTokenOf(c), newer);
    }

    /// v1 (baseline) tidak punya pengecekan itu: dua token aktif untuk satu commitment.
    function test_v1_reissue_twiceFromOldToken_createsTwoActiveTokens() public {
        bytes32 c = commitUnsalted(NIM1, IPK1, SKS1);
        uint256 oldId = mintV1(student1, c);
        address a = makeAddr("baru-1");
        address b = makeAddr("baru-2");
        vm.startPrank(issuer);
        uint256 id2 = v1.reissue(oldId, a);
        uint256 id3 = v1.reissue(oldId, b);
        vm.stopPrank();
        assertTrue(v1.verify(id2, a, c));
        assertTrue(v1.verify(id3, b, c)); // kelemahan: dua-duanya valid
    }
}
