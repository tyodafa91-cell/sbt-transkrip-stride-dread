// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/// @title IssuerRegistry (dipakai v2)
/// @notice Daftar penerbit (institusi) terakreditasi. Hanya pemegang ACCREDITOR_ROLE yang boleh
///         mendaftarkan atau mencabut penerbit. ACCREDITOR_ROLE (registry) sengaja dipisah dari
///         ISSUER_ROLE (kontrak token) = pemisahan tugas.
///         Fungsi sesuai spesifikasi proposal (subbab 2.3.3): registerIssuer().
contract IssuerRegistry is AccessControl {
    bytes32 public constant ACCREDITOR_ROLE = keccak256("ACCREDITOR_ROLE");

    mapping(address => bool) private _active;

    event IssuerRegistered(address indexed issuer, address indexed by);
    event IssuerRevoked(address indexed issuer, address indexed by);

    error AlreadyRegistered(address issuer);
    error NotRegistered(address issuer);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    function registerIssuer(address issuer) external onlyRole(ACCREDITOR_ROLE) {
        if (_active[issuer]) revert AlreadyRegistered(issuer);
        _active[issuer] = true;
        emit IssuerRegistered(issuer, msg.sender);
    }

    function revokeIssuer(address issuer) external onlyRole(ACCREDITOR_ROLE) {
        if (!_active[issuer]) revert NotRegistered(issuer);
        _active[issuer] = false;
        emit IssuerRevoked(issuer, msg.sender);
    }

    function isActiveIssuer(address issuer) external view returns (bool) {
        return _active[issuer];
    }
}
