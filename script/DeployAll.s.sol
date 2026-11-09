// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {IssuerRegistry} from "../src/IssuerRegistry.sol";
import {SBTTranskripV1} from "../src/v1/SBTTranskripV1.sol";
import {SBTTranskripV2} from "../src/v2/SBTTranskripV2.sol";

/// @notice Deploy v1, IssuerRegistry, v2 dengan AKUN TERPISAH per peran (Tabel 2.2 no. 6):
///   PRIVATE_KEY     = Admin (deployer, DEFAULT_ADMIN_ROLE)
///   ACCREDITOR_KEY  = Accreditor (ACCREDITOR_ROLE di registry, memanggil registerIssuer)
///   ISSUER_KEY      = Issuer (ISSUER_ROLE di v2; owner tunggal di v1 baseline)
/// Holder, Verifier, Attacker cukup ALAMAT (verifier & attacker tidak mengirim transaksi).
/// Bila saldo Accreditor/Issuer kurang dari FUND_WEI, Admin mengirimkan selisihnya (default 0.01 ETH).
/// Alamat hasil deploy ditulis ke deployments/<chainId>.env
contract DeployAll is Script {
    bytes32 internal constant ACCREDITOR_ROLE = keccak256("ACCREDITOR_ROLE");
    bytes32 internal constant ISSUER_ROLE = keccak256("ISSUER_ROLE");

    function run() external {
        uint256 adminPk = vm.envUint("PRIVATE_KEY");
        uint256 accPk = vm.envUint("ACCREDITOR_KEY");
        uint256 issPk = vm.envUint("ISSUER_KEY");
        uint256 fund = vm.envOr("FUND_WEI", uint256(0.01 ether));
        address admin = vm.addr(adminPk);
        address accreditor = vm.addr(accPk);
        address issuer = vm.addr(issPk);
        require(admin != accreditor && admin != issuer && accreditor != issuer, "pakai 3 akun berbeda");

        // 1) Admin: deploy + bagi peran (+ isi saldo bila perlu)
        vm.startBroadcast(adminPk);
        SBTTranskripV1 v1 = new SBTTranskripV1(issuer);
        IssuerRegistry reg = new IssuerRegistry(admin);
        SBTTranskripV2 v2 = new SBTTranskripV2(admin, reg);
        reg.grantRole(ACCREDITOR_ROLE, accreditor);
        v2.grantRole(ISSUER_ROLE, issuer);
        if (accreditor.balance < fund) payable(accreditor).transfer(fund - accreditor.balance);
        if (issuer.balance < fund) payable(issuer).transfer(fund - issuer.balance);
        vm.stopBroadcast();

        // 2) Accreditor: daftarkan Issuer di registry
        vm.startBroadcast(accPk);
        reg.registerIssuer(issuer);
        vm.stopBroadcast();

        console.log("V1         :", address(v1));
        console.log("REG        :", address(reg));
        console.log("V2         :", address(v2));
        console.log("ADMIN      :", admin);
        console.log("ACCREDITOR :", accreditor);
        console.log("ISSUER     :", issuer);

        string memory path = string.concat("deployments/", vm.toString(block.chainid), ".env");
        vm.writeFile(
            path,
            string.concat(
                "V1=", vm.toString(address(v1)),
                "\nREG=", vm.toString(address(reg)),
                "\nV2=", vm.toString(address(v2)),
                "\nADMIN=", vm.toString(admin),
                "\nACCREDITOR=", vm.toString(accreditor),
                "\nISSUER=", vm.toString(issuer),
                "\n"
            )
        );
        console.log("Alamat ditulis ke:", path);
    }
}
