// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {BoringSwapper} from "src/base/Periphery/BoringSwapper.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {BoringSwapperDecoder} from "src/base/DecodersAndSanitizers/Protocols/BoringSwapperDecoderAndSanitizer.sol";
import {AdapterRegistry} from "src/base/Periphery/AdapterRegistry.sol"; 
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {PriceValidator} from "src/base/Periphery/adapters/price/PriceValidator.sol";
import {IPriceValidator} from "src/interfaces/IPriceValidator.sol";
import {GenericRateProviderWithStalenessCheck} from "src/helper/GenericRateProviderWithStalenessCheck.sol";
import {BoringSwapperDecoder} from "src/base/DecodersAndSanitizers/Protocols/BoringSwapperDecoderAndSanitizer.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {UniswapV3Adapter} from "src/base/Periphery/adapters/UniswapV3Adapter.sol"; 
import {CowswapAdapter} from "src/base/Periphery/adapters/CowswapAdapter.sol";
import {OneInchAdapter} from "src/base/Periphery/adapters/OneInchAdapter.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/Test/DeployBoringSwapper.s.sol:DeployBoringSwapperTestSuite --with-gas-price 30000000000 --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployBoringSwapperTestSuite is Script, ContractNames, MainnetAddresses, MerkleTreeHelper {
    uint256 public privateKey;
    Deployer public deployer = Deployer(deployerAddress);

    AdapterRegistry registry;
    BoringSwapper swapper;
    PriceValidator validator;

    GenericRateProviderWithStalenessCheck usdRate;
    GenericRateProviderWithStalenessCheck ethRate;

    BoringSwapperDecoder boringSwapperDecoder; 

    uint8 UNISWAP_V3 = 1;
    uint8 COWSWAP = 3;
    uint8 ONEINCH = 4;

    // CoW Protocol constants BEGIN //
    address constant COW_SETTLEMENT = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    address constant COW_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;
    // 1inch constants BEGIN //
    address constant ONEINCH_ROUTER = 0x111111125421cA6dc452d289314280a0f8842A65;

    //VAULT ECOSYSTEM CONSTANTS
    address boringVault = 0x0Fc760EEbEFbF5FE3B452A9a52325c4376FEADFA;
    address manager = 0x1AE3346BC6d3267b860De524D5E38E19679A1DB0;
    address accountant = 0xD1135B891143d3c5DfE158C6b4961937a27b8AE4;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        setSourceChainName("mainnet");
        vm.createSelectFork("mainnet"); 
    }

    function run() external {
        vm.startBroadcast(privateKey);
        //vault is already deployed, we can deploy the decoder here
        //deploy boring swapper decoder
        //BoringSwapperDecoder swapperDecoder = new BoringSwapperDecoder();
        //console.log("Swapper decoder: ", address(swapperDecoder));
         
        //set addresses 
        setAddress(false, sourceChain, "boringVault", address(boringVault));
        ///setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", address(swapperDecoder));
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(accountant));

        //deploy registry
        registry = new AdapterRegistry(); 
        console.log("Adapter registry: ", address(registry));

        //deploy boring swapper
        swapper = new BoringSwapper(0xBBc5569B0b32403037F37255f4ff50B8Bb825b2A, registry);
        console.log("Boring Swapper: ", address(swapper));


        //do additional setup here
        //deploy adapter (1inch)
        //deploy adapter (cowswap)
        address uniswapV3AdapterVersion0_1 = address(new UniswapV3Adapter(getAddress(sourceChain, "uniV3Router")));
        address cowswapAdapterVersion0_1 = address(new CowswapAdapter(COW_SETTLEMENT, COW_VAULT_RELAYER));
        address oneInchAdapterVersion0_1 = address(new OneInchAdapter(ONEINCH_ROUTER));

        swapper.setApprovedRoute(getERC20(sourceChain, "WETH"), getERC20(sourceChain, "USDC"), true, 50, 0, 0);
        swapper.setApprovedProtocol(UNISWAP_V3, true); //UNI_V3
        swapper.setApprovedProtocol(COWSWAP, true); //COWSWAP
        swapper.setApprovedProtocol(ONEINCH, true); //1INCH
        swapper.addApprovedVersion(UNISWAP_V3, 1);
        swapper.addApprovedVersion(COWSWAP, 1);
        swapper.addApprovedVersion(ONEINCH, 1);

        registry.put(UNISWAP_V3, uniswapV3AdapterVersion0_1, "UNISWAP_V3");
        registry.put(COWSWAP, cowswapAdapterVersion0_1, "COWSWAP");
        registry.put(ONEINCH, oneInchAdapterVersion0_1, "ONEINCH");

        //GenericRateProviderWithStalenessCheck.ConstructorArgs memory argsUsd = GenericRateProviderWithStalenessCheck.ConstructorArgs(
        //    0x37be050e75C7F0a80F0E8abBFC2c4Ff826728cAa,
        //    0x50d25bcd,
        //    bytes32(0),
        //    bytes32(0),
        //    bytes32(0),
        //    bytes32(0),
        //    bytes32(0),
        //    bytes32(0),
        //    bytes32(0),
        //    bytes32(0),
        //    true,
        //    8,
        //    18, 
        //    6 hours, 
        //    0xfeaf968c,
        //    4
        //);

        //usdRate = new GenericRateProviderWithStalenessCheck(
        //    argsUsd     
        //);

        //GenericRateProviderWithStalenessCheck.ConstructorArgs memory argsEth = GenericRateProviderWithStalenessCheck.ConstructorArgs(
        //    0xc0053f3FBcCD593758258334Dfce24C2A9A673aD,
        //    0x50d25bcd,
        //    bytes32(0),
        //    bytes32(0),
        //    bytes32(0),
        //    bytes32(0),
        //    bytes32(0),
        //    bytes32(0),
        //    bytes32(0),
        //    bytes32(0),
        //    true,
        //    8,
        //    18, 
        //    6 hours, 
        //    0xfeaf968c,
        //    4
        //);

        //ethRate = new GenericRateProviderWithStalenessCheck(argsEth);

        address usdQuoteAsset = getAddress(sourceChain, "USDC");
        address ethQuoteAsset = getAddress(sourceChain, "WETH");
        swapper.setApprovedOracle(getERC20(sourceChain, "USDC"), usdQuoteAsset, address(usdRate));
        swapper.setApprovedOracle(getERC20(sourceChain, "WETH"), ethQuoteAsset, address(ethRate));

        //price validator setup
        //validator = new PriceValidator();
        swapper.setPriceValidator(IPriceValidator(0xA528Aa462396124e376d8E8B7640b10D288CC306));
        
        //create boring swapper merkle root (bb)
        vm.stopBroadcast();
    }
}
