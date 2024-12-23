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
import {sBTCNMaizenetDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/sBTCNMaizenetDecoderAndSanitizer.sol";
import {UniBTCDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/UniBTCDecoderAndSanitizer.sol";
import {EdgeCapitalDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/EdgeCapitalDecoderAndSanitizer.sol";

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

    //address boringVault = 0x5401b8620E5FB570064CA9114fd1e135fd77D57c;

    //address eEigen = 0xE77076518A813616315EaAba6cA8e595E845EeE9;

    //address boringVault = 0xf6d71c15657A7f2B9aeDf561615feF9E05fE2cb3;

    //address eEigen = 0xE77076518A813616315EaAba6cA8e595E845EeE9;

    //address eEigen = 0xE77076518A813616315EaAba6cA8e595E845EeE9;

    //address ultraUSDBoringVault = 0xbc0f3B23930fff9f4894914bD745ABAbA9588265;

    //address liquidUsd = 0x08c6F91e2B681FaF5e17227F2a44C307b3C1364C;

    address boringVault = 0x5E272ca4bD94e57Ec5C51D26703621Ccac1A7089;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        vm.createSelectFork("corn");
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

        // creationCode = type(EtherFiLiquidUsdDecoderAndSanitizer).creationCode;
        // constructorArgs = abi.encode(liquidUsd, uniswapV3NonFungiblePositionManager);
        // deployer.deployContract(EtherFiLiquidUsdDecoderAndSanitizerName, creationCode, constructorArgs, 0);

        //creationCode = type(OnlyHyperlaneDecoderAndSanitizer).creationCode;
        //constructorArgs = abi.encode(address(0));
        //deployer.deployContract("Hyperlane Decoder and Sanitizer V0.0", creationCode, constructorArgs, 0);

        creationCode = type(sBTCNMaizenetDecoderAndSanitizer).creationCode;
        constructorArgs = abi.encode(boringVault);
        //version is not synced w/ current deployed version anymore
        deployer.deployContract("Staked BTCN Decoder and Sanitizer V0.4", creationCode, constructorArgs, 0);

        //creationCode = type(UniBTCDecoderAndSanitizer).creationCode;
        //constructorArgs = abi.encode(boringVault, uniswapV3NonFungiblePositionManager);
        //deployer.deployContract("Bedrock BTC DeFi Vault Decoder And Sanitizer V0.0", creationCode, constructorArgs, 0);

        //creationCode = type(EdgeCapitalDecoderAndSanitizer).creationCode;
        //constructorArgs = abi.encode(ultraUSDBoringVault, uniswapV3NonFungiblePositionManager);
        //deployer.deployContract("Ultra Yield Stablecoin Vault Decoder And Sanitizer V0.0", creationCode, constructorArgs, 0);

        vm.stopBroadcast();
    }
}
