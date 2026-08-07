// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {BoringSwapper} from "src/base/Periphery/BoringSwapper.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {AdapterRegistry} from "src/base/Periphery/AdapterRegistry.sol";
import {IFeeRegistry} from "src/interfaces/IFeeRegistry.sol";
import {IPriceValidator} from "src/interfaces/IPriceValidator.sol";
import {Deployer} from "src/helper/Deployer.sol";

import "forge-std/Script.sol";

/**
 *  source .env && forge script script/Test/RedeploySwapper.s.sol:RedeploySwapperScript --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract RedeploySwapperScript is Script, MerkleTreeHelper {
    address constant boringVault = 0x0Fc760EEbEFbF5FE3B452A9a52325c4376FEADFA;
    address constant rolesAuthority = 0x13b92D87894E24B266A947255CD022749Fb52755;

    address constant registry = 0xAf89917Df73EF405e54CA4DA19560AbB3865253B;
    address constant feeRegistry = 0x123860b01C73BC97d0EB29f24D9E55C3416dAd1A;
    address constant validator = 0x5F37ABAd03A8426EaDdC64D052696E7D4eBF79E8;

    address constant uniswapV3Adapter = 0x89A7bc88bD554cCFa6323A12c6B833A3fA46e518;
    address constant cowswapAdapter = 0x52FE4D4C31C95EC3b9A074E61b578C20eE1aD9d7;
    address constant oneInchAdapter = 0x1c5d8ca5662E1C0c5979659c0035955C89101206;
    address constant openOceanAdapter = 0x3F6ad7DeeC238AF778e83fad209587814717d80F;
    address constant lifiAdapter = 0xD4A95aAC320380910a09767B070670f979B120cE;
    address constant m0Adapter = 0xBd8fab1C87A5191CC8dBF5dDC895Ef6d3f9E3265;

    function setUp() external {
        setSourceChainName("mainnet");
        vm.createSelectFork("mainnet");
    }

    function run() external {
        vm.startBroadcast();

        BoringSwapper swapper = new BoringSwapper(
            getAddress(sourceChain, "txBundlerAddress"),
            AdapterRegistry(registry),
            IFeeRegistry(feeRegistry),
            BoringVault(payable(boringVault)),
            IPriceValidator(validator)
        );
        console.log("BoringSwapper (vault 0x0Fc760):", address(swapper));

        address usdQuoteAsset = getAddress(sourceChain, "USDC");
        address[] memory usdRateProviders = new address[](1);
        usdRateProviders[0] = getAddress(sourceChain, "usdcUsdRateProvider");
        address[] memory ethRateProviders = new address[](1);
        ethRateProviders[0] = getAddress(sourceChain, "wethUsdRateProvider");

        Deployer.Tx[] memory txs = new Deployer.Tx[](12);
        txs[0] = Deployer.Tx({ target: address(swapper), data: abi.encodeWithSignature("setAuthority(address)", rolesAuthority), value: 0 });
        txs[1] = Deployer.Tx({ target: address(swapper), data: abi.encodeWithSelector(BoringSwapper.setApprovedAdapter.selector, uniswapV3Adapter, true), value: 0 });
        txs[2] = Deployer.Tx({ target: address(swapper), data: abi.encodeWithSelector(BoringSwapper.setApprovedAdapter.selector, cowswapAdapter,   true), value: 0 });
        txs[3] = Deployer.Tx({ target: address(swapper), data: abi.encodeWithSelector(BoringSwapper.setApprovedAdapter.selector, oneInchAdapter,   true), value: 0 });
        txs[4] = Deployer.Tx({ target: address(swapper), data: abi.encodeWithSelector(BoringSwapper.setApprovedAdapter.selector, openOceanAdapter, true), value: 0 });
        txs[5] = Deployer.Tx({ target: address(swapper), data: abi.encodeWithSelector(BoringSwapper.setApprovedAdapter.selector, lifiAdapter,      true), value: 0 });
        txs[6] = Deployer.Tx({ target: address(swapper), data: abi.encodeWithSelector(BoringSwapper.setApprovedAdapter.selector, m0Adapter,        true), value: 0 });
        txs[7] = Deployer.Tx({ target: address(swapper), data: abi.encodeWithSelector(BoringSwapper.setTokenOracle.selector, getERC20(sourceChain, "USDC"), usdQuoteAsset, _makeOracleConfig(usdRateProviders[0], address(0), false)), value: 0 });
        txs[8] = Deployer.Tx({ target: address(swapper), data: abi.encodeWithSelector(BoringSwapper.setTokenOracle.selector, getERC20(sourceChain, "WETH"), usdQuoteAsset, _makeOracleConfig(ethRateProviders[0], address(0), false)), value: 0 });
        txs[9] = Deployer.Tx({ target: address(swapper), data: abi.encodeWithSelector(BoringSwapper.setBaseAssetOracle.selector, getERC20(sourceChain, "USDC"), usdQuoteAsset, usdRateProviders), value: 0 });
        txs[10] = Deployer.Tx({ target: address(swapper), data: abi.encodeWithSelector(BoringSwapper.setBaseAssetOracle.selector, getERC20(sourceChain, "WETH"), usdQuoteAsset, ethRateProviders), value: 0 });
        txs[11] = Deployer.Tx({ target: address(swapper), data: abi.encodeWithSelector(BoringSwapper.setRouteConfig.selector, getERC20(sourceChain, "USDC"), getERC20(sourceChain, "WETH"), 1000, 100_000_000e18, 100_000e18), value: 0 });

        Deployer(getAddress(sourceChain, "txBundlerAddress")).bundleTxs(txs);

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
