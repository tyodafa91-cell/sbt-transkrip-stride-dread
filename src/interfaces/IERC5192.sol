// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IERC5192 - Minimal Soulbound NFTs (EIP-5192)
/// @notice Interface ID = 0xb45a3c0e
interface IERC5192 {
    /// Token terkunci (tidak bisa dipindah).
    event Locked(uint256 tokenId);
    /// Token tidak terkunci lagi (tidak dipakai di proyek ini: SBT transkrip selalu terkunci).
    event Unlocked(uint256 tokenId);

    /// @notice Status kunci token. Revert kalau token tidak ada.
    function locked(uint256 tokenId) external view returns (bool);
}
