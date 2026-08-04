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
import {GenericRateProviderWithStalenessCheck} from "src/helper/GenericRateProviderWithStalenessCheck.sol";

import "forge-std/Script.sol";

/**
 *  source .env && forge script script/Test/DeployDemoSwapper.s.sol:DeployDemoSwapperScript --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployDemoSwapperScript is Script, MerkleTreeHelper {
    address constant boringVault = 0xFDea370fa75353e650Cd6b8055600B04a47F68c2;
    address constant rolesAuthority = 0x50215AcEB5BA72d82e0A84BB41e12F8FAa55DfdD;

    address constant registry = 0xef15A0Fde6F89fc72cf04c1896E049D4701A8c6c;
    address constant feeRegistry = 0xc5865A854d4C00cc56e58d735cdb6354aa2884f0;
    address constant validator = 0x0Bea4ff85C12fa27b37514d7eD6d886DF9Ad55C6;

    address constant uniswapV3Adapter = 0x47d0A1cA4fd3F2aeC3e2505ec86f9341C6Ef75F3;
    address constant lifiAdapter = 0x325857fC030f07F62bA2cD0E11105f022193f2a5;
    address constant openOceanAdapter = 0x248F9dD2E288C6934B4BB8e072F26F173800f8Ce;
    address constant oneInchNoLimitAdapter = 0xf3654cD72DA53561a59056438F0c5DF2D663CB7d;

    address constant USDC_USD_FEED = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address constant RLUSD_USD_FEED = 0x26C46B7aD0012cA71F2298ada567dC9Af14E7f2A;
    address constant PYUSD_USD_FEED = 0x8f1dF6D7F2db73eECE86a18b4381F4707b918FB1;

    uint256 constant SLIPPAGE_BPS = 50;
    uint256 constant CAPACITY = 10_000_000e18;
    uint256 constant REFILL_PER_SECOND = CAPACITY / 86_400;
    uint256 constant MAX_STALENESS = 90_000;

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
        console.log("BoringSwapper (DEMO vault):", address(swapper));

        address usdQuoteAsset = getAddress(sourceChain, "USDC");
        address usdcRateProvider = _deployChainlinkRateProvider(USDC_USD_FEED);
        address rlusdRateProvider = _deployChainlinkRateProvider(RLUSD_USD_FEED);
        address pyusdRateProvider = _deployChainlinkRateProvider(PYUSD_USD_FEED);
        console.log("USDC RateProvider:", usdcRateProvider);
        console.log("RLUSD RateProvider:", rlusdRateProvider);
        console.log("PYUSD RateProvider:", pyusdRateProvider);

        address[] memory usdcRateProviders = new address[](1);
        usdcRateProviders[0] = usdcRateProvider;
        address[] memory rlusdRateProviders = new address[](1);
        rlusdRateProviders[0] = rlusdRateProvider;
        address[] memory pyusdRateProviders = new address[](1);
        pyusdRateProviders[0] = pyusdRateProvider;

        Deployer.Tx[] memory txs = new Deployer.Tx[](16);
        txs[0] = Deployer.Tx({target: address(swapper), data: abi.encodeWithSignature("setAuthority(address)", rolesAuthority), value: 0});

        txs[1] = Deployer.Tx({
            target: address(swapper), data: abi.encodeWithSelector(BoringSwapper.setApprovedAdapter.selector, uniswapV3Adapter, true), value: 0
        });
        txs[2] = Deployer.Tx({target: address(swapper), data: abi.encodeWithSelector(BoringSwapper.setApprovedAdapter.selector, lifiAdapter, true), value: 0});
        txs[3] = Deployer.Tx({
            target: address(swapper), data: abi.encodeWithSelector(BoringSwapper.setApprovedAdapter.selector, openOceanAdapter, true), value: 0
        });
        txs[4] = Deployer.Tx({
            target: address(swapper), data: abi.encodeWithSelector(BoringSwapper.setApprovedAdapter.selector, oneInchNoLimitAdapter, true), value: 0
        });

        txs[5] = Deployer.Tx({
            target: address(swapper),
            data: abi.encodeWithSelector(
                BoringSwapper.setTokenOracle.selector, getERC20(sourceChain, "USDC"), usdQuoteAsset, _makeOracleConfig(usdcRateProvider, address(0), false)
            ),
            value: 0
        });
        txs[6] = Deployer.Tx({
            target: address(swapper),
            data: abi.encodeWithSelector(BoringSwapper.setBaseAssetOracle.selector, getERC20(sourceChain, "USDC"), usdQuoteAsset, usdcRateProviders),
            value: 0
        });
        txs[7] = Deployer.Tx({
            target: address(swapper),
            data: abi.encodeWithSelector(
                BoringSwapper.setTokenOracle.selector, getERC20(sourceChain, "RLUSD"), usdQuoteAsset, _makeOracleConfig(rlusdRateProvider, address(0), false)
            ),
            value: 0
        });
        txs[8] = Deployer.Tx({
            target: address(swapper),
            data: abi.encodeWithSelector(BoringSwapper.setBaseAssetOracle.selector, getERC20(sourceChain, "RLUSD"), usdQuoteAsset, rlusdRateProviders),
            value: 0
        });
        txs[9] = Deployer.Tx({
            target: address(swapper),
            data: abi.encodeWithSelector(
                BoringSwapper.setTokenOracle.selector, getERC20(sourceChain, "PYUSD"), usdQuoteAsset, _makeOracleConfig(pyusdRateProvider, address(0), false)
            ),
            value: 0
        });
        txs[10] = Deployer.Tx({
            target: address(swapper),
            data: abi.encodeWithSelector(BoringSwapper.setBaseAssetOracle.selector, getERC20(sourceChain, "PYUSD"), usdQuoteAsset, pyusdRateProviders),
            value: 0
        });

        txs[11] = Deployer.Tx({
            target: address(swapper),
            data: abi.encodeWithSelector(
                BoringSwapper.setRouteConfig.selector, getERC20(sourceChain, "USDC"), getERC20(sourceChain, "RLUSD"), SLIPPAGE_BPS, CAPACITY, REFILL_PER_SECOND
            ),
            value: 0
        });
        txs[12] = Deployer.Tx({
            target: address(swapper),
            data: abi.encodeWithSelector(
                BoringSwapper.setRouteConfig.selector, getERC20(sourceChain, "RLUSD"), getERC20(sourceChain, "USDC"), SLIPPAGE_BPS, CAPACITY, REFILL_PER_SECOND
            ),
            value: 0
        });
        txs[13] = Deployer.Tx({
            target: address(swapper),
            data: abi.encodeWithSelector(
                BoringSwapper.setRouteConfig.selector, getERC20(sourceChain, "USDC"), getERC20(sourceChain, "PYUSD"), SLIPPAGE_BPS, CAPACITY, REFILL_PER_SECOND
            ),
            value: 0
        });
        txs[14] = Deployer.Tx({
            target: address(swapper),
            data: abi.encodeWithSelector(
                BoringSwapper.setRouteConfig.selector, getERC20(sourceChain, "PYUSD"), getERC20(sourceChain, "USDC"), SLIPPAGE_BPS, CAPACITY, REFILL_PER_SECOND
            ),
            value: 0
        });
        txs[15] = Deployer.Tx({
            target: address(swapper),
            data: abi.encodeWithSelector(
                BoringSwapper.setRouteConfig.selector, getERC20(sourceChain, "RLUSD"), getERC20(sourceChain, "PYUSD"), SLIPPAGE_BPS, CAPACITY, REFILL_PER_SECOND
            ),
            value: 0
        });

        Deployer(getAddress(sourceChain, "txBundlerAddress")).bundleTxs(txs);

        vm.stopBroadcast();
    }

    function _deployChainlinkRateProvider(address feed) internal returns (address) {
        return address(
            new GenericRateProviderWithStalenessCheck(
                GenericRateProviderWithStalenessCheck.ConstructorArgs({
                    target: feed,
                    selector: 0x50d25bcd,
                    staticArgument0: 0,
                    staticArgument1: 0,
                    staticArgument2: 0,
                    staticArgument3: 0,
                    staticArgument4: 0,
                    staticArgument5: 0,
                    staticArgument6: 0,
                    staticArgument7: 0,
                    signed: true,
                    inputDecimals: 8,
                    outputDecimals: 18,
                    maxStaleness: MAX_STALENESS,
                    lastUpdateSelector: 0x8205bf6a,
                    lastUpdateOffset: 0
                })
            )
        );
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
