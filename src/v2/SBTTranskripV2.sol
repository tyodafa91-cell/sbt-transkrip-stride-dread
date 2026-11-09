// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {SoulboundBase} from "../common/SoulboundBase.sol";
import {IssuerRegistry} from "../IssuerRegistry.sol";

/// @title SBTTranskripV2 - versi dengan mitigasi
/// @notice Mitigasi terhadap kelemahan v1:
///   [E/S] AccessControl: ISSUER_ROLE (token) + ACCREDITOR_ROLE (registry); mint wajib penerbit
///         terakreditasi; verify() menolak penerbit yang tidak terdaftar/dicabut
///   [T]   Checks-Effects-Interactions + ReentrancyGuard; record tidak bisa diubah setelah terbit
///   [R]   Event untuk semua operasi penting (Issued, Revoked, + event registry & role)
///   [I]   commitment bergaram (salt acak 32 byte disimpan di luar chain), dihitung off-chain
///   [D]   revokeBatch dibatasi MAX_REVOKE_PER_TX per transaksi
/// Kebutuhan fungsional tambahan (proposal 2.3.2): reissue() menerbitkan ulang token ke alamat
/// baru bila dompet holder hilang, SETELAH identitas holder diverifikasi off-chain oleh penerbit.
contract SBTTranskripV2 is SoulboundBase, AccessControl, ReentrancyGuard {
    bytes32 public constant ISSUER_ROLE = keccak256("ISSUER_ROLE");
    uint256 public constant MAX_REVOKE_PER_TX = 50;

    struct Record {
        bytes32 commitment;
        address issuer;
        uint64 issuedAt;
        bool revoked;
    }

    IssuerRegistry public immutable registry;
    uint256 public nextId;
    mapping(bytes32 => bool) public commitmentIssued;
    mapping(uint256 => Record) private _records;
    mapping(uint256 => string) private _uri;
    /// Token terbaru untuk tiap commitment (hanya token ini yang boleh diterbitkan ulang)
    mapping(bytes32 => uint256) public currentTokenOf;

    event Issued(
        uint256 indexed tokenId,
        address indexed holder,
        address indexed issuer,
        bytes32 commitment
    );
    event Revoked(uint256 indexed tokenId, address indexed issuer, bytes32 reason);
    event Reissued(uint256 indexed oldTokenId, uint256 indexed newTokenId, address indexed newHolder);

    error IssuerNotAccredited(address issuer);
    error CommitmentAlreadyIssued(bytes32 commitment);
    error NotTokenIssuer(uint256 tokenId, address caller);
    error AlreadyRevoked(uint256 tokenId);
    error BatchTooLarge(uint256 given, uint256 max);
    error InvalidNewHolder(address newHolder);
    error NotCurrentToken(uint256 tokenId, uint256 current);

    constructor(address admin, IssuerRegistry registry_) ERC721("SBT Transkrip V2", "SBTT2") {
        registry = registry_;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function mint(address to, bytes32 commitment, string calldata uri)
        external
        nonReentrant
        onlyRole(ISSUER_ROLE)
        returns (uint256 id)
    {
        if (!registry.isActiveIssuer(msg.sender)) revert IssuerNotAccredited(msg.sender);
        if (commitmentIssued[commitment]) revert CommitmentAlreadyIssued(commitment);

        // Effects dulu
        commitmentIssued[commitment] = true;
        id = ++nextId;
        _records[id] = Record(commitment, msg.sender, uint64(block.timestamp), false);
        currentTokenOf[commitment] = id;
        _uri[id] = uri;
        emit Issued(id, to, msg.sender, commitment);
        emit Locked(id);

        // Interaction terakhir
        _safeMint(to, id);
    }

    /// @notice Terbit ulang ke dompet baru (dompet lama hilang). Token lama dicabut, token baru
    ///         membawa commitment & URI yang sama. Hanya penerbit asli yang masih terakreditasi.
    ///         Verifikasi identitas holder dilakukan OFF-CHAIN sebelum fungsi ini dipanggil.
    function reissue(uint256 oldId, address newHolder, bytes32 reason)
        external
        nonReentrant
        onlyRole(ISSUER_ROLE)
        returns (uint256 newId)
    {
        if (!registry.isActiveIssuer(msg.sender)) revert IssuerNotAccredited(msg.sender);
        address oldHolder = _requireOwned(oldId);
        if (newHolder == address(0) || newHolder == oldHolder) revert InvalidNewHolder(newHolder);
        Record storage old = _records[oldId];
        if (old.issuer != msg.sender) revert NotTokenIssuer(oldId, msg.sender);
        uint256 cur = currentTokenOf[old.commitment];
        if (cur != oldId) revert NotCurrentToken(oldId, cur); // cegah 2 token aktif untuk 1 commitment

        // Effects
        if (!old.revoked) {
            old.revoked = true;
            emit Revoked(oldId, msg.sender, reason);
        }
        newId = ++nextId;
        currentTokenOf[old.commitment] = newId;
        _records[newId] = Record(old.commitment, msg.sender, uint64(block.timestamp), false);
        _uri[newId] = _uri[oldId];
        emit Issued(newId, newHolder, msg.sender, old.commitment);
        emit Reissued(oldId, newId, newHolder);
        emit Locked(newId);

        // Interaction
        _safeMint(newHolder, newId);
    }

    function revoke(uint256 id, bytes32 reason) external onlyRole(ISSUER_ROLE) {
        _revoke(id, reason);
    }

    function revokeBatch(uint256[] calldata ids, bytes32 reason) external onlyRole(ISSUER_ROLE) {
        if (ids.length > MAX_REVOKE_PER_TX) revert BatchTooLarge(ids.length, MAX_REVOKE_PER_TX);
        for (uint256 i = 0; i < ids.length; ++i) {
            _revoke(ids[i], reason);
        }
    }

    function _revoke(uint256 id, bytes32 reason) internal {
        _requireOwned(id);
        Record storage r = _records[id];
        if (r.issuer != msg.sender) revert NotTokenIssuer(id, msg.sender);
        if (r.revoked) revert AlreadyRevoked(id);
        r.revoked = true;
        emit Revoked(id, msg.sender, reason);
    }

    function verify(uint256 id, address holder, bytes32 commitment) external view returns (bool) {
        address o = _ownerOf(id);
        if (o == address(0) || o != holder) return false;
        Record storage r = _records[id];
        if (r.revoked || r.commitment != commitment) return false;
        return registry.isActiveIssuer(r.issuer);
    }

    function recordOf(uint256 id) external view returns (Record memory) {
        _requireOwned(id);
        return _records[id];
    }

    function tokenURI(uint256 id) public view override returns (string memory) {
        _requireOwned(id);
        return _uri[id];
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(SoulboundBase, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
