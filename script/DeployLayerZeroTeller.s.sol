// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {LayerZeroTellerWithRateLimiting} from
    "src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTellerWithRateLimiting.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployLayerZeroTeller.s.sol:DeployLayerZeroTellerScript --with-gas-price 15000000000 --broadcast --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployLayerZeroTellerScript is Script, ContractNames, MainnetAddresses {
    uint256 public privateKey;

    // Contracts to deploy
    RolesAuthority public rolesAuthority;
    Deployer public deployer;
    LayerZeroTellerWithRateLimiting public layerZeroTeller;
    address internal weth = address(WETH);
    address internal boringVault = 0x657e8C867D8B37dCC18fA4Caead9C45EB088C642;
    address internal accountant = 0x1b293DC39F94157fA0D1D36d7e0090C8B8B8c13F;
    address internal lzEndPoint = 0x1a44076050125825900e736c501f859c50fE728c;
    address internal delegate = address(1); // I do not think we need this functionality, but for future use, setDelegate has a requires auth modifier so it can be changed.

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        deployer = Deployer(deployerAddress);
        creationCode = type(LayerZeroTellerWithRateLimiting).creationCode;
        constructorArgs = abi.encode(dev1Address, boringVault, accountant, weth, lzEndPoint, delegate, address(0));
        layerZeroTeller = LayerZeroTellerWithRateLimiting(
            deployer.deployContract("eBTC LayerZero Teller V0.0", creationCode, constructorArgs, 0)
        );

        vm.stopBroadcast();
    }
}