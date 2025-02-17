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
import {SonicBTCDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/SonicBTCDecoderAndSanitizer.sol";

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
        vm.createSelectFork("sonicMainnet");

    }

    function run() external {
        bytes memory creationCode;
        bytes memory constructorArgs;
        vm.startBroadcast(privateKey);

        // creationCode = type(AerodromeDecoderAndSanitizer).creationCode;
        // constructorArgs =
        //     abi.encode(0xf0bb20865277aBd641a307eCe5Ee04E79073416C, 0x416b433906b1B72FA758e166e239c43d68dC6F29);
        // deployer.deployContract(EtherFiLiquidEthAerodromeDecoderAndSanitizerName, creationCode, constructorArgs, 0);

        // creationCode = type(OnlyKarakDecoderAndSanitizer).creationCode;
        // constructorArgs = abi.encode(boringVault);
        // deployer.deployContract(EtherFiLiquidEthDecoderAndSanitizerName, creationCode, constructorArgs, 0);

        // creationCode = type(PancakeSwapV3FullDecoderAndSanitizer).creationCode;
        // constructorArgs = abi.encode(boringVault, pancakeSwapV3NonFungiblePositionManager, pancakeSwapV3MasterChefV3);
        // deployer.deployContract(LombardPancakeSwapDecoderAndSanitizerName, creationCode, constructorArgs, 0);

        // creationCode = type(ITBPositionDecoderAndSanitizer).creationCode;
        // constructorArgs = abi.encode(eEigen);
        // deployer.deployContract(
        //     "ITB Eigen Position Manager Decoder and Sanitizer V0.1", creationCode, constructorArgs, 0
        // );
        // creationCode = type(ITBPositionDecoderAndSanitizer).creationCode;
        // constructorArgs = abi.encode(liquidUsd);
        // deployer.deployContract(ItbPositionDecoderAndSanitizerName, creationCode, constructorArgs, 0);

        //creationCode = type(EtherFiLiquidUsdDecoderAndSanitizer).creationCode;
        //constructorArgs = abi.encode(uniswapV3NonFungiblePositionManager);
        //deployer.deployContract(EtherFiLiquidUsdDecoderAndSanitizerName, creationCode, constructorArgs, 0);

        //creationCode = type(OnlyHyperlaneDecoderAndSanitizer).creationCode;
        //constructorArgs = abi.encode(address(0));
        //deployer.deployContract("Hyperlane Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        //creationCode = type(sBTCNMaizenetDecoderAndSanitizer).creationCode;
        //constructorArgs = abi.encode(boringVault);
        //version is not synced w/ current deployed version anymore
        //deployer.deployContract("Staked BTCN Decoder and Sanitizer V0.4", creationCode, constructorArgs, 0);

        //creationCode = type(sBTCNMaizenetDecoderAndSanitizer).creationCode;
        //constructorArgs = abi.encode(boringVault);
        //version is synced w/ current deployed version
        //deployer.deployContract("Staked BTCN Decoder and Sanitizer V0.2", creationCode, constructorArgs, 0);

        //creationCode = type(UniBTCDecoderAndSanitizer).creationCode;
        //constructorArgs = abi.encode(boringVault, uniswapV3NonFungiblePositionManager);
        //deployer.deployContract("Bedrock BTC DeFi Vault Decoder And Sanitizer V0.0", creationCode, constructorArgs, 0);

        //creationCode = type(EdgeCapitalDecoderAndSanitizer).creationCode;
        //constructorArgs = abi.encode(ultraUSDBoringVault, uniswapV3NonFungiblePositionManager);
        //deployer.deployContract("Ultra Yield Stablecoin Vault Decoder And Sanitizer V0.0", creationCode, constructorArgs, 0);

        //creationCode = type(SonicMainnetDecoderAndSanitizer).creationCode;
        //constructorArgs = abi.encode(boringVault, uniswapV3NonFungiblePositionManager);
        // deployer.deployContract("Sonic ETH Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        //creationCode = type(EtherFiLiquidBtcDecoderAndSanitizer).creationCode;
        //constructorArgs = abi.encode(boringVault, uniswapV3NonFungiblePositionManager);
        //deployer.deployContract("EtherFi Liquid BTC Decoder And Sanitizer V0.0", creationCode, constructorArgs, 0);
        

        //address mainnetRecipeMarketHub = 0x783251f103555068c1E9D755f69458f39eD937c0;  
        //creationCode = type(LiquidBeraEthDecoderAndSanitizer).creationCode;
        //constructorArgs = abi.encode(uniswapV3NonFungiblePositionManager, mainnetRecipeMarketHub); 
        //deployer.deployContract("Liquid Bera ETH Decoder And Sanitizer V0.1", creationCode, constructorArgs, 0);

        // creationCode = type(EtherFiLiquidEthDecoderAndSanitizer).creationCode;
        // constructorArgs = abi.encode(uniswapV3NonFungiblePositionManager); 
        // deployer.deployContract("EtherFi Liquid ETH Decoder And Sanitizer V0.8", creationCode, constructorArgs, 0);

        //creationCode = type(LombardBtcDecoderAndSanitizer).creationCode;
        //constructorArgs = abi.encode(uniswapV3NonFungiblePositionManager);
        //deployer.deployContract("Lombard BTC Decoder And Sanitizer V0.2", creationCode, constructorArgs, 0);

        //creationCode = type(EtherFiBtcDecoderAndSanitizer).creationCode;
        //constructorArgs = abi.encode(uniswapV3NonFungiblePositionManager);
        //deployer.deployContract("ether.fi BTC Decoder and Sanitizer V0.2", creationCode, constructorArgs, 0);

        //creationCode = type(SymbioticLRTDecoderAndSanitizer).creationCode;
        //constructorArgs = abi.encode(uniswapV3NonFungiblePositionManager);
        //deployer.deployContract("Symbiotic LRT Vault Decoder and Sanitizer V0.4", creationCode, constructorArgs, 0);

        // address pancakeswapV3nfpm = 0x46A15B0b27311cedF172AB29E4f4766fbE7F4364;
        // address pancakeswapV3chef = 0x556B9306565093C855AEA9AE92A594704c2Cd59e;
        // creationCode = type(PancakeSwapV3FullDecoderAndSanitizer).creationCode;
        // constructorArgs = abi.encode(pancakeswapV3nfpm, pancakeswapV3chef);
        // deployer.deployContract("PancakeSwapV3 Decoder And Sanitizer V0.1", creationCode, constructorArgs, 0);

        creationCode = type(SonicBTCDecoderAndSanitizer).creationCode;
        constructorArgs = abi.encode("");
        deployer.deployContract("Sonic BTC Decoder And Sanitizer V0.2", creationCode, constructorArgs, 0);


        vm.stopBroadcast();
    }
}
