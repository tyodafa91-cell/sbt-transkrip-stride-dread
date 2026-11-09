// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Base} from "./Base.t.sol";
import {SBTTranskripV1} from "../src/v1/SBTTranskripV1.sol";

/// @notice D = Denial of Service. Skenario (Tabel 2.4): pencabutan massal dengan N bertambah
///         dibandingkan batas gas blok.
///         Catatan: angka gas di sini perkiraan dari Foundry (di luar 21.000 gas dasar transaksi
///         dan biaya calldata). Ukur ulang di Anvil/Sepolia untuk angka yang dilaporkan.
contract AttackDoSTest is Base {
    /// Batas gas per blok yang dipakai sebagai patokan. Cek nilai jaringan sebenarnya:
    ///   cast block latest --rpc-url <RPC> --field gasLimit
    uint256 internal constant BLOCK_GAS_LIMIT = 30_000_000;

    function _freshV1WithTokens(uint256 n)
        internal
        returns (SBTTranskripV1 f, uint256[] memory ids)
    {
        f = new SBTTranskripV1(issuer);
        ids = new uint256[](n);
        vm.startPrank(issuer);
        for (uint256 i = 0; i < n; ++i) {
            ids[i] = f.mint(address(uint160(0x10000 + i)), keccak256(abi.encode("c", i)), "x");
        }
        vm.stopPrank();
    }

    /// D1 (v1): revokeMany tanpa batas. Makin besar N, makin dekat ke batas gas blok.
    function test_D1_v1_unboundedRevokeMany_exceedsBlockGasLimit() public {
        uint256[4] memory ns = [uint256(100), 500, 1000, 1500];
        bool smallOk;
        bool bigOk = true;
        for (uint256 k = 0; k < ns.length; ++k) {
            (SBTTranskripV1 f, uint256[] memory ids) = _freshV1WithTokens(ns[k]);
            vm.prank(issuer);
            uint256 g0 = gasleft();
            (bool ok,) = address(f).call{gas: BLOCK_GAS_LIMIT}(
                abi.encodeCall(f.revokeMany, (ids))
            );
            uint256 used = g0 - gasleft();
            if (k == 0) smallOk = ok;
            if (k == ns.length - 1) bigOk = ok;
            _hasil(
                "D1",
                "v1",
                string.concat(
                    "revokeMany N=", vm.toString(ns[k]), " gas~", vm.toString(used),
                    " per_id~", vm.toString(ok ? used / ns[k] : 0)
                ),
                ok ? "MUAT_DI_SATU_BLOK" : "DOS_MELEBIHI_BATAS_GAS"
            );
        }
        assertTrue(smallOk); // N kecil lolos
        assertFalse(bigOk); // N besar tidak muat dalam satu blok: pencabutan massal macet
    }

    /// D2 (v2): revokeBatch dibatasi MAX_REVOKE_PER_TX. N besar dipecah jadi beberapa transaksi.
    function test_D2_v2_cappedBatchRevoke() public {
        uint256 total = 120;
        uint256[] memory all = new uint256[](total);
        for (uint256 i = 0; i < total; ++i) {
            all[i] = mintV2(address(uint160(0x10000 + i)), keccak256(abi.encode("c", i)));
        }
        uint256 cap = v2.MAX_REVOKE_PER_TX();
        assertEq(cap, 50);

        // 51 ditolak
        uint256[] memory tooBig = new uint256[](cap + 1);
        for (uint256 i = 0; i < tooBig.length; ++i) tooBig[i] = all[i];
        vm.prank(issuer);
        vm.expectRevert(abi.encodeWithSignature("BatchTooLarge(uint256,uint256)", cap + 1, cap));
        v2.revokeBatch(tooBig, bytes32(0));

        // dipecah per 50
        uint256 done;
        uint256 maxGas;
        while (done < total) {
            uint256 n = total - done > cap ? cap : total - done;
            uint256[] memory part = new uint256[](n);
            for (uint256 i = 0; i < n; ++i) part[i] = all[done + i];
            vm.prank(issuer);
            uint256 g0 = gasleft();
            v2.revokeBatch(part, bytes32(0));
            uint256 used = g0 - gasleft();
            if (used > maxGas) maxGas = used;
            done += n;
        }
        assertLt(maxGas, BLOCK_GAS_LIMIT);
        for (uint256 i = 0; i < total; i += 17) {
            assertFalse(v2.verify(all[i], address(uint160(0x10000 + i)), keccak256(abi.encode("c", i))));
        }
        _hasil(
            "D2",
            "v2",
            string.concat("batas ", vm.toString(cap), "/tx; 120 token dicabut dlm 3 tx; gas maks~", vm.toString(maxGas)),
            DITOLAK
        );
    }
}
