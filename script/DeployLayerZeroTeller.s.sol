// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {LayerZeroTeller} from "src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTeller.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
import {AccountantWithFixedRate} from "src/base/Roles/AccountantWithFixedRate.sol";

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
    address internal deployerAddress = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d;
    address internal dev1Address = 0xf8553c8552f906C19286F21711721E206EE4909E;
    address internal weth = 0x6969696969696969696969696969696969696969;
    address internal lzEndPoint = 0x6F475642a6e85809B1c36Fa62763669b1b48DD5B;
    address internal delegate = dev1Address; // I do not think we need this functionality, but for future use, setDelegate has a requires auth modifier so it can be changed.

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("berachain");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        deployer = Deployer(deployerAddress);

        address primeBeraBtc = 0x46fcd35431f5B371224ACC2e2E91732867B1A77e;
        creationCode = type(AccountantWithFixedRate).creationCode;
        constructorArgs = abi.encode(
            dev1Address,
            primeBeraBtc,
            0x91A2caD3C28c08783b684080585dE1593268E2ef,
            1e8,
            0x0555E30da8f98308EdB960aa94C0Db47230d2B9c,
            10050,
            9950,
            21600,
            200,
            0
        );
        address primeBeraBtcAccountant =
            deployer.deployContract("Prime Bera BTC Accountant With Fixed Rate V0.1", creationCode, constructorArgs, 0);

        creationCode = type(LayerZeroTeller).creationCode;
        constructorArgs =
            abi.encode(dev1Address, primeBeraBtc, primeBeraBtcAccountant, weth, lzEndPoint, delegate, address(0));
        address primeBeraBtcTeller =
            deployer.deployContract("Prime Bera BTC LayerZero Teller V0.1", creationCode, constructorArgs, 0);

        address primeBeraEth = 0xB83742330443f7413DBD2aBdfc046dB0474a944e;
        creationCode = type(AccountantWithFixedRate).creationCode;
        constructorArgs = abi.encode(
            dev1Address,
            primeBeraEth,
            0x91A2caD3C28c08783b684080585dE1593268E2ef,
            1e18,
            0x2F6F07CDcf3588944Bf4C42aC74ff24bF56e7590,
            10050,
            9950,
            21600,
            200,
            0
        );
        address primeBeraEthAccountant =
            deployer.deployContract("Prime Bera ETH Accountant With Fixed Rate V0.1", creationCode, constructorArgs, 0);

        creationCode = type(LayerZeroTeller).creationCode;
        constructorArgs =
            abi.encode(dev1Address, primeBeraEth, primeBeraEthAccountant, weth, lzEndPoint, delegate, address(0));
        address primeBeraEthTeller =
            deployer.deployContract("Prime Bera ETH LayerZero Teller V0.1", creationCode, constructorArgs, 0);

        vm.stopBroadcast();
    }
}
