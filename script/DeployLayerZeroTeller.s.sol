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
contract DeployLayerZeroTellerScript is Script, ContractNames {
    uint256 public privateKey;

    // Contracts to deploy
    RolesAuthority public rolesAuthority;
    Deployer public deployer;
    LayerZeroTellerWithRateLimiting public layerZeroTeller;
    address internal deployerAddress = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d;
    address internal dev1Address = 0xf8553c8552f906C19286F21711721E206EE4909E;
    address internal weth = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38;
    address internal boringVault = 0x657e8C867D8B37dCC18fA4Caead9C45EB088C642;
    address internal accountant = 0x1b293DC39F94157fA0D1D36d7e0090C8B8B8c13F;
    address internal lzEndPoint = 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B;
    address internal delegate = dev1Address; // I do not think we need this functionality, but for future use, setDelegate has a requires auth modifier so it can be changed.

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("sonicMainnet");
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
