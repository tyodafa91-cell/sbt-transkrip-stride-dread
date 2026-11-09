// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Vm} from "forge-std/Vm.sol";
import {Base} from "./Base.t.sol";

/// @notice R = Repudiation. Skenario (Tabel 2.4): audit kelengkapan event.
contract AttackRepudiationTest is Base {
    bytes32 internal constant SIG_REVOKED = keccak256("Revoked(uint256,address,bytes32)");
    bytes32 internal constant SIG_ISSUED = keccak256("Issued(uint256,address,address,bytes32)");
    bytes32 internal constant SIG_LOCKED = keccak256("Locked(uint256)");
    bytes32 internal constant SIG_TRANSFER = keccak256("Transfer(address,address,uint256)");
    bytes32 internal constant SIG_ACCREDITED = keccak256("IssuerRegistered(address,address)");
    bytes32 internal constant SIG_ACC_REVOKED =
        keccak256("IssuerRevoked(address,address)");

    /// R1 (v1): mint hanya menghasilkan Transfer + Locked; revoke/revokeMany/updateRecord = 0 event.
    function test_R1_v1_criticalOperationsEmitNoEvents() public {
        bytes32 c = commitUnsalted(NIM1, IPK1, SKS1);

        vm.recordLogs();
        uint256 id = mintV1(student1, c);
        Vm.Log[] memory mintLogs = vm.getRecordedLogs();
        assertEq(mintLogs.length, 2); // Transfer + Locked, tidak ada "Issued" (siapa penerbitnya?)

        vm.recordLogs();
        vm.prank(issuer);
        v1.revoke(id);
        assertEq(vm.getRecordedLogs().length, 0); // pencabutan tanpa jejak

        uint256 id2 = mintV1(student2, commitUnsalted(NIM1 + 1, IPK1, SKS1));
        uint256[] memory ids = new uint256[](1);
        ids[0] = id2;
        vm.recordLogs();
        vm.prank(issuer);
        v1.revokeMany(ids);
        assertEq(vm.getRecordedLogs().length, 0);

        vm.recordLogs();
        vm.prank(issuer);
        v1.updateRecord(id2, bytes32(uint256(7)), "x");
        assertEq(vm.getRecordedLogs().length, 0);

        // terbit ulang: hanya Transfer + Locked, tidak ada catatan token lama dicabut / alasan
        vm.recordLogs();
        vm.prank(issuer);
        v1.reissue(id2, makeAddr("baru"));
        assertEq(vm.getRecordedLogs().length, 2);

        _hasil("R1", "v1", "revoke/revokeMany/updateRecord/reissue tanpa event pencabutan (tak bisa diaudit)", TEMUAN);
    }

    /// R2 (v2): semua operasi penting punya event yang memuat siapa pelakunya.
    function test_R2_v2_allCriticalOperationsEmitEvents() public {
        bytes32 c = commitSalted(SALT1, NIM1, IPK1, SKS1);

        vm.recordLogs();
        uint256 id = mintV2(student1, c);
        Vm.Log[] memory m = vm.getRecordedLogs();
        assertEq(m.length, 3);
        assertEq(m[0].topics[0], SIG_ISSUED);
        assertEq(m[0].topics[2], bytes32(uint256(uint160(student1)))); // holder
        assertEq(m[0].topics[3], bytes32(uint256(uint160(issuer)))); // issuer
        assertEq(m[1].topics[0], SIG_LOCKED);
        assertEq(m[2].topics[0], SIG_TRANSFER);

        vm.recordLogs();
        vm.prank(issuer);
        v2.revoke(id, keccak256("salah-input"));
        Vm.Log[] memory r = vm.getRecordedLogs();
        assertEq(r.length, 1);
        assertEq(r[0].topics[0], SIG_REVOKED);
        assertEq(r[0].topics[2], bytes32(uint256(uint160(issuer))));

        address issuer2 = makeAddr("issuer2");
        vm.recordLogs();
        vm.prank(accreditor);
        registry.registerIssuer(issuer2);
        Vm.Log[] memory a = vm.getRecordedLogs();
        assertEq(a.length, 1);
        assertEq(a[0].topics[0], SIG_ACCREDITED);

        vm.recordLogs();
        vm.prank(accreditor);
        registry.revokeIssuer(issuer2);
        Vm.Log[] memory ar = vm.getRecordedLogs();
        assertEq(ar.length, 1);
        assertEq(ar[0].topics[0], SIG_ACC_REVOKED);

        // terbit ulang: Revoked(lama) + Issued(baru) + Reissued + Locked + Transfer
        uint256 id3 = mintV2(student2, commitSalted(SALT1, NIM1 + 1, IPK1, SKS1));
        vm.recordLogs();
        vm.prank(issuer);
        v2.reissue(id3, makeAddr("baru"), keccak256("dompet-hilang"));
        Vm.Log[] memory ri = vm.getRecordedLogs();
        assertEq(ri.length, 5);
        assertEq(ri[0].topics[0], SIG_REVOKED);
        assertEq(ri[1].topics[0], SIG_ISSUED);
        assertEq(ri[2].topics[0], keccak256("Reissued(uint256,uint256,address)"));

        bytes32 role = v2.ISSUER_ROLE();
        vm.recordLogs();
        vm.prank(admin);
        v2.grantRole(role, issuer2); // event RoleGranted dari AccessControl
        assertEq(vm.getRecordedLogs().length, 1);

        _hasil("R2", "v2", "mint/revoke/reissue/registerIssuer/role semuanya mengeluarkan event lengkap", LULUS);
    }
}
