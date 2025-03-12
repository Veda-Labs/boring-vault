// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {BoringDrone} from "src/base/Drones/BoringDrone.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
/**
 *  source .env && forge script script/DeployManager.s.sol:DeployManagerScript --with-gas-price 30000000000 --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */

contract DeployManagerScript is Script, ContractNames, MainnetAddresses, MerkleTreeHelper {
    uint256 public privateKey;
    Deployer public deployer = Deployer(deployerAddress);

    address internal sETHFI = 0x86B5780b606940Eb59A062aA85a07959518c0161;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("mainnet");
        setSourceChainName(mainnet);
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        creationCode = type(ManagerWithMerkleVerification).creationCode;
        constructorArgs = abi.encode(dev0Address, sETHFI, address(0));
        deployer.deployContract("sETHFI Manager with Merkle Verification V0.0", creationCode, constructorArgs, 0);

        vm.stopBroadcast();
    }
}
