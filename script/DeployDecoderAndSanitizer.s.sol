// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ChainValues} from "test/resources/ChainValues.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

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
import {SonicEthMainnetDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SonicEthMainnetDecoderAndSanitizer.sol";
import {AaveV3FullDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/AaveV3FullDecoderAndSanitizer.sol"; 
import {LombardBtcDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/LombardBtcDecoderAndSanitizer.sol"; 
import {StakedSonicUSDDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/StakedSonicUSDDecoderAndSanitizer.sol"; 
import {TestVaultDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/TestVaultDecoderAndSanitizer.sol";
import {LiquidBeraEthDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/LiquidBeraEthDecoderAndSanitizer.sol"; 
import {SonicIncentivesHandlerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SonicIncentivesHandlerDecoderAndSanitizer.sol";
import {AaveV3FullDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/AaveV3FullDecoderAndSanitizer.sol";
import {EtherFiBtcDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/EtherFiBtcDecoderAndSanitizer.sol";
import {SymbioticLRTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SymbioticLRTDecoderAndSanitizer.sol";
import {SonicLBTCvSonicDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SonicLBTCvSonicDecoderAndSanitizer.sol";
import {eBTCBerachainDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/eBTCBerachainDecoderAndSanitizer.sol"; 
import {SonicBTCDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SonicBTCDecoderAndSanitizer.sol";
import {BerachainDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BerachainDecoderAndSanitizer.sol"; 
import {PrimeLiquidBeraBtcDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/PrimeLiquidBeraBtcDecoderAndSanitizer.sol"; 
import {StakedSonicDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/StakedSonicDecoderAndSanitizer.sol";
import {HybridBtcBobDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/HybridBtcBobDecoderAndSanitizer.sol";
import {HybridBtcDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/HybridBtcDecoderAndSanitizer.sol";
import {SonicVaultDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SonicVaultDecoderAndSanitizer.sol";
import {LBTCvBNBDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/LBTCvBNBDecoderAndSanitizer.sol";
import {LBTCvBaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/LBTCvBaseDecoderAndSanitizer.sol";
import {SonicLBTCvSonicDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SonicLBTCvSonicDecoderAndSanitizer.sol";
import {RoyUSDCMainnetDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/RoyUSDCMainnetDecoderAndSanitizer.sol";
import {RoyUSDCSonicDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/RoyUSDCSonicDecoderAndSanitizer.sol";
import {RoySonicUSDCDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/RoySonicUSDCDecoderAndSanitizer.sol";
import {TacETHDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/TacETHDecoderAndSanitizer.sol";
import {TacUSDDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/TacUSDDecoderAndSanitizer.sol";
import {TacLBTCvDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/TacLBTCvDecoderAndSanitizer.sol";
import {sBTCNDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/sBTCNDecoderAndSanitizer.sol";
import {CamelotFullDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/CamelotFullDecoderAndSanitizer.sol";
import {EtherFiEigenDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/EtherFiEigenDecoderAndSanitizer.sol";
import {UnichainEtherFiLiquidEthDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/UnichainEtherFiLiquidEthDecoderAndSanitizer.sol";
import {LiquidBeraDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/LiquidBeraDecoderAndSanitizer.sol";
import {LiquidBeraEthBerachainDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/LiquidBeraEthBerachainDecoderAndSanitizer.sol";
import {LiquidUSDFlareDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/LiquidUSDFlareDecoderAndSanitizer.sol"; 
import {UltraUSDFlareDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/UltraUSDFlareDecoderAndSanitizer.sol"; 
import {AlphaSTETHDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/AlphaSTETHDecoderAndSanitizer.sol";
import {RoycoUSDDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/RoycoUSDDecoderAndSanitizer.sol";
import {RoycoUSDPlumeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/RoycoUSDPlumeDecoderAndSanitizer.sol";
import {FullScrollBridgeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/FullScrollBridgeDecoderAndSanitizer.sol"; 
import {ScrollVaultsDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/ScrollVaultsDecoderAndSanitizer.sol"; 
import {FullRewardTokenUnwrappingDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/FullRewardTokenUnwrappingDecoderAndSanitizer.sol"; 
import {SonicLBTCvDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SonicLBTCvDecoderAndSanitizer.sol"; 
import { SonicEthMainnetDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SonicEthMainnetDecoderAndSanitizer.sol";
import {GoldenGooseUnichainDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/GoldenGooseUnichainDecoderAndSanitizer.sol";

import {RoycoUSDDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/RoycoUSDDecoderAndSanitizer.sol";
import {RoycoUSDPlumeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/RoycoUSDPlumeDecoderAndSanitizer.sol";
import {BoringDrone} from "src/base/Drones/BoringDrone.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployDecoderAndSanitizer.s.sol:DeployDecoderAndSanitizerScript --broadcast --etherscan-api-key $FLARESCAN_KEY --verify --with-gas-price 30000000000
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */

contract DeployDecoderAndSanitizerScript is Script, ContractNames, MainnetAddresses, MerkleTreeHelper {
    uint256 public privateKey;
    Deployer public deployer = Deployer(deployerAddress);
    //Deployer public bobDeployer = Deployer(0xF3d0672a91Fd56C9ef04C79ec67d60c34c6148a0); 

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        
        vm.createSelectFork("flare");
        setSourceChainName("flare"); 

    }

    function run() external {
        bytes memory creationCode; bytes memory constructorArgs;
        vm.startBroadcast(privateKey);
        
        creationCode = type(UltraUSDFlareDecoderAndSanitizer).creationCode;
        constructorArgs = abi.encode(getAddress(sourceChain, "uniswapV3NonFungiblePositionManager"));
        deployer.deployContract("Ultra USD Flare Decoder And Sanitizer V0.0", creationCode, constructorArgs, 0);

        vm.stopBroadcast();
    }
}
