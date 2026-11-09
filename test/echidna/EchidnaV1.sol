// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {SBTTranskripV1} from "../../src/v1/SBTTranskripV1.sol";

/// @notice Pihak luar (bukan owner) yang mencoba melakukan aksi terlarang.
contract OutsiderV1 {
    function tryMint(SBTTranskripV1 t, address to, bytes32 c) external returns (bool ok) {
        try t.mint(to, c, "x") returns (uint256) {
            ok = true;
        } catch {}
    }
}

/// @title EchidnaV1 - harness fuzzing untuk SBTTranskripV1
/// @notice Jalankan:  echidna test/echidna/EchidnaV1.sol --contract EchidnaV1 --config echidna.yaml
///   HARAPAN untuk v1 (kontrak sengaja rentan):
///     echidna_unique_commitment   -> GAGAL (reentrancy membuat 2 token AKTIF untuk 1 commitment)
///     echidna_record_immutable    -> GAGAL (updateRecord mengubah commitment)
///     echidna_soulbound           -> LULUS
///     echidna_outsider_cannot_mint-> LULUS
///     echidna_revoked_cannot_verify-> LULUS
/// Properti unique_commitment = paling banyak SATU token AKTIF (belum dicabut) per commitment
/// (reissue sah membuat token baru dengan commitment sama, tetapi token lama dicabut).
/// Harness ini = owner v1, sekaligus penerima token (punya callback onERC721Received).
contract EchidnaV1 is IERC721Receiver {
    SBTTranskripV1 internal t;
    OutsiderV1 internal outsider;

    bool internal reenterOn; // dinyalakan fuzzer lewat setReenter
    bool internal inCallback;
    bytes32 internal currentC;

    bool internal outsiderSucceeded;
    bool internal moveSucceeded;
    uint256[] internal recordedIds;
    mapping(uint256 => bytes32) internal recordedC;
    uint256[] internal revokedIds;

    constructor() {
        t = new SBTTranskripV1(address(this));
        outsider = new OutsiderV1();
    }

    // ----------------------------- aksi yang dipicu fuzzer -----------------------------
    function setReenter(bool on) public {
        reenterOn = on;
    }

    function doMint(uint8 who, uint8 k) public {
        address to = (who % 2 == 0) ? address(this) : address(uint160(0x1000 + (who % 4)));
        bytes32 c = keccak256(abi.encode("c", k % 4)); // hanya 4 commitment -> duplikat sering dicoba
        currentC = c;
        try t.mint(to, c, "x") returns (uint256 id) {
            recordedC[id] = c;
            recordedIds.push(id);
        } catch {}
    }

    function doReissue(uint8 idx, uint8 who) public {
        if (recordedIds.length == 0) return;
        uint256 id = recordedIds[idx % recordedIds.length];
        address to = address(uint160(0x2000 + (who % 4)));
        try t.reissue(id, to) returns (uint256 newId) {
            recordedC[newId] = recordedC[id];
            recordedIds.push(newId);
            revokedIds.push(id);
        } catch {}
    }

    function doUpdate(uint8 idx, uint8 k) public {
        if (recordedIds.length == 0) return;
        uint256 id = recordedIds[idx % recordedIds.length];
        try t.updateRecord(id, keccak256(abi.encode("u", id, k)), "y") {} catch {}
    }

    function doRevoke(uint8 idx) public {
        if (recordedIds.length == 0) return;
        uint256 id = recordedIds[idx % recordedIds.length];
        try t.revoke(id) {
            revokedIds.push(id);
        } catch {}
    }

    function doOutsiderMint(uint8 k) public {
        if (outsider.tryMint(t, address(0xBEEF), keccak256(abi.encode("o", k)))) {
            outsiderSucceeded = true;
        }
    }

    function doMove(uint8 idx, address to) public {
        if (recordedIds.length == 0) return;
        uint256 id = recordedIds[idx % recordedIds.length];
        try t.transferFrom(t.ownerOf(id), to, id) {
            moveSucceeded = true;
        } catch {}
        try t.approve(to, id) {
            moveSucceeded = true;
        } catch {}
        try t.setApprovalForAll(to, true) {
            moveSucceeded = true;
        } catch {}
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        override
        returns (bytes4)
    {
        require(msg.sender == address(t), "hanya dari token");
        if (reenterOn && !inCallback) {
            inCallback = true;
            try t.mint(address(this), currentC, "re") returns (uint256) {} catch {}
            inCallback = false;
        }
        return IERC721Receiver.onERC721Received.selector;
    }

    // ------------------------------- properti (invarian) -------------------------------
    function echidna_unique_commitment() public view returns (bool) {
        uint256 n = t.nextId();
        for (uint256 i = 1; i <= n; ++i) {
            if (t.revoked(i)) continue;
            for (uint256 j = i + 1; j <= n; ++j) {
                if (t.revoked(j)) continue;
                if (t.commitmentOf(i) == t.commitmentOf(j)) return false;
            }
        }
        return true;
    }

    function echidna_record_immutable() public view returns (bool) {
        for (uint256 i = 0; i < recordedIds.length; ++i) {
            uint256 id = recordedIds[i];
            if (t.commitmentOf(id) != recordedC[id]) return false;
        }
        return true;
    }

    function echidna_soulbound() public view returns (bool) {
        return !moveSucceeded;
    }

    function echidna_outsider_cannot_mint() public view returns (bool) {
        return !outsiderSucceeded;
    }

    function echidna_revoked_cannot_verify() public view returns (bool) {
        for (uint256 i = 0; i < revokedIds.length; ++i) {
            uint256 id = revokedIds[i];
            if (t.verify(id, t.ownerOf(id), t.commitmentOf(id))) return false;
        }
        return true;
    }
}
