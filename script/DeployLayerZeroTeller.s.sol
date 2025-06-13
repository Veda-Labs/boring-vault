// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {LayerZeroTeller} from "src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTeller.sol";
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
    LayerZeroTeller public layerZeroTeller;
    address internal deployerAddress = 0x00bF0B30655a43Af93c1b371Be021Bd4567c51d5;
    address internal dev1Address = 0x9DBEab770dA635f828AB42433195DC73D57Fd20F;
    address internal weth = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal boringVault = 0x0CDF04e97aef579ef20661c0FA445593948790F3;
    address internal accountant = 0x8970180d667A95ad1399fF7Dd57d4b5061B0244c;
    address internal lzEndPoint = 0x1a44076050125825900e736c501f859c50fE728c;
    address internal lzToken = 0x6985884C4392D348587B19cb9eAAf157F13271cd;
    address internal rolesAuthorityAddress = 0x2B9A752B7407D37A16A089c2A28d39d08EdB108D;
    address internal delegate = dev1Address; // I do not think we need this functionality, but for future use, setDelegate has a requires auth modifier so it can be changed.

    function setUp() external {
        privateKey = vm.envUint("PLASMA_DEPLOYER_KEY");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        deployer = Deployer(deployerAddress);
        rolesAuthority = RolesAuthority(rolesAuthorityAddress);
        creationCode = type(LayerZeroTeller).creationCode;
        constructorArgs = abi.encode(dev1Address, boringVault, accountant, weth, lzEndPoint, delegate, lzToken);
        layerZeroTeller =
            LayerZeroTeller(deployer.deployContract("Plasma USD Vault Teller V0.2", creationCode, constructorArgs, 0));
        layerZeroTeller.setAuthority(rolesAuthority);

        vm.stopBroadcast();
    }
}
