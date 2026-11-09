// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IMintable {
    function mint(address to, bytes32 commitment, string calldata uri) external returns (uint256);
}

/// @notice Kontrak penyerang untuk skenario Tampering (reentrancy saat penerbitan).
///         Model ancaman: akun penerbit berupa smart-contract wallet yang juga bertindak sebagai
///         penerima token. Saat menerima token (callback onERC721Received) ia mencoba mint LAGI
///         dengan commitment yang sama.
contract ReentrantIssuer is IERC721Receiver {
    IMintable public target;
    bytes32 public commitment;
    bool public reentered;
    bool public reentrySucceeded;

    function attack(IMintable target_, bytes32 commitment_) external {
        target = target_;
        commitment = commitment_;
        target_.mint(address(this), commitment_, "ipfs://serangan-1");
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        override
        returns (bytes4)
    {
        if (!reentered) {
            reentered = true;
            try target.mint(address(this), commitment, "ipfs://serangan-2") returns (uint256) {
                reentrySucceeded = true;
            } catch {
                reentrySucceeded = false;
            }
        }
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @notice Kontrak "penerbit palsu" untuk skenario Spoofing.
contract FakeIssuer {
    function tryMint(IMintable target, address to, bytes32 commitment) external returns (bool ok) {
        try target.mint(to, commitment, "ipfs://palsu") returns (uint256) {
            ok = true;
        } catch {
            ok = false;
        }
    }
}

/// @notice Penerima token yang valid (bukan penyerang) dan menyimpan token.
contract PlainReceiver is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }
}
