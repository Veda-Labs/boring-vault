// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {BoringSwapper} from "src/base/Periphery/BoringSwapper.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {BoringSwapperDecoder} from "src/base/DecodersAndSanitizers/Protocols/BoringSwapperDecoderAndSanitizer.sol";
import {AdapterRegistry} from "src/base/Periphery/AdapterRegistry.sol"; 
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {PriceValidator} from "src/base/Periphery/adapters/price/PriceValidator.sol";
import {IPriceValidator} from "src/interfaces/IPriceValidator.sol";
import {IFeeRegistry} from "src/interfaces/IFeeRegistry.sol";
import {GenericRateProviderWithStalenessCheck} from "src/helper/GenericRateProviderWithStalenessCheck.sol";
import {BoringSwapperDecoder} from "src/base/DecodersAndSanitizers/Protocols/BoringSwapperDecoderAndSanitizer.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {UniswapV3Adapter} from "src/base/Periphery/adapters/UniswapV3Adapter.sol"; 
import {CowswapAdapter} from "src/base/Periphery/adapters/CowswapAdapter.sol";
import {OneInchAdapter} from "src/base/Periphery/adapters/OneInchAdapter.sol";

import {ERC20} from "@solmate/tokens/ERC20.sol";
import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/Test/DeployBoringSwapper.s.sol:DeployBoringSwapperTestSuite --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
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

    // The vault already has this role in the existing RolesAuthority.
    // Capabilities for the four swapper functions are added to it below.
    uint8 constant BORING_VAULT_ROLE = 12; // update to match the deployed vault's role ID

    // CoW Protocol constants
    address constant COW_SETTLEMENT    = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    address constant COW_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;
    // 1inch constants
    address constant ONEINCH_ROUTER    = 0x111111125421cA6dc452d289314280a0f8842A65;
    address constant ONEINCH_FEE_TAKER = 0xc0DFdB9E7a392c3dBBE7c6FBe8FBC1789C9FE05e;

    // Vault ecosystem constants
    address boringVault = 0x0Fc760EEbEFbF5FE3B452A9a52325c4376FEADFA;
    address manager     = 0x1AE3346BC6d3267b860De524D5E38E19679A1DB0;
    address accountant  = 0xD1135B891143d3c5DfE158C6b4961937a27b8AE4;

    function setUp() external {
        privateKey = vm.envUint("BORING_DEVELOPER");
        setSourceChainName("mainnet");
        vm.createSelectFork("mainnet"); 
    }

    function run() external {
        vm.startBroadcast(privateKey);
        setAddress(false, sourceChain, "boringVault", boringVault);
        setAddress(false, sourceChain, "manager", manager);
        setAddress(false, sourceChain, "managerAddress", manager);
        setAddress(false, sourceChain, "accountantAddress", accountant);

        // Deploy registry
        registry = new AdapterRegistry();
        console.log("AdapterRegistry:", address(registry));

        // Deploy swapper (no fee registry at deploy time — set post-deployment via setFeeRegistry by Veda multisig)
        swapper = new BoringSwapper(0xBBc5569B0b32403037F37255f4ff50B8Bb825b2A, registry, IFeeRegistry(address(0)));
        console.log("BoringSwapper:  ", address(swapper));

        // Deploy adapters and register in registry
        address uniswapV3Adapter = address(new UniswapV3Adapter(getAddress(sourceChain, "uniV3Router")));
        address cowswapAdapter   = address(new CowswapAdapter(COW_SETTLEMENT, COW_VAULT_RELAYER));
        address oneInchAdapter   = address(new OneInchAdapter(ONEINCH_ROUTER, ONEINCH_FEE_TAKER));

        console.log("UniswapV3Adapter:", uniswapV3Adapter);
        console.log("CowswapAdapter:  ", cowswapAdapter);
        console.log("OneInchAdapter:  ", oneInchAdapter);

        registry.put(uniswapV3Adapter, "UNISWAP_V3");
        registry.put(cowswapAdapter,   "COWSWAP");
        registry.put(oneInchAdapter,   "ONEINCH");

        // Approve adapters and routes on the swapper
        swapper.setApprovedAdapter(uniswapV3Adapter, true);
        swapper.setApprovedAdapter(cowswapAdapter,   true);
        swapper.setApprovedAdapter(oneInchAdapter,   true);

        swapper.setApprovedRoute(getERC20(sourceChain, "WETH"), getERC20(sourceChain, "USDC"), true, 500, 0, 0);

        // Auth: wire swapper into the vault's existing RolesAuthority.
        // Pull the authority from the vault so we don't need to hardcode a second address.
        RolesAuthority rolesAuthority = RolesAuthority(address(BoringVault(payable(boringVault)).authority()));
        console.log("RolesAuthority:  ", address(rolesAuthority));

        // Point the swapper at the authority (deployer owns the swapper, so this works).
        swapper.setAuthority(rolesAuthority);

        // The four capability grants below must be executed by the RolesAuthority owner
        // (not the deployer key). Call these through the multisig after deployment:
        //
        //   rolesAuthority.setRoleCapability(BORING_VAULT_ROLE, address(swapper), BoringSwapper.swap.selector,         true);
        //   rolesAuthority.setRoleCapability(BORING_VAULT_ROLE, address(swapper), BoringSwapper.submitOrder.selector,  true);
        //   rolesAuthority.setRoleCapability(BORING_VAULT_ROLE, address(swapper), BoringSwapper.cancelOrder.selector,  true);
        //   rolesAuthority.setRoleCapability(BORING_VAULT_ROLE, address(swapper), BoringSwapper.replaceOrder.selector, true);
        console.log("TODO (multisig): setRoleCapability for swap/submitOrder/cancelOrder/replaceOrder on swapper above");

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

        // token oracle config: USDC → USD quote (direct, no intermediary)
        swapper.setTokenOracle(
            getERC20(sourceChain, "USDC"),
            usdQuoteAsset,
            _makeOracleConfig(0x8d99465A5F1631f9B7063C9437e6C09AC3504527, address(0), false)
        );

        // token oracle config: WETH → USD quote (direct, no intermediary)
        swapper.setTokenOracle(
            getERC20(sourceChain, "WETH"),
            usdQuoteAsset,
            _makeOracleConfig(0x2F22FBE27D24CA359eb282A6a13c0017C13dEDa4, address(0), false)
        );

        // base asset oracles
        address[] memory usdRateProviders = new address[](1);
        usdRateProviders[0] = 0x8d99465A5F1631f9B7063C9437e6C09AC3504527;
        swapper.setBaseAssetOracle(getERC20(sourceChain, "USDC"), usdQuoteAsset, usdRateProviders);

        address[] memory ethRateProviders = new address[](1);
        ethRateProviders[0] = 0x2F22FBE27D24CA359eb282A6a13c0017C13dEDa4;
        swapper.setBaseAssetOracle(getERC20(sourceChain, "WETH"), usdQuoteAsset, ethRateProviders);

        //price validator setup
        validator = new PriceValidator();
        swapper.setPriceValidator(IPriceValidator(validator));
        
        //create boring swapper merkle root (bb)
        vm.stopBroadcast();
    }

    function _makeOracleConfig(address rateProvider, address intermediary, bool skipValidation)
        internal
        pure
        returns (BoringSwapper.RateProviderConfig memory)
    {
        address[] memory rateProviders = new address[](1);
        rateProviders[0] = rateProvider;
        address[] memory intermediaries = new address[](1);
        intermediaries[0] = intermediary;
        return BoringSwapper.RateProviderConfig(rateProviders, intermediaries, skipValidation);
    }
}
