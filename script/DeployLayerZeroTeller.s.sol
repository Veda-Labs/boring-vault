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

    // address internal weth = 0x5300000000000000000000000000000000000004;
    address internal weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address internal lzEndPoint = 0x1a44076050125825900e736c501f859c50fE728c;
    address internal delegate = dev1Address; // I do not think we need this functionality, but for future use, setDelegate has a requires auth modifier so it can be changed.

    address internal liquidETH = 0xf0bb20865277aBd641a307eCe5Ee04E79073416C;
    address internal liquidETHAccountant = 0x0d05D94a5F1E76C18fbeB7A13d17C8a314088198;

    address internal liquidUSD = 0x08c6F91e2B681FaF5e17227F2a44C307b3C1364C;
    address internal liquidUSDAccountant = 0xc315D6e14DDCDC7407784e2Caf815d131Bc1D3E7;

    address internal eUSD = 0x939778D83b46B456224A33Fb59630B11DEC56663;
    address internal eUSDAccountant = 0xEB440B36f61Bf62E0C54C622944545f159C3B790;

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

        constructorArgs =
            abi.encode(dev1Address, liquidETH, liquidETHAccountant, weth, lzEndPoint, delegate, address(0));
        layerZeroTeller = LayerZeroTellerWithRateLimiting(
            deployer.deployContract("LiquidETH LayerZero Teller V0.0", creationCode, constructorArgs, 0)
        );

        constructorArgs =
            abi.encode(dev1Address, liquidUSD, liquidUSDAccountant, weth, lzEndPoint, delegate, address(0));
        layerZeroTeller = LayerZeroTellerWithRateLimiting(
            deployer.deployContract("LiquidUSD LayerZero Teller V0.0", creationCode, constructorArgs, 0)
        );

        constructorArgs = abi.encode(dev1Address, eUSD, eUSDAccountant, weth, lzEndPoint, delegate, address(0));
        layerZeroTeller = LayerZeroTellerWithRateLimiting(
            deployer.deployContract("eUSD LayerZero Teller V0.0", creationCode, constructorArgs, 0)
        );

        vm.stopBroadcast();
    }
}
