// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {EchidnaV2} from "../echidna/EchidnaV2.sol";

/// @notice Menjalankan harness Echidna v2 sebagai invariant test Foundry (fuzzing bawaan Foundry).
///         Berguna kalau Echidna belum terpasang: `forge test --match-contract EchidnaV2Invariant`.
contract EchidnaV2InvariantTest is Test {
    EchidnaV2 internal h;

    function setUp() public {
        h = new EchidnaV2();
        targetContract(address(h));
    }

    function invariant_unique_commitment() public view {
        assertTrue(h.echidna_unique_commitment());
    }

    function invariant_record_immutable() public view {
        assertTrue(h.echidna_record_immutable());
    }

    function invariant_soulbound() public view {
        assertTrue(h.echidna_soulbound());
    }

    function invariant_outsider_cannot_mint() public view {
        assertTrue(h.echidna_outsider_cannot_mint());
    }

    function invariant_deaccredited_cannot_mint() public view {
        assertTrue(h.echidna_deaccredited_cannot_mint());
    }

    function invariant_revoked_cannot_verify() public view {
        assertTrue(h.echidna_revoked_cannot_verify());
    }
}
