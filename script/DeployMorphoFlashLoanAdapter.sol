// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {MorphoFlashLoanAdapter} from "src/base/Roles/MorphoFlashLoan/MorphoFlashLoanAdapter.sol";

import "@forge-std/Script.sol";

contract DeployMorphoFlashLoanAdapter is Script, MerkleTreeHelper {
    Deployer public deployer = Deployer(0x771263e3Bc6aCDa5aE388A3F8A0c2dd7A17275FC);

    function setUp() external {}

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;

        vm.createSelectFork("mainnet");
        setSourceChainName("mainnet");

        vm.startBroadcast(vm.envUint("BORING_DEVELOPER"));

        creationCode = type(MorphoFlashLoanAdapter).creationCode;
        constructorArgs = abi.encode(
            getAddress(sourceChain, "morphoBlue"),
            0x279CAD277447965AF3d24a78197aad1B02a2c589,
            0x9B3e565ffC70c4b72516BC2dbec4b3c790940CE8
        );
        deployer.deployContract("MorphoFlashLoanAdapter_syUsdEthereumV2", creationCode, constructorArgs, 0);

        vm.stopBroadcast();
    }
}
