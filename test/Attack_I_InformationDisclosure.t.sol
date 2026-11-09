// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Base} from "./Base.t.sol";

/// @notice I = Information Disclosure. Skenario (Tabel 2.4): inspeksi storage/calldata dan
///         brute-force hash data sintetis berentropi rendah.
///         SEMUA DATA SINTETIS. Jangan pernah menaruh data mahasiswa asli di chain.
contract AttackInfoDisclosureTest is Base {
    // Ruang tebakan penyerang: NIM karangan 2311100001..2311100050, IPK 2.00..4.00, SKS 140..147
    uint64 internal constant NIM_START = 2311100001;
    uint64 internal constant NIM_COUNT = 50;
    uint16 internal constant IPK_START = 200;
    uint16 internal constant IPK_COUNT = 201;
    uint16 internal constant SKS_START = 140;
    uint16 internal constant SKS_COUNT = 8;

    function _bruteForceUnsalted(bytes32 target)
        internal
        pure
        returns (bool found, uint64 nim, uint16 ipk, uint16 sks, uint256 tries)
    {
        for (uint64 n = 0; n < NIM_COUNT; ++n) {
            for (uint16 i = 0; i < IPK_COUNT; ++i) {
                for (uint16 s = 0; s < SKS_COUNT; ++s) {
                    ++tries;
                    if (commitUnsalted(NIM_START + n, IPK_START + i, SKS_START + s) == target) {
                        return (true, NIM_START + n, IPK_START + i, SKS_START + s, tries);
                    }
                }
            }
        }
    }

    /// I1: siapa pun bisa membaca slot storage commitment (private != rahasia).
    ///     Slot 8 = commitmentOf pada v1 (lihat `forge inspect SBTTranskripV1 storageLayout`).
    function test_I1_v1_storageIsPublic_andUnsaltedHashIsBruteForceable() public {
        bytes32 c = commitUnsalted(NIM1, IPK1, SKS1);
        uint256 id = mintV1(student1, c);

        bytes32 slot = keccak256(abi.encode(id, uint256(8)));
        bytes32 raw = vm.load(address(v1), slot);
        assertEq(raw, c); // terbaca langsung dari storage, tanpa panggilan fungsi

        (bool found, uint64 nim, uint16 ipk, uint16 sks, uint256 tries) = _bruteForceUnsalted(raw);
        assertTrue(found);
        assertEq(nim, NIM1);
        assertEq(ipk, IPK1);
        assertEq(sks, SKS1);
        emit log_named_uint("tebakan sampai ketemu (ruang 80.400)", tries);
        _hasil("I1", "v1", "hash tanpa salt di-brute-force dari storage: NIM+IPK+SKS terbongkar", BERHASIL);
    }

    /// I2: pada v2 commitment bergaram (salt 32 byte acak, disimpan off-chain).
    ///     Penyerang yang tidak tahu salt tidak menemukan apa pun di ruang tebakan yang sama.
    function test_I2_v2_saltedCommitment_notBruteForceable() public {
        bytes32 c = commitSalted(SALT1, NIM1, IPK1, SKS1);
        uint256 id = mintV2(student1, c);

        bytes32 slot = keccak256(abi.encode(id, uint256(10))); // _records[id].commitment (word pertama)
        bytes32 raw = vm.load(address(v2), slot);
        assertEq(raw, c); // storage tetap publik, tapi isinya tidak bisa ditebak

        (bool found,,,,) = _bruteForceUnsalted(raw);
        assertFalse(found);

        // Verifier sah yang diberi salt oleh mahasiswa bisa mencocokkan:
        assertTrue(v2.verify(id, student1, commitSalted(SALT1, NIM1, IPK1, SKS1)));
        _hasil("I2", "v2", "commitment bergaram: brute-force di ruang tebakan sama gagal", DITOLAK);
    }

    /// I3: calldata mint tidak memuat NIM/IPK/SKS mentah (hanya alamat, commitment, URI).
    function test_I3_calldataHasNoRawAcademicData() public view {
        bytes memory nimBytes = abi.encodePacked(NIM1);
        bytes memory cd1 = abi.encodeCall(
            v1.mint, (student1, commitUnsalted(NIM1, IPK1, SKS1), "ipfs://contoh")
        );
        bytes memory cd2 = abi.encodeCall(
            v2.mint, (student1, commitSalted(SALT1, NIM1, IPK1, SKS1), "ipfs://contoh")
        );
        assertFalse(_contains(cd1, nimBytes));
        assertFalse(_contains(cd2, nimBytes));
    }

    function _contains(bytes memory hay, bytes memory needle) internal pure returns (bool) {
        if (needle.length == 0 || hay.length < needle.length) return false;
        for (uint256 i = 0; i <= hay.length - needle.length; ++i) {
            bool ok = true;
            for (uint256 j = 0; j < needle.length; ++j) {
                if (hay[i + j] != needle[j]) {
                    ok = false;
                    break;
                }
            }
            if (ok) return true;
        }
        return false;
    }
}
