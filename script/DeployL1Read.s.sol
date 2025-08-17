// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ChainValues} from "test/resources/ChainValues.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {L1Read} from "test/resources/L1Read.sol";
import {Deployer} from "src/helper/Deployer.sol";
import "forge-std/Script.sol";

contract DeployL1Read is Script, MerkleTreeHelper {
    uint256 public pk;
    Deployer public deployer = Deployer(0x771263e3Bc6aCDa5aE388A3F8A0c2dd7A17275FC);

    function setUp() external {
        pk = vm.envUint("BORING_DEVELOPER");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;

        vm.createSelectFork("hyperevm");
        setSourceChainName("hyperevm");
        vm.startBroadcast(pk);
        creationCode = type(L1Read).creationCode;
        deployer.deployContract("Lucidly L1Read", creationCode, constructorArgs, 0);
        vm.stopBroadcast();
    }
}
