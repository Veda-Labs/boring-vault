// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {BoringSwapper} from "src/base/Periphery/BoringSwapper.sol";
import {ISwapperTypes} from "src/interfaces/ISwapperTypes.sol";
import {BoringSwapperDecoder} from "src/base/DecodersAndSanitizers/Protocols/BoringSwapperDecoderAndSanitizer.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {AdapterRegistry} from "src/base/Periphery/AdapterRegistry.sol";
import {OpenOceanAdapter} from "src/base/Periphery/adapters/OpenOceanAdapter.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {PriceValidator} from "src/base/Periphery/adapters/price/PriceValidator.sol";
import {IPriceValidator} from "src/interfaces/IPriceValidator.sol";
import {FeeRegistry} from "src/base/Periphery/FeeRegistry.sol";
import {IFeeRegistry} from "src/interfaces/IFeeRegistry.sol";

import {Test, console} from "@forge-std/Test.sol";

contract MockRateProvider is IRateProvider {
    uint256 internal rate;

    constructor(uint256 _rate) {
        rate = _rate;
    }

    function getRate() public view override returns (uint256) {
        return rate;
    }
}

contract OpenOceanAdapterTest is BaseTestIntegration {

    // OpenOcean Exchange V2 router on mainnet
    address constant OPENOCEAN_ROUTER = 0x6352a56caadC4F1E25CD6c75970Fa768A3304e64;
    // Official OpenOcean caller — enforced by the adapter
    address constant OPENOCEAN_CALLER = 0x7Baa298D36fE21Df2F6B54510Da76445661A91Ed;

    address openOceanAdapter;

    AdapterRegistry registry;
    BoringSwapper swapper;
    PriceValidator validator;

    MockRateProvider usdRate;
    MockRateProvider ethRate;

    function setUp() public override {
        super.setUp();
        _setupChain("mainnet", 24843705);

        address swapperDecoder = address(new BoringSwapperDecoder());
        _overrideDecoder(swapperDecoder);

        registry = new AdapterRegistry();
        validator = new PriceValidator();
        swapper = new BoringSwapper(address(this), registry, new FeeRegistry(address(this), 1000), boringVault, IPriceValidator(address(validator)));
        swapper.setAuthority(rolesAuthority);

        openOceanAdapter = address(new OpenOceanAdapter(OPENOCEAN_ROUTER, OPENOCEAN_CALLER, address(0x420)));

        //console.log(openOceanAdapter);

        swapper.setRouteConfig(getERC20(sourceChain, "WETH"), getERC20(sourceChain, "USDC"), 10000, 0, 0);
        swapper.setRouteConfig(getERC20(sourceChain, "WETH"), getERC20(sourceChain, "USDT"), 10000, 0, 0);
        swapper.setApprovedAdapter(openOceanAdapter, true);

        registry.put(openOceanAdapter, "OPENOCEAN");

        // oracle setup
        usdRate = new MockRateProvider(1e18);
        ethRate = new MockRateProvider(2000e18);
        address usdQuoteAsset = getAddress(sourceChain, "USDC");

        swapper.setTokenOracle(getERC20(sourceChain, "USDC"), usdQuoteAsset, _makeOracleConfig(address(usdRate), address(0), false));
        swapper.setTokenOracle(getERC20(sourceChain, "USDT"), usdQuoteAsset, _makeOracleConfig(address(usdRate), address(0), false));
        swapper.setTokenOracle(getERC20(sourceChain, "WETH"), usdQuoteAsset, _makeOracleConfig(address(ethRate), address(0), false));

        // roles setup
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
        rolesAuthority.setRoleCapability(BORING_VAULT_ROLE, address(swapper), BoringSwapper.swap.selector, true);
        rolesAuthority.setRoleCapability(BORING_VAULT_ROLE, address(swapper), BoringSwapper.submitOrder.selector, true);
        rolesAuthority.setRoleCapability(BORING_VAULT_ROLE, address(swapper), BoringSwapper.cancelOrder.selector, true);
        rolesAuthority.setRoleCapability(BORING_VAULT_ROLE, address(swapper), BoringSwapper.replaceOrder.selector, true);

        // base asset oracles — required for limit order price validation
        swapper.setBaseAssetOracle(getERC20(sourceChain, "WETH"), usdQuoteAsset, _toArray(address(ethRate)));
        swapper.setBaseAssetOracle(getERC20(sourceChain, "USDC"), usdQuoteAsset, _toArray(address(usdRate)));

        // allow swapper to pull WETH from vault for limit orders
        vm.prank(getAddress(sourceChain, "boringVault"));
        getERC20(sourceChain, "WETH").approve(address(swapper), type(uint256).max);
    }

    //==================== OpenOcean swap() Tests ====================

    function testSwap() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        address[] memory tokens = new address[](2);
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDC");

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), tokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[0]; // approve token
        tx_.manageLeafs[1] = leafs[5]; // swap WETH -> USDC

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH"); // approve
        tx_.targets[1] = address(swapper);

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );

        // swap() WETH -> USDC via OpenOcean (live quote, dstReceiver = test swapper)
        bytes memory swapData = hex"90411a320000000000000000000000007baa298d36fe21df2f6b54510da76445661a91ed000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000001c0000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000007baa298d36fe21df2f6b54510da76445661a91ed00000000000000000000000003A6a84cD762D9707A21605b548aaaB891562aAb00000000000000000000000000000000000000000000000000038d7ea4c680000000000000000000000000000000000000000000000000000000000000216808000000000000000000000000000000000000000000000000000000000021be720000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000500000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000026000000000000000000000000000000000000000000000000000000000000004200000000000000000000000000000000000000000000000000000000000000720000000000000000000000000000000000000000000000000000000000000084000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000104e5b07cdb0000000000000000000000008db1b906d47dfc1d84a87fc49bd0522e285b98b9000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000037b4e07e140000000000000000000000000007baa298d36fe21df2f6b54510da76445661a91ed00000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000002ec02aaa39b223fe8d0a0e5c4f27ead9083c756cc20001f41a7e4e63778b4f12a199c062f3efdd288afcbce80000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000104e5b07cdb0000000000000000000000009496d107a4b90c7d18c703e8685167f90ac273b00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000012309ce540000000000000000000000000007baa298d36fe21df2f6b54510da76445661a91ed00000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000002ec02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000bb81a7e4e63778b4f12a199c062f3efdd288afcbce800000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000002449f8654220000000000000000000000001a7e4e63778b4f12a199c062f3efdd288afcbce800000000000000000000000000000001000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000004400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000104e5b07cdb000000000000000000000000735a26a57a0a0069dfabd41595a970faf5e1ee8b000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000010000000000000000000000007baa298d36fe21df2f6b54510da76445661a91ed00000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000002e1a7e4e63778b4f12a199c062f3efdd288afcbce8000064a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000000648a6a1e85000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000922164bbbd36acf9e854acbbf32facc949fcaeef000300000000000000000000000000000000000000000000000000000021c10900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000008000000000000000000000000000000000000000000000000000000000000001a49f865422000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000001000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000004400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000064d1660f99000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000003a6a84cd762d9707a21605b548aaab891562aab00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000";

        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );
        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.swap.selector,
            ISwapperTypes.SwapConfig({
                tokenRoute: tokenRoute,
                adapter: openOceanAdapter,
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: swapData,
                slippageBps: 10,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);
    }

    //==================== OpenOcean simpleSwap() Tests ====================

    function testSimpleSwap() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        address[] memory tokens = new address[](2);
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDC");

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), tokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[0]; // approve token
        tx_.manageLeafs[1] = leafs[5]; // swap WETH -> USDC

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH"); // approve
        tx_.targets[1] = address(swapper);

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );

        // simpleSwap() WETH -> USDC — manually constructed, empty calls[] so router fails but adapter validates
        bytes memory swapData = hex"0a9704d50000000000000000000000007baa298d36fe21df2f6b54510da76445661a91ed000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000001a0000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000007baa298d36fe21df2f6b54510da76445661a91ed000000000000000000000000a4ad4f68d0b91cfd19687c881e50f3a00242828c00000000000000000000000000000000000000000000000000038d7ea4c68000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );
        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.swap.selector,
            ISwapperTypes.SwapConfig({
                tokenRoute: tokenRoute,
                adapter: openOceanAdapter,
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: swapData,
                slippageBps: 10,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        // Adapter validation passes; router fails with empty calls[] — zero output fails price check.
        vm.expectRevert();
        _submitManagerCall(manageProofs, tx_);
    }

    //==================== OpenOcean callUniswap() Tests ====================

    function testCallUniswap() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        address[] memory tokens = new address[](2);
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDC");

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), tokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[0]; // approve token
        tx_.manageLeafs[1] = leafs[5]; // swap WETH -> USDC

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH"); // approve
        tx_.targets[1] = address(swapper);

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );

        // callUniswap() WETH -> USDC via UniV2 USDC/WETH pool (REVERSE_MASK set — output is token0=USDC)
        bytes memory swapData = hex"8980041a000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000038d7ea4c68000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000001800000000000000000000000b4e16d0168e52d35cacd2c6185b44281ec28c9dc";

        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );
        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.swap.selector,
            ISwapperTypes.SwapConfig({
                tokenRoute: tokenRoute,
                adapter: openOceanAdapter,
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: swapData,
                slippageBps: 10,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        // Adapter preflight passes (tokens validate correctly); router fails because the manually-
        // constructed pool bytes omit the fee numerator, so OpenOcean computes amountOut=0.
        vm.expectRevert(abi.encodeWithSelector(BoringSwapper.BoringSwapper__SwapFailed.selector));
        _submitManagerCall(manageProofs, tx_);
    }

    function testCallUniswap_RevertsDstTokenMismatch() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        address[] memory tokens = new address[](2);
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDT");

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), tokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[0]; // approve token
        tx_.manageLeafs[1] = leafs[5]; // swap WETH -> USDT

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH"); // approve
        tx_.targets[1] = address(swapper);

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );

        // Same callUniswap WETH->USDC calldata; SwapConfig claims USDT — dstToken mismatch expected
        bytes memory swapData = hex"8980041a000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000038d7ea4c68000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000001800000000000000000000000b4e16d0168e52d35cacd2c6185b44281ec28c9dc";

        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDT")
        );
        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.swap.selector,
            ISwapperTypes.SwapConfig({
                tokenRoute: tokenRoute,
                adapter: openOceanAdapter,
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: swapData,
                slippageBps: 10,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        vm.expectRevert(abi.encodeWithSelector(OpenOceanAdapter.OpenOceanAdapter__DstTokenMismatch.selector));
        _submitManagerCall(manageProofs, tx_);
    }

    //==================== OpenOcean callUniswapTo() Tests ====================

    function testCallUniswapTo() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        address[] memory tokens = new address[](2);
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDC");

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), tokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[0]; // approve token
        tx_.manageLeafs[1] = leafs[5]; // swap WETH -> USDC

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH"); // approve
        tx_.targets[1] = address(swapper);

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );

        // callUniswapTo() WETH -> USDC via UniV2, recipient = test swapper
        //
        //
        //bytes memory swapData = hex"6b58f2f0000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000038d7ea4c68000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000a4ad4f68d0b91cfd19687c881e50f3a00242828c0000000000000000000000000000000000000000000000000000000000000001800000000000000000000000b4e16d0168e52d35cacd2c6185b44281ec28c9dc";

        // bit 255 = REVERSE (token1→token0); bits 160–191 = fee numerator (997e6 = V2 0.3%); bits 0–159 = pool
        bytes32[] memory pools = new bytes32[](1);
        pools[0] = bytes32(
            uint256(0x8000000000000000000000000000000000000000000000000000000000000000)
            | (uint256(997_000_000) << 160)
            | uint256(uint160(0xB4e16d0168e52d35CaCD2c6185b44281Ec28C9Dc))
        );

        bytes memory swapData = abi.encodeWithSelector(
            OpenOceanAdapter.callUniswapTo.selector,
            getAddress(sourceChain, "WETH"),
            1e15,
            1.75e6,
            pools,
            address(swapper)
        );

        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );
        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.swap.selector,
            ISwapperTypes.SwapConfig({
                tokenRoute: tokenRoute,
                adapter: openOceanAdapter,
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: swapData,
                slippageBps: 5000,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);
    }

    //==================== OpenOcean uniswapV3SwapTo() Tests ====================

    function testUniswapV3SwapTo() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        address[] memory tokens = new address[](2);
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDC");

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), tokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[0]; // approve token
        tx_.manageLeafs[1] = leafs[5]; // swap WETH -> USDC

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH"); // approve
        tx_.targets[1] = address(swapper);

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );

        // uniswapV3SwapTo() WETH -> USDC via UniV3 0.05% pool, ONE_FOR_ZERO_MASK set (token1→token0), recipient = test swapper
        // minReturn = 2_000_000 (2 USDC) — must be non-zero or OpenOcean sends all output to its fee taker
        bytes memory swapData = hex"bc80f1a800000000000000000000000003A6a84cD762D9707A21605b548aaaB891562aAb00000000000000000000000000000000000000000000000000038d7ea4c6800000000000000000000000000000000000000000000000000000000000001e84800000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000180000000000000000000000088e6a0c2ddd26feeb64f039a2c41296fcb3f5640";

        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );
        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.swap.selector,
            ISwapperTypes.SwapConfig({
                tokenRoute: tokenRoute,
                adapter: openOceanAdapter,
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: swapData,
                slippageBps: 500,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        _submitManagerCall(manageProofs, tx_);
    }

    function testUniswapV3SwapTo_RevertsDstTokenMismatch() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        address[] memory tokens = new address[](2);
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDT");

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), tokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[0]; // approve token
        tx_.manageLeafs[1] = leafs[5]; // swap WETH -> USDT

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH"); // approve
        tx_.targets[1] = address(swapper);

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );

        console.log("swapper ", address(swapper));

        // Same uniswapV3SwapTo WETH->USDC calldata; SwapConfig claims USDT — dstToken mismatch expected
        bytes memory swapData = hex"bc80f1a800000000000000000000000003A6a84cD762D9707A21605b548aaaB891562aAb00000000000000000000000000000000000000000000000000038d7ea4c6800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000180000000000000000000000088e6a0c2ddd26feeb64f039a2c41296fcb3f5640";

        ISwapperTypes.TokenRoute memory tokenRoute = ISwapperTypes.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDT")
        );
        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.swap.selector,
            ISwapperTypes.SwapConfig({
                tokenRoute: tokenRoute,
                adapter: openOceanAdapter,
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: swapData,
                slippageBps: 10,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        vm.expectRevert(abi.encodeWithSelector(OpenOceanAdapter.OpenOceanAdapter__DstTokenMismatch.selector));
        _submitManagerCall(manageProofs, tx_);
    }

    //==================== Limit Order Tests ====================

    bytes32 constant LIMIT_ORDER_TYPE_HASH = keccak256(
        "Order(uint256 salt,address makerAsset,address takerAsset,address maker,address receiver,address allowedSender,uint256 makingAmount,uint256 takingAmount,bytes makerAssetData,bytes takerAssetData,bytes getMakerAmount,bytes getTakerAmount,bytes predicate,bytes permit,bytes interaction)"
    );

    function testSubmitLimitOrder() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        (ISwapperTypes.SwapConfig memory config,, uint256 orderId) = _submitLimitOrder(1e18, 2000e6);

        (ERC20 tokenIn,, address cancelTarget, BoringVault receiver, uint256 inputAmount,,,) =
            swapper.orderRecords(orderId);
        assertEq(address(tokenIn), getAddress(sourceChain, "WETH"));
        assertEq(inputAmount, 1e18);
        assertEq(address(receiver), getAddress(sourceChain, "boringVault"));
        assertEq(cancelTarget, address(0x420));

        assertEq(getERC20(sourceChain, "WETH").balanceOf(address(swapper)), 1e18);
        assertEq(getERC20(sourceChain, "WETH").balanceOf(getAddress(sourceChain, "boringVault")), 99e18);
    }

    function testSubmitLimitOrder_RevertBadSlippage() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        // Route allows 500 bps (5%), oracle says 2000 USDC per WETH — 1800 USDC is 10% below
        (ISwapperTypes.SwapConfig memory config,) = _buildLimitOrderConfig(1e18, 1800e6);
        vm.prank(getAddress(sourceChain, "boringVault"));
        vm.expectRevert(abi.encodeWithSelector(PriceValidator.PriceValidator__ExceedsMaxSlippage.selector));
        swapper.submitOrder(config);
    }

    function testSubmitLimitOrder_RevertMakerAssetMismatch() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        // Route stays WETH→USDC (approved). Order has wrong makerAsset — adapter catches the mismatch.
        DecoderCustomTypes.OpenOceanLimitOrder memory order = _defaultOrder(1e18, 2000e6);
        order.makerAsset = getAddress(sourceChain, "USDC");

        vm.prank(getAddress(sourceChain, "boringVault"));
        vm.expectRevert(abi.encodeWithSelector(OpenOceanAdapter.OpenOceanAdapter__MakerAssetMismatch.selector));
        swapper.submitOrder(_orderToConfig(order));
    }

    function testSubmitLimitOrder_RevertTakerAssetMismatch() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        // Route stays WETH→USDC (approved). Order has wrong takerAsset — adapter catches the mismatch.
        DecoderCustomTypes.OpenOceanLimitOrder memory order = _defaultOrder(1e18, 2000e6);
        order.takerAsset = getAddress(sourceChain, "WETH");

        vm.prank(getAddress(sourceChain, "boringVault"));
        vm.expectRevert(abi.encodeWithSelector(OpenOceanAdapter.OpenOceanAdapter__TakerAssetMismatch.selector));
        swapper.submitOrder(_orderToConfig(order));
    }

    function testSubmitLimitOrder_RevertMakerNotSwapper() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        DecoderCustomTypes.OpenOceanLimitOrder memory order = _defaultOrder(1e18, 2000e6);
        order.maker = address(0x42069);

        vm.prank(getAddress(sourceChain, "boringVault"));
        vm.expectRevert(abi.encodeWithSelector(OpenOceanAdapter.OpenOceanAdapter__MakerNotSwapper.selector));
        swapper.submitOrder(_orderToConfig(order));
    }

    function testSubmitLimitOrder_RevertReceiverMismatch() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        DecoderCustomTypes.OpenOceanLimitOrder memory order = _defaultOrder(1e18, 2000e6);
        order.receiver = address(0x42069);

        vm.prank(getAddress(sourceChain, "boringVault"));
        vm.expectRevert(abi.encodeWithSelector(OpenOceanAdapter.OpenOceanAdapter__ReceiverMismatch.selector));
        swapper.submitOrder(_orderToConfig(order));
    }

    function testSubmitLimitOrder_RevertNonEmptyGetMakerAmount() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        DecoderCustomTypes.OpenOceanLimitOrder memory order = _defaultOrder(1e18, 2000e6);
        order.getMakerAmount = hex"1234";

        vm.prank(getAddress(sourceChain, "boringVault"));
        vm.expectRevert(abi.encodeWithSelector(OpenOceanAdapter.OpenOceanAdapter__NonEmptyGetMakerAmount.selector));
        swapper.submitOrder(_orderToConfig(order));
    }

    function testSubmitLimitOrder_RevertNonEmptyGetTakerAmount() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        DecoderCustomTypes.OpenOceanLimitOrder memory order = _defaultOrder(1e18, 2000e6);
        order.getTakerAmount = hex"1234";

        vm.prank(getAddress(sourceChain, "boringVault"));
        vm.expectRevert(abi.encodeWithSelector(OpenOceanAdapter.OpenOceanAdapter__NonEmptyGetTakerAmount.selector));
        swapper.submitOrder(_orderToConfig(order));
    }

    function testSubmitLimitOrder_RevertNonEmptyMakerAssetData() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        DecoderCustomTypes.OpenOceanLimitOrder memory order = _defaultOrder(1e18, 2000e6);
        order.makerAssetData = hex"1234";

        vm.prank(getAddress(sourceChain, "boringVault"));
        vm.expectRevert(abi.encodeWithSelector(OpenOceanAdapter.OpenOceanAdapter__NonEmptyMakerAssetData.selector));
        swapper.submitOrder(_orderToConfig(order));
    }

    function testSubmitLimitOrder_RevertNonEmptyTakerAssetData() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        DecoderCustomTypes.OpenOceanLimitOrder memory order = _defaultOrder(1e18, 2000e6);
        order.takerAssetData = hex"1234";

        vm.prank(getAddress(sourceChain, "boringVault"));
        vm.expectRevert(abi.encodeWithSelector(OpenOceanAdapter.OpenOceanAdapter__NonEmptyTakerAssetData.selector));
        swapper.submitOrder(_orderToConfig(order));
    }

    function testSubmitLimitOrder_RevertNonEmptyPredicate() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        DecoderCustomTypes.OpenOceanLimitOrder memory order = _defaultOrder(1e18, 2000e6);
        order.predicate = hex"1234";

        vm.prank(getAddress(sourceChain, "boringVault"));
        vm.expectRevert(abi.encodeWithSelector(OpenOceanAdapter.OpenOceanAdapter__NonEmptyPredicate.selector));
        swapper.submitOrder(_orderToConfig(order));
    }

    function testSubmitLimitOrder_RevertNonEmptyPermit() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        DecoderCustomTypes.OpenOceanLimitOrder memory order = _defaultOrder(1e18, 2000e6);
        order.permit = hex"1234";

        vm.prank(getAddress(sourceChain, "boringVault"));
        vm.expectRevert(abi.encodeWithSelector(OpenOceanAdapter.OpenOceanAdapter__NonEmptyPermit.selector));
        swapper.submitOrder(_orderToConfig(order));
    }

    function testSubmitLimitOrder_RevertNonEmptyInteraction() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        DecoderCustomTypes.OpenOceanLimitOrder memory order = _defaultOrder(1e18, 2000e6);
        order.interaction = hex"1234";

        vm.prank(getAddress(sourceChain, "boringVault"));
        vm.expectRevert(abi.encodeWithSelector(OpenOceanAdapter.OpenOceanAdapter__NonEmptyInteraction.selector));
        swapper.submitOrder(_orderToConfig(order));
    }

    function testIsValidSignatureLimitOrder() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        (ISwapperTypes.SwapConfig memory config, bytes32 digest,) = _submitLimitOrder(1e18, 2000e6);

        vm.prank(address(0x420)); // mock LOP is the settlementCaller
        bytes4 result = swapper.isValidSignature(digest, abi.encode(config));
        assertEq(result, bytes4(0x1626ba7e));
    }

    function testIsValidSignatureLimitOrder_RevertHashMismatch() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        (ISwapperTypes.SwapConfig memory config, bytes32 digest,) = _submitLimitOrder(1e18, 2000e6);

        vm.expectRevert(abi.encodeWithSelector(
            BoringSwapper.BoringSwapper__HashMismatch.selector,
            digest,
            bytes32(uint256(0x69420))
        ));
        vm.prank(address(0x420));
        swapper.isValidSignature(bytes32(uint256(0x69420)), abi.encode(config));
    }

    function testCancelLimitOrder() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        (ISwapperTypes.SwapConfig memory config,, uint256 orderId) = _submitLimitOrder(1e18, 2000e6);

        assertEq(getERC20(sourceChain, "WETH").balanceOf(address(swapper)), 1e18);

        vm.prank(getAddress(sourceChain, "boringVault"));
        swapper.cancelOrder(orderId, config);

        assertEq(getERC20(sourceChain, "WETH").balanceOf(address(swapper)), 0);
        assertEq(getERC20(sourceChain, "WETH").balanceOf(getAddress(sourceChain, "boringVault")), 100e18);
    }

    function testSimulateLimitOrderFill() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        (ISwapperTypes.SwapConfig memory config, bytes32 digest,) = _submitLimitOrder(1e18, 2000e6);

        ERC20 WETH = getERC20(sourceChain, "WETH");
        ERC20 USDC = getERC20(sourceChain, "USDC");

        // LOP verifies signature
        vm.prank(address(0x420));
        assertEq(swapper.isValidSignature(digest, abi.encode(config)), bytes4(0x1626ba7e));

        // LOP pulls makerAsset from swapper via pre-approval
        vm.prank(address(0x420));
        WETH.transferFrom(address(swapper), address(0x420), 1e18);

        // LOP sends takerAsset to vault
        deal(address(USDC), address(0x420), 2000e6);
        vm.prank(address(0x420));
        USDC.transfer(getAddress(sourceChain, "boringVault"), 2000e6);

        assertEq(WETH.balanceOf(address(swapper)), 0);
        assertEq(USDC.balanceOf(getAddress(sourceChain, "boringVault")), 2000e6);
    }

    //==================== Helpers ====================

    function _defaultOrder(uint256 makingAmount, uint256 takingAmount)
        internal
        view
        returns (DecoderCustomTypes.OpenOceanLimitOrder memory)
    {
        return DecoderCustomTypes.OpenOceanLimitOrder({
            salt: 1,
            makerAsset: getAddress(sourceChain, "WETH"),
            takerAsset: getAddress(sourceChain, "USDC"),
            maker: address(swapper),
            receiver: getAddress(sourceChain, "boringVault"),
            allowedSender: address(0),
            makingAmount: makingAmount,
            takingAmount: takingAmount,
            makerAssetData: "",
            takerAssetData: "",
            getMakerAmount: "",
            getTakerAmount: "",
            predicate: "",
            permit: "",
            interaction: ""
        });
    }

    function _orderToConfig(DecoderCustomTypes.OpenOceanLimitOrder memory order)
        internal
        view
        returns (ISwapperTypes.SwapConfig memory)
    {
        return ISwapperTypes.SwapConfig({
            tokenRoute: ISwapperTypes.TokenRoute(getERC20(sourceChain, "WETH"), getERC20(sourceChain, "USDC")),
            adapter: openOceanAdapter,
            quoteAsset: getAddress(sourceChain, "USDC"),
            swapData: abi.encode(order),
            slippageBps: 10,
            receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
        });
    }

    function _buildLimitOrderConfig(uint256 makingAmount, uint256 takingAmount)
        internal
        view
        returns (ISwapperTypes.SwapConfig memory config, bytes32 orderDigest)
    {
        DecoderCustomTypes.OpenOceanLimitOrder memory order = _defaultOrder(makingAmount, takingAmount);
        config = _orderToConfig(order);

        bytes32 domainSeparator = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256("openocean Limit Order Protocol"),
            keccak256("2"),
            block.chainid,
            address(0x420)
        ));

        bytes32 structHash = keccak256(
            bytes.concat(
                abi.encode(
                    LIMIT_ORDER_TYPE_HASH,
                    order.salt,
                    order.makerAsset,
                    order.takerAsset,
                    order.maker,
                    order.receiver,
                    order.allowedSender,
                    order.makingAmount,
                    order.takingAmount
                ),
                abi.encode(
                    keccak256(order.makerAssetData),
                    keccak256(order.takerAssetData),
                    keccak256(order.getMakerAmount),
                    keccak256(order.getTakerAmount),
                    keccak256(order.predicate),
                    keccak256(order.permit),
                    keccak256(order.interaction)
                )
            )
        );
        orderDigest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

    function _submitLimitOrder(uint256 makingAmount, uint256 takingAmount)
        internal
        returns (ISwapperTypes.SwapConfig memory config, bytes32 orderDigest, uint256 orderId)
    {
        (config, orderDigest) = _buildLimitOrderConfig(makingAmount, takingAmount);
        orderId = swapper.orders();
        vm.prank(getAddress(sourceChain, "boringVault"));
        swapper.submitOrder(config);
    }

    function _makeOracleConfig(address rateProvider, address intermediary, bool skipValidation) internal pure returns (BoringSwapper.RateProviderConfig memory) {
        address[] memory rateProviders = new address[](1);
        rateProviders[0] = rateProvider;
        address[] memory intermediaries = new address[](1);
        intermediaries[0] = intermediary;
        return BoringSwapper.RateProviderConfig(rateProviders, intermediaries, skipValidation);
    }

    function _toArray(address addr) internal pure returns (address[] memory) {
        address[] memory arr = new address[](1);
        arr[0] = addr;
        return arr;
    }
}
