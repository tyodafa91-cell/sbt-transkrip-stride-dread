// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {SoulboundBase} from "../common/SoulboundBase.sol";

/// @title SBTTranskripV1 - BASELINE (SENGAJA RENTAN, JANGAN DIPAKAI SUNGGUHAN)
/// @notice Dipakai hanya sebagai pembanding penelitian STRIDE/DREAD. Kelemahan sengaja:
///   [E/S] satu owner = satu-satunya penerbit, tidak ada akreditasi/pemisahan tugas
///   [T]   mint() memanggil _safeMint SEBELUM menandai commitment (reentrancy), tanpa ReentrancyGuard
///   [T]   updateRecord(): commitment & URI bisa diubah setelah mint
///   [R]   revoke()/revokeMany()/updateRecord() tidak mengeluarkan event
///   [I]   commitment = keccak256 tanpa salt (ruang tebakan kecil bisa di-brute-force)
///   [D]   revokeMany() tanpa batas jumlah (loop tak terbatas)
contract SBTTranskripV1 is SoulboundBase, Ownable {
    uint256 public nextId;
    mapping(uint256 => bytes32) public commitmentOf;
    mapping(uint256 => bool) public revoked;
    mapping(bytes32 => bool) public commitmentIssued;
    mapping(uint256 => string) private _uri;

    constructor(address initialOwner)
        ERC721("SBT Transkrip V1", "SBTT1")
        Ownable(initialOwner)
    {}

    function mint(address to, bytes32 commitment, string calldata uri)
        external
        onlyOwner
        returns (uint256 id)
    {
        require(!commitmentIssued[commitment], "sudah terbit");
        id = ++nextId;
        _safeMint(to, id); // KELEMAHAN: interaksi eksternal dulu ...
        commitmentIssued[commitment] = true; // ... baru efek (state) dicatat
        commitmentOf[id] = commitment;
        _uri[id] = uri;
        emit Locked(id);
    }

    function revoke(uint256 id) external onlyOwner {
        _requireOwned(id);
        revoked[id] = true; // KELEMAHAN: tanpa event
    }

    function revokeMany(uint256[] calldata ids) external onlyOwner {
        for (uint256 i = 0; i < ids.length; ++i) {
            // KELEMAHAN: tanpa batas jumlah, tanpa event
            _requireOwned(ids[i]);
            revoked[ids[i]] = true;
        }
    }

    /// Terbit ulang ke dompet baru (dompet lama hilang). KELEMAHAN: tanpa event, tanpa pemisahan peran,
    /// dan tidak mengecek apakah oldId masih token terbaru (bisa menghasilkan 2 token aktif).
    function reissue(uint256 oldId, address newHolder) external onlyOwner returns (uint256 newId) {
        _requireOwned(oldId);
        revoked[oldId] = true;
        newId = ++nextId;
        _safeMint(newHolder, newId);
        commitmentOf[newId] = commitmentOf[oldId];
        _uri[newId] = _uri[oldId];
        emit Locked(newId);
    }

    function updateRecord(uint256 id, bytes32 commitment, string calldata uri) external onlyOwner {
        _requireOwned(id);
        commitmentOf[id] = commitment; // KELEMAHAN: data bisa diubah setelah terbit, tanpa jejak
        _uri[id] = uri;
    }

    function verify(uint256 id, address holder, bytes32 commitment) external view returns (bool) {
        address o = _ownerOf(id);
        return o != address(0) && o == holder && !revoked[id] && commitmentOf[id] == commitment;
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        _requireOwned(id);
        return _uri[id];
    }
}
