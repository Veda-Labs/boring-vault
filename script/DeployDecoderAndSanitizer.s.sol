// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ITBPositionDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ITB/ITBPositionDecoderAndSanitizer.sol";
import {EtherFiLiquidUsdDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/EtherFiLiquidUsdDecoderAndSanitizer.sol";
import {PancakeSwapV3FullDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/PancakeSwapV3FullDecoderAndSanitizer.sol";
import {AerodromeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/AerodromeDecoderAndSanitizer.sol";
import {EtherFiLiquidEthDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/EtherFiLiquidEthDecoderAndSanitizer.sol";
import {OnlyKarakDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/OnlyKarakDecoderAndSanitizer.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {PointFarmingDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/PointFarmingDecoderAndSanitizer.sol";
import {OnlyHyperlaneDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/OnlyHyperlaneDecoderAndSanitizer.sol";
import {SwellEtherFiLiquidEthDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/SwellEtherFiLiquidEthDecoderAndSanitizer.sol";
import {sBTCNMaizenetDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/sBTCNMaizenetDecoderAndSanitizer.sol";
import {UniBTCDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/UniBTCDecoderAndSanitizer.sol";
import {EdgeCapitalDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/EdgeCapitalDecoderAndSanitizer.sol";
import {EtherFiLiquidBtcDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/EtherFiLiquidBtcDecoderAndSanitizer.sol";
import {LiquidBeraEthDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/LiquidBeraEthDecoderAndSanitizer.sol"; 
import {SonicMainnetDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SonicEthMainnetDecoderAndSanitizer.sol"; 
import {SonicIncentivesHandlerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SonicIncentivesHandlerDecoderAndSanitizer.sol";
import {AaveV3FullDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/AaveV3FullDecoderAndSanitizer.sol";
import {LombardBtcDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/LombardBtcDecoderAndSanitizer.sol";
import {EtherFiBtcDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/EtherFiBtcDecoderAndSanitizer.sol";
import {SymbioticLRTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SymbioticLRTDecoderAndSanitizer.sol";
import {eBTCBerachainDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/eBTCBerachainDecoderAndSanitizer.sol"; 

import {BoringDrone} from "src/base/Drones/BoringDrone.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";
/**
 *  source .env && forge script script/DeployDecoderAndSanitizer.s.sol:DeployDecoderAndSanitizerScript --with-gas-price 30000000000 --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */

contract DeployDecoderAndSanitizerScript is Script, ContractNames, MainnetAddresses {
    uint256 public privateKey;
    Deployer public deployer = Deployer(deployerAddress);

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        creationCode = type(SonicMainnetDecoderAndSanitizer).creationCode;
        constructorArgs = abi.encode(uniswapV3NonFungiblePositionManager);
        deployer.deployContract("Sonic BTC Decoder and Sanitizer V0.1", creationCode, constructorArgs, 0);

        vm.stopBroadcast();
    }
}
