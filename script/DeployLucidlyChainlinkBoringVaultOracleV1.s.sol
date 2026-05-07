// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity >=0.8.0;

import {Deployer} from "src/helper/Deployer.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {AggregatorV3Interface} from "src/adapters/libraries/ChainlinkDataFeedLib.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {LucidlyChainlinkBoringVaultOracleV1} from "src/adapters/oracle/LucidlyChainlinkBoringVaultOracleV1.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

contract DeployLucidlyChainlinkBoringVaultOracleV1Script is Script {
    using stdJson for string;

    Deployer deployer = Deployer(0x771263e3Bc6aCDa5aE388A3F8A0c2dd7A17275FC);

    function run(string memory configFile) external {
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/deployments/oracles/", configFile);
        string memory json = vm.readFile(path);

        vm.createSelectFork("mainnet");

        vm.startBroadcast(vm.envUint(json.readString(".privateKeyEnvName")));

        bytes memory creationCode = type(LucidlyChainlinkBoringVaultOracleV1).creationCode;
        bytes memory constructorArgs = abi.encode(
            json.readAddress(".accountant"),
            json.readAddress(".baseFeed1"),
            json.readAddress(".baseFeed2"),
            uint8(json.readUint(".outputDecimals")),
            json.readString(".name")
        );

        string memory deploymentName = json.readString(".deploymentName");
        deployer.deployContract(deploymentName, creationCode, constructorArgs, 0);

        console.log("Deployed:", deploymentName, deployer.getAddress(deploymentName));

        vm.stopBroadcast();
    }
}
