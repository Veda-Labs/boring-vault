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
 * Deploys and configures a BoringSwapper through the chain's newer Deployer.
 *
 * The no-argument entrypoint targets Ethereum mainnet, uses the module
 * addresses produced by DeployFullSwapperSuiteScript, points the new swapper
 * at the configured Boring Vault and authority, and approves every deployed
 * adapter. It configures USDC, RLUSD, and PYUSD oracles plus the five routes
 * used by DeployDemoSwapperScript. It reuses the existing USDC rate provider
 * and deploys dedicated RLUSD and PYUSD rate providers.
 *
 * `runWithConfig(DeploymentConfig)` remains available for custom chains,
 * registries, adapters, or route/oracle configuration.
 *
 * Run with `--broadcast --trezor --sender $TREZOR_ADDRESS` when signing with a
 * Trezor. The default entrypoint requires no tuple calldata.
 */
contract DeploySwapperScript is Script, MerkleTreeHelper {
    error DeploySwapper__OracleArrayLengthMismatch();
    error DeploySwapper__RouteArrayLengthMismatch();
    string internal constant DEFAULT_CHAIN = "mainnet";
    string internal constant DEFAULT_SWAPPER_NAME = "BoostedUSDC Boring Swapper Mainnet V0.0";
    address internal constant DEFAULT_BORING_VAULT = 0xDbD87325D7b1189Dcc9255c4926076fF4a96A271;
    address internal constant DEFAULT_ROLES_AUTHORITY = 0x1F53135155d6fF516bCcfDd9424fcdB8AD1eFB77;

    // Outputs from the completed DeployFullSwapperSuiteScript deployment.
    address internal constant DEFAULT_REGISTRY = 0x4Ff93326CaEf992888B8174102d2704Ac9B1C6cd;
    address internal constant DEFAULT_FEE_REGISTRY = 0x284dA0dB01Ad5dbF6aAa690F2f5fdFB172369830;
    address internal constant DEFAULT_VALIDATOR = 0x3aA6dfdBFeE7874C43bbDf476b765215fE9C47e2;
    address internal constant DEFAULT_UNISWAP_V3_ADAPTER = 0x3b2048e24cFdcdBc048Fe2AF7e544422fc5Fa1b1;
    address internal constant DEFAULT_COWSWAP_ADAPTER = 0x25109a67BDC3b90B97F057eCbEc516743CeC3710;
    address internal constant DEFAULT_ONE_INCH_ADAPTER = 0xe404A65fe29a6FC8fbCE781d1440b8A231ca5eB1;
    address internal constant DEFAULT_ONE_INCH_NO_LIMIT_ADAPTER = 0x2481Ff484D2899B9AcCF51Fc5D4e59b2912BD456;
    address internal constant DEFAULT_OPEN_OCEAN_ADAPTER = 0x31193AFA9141d8C8bAFBe7f9f5670aad5e159Fa7;
    address internal constant DEFAULT_LIFI_ADAPTER = 0xB4E998860b0156d33726eA359c6C3f9F13FBC5b4;
    address internal constant DEFAULT_M0_ADAPTER = 0xdE857D64cd0a6A0951a72EF2b9DF791648c33453;
    address internal constant DEFAULT_USDC_RATE_PROVIDER = 0xAD96667e0279c29bb4419d3a8713D381647a43AE;
    address internal constant DEFAULT_USDC_USD_FEED = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address internal constant DEFAULT_RLUSD_USD_FEED = 0x26C46B7aD0012cA71F2298ada567dC9Af14E7f2A;
    address internal constant DEFAULT_PYUSD_USD_FEED = 0x8f1dF6D7F2db73eECE86a18b4381F4707b918FB1;
    uint256 internal constant DEFAULT_SLIPPAGE_BPS = 50;
    uint256 internal constant DEFAULT_ROUTE_CAPACITY = 10_000_000e18;
    uint256 internal constant DEFAULT_ROUTE_REFILL_PER_SECOND = DEFAULT_ROUTE_CAPACITY / 86_400;
    uint256 internal constant DEFAULT_MAX_STALENESS = 90_000;

    struct DeploymentConfig {
        string chainName;
        string swapperName;
        address boringVault;
        address rolesAuthority;
        address registry;
        address feeRegistry;
        address validator;
        address quoteAsset;
        address[] approvedAdapters;
        address[] oracleTokens;
        address[] rateProviderAddresses;
        address[] rateFeeds;
        string[] rateProviderNames;
        uint256[] rateProviderMaxStaleness;
        address[] routeTokenIns;
        address[] routeTokenOuts;
        uint256[] routeSlippageBps;
        uint256[] routeCapacities;
        uint256[] routeRefillPerSecond;
    }

    function run() external {
        _run(_defaultConfig());
    }

    function runWithConfig(DeploymentConfig calldata config) external {
        _run(config);
    }

    function _run(DeploymentConfig memory config) internal {
        _validate(config);

        setSourceChainName(config.chainName);
        vm.createSelectFork(config.chainName);
        vm.startBroadcast();

        Deployer deployer = Deployer(getAddress(sourceChain, "newDeployer"));
        BoringSwapper swapper = _deploySwapper(deployer, config);
        address[] memory rateProviders = _deployRateProviders(deployer, config);
        Deployer.Tx[] memory txs = _buildConfigurationTxs(swapper, config, rateProviders);

        deployer.bundleTxs(txs);
        vm.stopBroadcast();
    }

    function _defaultConfig() internal view returns (DeploymentConfig memory config) {
        config.chainName = DEFAULT_CHAIN;
        config.swapperName = DEFAULT_SWAPPER_NAME;
        config.boringVault = DEFAULT_BORING_VAULT;
        config.rolesAuthority = DEFAULT_ROLES_AUTHORITY;
        config.registry = DEFAULT_REGISTRY;
        config.feeRegistry = DEFAULT_FEE_REGISTRY;
        config.validator = DEFAULT_VALIDATOR;
        config.quoteAsset = getAddress(DEFAULT_CHAIN, "USDC");

        config.approvedAdapters = new address[](7);
        config.approvedAdapters[0] = DEFAULT_UNISWAP_V3_ADAPTER;
        config.approvedAdapters[1] = DEFAULT_COWSWAP_ADAPTER;
        config.approvedAdapters[2] = DEFAULT_ONE_INCH_ADAPTER;
        config.approvedAdapters[3] = DEFAULT_ONE_INCH_NO_LIMIT_ADAPTER;
        config.approvedAdapters[4] = DEFAULT_OPEN_OCEAN_ADAPTER;
        config.approvedAdapters[5] = DEFAULT_LIFI_ADAPTER;
        config.approvedAdapters[6] = DEFAULT_M0_ADAPTER;

        config.oracleTokens = new address[](3);
        config.oracleTokens[0] = address(getERC20(DEFAULT_CHAIN, "USDC"));
        config.oracleTokens[1] = address(getERC20(DEFAULT_CHAIN, "RLUSD"));
        config.oracleTokens[2] = address(getERC20(DEFAULT_CHAIN, "PYUSD"));

        config.rateProviderAddresses = new address[](3);
        config.rateProviderAddresses[0] = DEFAULT_USDC_RATE_PROVIDER;

        config.rateFeeds = new address[](3);
        config.rateFeeds[0] = DEFAULT_USDC_USD_FEED;
        config.rateFeeds[1] = DEFAULT_RLUSD_USD_FEED;
        config.rateFeeds[2] = DEFAULT_PYUSD_USD_FEED;

        config.rateProviderNames = new string[](3);
        config.rateProviderNames[0] = "BoostedUSDC USDC USD Rate Provider V0.0";
        config.rateProviderNames[1] = "BoostedUSDC RLUSD USD Rate Provider V0.0";
        config.rateProviderNames[2] = "BoostedUSDC PYUSD USD Rate Provider V0.0";

        config.rateProviderMaxStaleness = new uint256[](3);
        config.rateProviderMaxStaleness[0] = DEFAULT_MAX_STALENESS;
        config.rateProviderMaxStaleness[1] = DEFAULT_MAX_STALENESS;
        config.rateProviderMaxStaleness[2] = DEFAULT_MAX_STALENESS;

        config.routeTokenIns = new address[](5);
        config.routeTokenOuts = new address[](5);
        config.routeTokenIns[0] = config.oracleTokens[0];
        config.routeTokenOuts[0] = config.oracleTokens[1];
        config.routeTokenIns[1] = config.oracleTokens[1];
        config.routeTokenOuts[1] = config.oracleTokens[0];
        config.routeTokenIns[2] = config.oracleTokens[0];
        config.routeTokenOuts[2] = config.oracleTokens[2];
        config.routeTokenIns[3] = config.oracleTokens[2];
        config.routeTokenOuts[3] = config.oracleTokens[0];
        config.routeTokenIns[4] = config.oracleTokens[1];
        config.routeTokenOuts[4] = config.oracleTokens[2];

        config.routeSlippageBps = new uint256[](5);
        config.routeCapacities = new uint256[](5);
        config.routeRefillPerSecond = new uint256[](5);
        for (uint256 i; i < 5; ++i) {
            config.routeSlippageBps[i] = DEFAULT_SLIPPAGE_BPS;
            config.routeCapacities[i] = DEFAULT_ROUTE_CAPACITY;
            config.routeRefillPerSecond[i] = DEFAULT_ROUTE_REFILL_PER_SECOND;
        }
    }

    function _validate(DeploymentConfig memory config) internal pure {
        if (
            config.oracleTokens.length != config.rateProviderAddresses.length || config.oracleTokens.length != config.rateFeeds.length
                || config.oracleTokens.length != config.rateProviderNames.length || config.oracleTokens.length != config.rateProviderMaxStaleness.length
        ) {
            revert DeploySwapper__OracleArrayLengthMismatch();
        }
        if (
            config.routeTokenIns.length != config.routeTokenOuts.length || config.routeTokenIns.length != config.routeSlippageBps.length
                || config.routeTokenIns.length != config.routeCapacities.length || config.routeTokenIns.length != config.routeRefillPerSecond.length
        ) {
            revert DeploySwapper__RouteArrayLengthMismatch();
        }
    }

    function _deploySwapper(Deployer deployer, DeploymentConfig memory config) internal returns (BoringSwapper swapper) {
        swapper = BoringSwapper(
            deployer.deployContract(
                config.swapperName,
                type(BoringSwapper).creationCode,
                abi.encode(
                    address(deployer),
                    AdapterRegistry(config.registry),
                    IFeeRegistry(config.feeRegistry),
                    BoringVault(payable(config.boringVault)),
                    IPriceValidator(config.validator)
                ),
                0
            )
        );
        console.log("BoringSwapper:", address(swapper));
    }

    function _deployRateProviders(Deployer deployer, DeploymentConfig memory config) internal returns (address[] memory rateProviders) {
        rateProviders = new address[](config.oracleTokens.length);
        for (uint256 i; i < config.oracleTokens.length; ++i) {
            if (config.rateProviderAddresses[i] != address(0)) {
                rateProviders[i] = config.rateProviderAddresses[i];
            } else {
                rateProviders[i] = _deployChainlinkRateProvider(deployer, config.rateProviderNames[i], config.rateFeeds[i], config.rateProviderMaxStaleness[i]);
            }
            console.log("RateProvider:", rateProviders[i]);
        }
    }

    function _buildConfigurationTxs(BoringSwapper swapper, DeploymentConfig memory config, address[] memory rateProviders)
        internal
        pure
        returns (Deployer.Tx[] memory txs)
    {
        uint256 txCount = 1 + config.approvedAdapters.length + (config.oracleTokens.length * 2) + config.routeTokenIns.length;
        txs = new Deployer.Tx[](txCount);
        uint256 txIndex;

        txs[txIndex] = Deployer.Tx({target: address(swapper), data: abi.encodeWithSignature("setAuthority(address)", config.rolesAuthority), value: 0});
        ++txIndex;

        for (uint256 i; i < config.approvedAdapters.length; ++i) {
            txs[txIndex] = Deployer.Tx({
                target: address(swapper), data: abi.encodeWithSelector(BoringSwapper.setApprovedAdapter.selector, config.approvedAdapters[i], true), value: 0
            });
            ++txIndex;
        }

        for (uint256 i; i < config.oracleTokens.length; ++i) {
            txs[txIndex] = Deployer.Tx({
                target: address(swapper),
                data: abi.encodeWithSelector(
                    BoringSwapper.setTokenOracle.selector, config.oracleTokens[i], config.quoteAsset, _makeOracleConfig(rateProviders[i], address(0), false)
                ),
                value: 0
            });
            ++txIndex;

            txs[txIndex] = Deployer.Tx({
                target: address(swapper),
                data: abi.encodeWithSelector(
                    BoringSwapper.setBaseAssetOracle.selector, config.oracleTokens[i], config.quoteAsset, _asSingleton(rateProviders[i])
                ),
                value: 0
            });
            ++txIndex;
        }

        for (uint256 i; i < config.routeTokenIns.length; ++i) {
            txs[txIndex] = Deployer.Tx({
                target: address(swapper),
                data: abi.encodeWithSelector(
                    BoringSwapper.setRouteConfig.selector,
                    config.routeTokenIns[i],
                    config.routeTokenOuts[i],
                    config.routeSlippageBps[i],
                    config.routeCapacities[i],
                    config.routeRefillPerSecond[i]
                ),
                value: 0
            });
            ++txIndex;
        }
    }

    function _deployChainlinkRateProvider(Deployer deployer, string memory name, address feed, uint256 maxStaleness) internal returns (address) {
        return deployer.deployContract(
            name,
            type(GenericRateProviderWithStalenessCheck).creationCode,
            abi.encode(
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
                    maxStaleness: maxStaleness,
                    lastUpdateSelector: 0x8205bf6a,
                    lastUpdateOffset: 0
                })
            ),
            0
        );
    }

    function _asSingleton(address value) internal pure returns (address[] memory values) {
        values = new address[](1);
        values[0] = value;
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
