// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {Base} from "./Base.t.sol";
import {ReentrantIssuer, IMintable} from "./mocks/Attackers.sol";

/// @notice T = Tampering. Skenario (Tabel 2.4): kontrak penyerang reentrancy saat penerbitan;
///         metadata diubah setelah mint.
contract AttackTamperingTest is Base {
    /// T1 (v1): penerbit berupa smart-contract wallet yang juga penerima. Saat callback
    /// onERC721Received ia mint LAGI dengan commitment yang sama -> 2 token untuk 1 commitment.
    function test_T1_v1_reentrancyDuplicatesIssuance() public {
        ReentrantIssuer atk = new ReentrantIssuer();
        vm.prank(issuer);
        v1.transferOwnership(address(atk)); // model: penerbit = contract wallet yang bisa dikuasai penyerang

        bytes32 c = commitUnsalted(NIM1, IPK1, SKS1);
        atk.attack(IMintable(address(v1)), c);

        assertTrue(atk.reentered());
        assertTrue(atk.reentrySucceeded());
        assertEq(v1.nextId(), 2); // seharusnya 1
        assertEq(v1.commitmentOf(1), c);
        assertEq(v1.commitmentOf(2), c); // dua token, satu commitment
        _hasil("T1", "v1", "reentrancy saat mint: 1 commitment menghasilkan 2 token", BERHASIL);
    }

    /// T2 (v2): serangan yang sama diblok ReentrancyGuard (dan urutan CEI).
    function test_T2_v2_reentrancyBlocked() public {
        ReentrantIssuer atk = new ReentrantIssuer();
        bytes32 role = v2.ISSUER_ROLE();
        vm.prank(admin);
        v2.grantRole(role, address(atk));
        vm.prank(accreditor);
        registry.registerIssuer(address(atk));

        bytes32 c = commitSalted(SALT1, NIM1, IPK1, SKS1);
        atk.attack(IMintable(address(v2)), c);

        assertTrue(atk.reentered());
        assertFalse(atk.reentrySucceeded());
        assertEq(v2.nextId(), 1);
        _hasil("T2", "v2", "reentrancy saat mint: panggilan ulang ditolak ReentrancyGuard", DITOLAK);
    }

    /// T3 (v1): metadata/commitment diubah setelah terbit, tanpa event sama sekali.
    function test_T3_v1_metadataMutableAfterMint_noTrace() public {
        bytes32 c = commitUnsalted(NIM1, IPK1, SKS1);
        uint256 id = mintV1(student1, c);
        assertTrue(v1.verify(id, student1, c));

        bytes32 forged = commitUnsalted(NIM1, 400, SKS1);
        vm.recordLogs();
        vm.prank(issuer);
        v1.updateRecord(id, forged, "ipfs://diubah");
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(logs.length, 0); // tidak ada jejak
        assertFalse(v1.verify(id, student1, c)); // data asli tidak lagi valid
        assertTrue(v1.verify(id, student1, forged)); // data palsu valid
        assertEq(v1.tokenURI(id), "ipfs://diubah");
        _hasil("T3", "v1", "commitment & URI diubah setelah terbit tanpa event", BERHASIL);
    }

    /// T4 (v2): tidak ada fungsi pengubah record; panggilan ke fungsi semacam itu gagal.
    function test_T4_v2_recordImmutableAfterMint() public {
        bytes32 c = commitSalted(SALT1, NIM1, IPK1, SKS1);
        uint256 id = mintV2(student1, c);
        bytes32 forged = commitSalted(SALT1, NIM1, 400, SKS1);

        vm.prank(issuer);
        (bool ok1,) = address(v2).call(
            abi.encodeWithSignature("updateRecord(uint256,bytes32,string)", id, forged, "x")
        );
        vm.prank(issuer);
        (bool ok2,) = address(v2).call(abi.encodeWithSignature("setTokenURI(uint256,string)", id, "x"));
        assertFalse(ok1);
        assertFalse(ok2);
        assertTrue(v2.verify(id, student1, c));
        assertEq(v2.tokenURI(id), "ipfs://contoh");
        _hasil("T4", "v2", "tidak ada fungsi ubah record; commitment & URI tetap", DITOLAK);
    }

    /// T5 (v2): commitment yang sudah dicabut tidak bisa diterbitkan ulang diam-diam.
    function test_T5_v2_revokedCommitmentCannotBeReissued() public {
        bytes32 c = commitSalted(SALT1, NIM1, IPK1, SKS1);
        uint256 id = mintV2(student1, c);
        vm.startPrank(issuer);
        v2.revoke(id, bytes32(0));
        vm.expectRevert(abi.encodeWithSignature("CommitmentAlreadyIssued(bytes32)", c));
        v2.mint(student1, c, "x");
        vm.stopPrank();
        _hasil("T5", "v2", "commitment lama tidak bisa diterbitkan ulang setelah dicabut", DITOLAK);
    }
}
