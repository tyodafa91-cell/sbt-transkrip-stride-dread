// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {console} from "forge-std/console.sol";
import {Base} from "./Base.t.sol";

/// @notice Pengukuran gas kasar di Foundry (mint, verify, revoke; v1 vs v2), 10 kali (+1 pemanasan).
///         Angka resmi untuk laporan sebaiknya dari transaksi nyata di Anvil: scripts/gas_anvil.sh.
///         Format keluaran: GAS|operasi|versi|gas  (dirangkum oleh scripts/gas_forge.sh)
contract GasBenchTest is Base {
    string internal constant URI = "ipfs://QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG";
    uint256 internal constant RUNS = 11; // run ke-1 = pemanasan (dibuang oleh scripts/gas_forge.sh) -> n=10

    function _gas(string memory op, string memory ver, uint256 g) internal pure {
        console.log(string.concat("GAS|", op, "|", ver, "|", vm.toString(g)));
    }

    function test_gasBench_v1_vs_v2() public {
        for (uint256 i = 0; i < RUNS; ++i) {
            address to = address(uint160(0x20000 + i));
            bytes32 c1 = commitUnsalted(NIM1 + uint64(i), IPK1, SKS1);
            bytes32 c2 = commitSalted(keccak256(abi.encode("salt", i)), NIM1 + uint64(i), IPK1, SKS1);

            // ---- v1 ----
            vm.prank(issuer);
            uint256 g0 = gasleft();
            uint256 id1 = v1.mint(to, c1, URI);
            _gas("mint", "v1", g0 - gasleft());

            g0 = gasleft();
            bool ok1 = v1.verify(id1, to, c1);
            _gas("verify", "v1", g0 - gasleft());
            assertTrue(ok1);

            vm.prank(issuer);
            g0 = gasleft();
            v1.revoke(id1);
            _gas("revoke", "v1", g0 - gasleft());

            // ---- v2 ----
            vm.prank(issuer);
            g0 = gasleft();
            uint256 id2 = v2.mint(to, c2, URI);
            _gas("mint", "v2", g0 - gasleft());

            g0 = gasleft();
            bool ok2 = v2.verify(id2, to, c2);
            _gas("verify", "v2", g0 - gasleft());
            assertTrue(ok2);

            vm.prank(issuer);
            g0 = gasleft();
            v2.revoke(id2, bytes32(0));
            _gas("revoke", "v2", g0 - gasleft());
        }
    }
}
