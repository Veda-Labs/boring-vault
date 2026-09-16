// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {AdapterRegistry} from "src/base/Periphery/AdapterRegistry.sol";
import {PriceValidator} from "src/base/Periphery/adapters/price/PriceValidator.sol";
import {UniswapV3Adapter} from "src/base/Periphery/adapters/UniswapV3Adapter.sol";
import {CowswapAdapter} from "src/base/Periphery/adapters/CowswapAdapter.sol";
import {OneInchAdapter} from "src/base/Periphery/adapters/OneInchAdapter.sol";
import {OneInchAdapterNoLimitOrdersNoExecutor} from "src/base/Periphery/adapters/OneInchAdapterNoLimitOrders.sol";
import {OpenOceanAdapter} from "src/base/Periphery/adapters/OpenOceanAdapter.sol";
import {LifiAdapter} from "src/base/Periphery/adapters/LifiAdapter.sol";
import {M0Adapter} from "src/base/Periphery/adapters/M0Adapter.sol";
import {M0SolverRegistry} from "src/base/Periphery/SolverRegistry.sol";
import {GenericRateProviderWithStalenessCheck} from "src/helper/GenericRateProviderWithStalenessCheck.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {FeeRegistry} from "src/base/Periphery/FeeRegistry.sol";

import "forge-std/Script.sol";

/**
 * Deploys the supporting swapper modules without deploying a BoringSwapper.
 * Every contract deployment is routed through the chain's newer Deployer and
 * adapter registration is bundled through it for a one-use deployment.
 *
 * The no-argument entrypoint targets Ethereum mainnet and reads the USDC/USD
 * feed and all protocol addresses from ChainValues. It does not require mUSD,
 * a Boring Vault address, an authority address, or a solver address because no
 * swapper or swapper route is deployed.
 * The existing Boring Vault is not modified or passed to any module; only a
 * BoringSwapper constructor would consume that address.
 *
 * Run with the normal Forge script command; no `--sig` or tuple calldata is
 * required. An optional `runWithConfig(DeploymentConfig)` entrypoint is
 * available for overriding the deployment chain and USDC feed.
 */
contract DeployableAdapterRegistry is AdapterRegistry {
    constructor(address owner_) {
        owner = owner_;
    }
}

contract DeployableM0SolverRegistry is M0SolverRegistry {
    constructor(address owner_) {
        owner = owner_;
    }
}

