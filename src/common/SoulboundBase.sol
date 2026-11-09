// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {IERC5192} from "../interfaces/IERC5192.sol";

/// @title SoulboundBase
/// @notice ERC-721 yang tidak bisa dipindah/di-approve (ERC-5192). Dipakai v1 dan v2 supaya
///         satu-satunya perbedaan v1 vs v2 adalah kelemahan/mitigasi yang diteliti.
abstract contract SoulboundBase is ERC721, IERC5192 {
    error SoulboundTokenCannotMove(uint256 tokenId);
    error SoulboundNoApproval();

    function locked(uint256 tokenId) external view returns (bool) {
        _requireOwned(tokenId); // revert kalau token belum/tidak ada
        return true;
    }

    /// @dev Approval dimatikan: SBT tidak boleh punya "operator".
    function approve(address, uint256) public pure override {
        revert SoulboundNoApproval();
    }

    function setApprovalForAll(address, bool) public pure override {
        revert SoulboundNoApproval();
    }

    /// @dev Semua pergerakan token selain mint (dari address(0)) ditolak.
    ///      transferFrom, safeTransferFrom, dan burn semuanya lewat _update.
    function _update(address to, uint256 tokenId, address auth)
        internal
        virtual
        override
        returns (address)
    {
        if (_ownerOf(tokenId) != address(0)) revert SoulboundTokenCannotMove(tokenId);
        return super._update(to, tokenId, auth);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721)
        returns (bool)
    {
        return interfaceId == type(IERC5192).interfaceId || super.supportsInterface(interfaceId);
    }
}
