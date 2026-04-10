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
            0x5373690c930553648f0aaA2e53B51f0C59290B7d,
            0x82D80b2e4B30eC260D282d7988a72e3365f85673
        );
        deployer.deployContract("MorphoFlashLoanAdapter_ETHUSDCarryCluster", creationCode, constructorArgs, 0);

        vm.stopBroadcast();
    }
}
