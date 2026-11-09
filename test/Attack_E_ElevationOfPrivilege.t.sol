// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Base} from "./Base.t.sol";

/// @notice E = Elevation of Privilege. Skenario (Tabel 2.4): akun tanpa peran memanggil fungsi
///         admin; transferFrom, safeTransferFrom, setApprovalForAll, approve harus revert.
contract AttackElevationTest is Base {
    /// E1 (v1): non-owner tidak bisa memanggil fungsi admin (Ownable bekerja).
    function test_E1_v1_nonOwnerAdminCallsRevert() public {
        bytes memory err = abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", attacker);
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        vm.startPrank(attacker);
        vm.expectRevert(err);
        v1.mint(attacker, bytes32(uint256(1)), "x");
        vm.expectRevert(err);
        v1.revoke(1);
        vm.expectRevert(err);
        v1.revokeMany(ids);
        vm.expectRevert(err);
        v1.updateRecord(1, bytes32(0), "x");
        vm.expectRevert(err);
        v1.reissue(1, attacker);
        vm.expectRevert(err);
        v1.transferOwnership(attacker);
        vm.stopPrank();
        _hasil("E1", "v1", "non-owner memanggil mint/revoke/reissue/updateRecord/transferOwnership: revert", DITOLAK);
    }

    /// E2 (v2): non-role tidak bisa; bahkan ISSUER sah tidak bisa menaikkan hak dirinya.
    function test_E2_v2_noRoleAndSeparationOfDuty() public {
        bytes32 issuerRole = v2.ISSUER_ROLE();
        bytes32 adminRole = v2.DEFAULT_ADMIN_ROLE();
        bytes32 accRole = registry.ACCREDITOR_ROLE();
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;

        // (a) penyerang tanpa peran
        vm.startPrank(attacker);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", attacker, issuerRole));
        v2.mint(attacker, bytes32(uint256(1)), "x");
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", attacker, issuerRole));
        v2.revoke(1, bytes32(0));
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", attacker, issuerRole));
        v2.revokeBatch(ids, bytes32(0));
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", attacker, adminRole));
        v2.grantRole(issuerRole, attacker);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", attacker, issuerRole));
        v2.reissue(1, attacker, bytes32(0));
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", attacker, accRole));
        registry.registerIssuer(attacker);
        vm.stopPrank();

        // (b) penerbit sah tidak bisa mengakreditasi/menaikkan hak dirinya sendiri
        vm.startPrank(issuer);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", issuer, adminRole));
        v2.grantRole(adminRole, issuer);
        vm.expectRevert(abi.encodeWithSignature("AccessControlUnauthorizedAccount(address,bytes32)", issuer, accRole));
        registry.revokeIssuer(issuer);
        vm.stopPrank();
        _hasil("E2", "v2", "tanpa peran panggil mint/revoke/reissue/registerIssuer/grantRole; penerbit naikkan hak sendiri: revert", DITOLAK);
    }

    function _assertSoulbound(address token, uint256 id, address holder, string memory idTag, string memory ver)
        internal
    {
        IERC721 t = IERC721(token);
        address[2] memory callers = [holder, attacker];
        bytes memory moveErr = abi.encodeWithSignature("SoulboundTokenCannotMove(uint256)", id);
        bytes memory apprErr = abi.encodeWithSignature("SoulboundNoApproval()");
        for (uint256 k = 0; k < callers.length; ++k) {
            vm.startPrank(callers[k]);
            vm.expectRevert(moveErr);
            t.transferFrom(holder, attacker, id);
            vm.expectRevert(moveErr);
            t.safeTransferFrom(holder, attacker, id);
            vm.expectRevert(moveErr);
            t.safeTransferFrom(holder, attacker, id, "data");
            vm.expectRevert(apprErr);
            t.approve(attacker, id);
            vm.expectRevert(apprErr);
            t.setApprovalForAll(attacker, true);
            vm.stopPrank();
        }
        assertEq(t.ownerOf(id), holder);
        _hasil(idTag, ver, "transferFrom/safeTransferFrom/approve/setApprovalForAll: semua revert", DITOLAK);
    }

    /// E3: SBT tidak bisa dipindah/di-approve oleh siapa pun, di v1 maupun v2.
    function test_E3_soulbound_transfersAndApprovalsRevert() public {
        uint256 id1 = mintV1(student1, commitUnsalted(NIM1, IPK1, SKS1));
        _assertSoulbound(address(v1), id1, student1, "E3", "v1");
        uint256 id2 = mintV2(student1, commitSalted(SALT1, NIM1, IPK1, SKS1));
        _assertSoulbound(address(v2), id2, student1, "E3", "v2");
    }

    /// E4 (v1, RISIKO SISA BESAR): satu owner = satu titik gagal. Kalau kunci owner bocor,
    /// penyerang bisa menerbitkan transkrip palsu, mengubah data, dan mencabut milik orang lain,
    /// dan tidak ada yang bisa menghentikannya (tak ada pemisahan tugas, tak ada event).
    function test_E4_v1_ownerKeyCompromise_fullTakeover() public {
        bytes32 c = commitUnsalted(NIM1, IPK1, SKS1);
        uint256 id = mintV1(student1, c);

        vm.recordLogs();
        vm.startPrank(issuer); // = penyerang yang memegang kunci owner
        uint256 fakeId = v1.mint(attacker, commitUnsalted(NIM1, 400, SKS1), "ipfs://palsu");
        v1.updateRecord(id, bytes32(uint256(99)), "ipfs://diubah");
        v1.revoke(fakeId);
        vm.stopPrank();
        Vm.Log[] memory logs = vm.getRecordedLogs();

        assertEq(v1.nextId(), 2);
        assertFalse(v1.verify(id, student1, c)); // transkrip asli mahasiswa rusak
        assertEq(logs.length, 2); // hanya Transfer+Locked milik mint; update & revoke tanpa jejak
        _hasil("E4", "v1", "kunci owner bocor: terbit palsu + ubah data + cabut = pengambilalihan penuh", TEMUAN);
    }

    /// E5 (v2): kunci ISSUER bocor tetap berbahaya sampai terdeteksi, tetapi dampaknya terbatas:
    /// tidak bisa menaikkan hak, dan ACCREDITOR bisa memutus semua token penerbit itu sekaligus.
    function test_E5_v2_compromisedIssuer_containedByAccreditor() public {
        bytes32 c = commitSalted(SALT1, NIM1, IPK1, SKS1);
        uint256 id = mintV2(student1, c);

        bytes32 forged = commitSalted(SALT1, NIM1, 400, SKS1);
        vm.prank(issuer); // penyerang memegang kunci issuer
        uint256 fakeId = v2.mint(attacker, forged, "ipfs://palsu");
        assertTrue(v2.verify(fakeId, attacker, forged)); // sebelum pemutusan: masih lolos (risiko sisa)

        vm.prank(accreditor);
        registry.revokeIssuer(issuer); // respons insiden

        assertFalse(v2.verify(fakeId, attacker, forged));
        assertFalse(v2.verify(id, student1, c)); // token sah dari penerbit itu juga berhenti valid (harus diterbitkan ulang)
        _hasil("E5", "v2", "kunci issuer bocor: dampak dibatasi; accreditor memutus penerbit", TEMUAN);
    }
}
