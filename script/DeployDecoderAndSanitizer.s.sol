// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
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
import {LiquidBtcDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/LiquidBtcDecoderAndSanitizer.sol";
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
import {HyperUsdDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/HyperUsdDecoderAndSanitizer.sol";
import {RoyUSDCSonicDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/RoyUSDCSonicDecoderAndSanitizer.sol";
import {RoySonicUSDCDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/RoySonicUSDCDecoderAndSanitizer.sol";
import {TacETHDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/TacETHDecoderAndSanitizer.sol";
import {TacUSDDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/TacUSDDecoderAndSanitizer.sol";
import {TacLBTCvDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/TacLBTCvDecoderAndSanitizer.sol";
import {sBTCNDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/sBTCNDecoderAndSanitizer.sol";
import {CamelotDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CamelotDecoderAndSanitizer.sol";
import {EtherFiEigenDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/EtherFiEigenDecoderAndSanitizer.sol";
import {UnichainEtherFiLiquidEthDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/UnichainEtherFiLiquidEthDecoderAndSanitizer.sol";
import {LiquidBeraDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/LiquidBeraDecoderAndSanitizer.sol";
import {LiquidBeraEthBerachainDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/LiquidBeraEthBerachainDecoderAndSanitizer.sol";
import {LiquidUSDFlareDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/LiquidUSDFlareDecoderAndSanitizer.sol";
import {AlphaSTETHDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/AlphaSTETHDecoderAndSanitizer.sol";
import {RoycoUSDDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/RoycoUSDDecoderAndSanitizer.sol";
import {RoycoUSDPlumeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/RoycoUSDPlumeDecoderAndSanitizer.sol";
import {FullScrollBridgeDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/FullScrollBridgeDecoderAndSanitizer.sol";
import {ScrollVaultsDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/ScrollVaultsDecoderAndSanitizer.sol";
import {FullRewardTokenUnwrappingDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/FullRewardTokenUnwrappingDecoderAndSanitizer.sol";
import {SonicLBTCvDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SonicLBTCvDecoderAndSanitizer.sol";
import {SonicEthMainnetDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SonicEthMainnetDecoderAndSanitizer.sol";
import {GoldenGooseUnichainDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/GoldenGooseUnichainDecoderAndSanitizer.sol";
import {LevelDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/LevelDecoderAndSanitizer.sol";
import {RoycoUSDDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/RoycoUSDDecoderAndSanitizer.sol";
import {RoycoUSDPlumeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/RoycoUSDPlumeDecoderAndSanitizer.sol";
import {BoringDrone} from "src/base/Drones/BoringDrone.sol";
import {PrimeGoldenGooseUnichainDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/PrimeGoldenGooseUnichainDecoderAndSanitizer.sol";
import {PrimeGoldenGooseDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/PrimeGoldenGooseDecoderAndSanitizer.sol";
import {GoldenGooseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/GoldenGooseDecoderAndSanitizer.sol";
import {GoldenGooseArbitrumDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/GoldenGooseArbitrumDecoderAndSanitizer.sol";
import {KatanaDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/KatanaDecoderAndSanitizer.sol";
import {EthMainnetTacDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/EthMainnetTacDecoderAndSanitizer.sol";
import {TacDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/TacUSDTacDecoderAndSanitizer.sol";
import {OdosDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OdosDecoderAndSanitizer.sol";
import {UniswapV3SwapRouter02DecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/UniswapV3SwapRouter02DecoderAndSanitizer.sol";
import {ConvexFXDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ConvexFXDecoderAndSanitizer.sol";
import {DolomiteDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/DolomiteDecoderAndSanitizer.sol";
import {DvStETHDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/DvStETHDecoderAndSanitizer.sol";
import {PancakeSwapV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/PancakeSwapV3DecoderAndSanitizer.sol";
import {RoycoWeirollDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/RoycoDecoderAndSanitizer.sol";
import {UniswapV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3DecoderAndSanitizer.sol";
import {UniswapV4DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV4DecoderAndSanitizer.sol";
import {VelodromeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/VelodromeDecoderAndSanitizer.sol";
import {AtomicQueueDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AtomicQueueDecoderAndSanitizer.sol";
import {KHypeHyperEVMDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/KHypeHyperEVMDecoderAndSanitizer.sol";
import {TacETHDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/TacETHDecoderAndSanitizer.sol";
import {PlasmaUSDDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/PlasmaUSDDecoderAndSanitizer.sol";
import {GoldenGooseUnichainDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/GoldenGooseUnichainDecoderAndSanitizer.sol";
import {OptimismGoldenGooseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/OptimismGoldenGooseDecoderAndSanitizer.sol";
import {GoldenGooseBaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/GoldenGooseBaseDecoderAndSanitizer.sol";
import {SentoraDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SentoraDecoderAndSanitizer.sol";
import {GoldenGooseLineaDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/GoldenGooseLineaDecoderAndSanitizer.sol";
import {EthenaRWADecoderAndSanitizer} from "src/base/DecodersAndSanitizers/EthenaRWADecoderAndSanitizer.sol";
import {LiquidMoveEthDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/LiquidMoveEthDecoderAndSanitizer.sol";
import {PlasmaUSDPlasmaDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/PlasmaUSDPlasmaDecoderAndSanitizer.sol";
import {LiquidETHPlasmaDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/LiquidETHPlasmaDecoderAndSanitizer.sol";
import {PlasmaUSDPlusPlasmaDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/PlasmaUSDPlusPlasmaDecoderAndSanitizer.sol";
import {TurtleMUSDDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/TurtleMUSDDecoderAndSanitizer.sol";
import {TestVault0DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/TestVault0DecoderAndSanitizer.sol";
import {InkLiquidETHDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/InkLiquidETHDecoderAndSanitizer.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployDecoderAndSanitizer.s.sol:DeployDecoderAndSanitizerScript --broadcast --etherscan-api-key $ETHERSCAN_API_KEY
 */
/** *   --verify --verifier-url 'https://api.routescan.io/v2/network/mainnet/evm/21000000/etherscan'
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 * @dev For Unichain verification, use appropriate block explorer when available
 */
contract DeployDecoderAndSanitizerScript is Script, ContractNames, MainnetAddresses, MerkleTreeHelper {
    uint256 public privateKey;
    Deployer public deployer = Deployer(deployerAddress);
    Deployer public bobDeployer = Deployer(0xF3d0672a91Fd56C9ef04C79ec67d60c34c6148a0);

    string[] addressKeys;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");

        vm.createSelectFork("ink");
        setSourceChainName("ink");
    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        creationCode = type(InkLiquidETHDecoderAndSanitizer).creationCode;
        constructorArgs = abi.encode(getAddress(sourceChain, "velodromeNonFungiblePositionManager"));
        deployer.deployContract("Liquid Eth Ink Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        vm.stopBroadcast();
    }

    // do not use, this is really intended for doing a giga deploy on a new chain
    function deployContract(string memory name, bytes memory creationCode, uint256 value) internal {
        address _contract = deployer.getAddress(name);
        if (_contract.code.length > 0) {
            console.log(name, "already deployed at", _contract);
            return;
        }

        bytes memory constructorArgs;
        for (uint256 i = 0; i < addressKeys.length; i++) {
            if (values[sourceChain][addressKeys[i]] != bytes32(0)) {
                constructorArgs = abi.encodePacked(constructorArgs, abi.encode(getAddress(sourceChain, addressKeys[i])));
            } else {
                console.log(string.concat("Skipping ", name, " because ", addressKeys[i], " is not set"));
                return;
            }
        }

        address deployed = deployer.deployContract(name, creationCode, constructorArgs, value);
        console.log(unicode"✅", name, "deployed to", deployed);
        console.logBytes(constructorArgs);
    }
}