contract DeployFullSwapperSuiteScript is Script, MerkleTreeHelper {
    uint256 internal constant MAX_FEE_BPS = 10_000;
    // Match the existing deployment scripts' 25-hour feed freshness window.
    uint256 internal constant MAX_STALENESS = 90_000;
    string internal constant DEFAULT_CHAIN = "mainnet";

    struct DeploymentConfig {
        string chainName;
        address usdcUsdFeed;
    }

    struct ChainAddresses {
        address uniV3Router;
        address cowswapSettlement;
        address cowswapVaultRelayer;
        address aggregationRouterV6;
        address oneInchFeeTaker;
        address oneInchFeeReceiver;
        address[] oneInchExecutors;
        address uniV2Factory;
        address uniV3Factory;
        address curveMetaRegistry;
        address openOceanRouter;
        address openOceanCaller;
        address lifiRouter;
        address m0OrderBook;
    }

    struct CoreContracts {
        address registry;
        address validator;
        address feeRegistry;
        address solverRegistry;
    }

    function run() external {
        _run(DeploymentConfig({chainName: DEFAULT_CHAIN, usdcUsdFeed: getAddress(DEFAULT_CHAIN, "USDC_USD_FEED")}));
    }

    function runWithConfig(DeploymentConfig calldata config) external {
        _run(config);
    }

    function _run(DeploymentConfig memory config) internal {
        setSourceChainName(config.chainName);
        vm.createSelectFork(config.chainName);

        ChainAddresses memory addresses = _loadChainAddresses();
        vm.startBroadcast();

        Deployer deployer = Deployer(getAddress(sourceChain, "newDeployer"));
        CoreContracts memory core = _deployCore(deployer);
        AdapterContracts memory adapters = _deployAdapters(deployer, addresses, core.solverRegistry);
        _deployOracles(deployer, config);
        Deployer.Tx[] memory txs = _buildSetupTransactions(core, adapters);

        deployer.bundleTxs(txs);
        vm.stopBroadcast();
    }

    function _loadChainAddresses() internal view returns (ChainAddresses memory addresses) {
        addresses.uniV3Router = getAddress(sourceChain, "uniV3Router");
        addresses.cowswapSettlement = getAddress(sourceChain, "cowswapSettlement");
        addresses.cowswapVaultRelayer = getAddress(sourceChain, "cowswapVaultRelayer");
        addresses.aggregationRouterV6 = getAddress(sourceChain, "aggregationRouterV6");
        addresses.oneInchFeeTaker = getAddress(sourceChain, "oneInchFeeTaker");
        addresses.oneInchFeeReceiver = getAddress(sourceChain, "oneInchFeeReceiver");
        addresses.oneInchExecutors = new address[](1);
        addresses.oneInchExecutors[0] = getAddress(sourceChain, "oneInchExecutor");
        addresses.uniV2Factory = getAddress(sourceChain, "uniV2Factory");
        addresses.uniV3Factory = getAddress(sourceChain, "uniV3Factory");
        addresses.curveMetaRegistry = getAddress(sourceChain, "curveMetaRegistry");
        addresses.openOceanRouter = getAddress(sourceChain, "openOceanRouter");
        addresses.openOceanCaller = getAddress(sourceChain, "openOceanCaller");
        addresses.lifiRouter = getAddress(sourceChain, "lifi");
        addresses.m0OrderBook = getAddress(sourceChain, "m0OrderBook");
    }

    struct AdapterContracts {
        address uniswapV3;
        address cowswap;
        address oneInch;
        address oneInchNoLimit;
        address openOcean;
        address lifi;
        address m0;
    }

    function _deployCore(Deployer deployer) internal returns (CoreContracts memory core) {
        core.registry =
            deployer.deployContract("Boring Swapper Adapter Registry V0.0", type(DeployableAdapterRegistry).creationCode, abi.encode(address(deployer)), 0);
        console.log("AdapterRegistry:", core.registry);

        core.validator = deployer.deployContract("Boring Swapper Price Validator V0.0", type(PriceValidator).creationCode, hex"", 0);
        console.log("PriceValidator:", core.validator);

        core.feeRegistry =
            deployer.deployContract("Boring Swapper Fee Registry V0.0", type(FeeRegistry).creationCode, abi.encode(address(deployer), MAX_FEE_BPS), 0);
        console.log("FeeRegistry:", core.feeRegistry);

        core.solverRegistry =
            deployer.deployContract("Boring Swapper M0 Solver Registry V0.0", type(DeployableM0SolverRegistry).creationCode, abi.encode(address(deployer)), 0);
        console.log("M0SolverRegistry:", core.solverRegistry);
    }

    function _deployAdapters(Deployer deployer, ChainAddresses memory addresses, address solverRegistry) internal returns (AdapterContracts memory adapters) {
        adapters.uniswapV3 =
            deployer.deployContract("Boring Swapper Uniswap V3 Adapter V0.0", type(UniswapV3Adapter).creationCode, abi.encode(addresses.uniV3Router), 0);
        console.log("UniswapV3Adapter:", adapters.uniswapV3);

        adapters.cowswap = deployer.deployContract(
            "Boring Swapper CowSwap Adapter V0.0", type(CowswapAdapter).creationCode, abi.encode(addresses.cowswapSettlement, addresses.cowswapVaultRelayer), 0
        );
        console.log("CowswapAdapter:", adapters.cowswap);

        adapters.oneInch = deployer.deployContract(
            "Boring Swapper One Inch Adapter V0.0",
            type(OneInchAdapter).creationCode,
            abi.encode(
                addresses.aggregationRouterV6,
                addresses.oneInchFeeTaker,
                addresses.oneInchFeeReceiver,
                addresses.oneInchExecutors,
                addresses.uniV2Factory,
                addresses.uniV3Factory,
                addresses.curveMetaRegistry
            ),
            0
        );
        console.log("OneInchAdapter:", adapters.oneInch);

        adapters.oneInchNoLimit = deployer.deployContract(
            "Boring Swapper One Inch No Limit Adapter V0.0",
            type(OneInchAdapterNoLimitOrdersNoExecutor).creationCode,
            abi.encode(
                addresses.aggregationRouterV6,
                addresses.oneInchFeeTaker,
                addresses.oneInchFeeReceiver,
                addresses.uniV2Factory,
                addresses.uniV3Factory,
                addresses.curveMetaRegistry
            ),
            0
        );
        console.log("OneInchAdapterNoLimitOrdersNoExecutor:", adapters.oneInchNoLimit);

        adapters.openOcean = deployer.deployContract(
            "Boring Swapper OpenOcean Adapter V0.0",
            type(OpenOceanAdapter).creationCode,
            abi.encode(addresses.openOceanRouter, addresses.openOceanCaller, addresses.uniV2Factory, addresses.uniV3Factory),
            0
        );
        console.log("OpenOceanAdapter:", adapters.openOcean);

        adapters.lifi = deployer.deployContract("Boring Swapper LiFi Adapter V0.0", type(LifiAdapter).creationCode, abi.encode(addresses.lifiRouter), 0);
        console.log("LifiAdapter:", adapters.lifi);

        adapters.m0 = deployer.deployContract(
            "Boring Swapper M0 Adapter V0.0", type(M0Adapter).creationCode, abi.encode(addresses.m0OrderBook, M0SolverRegistry(solverRegistry)), 0
        );
        console.log("M0Adapter:", adapters.m0);
    }

    function _deployOracles(Deployer deployer, DeploymentConfig memory config) internal {
        address tokenInRateProvider = _deployChainlinkRateProvider(deployer, "Full Swapper USDC Rate Provider V0.0", config.usdcUsdFeed);
        console.log("USDC RateProvider:", tokenInRateProvider);
    }

    function _buildSetupTransactions(CoreContracts memory core, AdapterContracts memory adapters) internal pure returns (Deployer.Tx[] memory txs) {
        txs = new Deployer.Tx[](7);
        uint256 txIndex;

        txs[txIndex++] =
            Deployer.Tx({target: core.registry, data: abi.encodeWithSelector(AdapterRegistry.put.selector, adapters.uniswapV3, "UNISWAPV3_V1"), value: 0});
        txs[txIndex++] =
            Deployer.Tx({target: core.registry, data: abi.encodeWithSelector(AdapterRegistry.put.selector, adapters.cowswap, "COWSWAP_V1"), value: 0});
        txs[txIndex++] =
            Deployer.Tx({target: core.registry, data: abi.encodeWithSelector(AdapterRegistry.put.selector, adapters.oneInch, "ONEINCH_V1"), value: 0});
        txs[txIndex++] = Deployer.Tx({
            target: core.registry,
            data: abi.encodeWithSelector(AdapterRegistry.put.selector, adapters.oneInchNoLimit, "ONEINCH_NO_LIMITS_NO_EXECUTOR_V1"),
            value: 0
        });
        txs[txIndex++] =
            Deployer.Tx({target: core.registry, data: abi.encodeWithSelector(AdapterRegistry.put.selector, adapters.openOcean, "OPENOCEAN_V1"), value: 0});
        txs[txIndex++] = Deployer.Tx({target: core.registry, data: abi.encodeWithSelector(AdapterRegistry.put.selector, adapters.lifi, "LIFI_V1"), value: 0});
        txs[txIndex++] = Deployer.Tx({target: core.registry, data: abi.encodeWithSelector(AdapterRegistry.put.selector, adapters.m0, "M0_V1"), value: 0});
    }

    function _deployChainlinkRateProvider(Deployer deployer, string memory name, address feed) internal returns (address) {
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
                    maxStaleness: MAX_STALENESS,
                    lastUpdateSelector: 0x8205bf6a,
                    lastUpdateOffset: 0
                })
            ),
            0
        );
    }
}
