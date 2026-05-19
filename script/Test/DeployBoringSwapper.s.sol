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
import {LifiAdapter} from "src/base/Periphery/adapters/LifiAdapter.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {Deployer} from "src/helper/Deployer.sol";

import "forge-std/Script.sol";

/**
 *  source .env && forge script script/Test/DeployBoringSwapper.s.sol:DeployBoringSwapperTestSuite --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployBoringSwapperTestSuite is Script, MainnetAddresses {
    AdapterRegistry registry;
    //BoringSwapper swapper;
    PriceValidator validator;

    // CoW Protocol constants
    address constant COW_SETTLEMENT    = 0x9008D19f58AAbD9eD0D60971565AA8510560ab41;
    address constant COW_VAULT_RELAYER = 0xC92E8bdf79f0507f65a392b0ab4667716BFE0110;
    // 1inch constants
    address constant ONEINCH_ROUTER    = 0x111111125421cA6dc452d289314280a0f8842A65;
    address constant ONEINCH_FEE_TAKER = 0xc0DFdB9E7a392c3dBBE7c6FBe8FBC1789C9FE05e;
    address constant ONEINCH_EXECUTOR  = 0x4c3ccC98C01103bE72bcfd29e1D2454c98d1A6e3;
    // OpenOcean constants
    address constant OPENOCEAN_ROUTER      = 0x6352a56caadC4F1E25CD6c75970Fa768A3304e64;
    address constant OPENOCEAN_CALLER      = 0xa8F8296f4053fd65e89b245d6c7F983a70234C8b;
    address constant OPENOCEAN_LIMIT_ORDER = 0xcC8d695603ce0b43D352891892FcC716c6a7C9f4;
    // LI.FI constants
    address constant LIFI_ROUTER           = 0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE;

    address constant boringVault     = 0xE003287E34fF16A109477e84A0D271C5c3dc3c7f;
    address constant txBundler       = 0x47Cec90FACc9364D7C21A8ab5e2aD9F1f75D740C;
    address constant rolesAuthority  = 0x1Ae56c37aF9C27d036a1A8a4d9C0762e15D947B8;
    address constant swapper         = 0x25f08477f1d39A3c962d20c41b2166a7C1aA7970;
    address constant adapterRegistry = 0x806D8c01D31e8a76D3d48132AF326dE68B3c5FDf;

    uint256 constant MAX_SLIPPAGE_BPS    = 200;
    uint256 constant RATE_LIMIT_CAPACITY = 0;
    uint256 constant RATE_LIMIT_REFILL   = 0;

    function setUp() external {
        vm.createSelectFork("mainnet");
    }

    function run() external {
        vm.startBroadcast();

        address lifiAdapter      = address(new LifiAdapter(LIFI_ROUTER));
        address openOceanAdapter = address(new OpenOceanAdapter(OPENOCEAN_ROUTER, OPENOCEAN_CALLER, OPENOCEAN_LIMIT_ORDER));
        console.log("LifiAdapter:     ", lifiAdapter);
        console.log("OpenOceanAdapter:", openOceanAdapter);

        Deployer.Tx[] memory txs = new Deployer.Tx[](2);

        txs[0] = Deployer.Tx({
            target: swapper,
            data: abi.encodeWithSelector(BoringSwapper.setApprovedAdapter.selector, lifiAdapter, true),
            value: 0
        });
        txs[1] = Deployer.Tx({
            target: swapper,
            data: abi.encodeWithSelector(BoringSwapper.setApprovedAdapter.selector, openOceanAdapter, true),
            value: 0
        });

        Deployer(txBundler).bundleTxs(txs);

        AdapterRegistry(adapterRegistry).put(lifiAdapter, "LIFI");
        AdapterRegistry(adapterRegistry).put(openOceanAdapter, "OPENOCEAN_V2");

        vm.stopBroadcast();
    }



    // ============================================================
    // Full initial deployment — already executed, kept for reference
    // ============================================================

    // function deploy() external {
    //     vm.startBroadcast();
    //
    //     registry = new AdapterRegistry();
    //     console.log("AdapterRegistry:", address(registry));
    //
    //     validator = new PriceValidator();
    //     console.log("PriceValidator: ", address(validator));
    //
    //     // Owner is set to the tx bundler so all auth-gated swapper calls go through bundleTxs.
    //     BoringSwapper _swapper = new BoringSwapper(
    //         txBundler,
    //         registry,
    //         IFeeRegistry(address(0)),
    //         BoringVault(payable(boringVault)),
    //         IPriceValidator(address(validator))
    //     );
    //     console.log("BoringSwapper:  ", address(_swapper));
    //
    //     address uniswapV3Adapter = address(new UniswapV3Adapter(uniV3Router));
    //     address cowswapAdapter   = address(new CowswapAdapter(COW_SETTLEMENT, COW_VAULT_RELAYER));
    //     address oneInchAdapter   = address(new OneInchAdapter(ONEINCH_ROUTER, ONEINCH_FEE_TAKER, ONEINCH_EXECUTOR));
    //     console.log("UniswapV3Adapter:", uniswapV3Adapter);
    //     console.log("CowswapAdapter:  ", cowswapAdapter);
    //     console.log("OneInchAdapter:  ", oneInchAdapter);
    //     console.log("OpenOceanAdapter:", openOceanAdapter);
    //
    //     registry.put(uniswapV3Adapter, "UNISWAP_V3");
    //     registry.put(cowswapAdapter,   "COWSWAP");
    //     registry.put(oneInchAdapter,   "ONEINCH");
    //     registry.put(openOceanAdapter, "OPENOCEAN");
    //
    //     Deployer.Tx[] memory txs = new Deployer.Tx[](5);
    //     txs[0] = Deployer.Tx({ target: address(_swapper), data: abi.encodeWithSignature("setAuthority(address)", rolesAuthority), value: 0 });
    //     txs[1] = Deployer.Tx({ target: address(_swapper), data: abi.encodeWithSelector(BoringSwapper.setApprovedAdapter.selector, uniswapV3Adapter, true), value: 0 });
    //     txs[2] = Deployer.Tx({ target: address(_swapper), data: abi.encodeWithSelector(BoringSwapper.setApprovedAdapter.selector, cowswapAdapter,   true), value: 0 });
    //     txs[3] = Deployer.Tx({ target: address(_swapper), data: abi.encodeWithSelector(BoringSwapper.setApprovedAdapter.selector, oneInchAdapter,   true), value: 0 });
    //     txs[4] = Deployer.Tx({ target: address(_swapper), data: abi.encodeWithSelector(BoringSwapper.setApprovedAdapter.selector, openOceanAdapter, true), value: 0 });
    //     Deployer(txBundler).bundleTxs(txs);
    //
           
}
