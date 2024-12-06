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
import {BoringModule} from "src/base/Gnosis/BoringModule.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {DroneLib} from "src/base/Drones/DroneLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ISafe} from "src/interfaces/ISafe.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  forge script script/DeployDecoderGuard.s.sol:DeployDecoderGuardScript --broadcast --verify
 *
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployDecoderGuardScript is Script, ContractNames, ArbitrumAddresses {
    using Address for address;

    uint256 public privateKey;

    // Contracts to deploy
    Deployer public deployer;
    DecoderGuard public decoderGuard;
    address public gnosisSafe = 0x5061F6517591804391b38937c99057014B1EDb78;
    address public multiSend = 0x9641d764fc13c8B624c04430C7356C1C7C8102e2;

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
        // creationCode = type(AaveGuardDecoderAndSanitizer).creationCode;
        // constructorArgs = hex"";
        // address aaveGuardDecoderAndSanitizer =
        //     deployer.deployContract("AaveGuardDecoderAndSanitizer V0.0", creationCode, constructorArgs, 0);
        address aaveGuardDecoderAndSanitizer = 0xc0048dfC91C33dc3F78D4F86ffC8c6B8de971f0E;

        // Deploy DecoderGuard
        creationCode = type(DecoderGuard).creationCode;
        constructorArgs = abi.encode(dev0Address, Authority(address(0)), aaveGuardDecoderAndSanitizer, multiSend);
        decoderGuard = DecoderGuard(deployer.deployContract("DecoderGuard V0.1", creationCode, constructorArgs, 0));

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

        // Deploy BoringModule
        // creationCode = type(BoringModule).creationCode;
        // constructorArgs = abi.encode(dev0Address, 0, gnosisSafe);
        // deployer.deployContract("BoringModule V0.0", creationCode, constructorArgs, 0);

        // Use the module to update the transaction guard.
        address module = 0xF5Ad9688D79b02508e8f0b1a698415746AEee81D;

        address realTarget = gnosisSafe;
        bytes memory moduleData =
            abi.encodeWithSelector(ISafe.setGuard.selector, decoderGuard, realTarget, DroneLib.TARGET_FLAG);
        module.functionCall(moduleData);
        vm.stopBroadcast();
    }
}
