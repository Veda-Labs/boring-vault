// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringSwapper} from "src/base/Periphery/BoringSwapper.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {AdapterRegistry} from "src/base/Periphery/AdapterRegistry.sol";
import {IFeeRegistry} from "src/interfaces/IFeeRegistry.sol";
import {IPriceValidator} from "src/interfaces/IPriceValidator.sol";
import {PriceValidator} from "src/base/Periphery/adapters/price/PriceValidator.sol";
import {UniswapV3Adapter} from "src/base/Periphery/adapters/UniswapV3Adapter.sol";
import {CowswapAdapter} from "src/base/Periphery/adapters/CowswapAdapter.sol";
import {OneInchAdapter} from "src/base/Periphery/adapters/OneInchAdapter.sol";
import {OpenOceanAdapter} from "src/base/Periphery/adapters/OpenOceanAdapter.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {Deployer} from "src/helper/Deployer.sol";

import "forge-std/Script.sol";

/**
 *  source .env && forge script script/Test/DeployBoringSwapper.s.sol:DeployBoringSwapperTestSuite --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployBoringSwapperTestSuite is Script, MainnetAddresses {
    AdapterRegistry registry;
    BoringSwapper swapper;
    PriceValidator validator;

    // CoW Protocol constants
    address constant COW_SETTLEMENT    = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    address constant COW_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;
    // 1inch constants
    address constant ONEINCH_ROUTER    = 0x111111125421cA6dc452d289314280a0f8842A65;
    address constant ONEINCH_FEE_TAKER = 0xc0DFdB9E7a392c3dBBE7c6FBe8FBC1789C9FE05e;
    address constant ONEINCH_EXECUTOR  = 0x990636ecB3FF04d33D92e970d3d588bF5cD8d086;
    // OpenOcean constants
    address constant OPENOCEAN_ROUTER      = 0x6352a56caadC4F1E25CD6c75970Fa768A3304e64;
    address constant OPENOCEAN_CALLER      = 0x7Baa298D36fE21Df2F6B54510Da76445661A91Ed;
    address constant OPENOCEAN_LIMIT_ORDER = 0xcC8d695603ce0b43D352891892FcC716c6a7C9f4;

    address constant boringVault   = 0xE003287E34fF16A109477e84A0D271C5c3dc3c7f;
    address constant txBundler     = 0x47Cec90FACc9364D7C21A8ab5e2aD9F1f75D740C;
    address constant rolesAuthority = 0x1Ae56c37aF9C27d036a1A8a4d9C0762e15D947B8;

    function setUp() external {
        vm.createSelectFork("mainnet");
    }

    function run() external {
        vm.startBroadcast();

        registry = new AdapterRegistry();
        console.log("AdapterRegistry:", address(registry));

        validator = new PriceValidator();
        console.log("PriceValidator: ", address(validator));

        // Owner is set to the tx bundler so all auth-gated swapper calls go through bundleTxs.
        swapper = new BoringSwapper(
            txBundler,
            registry,
            IFeeRegistry(address(0)),
            BoringVault(payable(boringVault)),
            IPriceValidator(address(validator))
        );
        console.log("BoringSwapper:  ", address(swapper));

        address uniswapV3Adapter = address(new UniswapV3Adapter(uniV3Router));
        address cowswapAdapter   = address(new CowswapAdapter(COW_SETTLEMENT, COW_VAULT_RELAYER));
        address oneInchAdapter   = address(new OneInchAdapter(ONEINCH_ROUTER, ONEINCH_FEE_TAKER, ONEINCH_EXECUTOR));
        address openOceanAdapter = address(new OpenOceanAdapter(OPENOCEAN_ROUTER, OPENOCEAN_CALLER, OPENOCEAN_LIMIT_ORDER));

        console.log("UniswapV3Adapter:", uniswapV3Adapter);
        console.log("CowswapAdapter:  ", cowswapAdapter);
        console.log("OneInchAdapter:  ", oneInchAdapter);
        console.log("OpenOceanAdapter:", openOceanAdapter);

        // Register adapters in the registry — direct calls, registry is owned by the broadcaster.
        registry.put(uniswapV3Adapter, "UNISWAP_V3");
        registry.put(cowswapAdapter,   "COWSWAP");
        registry.put(oneInchAdapter,   "ONEINCH");
        registry.put(openOceanAdapter, "OPENOCEAN");

        // Bundle all auth-gated swapper setup through the tx bundler (owner of the swapper).
        // This also routes the roles auth calls through the bundler, which holds the necessary
        // capabilities on the RolesAuthority.
        Deployer.Tx[] memory txs = new Deployer.Tx[](5);

        txs[0] = Deployer.Tx({
            target: address(swapper),
            data: abi.encodeWithSignature("setAuthority(address)", rolesAuthority),
            value: 0
        });
        txs[1] = Deployer.Tx({
            target: address(swapper),
            data: abi.encodeWithSelector(BoringSwapper.setApprovedAdapter.selector, uniswapV3Adapter, true),
            value: 0
        });
        txs[2] = Deployer.Tx({
            target: address(swapper),
            data: abi.encodeWithSelector(BoringSwapper.setApprovedAdapter.selector, cowswapAdapter, true),
            value: 0
        });
        txs[3] = Deployer.Tx({
            target: address(swapper),
            data: abi.encodeWithSelector(BoringSwapper.setApprovedAdapter.selector, oneInchAdapter, true),
            value: 0
        });
        txs[4] = Deployer.Tx({
            target: address(swapper),
            data: abi.encodeWithSelector(BoringSwapper.setApprovedAdapter.selector, openOceanAdapter, true),
            value: 0
        });

        Deployer(txBundler).bundleTxs(txs);

        vm.stopBroadcast();
    }
}
