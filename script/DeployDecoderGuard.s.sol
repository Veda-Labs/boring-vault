// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {ArbitrumAddresses} from "test/resources/ArbitrumAddresses.sol";
import {
    AaveGuardDecoderAndSanitizer,
    AaveV3DecoderAndSanitizer,
    BaseDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/AaveGuardDecoderAndSanitizer.sol";
import {DecoderGuard} from "src/base/Gnosis/DecoderGuard.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  forge script script/DeployDecoderGuard.s.sol:DeployDecoderGuardScript --broadcast --verify
 *
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployDecoderGuardScript is Script, ContractNames, ArbitrumAddresses {
    uint256 public privateKey;

    // Contracts to deploy
    Deployer public deployer;
    DecoderGuard public decoderGuard;
    address public gnosisSafe = 0x5061F6517591804391b38937c99057014B1EDb78;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("arbitrum");
    }

    function run() external {
        bytes memory constructorArgs;
        bytes memory creationCode;
        vm.startBroadcast(privateKey);

        deployer = Deployer(deployerAddress);

        // Deploy AaveGuardDecoderAndSanitizer
        creationCode = type(AaveGuardDecoderAndSanitizer).creationCode;
        constructorArgs = hex"";
        address aaveGuardDecoderAndSanitizer =
            deployer.deployContract("AaveGuardDecoderAndSanitizer V0.0", creationCode, constructorArgs, 0);

        // Deploy DecoderGuard
        creationCode = type(DecoderGuard).creationCode;
        constructorArgs = abi.encode(dev0Address, Authority(address(0)), aaveGuardDecoderAndSanitizer);
        decoderGuard = DecoderGuard(deployer.deployContract("DecoderGuard V0.0", creationCode, constructorArgs, 0));

        // Add approved calls to decoderGuard.
        bytes memory exampleData;

        // Approve Aave V3 pool to spend wETH
        exampleData = abi.encodeWithSelector(BaseDecoderAndSanitizer.approve.selector, v3Pool, 0);
        decoderGuard.makeDigestValid(address(WETH), 0, exampleData);

        // Approve Aave V3 pool to spend USDC
        exampleData = abi.encodeWithSelector(BaseDecoderAndSanitizer.approve.selector, v3Pool, 0);
        decoderGuard.makeDigestValid(address(USDC), 0, exampleData);

        // Supply wETH to Aave V3 pool
        exampleData = abi.encodeWithSelector(AaveV3DecoderAndSanitizer.supply.selector, address(WETH), 0, gnosisSafe, 0);
        decoderGuard.makeDigestValid(address(v3Pool), 0, exampleData);

        // Borrow USDC from Aave V3 pool
        exampleData =
            abi.encodeWithSelector(AaveV3DecoderAndSanitizer.borrow.selector, address(USDC), 0, 0, 0, gnosisSafe);
        decoderGuard.makeDigestValid(address(v3Pool), 0, exampleData);

        // Repay USDC to Aave V3 pool
        exampleData = abi.encodeWithSelector(AaveV3DecoderAndSanitizer.repay.selector, address(USDC), 0, 0, gnosisSafe);
        decoderGuard.makeDigestValid(address(v3Pool), 0, exampleData);

        // Withdraw wETH from Aave V3 pool
        exampleData = abi.encodeWithSelector(AaveV3DecoderAndSanitizer.withdraw.selector, address(WETH), 0, gnosisSafe);
        decoderGuard.makeDigestValid(address(v3Pool), 0, exampleData);

        vm.stopBroadcast();
    }
}
