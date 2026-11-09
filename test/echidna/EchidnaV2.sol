// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IssuerRegistry} from "../../src/IssuerRegistry.sol";
import {SBTTranskripV2} from "../../src/v2/SBTTranskripV2.sol";

/// @notice Pihak luar (tanpa peran) yang mencoba aksi terlarang.
contract OutsiderV2 {
    function tryMint(SBTTranskripV2 t, address to, bytes32 c) external returns (bool ok) {
        try t.mint(to, c, "x") returns (uint256) {
            ok = true;
        } catch {}
    }
}

/// @title EchidnaV2 - harness fuzzing untuk SBTTranskripV2
/// @notice Jalankan:  echidna test/echidna/EchidnaV2.sol --contract EchidnaV2 --config echidna.yaml
///   HARAPAN untuk v2 (versi mitigasi): SEMUA properti LULUS.
/// Properti unique_commitment = paling banyak SATU token AKTIF (belum dicabut) per commitment
/// (reissue sah membuat token baru dengan commitment sama, tetapi token lama dicabut).
/// Harness ini = admin + accreditor + issuer sekaligus, dan juga penerima token (callback).
contract EchidnaV2 is IERC721Receiver {
    bytes32 internal constant ACCREDITOR_ROLE = keccak256("ACCREDITOR_ROLE");
    bytes32 internal constant ISSUER_ROLE = keccak256("ISSUER_ROLE");

    IssuerRegistry internal reg;
    SBTTranskripV2 internal t;
    OutsiderV2 internal outsider;

    bool internal reenterOn;
    bool internal inCallback;
    bytes32 internal currentC;

    bool internal outsiderSucceeded;
    bool internal moveSucceeded;
    bool internal mintedWhileDeaccredited;
    uint256[] internal recordedIds;
    mapping(uint256 => bytes32) internal recordedC;
    uint256[] internal revokedIds;

    constructor() {
        reg = new IssuerRegistry(address(this));
        t = new SBTTranskripV2(address(this), reg);
        reg.grantRole(ACCREDITOR_ROLE, address(this));
        reg.registerIssuer(address(this));
        t.grantRole(ISSUER_ROLE, address(this));
        outsider = new OutsiderV2();
    }

    // ----------------------------- aksi yang dipicu fuzzer -----------------------------
    function setReenter(bool on) public {
        reenterOn = on;
    }

    function doMint(uint8 who, uint8 k) public {
        address to = (who % 2 == 0) ? address(this) : address(uint160(0x1000 + (who % 4)));
        bytes32 c = keccak256(abi.encode("c", k % 4));
        currentC = c;
        bool wasActive = reg.isActiveIssuer(address(this));
        try t.mint(to, c, "x") returns (uint256 id) {
            if (!wasActive) mintedWhileDeaccredited = true;
            recordedC[id] = c;
            recordedIds.push(id);
        } catch {}
    }

    function doRevoke(uint8 idx) public {
        if (recordedIds.length == 0) return;
        uint256 id = recordedIds[idx % recordedIds.length];
        try t.revoke(id, bytes32(0)) {
            revokedIds.push(id);
        } catch {}
    }

    function doReissue(uint8 idx, uint8 who) public {
        if (recordedIds.length == 0) return;
        uint256 id = recordedIds[idx % recordedIds.length];
        address to = address(uint160(0x2000 + (who % 4)));
        bool wasActive = reg.isActiveIssuer(address(this));
        try t.reissue(id, to, bytes32(0)) returns (uint256 newId) {
            if (!wasActive) mintedWhileDeaccredited = true;
            recordedC[newId] = recordedC[id];
            recordedIds.push(newId);
            revokedIds.push(id);
        } catch {}
    }

    function doDeaccredit() public {
        try reg.revokeIssuer(address(this)) {} catch {}
    }

    function doAccredit() public {
        try reg.registerIssuer(address(this)) {} catch {}
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
            if (t.recordOf(i).revoked) continue;
            for (uint256 j = i + 1; j <= n; ++j) {
                if (t.recordOf(j).revoked) continue;
                if (t.recordOf(i).commitment == t.recordOf(j).commitment) return false;
            }
        }
        return true;
    }

    function echidna_record_immutable() public view returns (bool) {
        for (uint256 i = 0; i < recordedIds.length; ++i) {
            uint256 id = recordedIds[i];
            if (t.recordOf(id).commitment != recordedC[id]) return false;
        }
        return true;
    }

    function echidna_soulbound() public view returns (bool) {
        return !moveSucceeded;
    }

    function echidna_outsider_cannot_mint() public view returns (bool) {
        return !outsiderSucceeded;
    }

    function echidna_deaccredited_cannot_mint() public view returns (bool) {
        return !mintedWhileDeaccredited;
    }

    function echidna_revoked_cannot_verify() public view returns (bool) {
        for (uint256 i = 0; i < revokedIds.length; ++i) {
            uint256 id = revokedIds[i];
            if (t.verify(id, t.ownerOf(id), t.recordOf(id).commitment)) return false;
        }
        return true;
    }
}
