// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {BoringSwapper} from "src/base/Periphery/BoringSwapper.sol";
import {BoringSwapperDecoder} from "src/base/DecodersAndSanitizers/Protocols/BoringSwapperDecoderAndSanitizer.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {AdapterRegistry} from "src/base/Periphery/AdapterRegistry.sol";
import {LifiAdapter} from "src/base/Periphery/adapters/LifiAdapter.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {PriceValidator} from "src/base/Periphery/adapters/price/PriceValidator.sol";
import {IPriceValidator} from "src/interfaces/IPriceValidator.sol";
import {FeeRegistry} from "src/base/Periphery/FeeRegistry.sol";

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

contract LifiAdapterTest is BaseTestIntegration {

    // LI.FI Diamond on mainnet — single entry point for all swaps
    address constant LIFI_ROUTER = 0x1231DEB6f5749EF6cE6943a275A1D3E7486F4EaE;

    address lifiAdapter;

    AdapterRegistry registry;
    BoringSwapper swapper;
    PriceValidator validator;

    MockRateProvider usdRate;
    MockRateProvider ethRate;

    function setUp() public override {
        super.setUp();
        _setupChain("mainnet", 24886820);

        address swapperDecoder = address(new BoringSwapperDecoder());
        _overrideDecoder(swapperDecoder);

        registry = new AdapterRegistry();
        swapper = new BoringSwapper(address(this), registry, new FeeRegistry(address(this), 1000));
        swapper.setAuthority(rolesAuthority);

        lifiAdapter = address(new LifiAdapter(LIFI_ROUTER));

        swapper.setRouteConfig(getERC20(sourceChain, "WETH"), getERC20(sourceChain, "USDC"), 500, 0, 0);
        swapper.setApprovedAdapter(lifiAdapter, true);

        registry.put(lifiAdapter, "LIFI");

        usdRate = new MockRateProvider(1e18);
        ethRate = new MockRateProvider(2000e18);
        address usdQuoteAsset = getAddress(sourceChain, "USDC");

        swapper.setTokenOracle(getERC20(sourceChain, "USDC"), usdQuoteAsset, _makeOracleConfig(address(usdRate), address(0), false));
        swapper.setTokenOracle(getERC20(sourceChain, "WETH"), usdQuoteAsset, _makeOracleConfig(address(ethRate), address(0), false));

        validator = new PriceValidator();
        swapper.setPriceValidator(IPriceValidator(validator));

        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
        rolesAuthority.setRoleCapability(BORING_VAULT_ROLE, address(swapper), BoringSwapper.swap.selector, true);
    }

    //==================== LI.FI Tests ====================

    // selector 0x5fd9ae2e — GenericSwapFacetV3, multi-hop array variant
    function testSwapTokensMultipleV3ERC20ToERC20_Live() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        address[] memory tokens = new address[](2);
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDC");

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), tokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[0]; // approve WETH
        tx_.manageLeafs[1] = leafs[5]; // swap WETH -> USDC

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH");
        tx_.targets[1] = address(swapper);

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );

        // swapTokensGeneric() WETH -> USDC via LI.FI (live quote, receiver = test swapper, block 24886820)
        bytes memory swapData = hex"5fd9ae2e372efe93366a83e0c4724e911ef6999470edf1166d13bbc137b3d6f93f04e02c00000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000100000000000000000000000000a4ad4f68d0b91cfd19687c881e50f3a00242828c000000000000000000000000000000000000000000000000000000000022bf72000000000000000000000000000000000000000000000000000000000000016000000000000000000000000000000000000000000000000000000000000000086c6966692d617069000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a30783030303030303030303030303030303030303030303030303030303030303030303030303030303000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000200000000000000000000000000685527c551cc40ce1f1c9818cd8683307076e4ed000000000000000000000000685527c551cc40ce1f1c9818cd8683307076e4ed000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000038d7ea4c6800000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000a4332d746b000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000000000000000400000000000000000000000000000000000000000000000000000000000000001000000000000000000000000c06ebbefd94032b85424d51906e2a335efae264b00000000000000000000000000000000000000000000000000000246139ca80000000000000000000000000000000000000000000000000000000000000000000000000000000000ac4c6e212a361c968f1725b4d055b47e63f80b75000000000000000000000000ac4c6e212a361c968f1725b4d055b47e63f80b75000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000000000000038b389129d80000000000000000000000000000000000000000000000000000000000000000e0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000003245f3bd1c8000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000038b389129d8000000000000000000000000001231deb6f5749ef6ce6943a275a1d3e7486f4eae000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000000000000022b68d000000000000000000000000c10ee9031f2a0b84766a86b55a8d90f357910fb400000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000204ba3f2165000000000000000000000000de7259893af7cdbc9fd806c6ba61d22d581d566700000000000000000000000000000000000000000000000000000000000008e5000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000038b389129d800000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000000000000023d2900000000000000000000000001231deb6f5749ef6ce6943a275a1d3e7486f4eae000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000009e019d9233222f000101c02aaa39b223fe8d0a0e5c4f27ead9083c756cc201ffff06000000000004444c5dc75cb358380d2e3de08a90a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000001f400000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c10ee9031f2a0b84766a86b55a8d90f357910fb4e2ce228f4a0600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

        BoringSwapper.TokenRoute memory tokenRoute = BoringSwapper.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );
        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.swap.selector,
            BoringSwapper.SwapConfig({
                tokenRoute: tokenRoute,
                adapter: lifiAdapter,
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: swapData,
                slippageBps: 100,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256 usdcBefore = getERC20(sourceChain, "USDC").balanceOf(getAddress(sourceChain, "boringVault"));
        assertEq(usdcBefore, 0); 

        _submitManagerCall(manageProofs, tx_);

        uint256 usdcAfter = getERC20(sourceChain, "USDC").balanceOf(getAddress(sourceChain, "boringVault"));
        assertGt(usdcAfter, usdcBefore, "vault did not receive USDC");
        assertGt(usdcAfter, 0);
    }

    // selector 0x4630a0d8 — GenericSwapFacet V1, single-hop via LiFi snwap adapter
    function testSwapTokensGeneric_Live() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        address[] memory tokens = new address[](2);
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDC");

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), tokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);
        tx_.manageLeafs[0] = leafs[0];
        tx_.manageLeafs[1] = leafs[5];
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH");
        tx_.targets[1] = address(swapper);

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );

        // swapTokensGeneric() V1 (0x4630a0d8): single-hop WETH→USDC via LiFi snwap adapter (block 24886820)
        bytes memory swapData = hex"4630a0d8000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000100000000000000000000000000a4ad4f68d0b91cfd19687c881e50f3a00242828c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000000c626f72696e672d7661756c740000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a3078303030303030303030303030303030303030303030303030303030303030303030303030303030300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000020000000000000000000000000ac4c6e212a361c968f1725b4d055b47e63f80b75000000000000000000000000ac4c6e212a361c968f1725b4d055b47e63f80b75000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000000000000038d7ea4c6800000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000324" hex"5f3bd1c8000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000038b389129d8000000000000000000000000001231deb6f5749ef6ce6943a275a1d3e7486f4eae000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000000000000022b68d000000000000000000000000c10ee9031f2a0b84766a86b55a8d90f357910fb400000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000204ba3f2165000000000000000000000000de7259893af7cdbc9fd806c6ba61d22d581d566700000000000000000000000000000000000000000000000000000000000008e5000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000038b389129d800000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000000000000023d2900000000000000000000000001231deb6f5749ef6ce6943a275a1d3e7486f4eae000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000009e019d9233222f000101c02aaa39b223fe8d0a0e5c4f27ead9083c756cc201ffff06000000000004444c5dc75cb358380d2e3de08a90a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000001f400000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c10ee9031f2a0b84766a86b55a8d90f357910fb4e2ce228f4a0600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

        BoringSwapper.TokenRoute memory tokenRoute = BoringSwapper.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );
        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.swap.selector,
            BoringSwapper.SwapConfig({
                tokenRoute: tokenRoute,
                adapter: lifiAdapter,
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: swapData,
                slippageBps: 100,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256 usdcBefore = getERC20(sourceChain, "USDC").balanceOf(getAddress(sourceChain, "boringVault"));
        assertEq(usdcBefore, 0);

        _submitManagerCall(manageProofs, tx_);

        uint256 usdcAfter = getERC20(sourceChain, "USDC").balanceOf(getAddress(sourceChain, "boringVault"));
        assertGt(usdcAfter, usdcBefore, "vault did not receive USDC");
        assertGt(usdcAfter, 0);
    }

    // selector 0x4666fc80 — GenericSwapFacetV3, single-hop struct variant
    function testSwapTokensSingleV3ERC20ToERC20_Live() external {
        deal(getAddress(sourceChain, "WETH"), getAddress(sourceChain, "boringVault"), 100e18);

        address[] memory tokens = new address[](2);
        tokens[0] = getAddress(sourceChain, "WETH");
        tokens[1] = getAddress(sourceChain, "USDC");

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addBoringSwapperLeafs(leafs, address(swapper), tokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        Tx memory tx_ = _getTxArrays(2);
        tx_.manageLeafs[0] = leafs[0];
        tx_.manageLeafs[1] = leafs[5];
        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH");
        tx_.targets[1] = address(swapper);

        tx_.targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", address(swapper), type(uint256).max
        );

        // swapTokensSingleV3ERC20ToERC20() (0x4666fc80): single-hop WETH→USDC via LiFi snwap adapter (block 24886820)
        bytes memory swapData = hex"4666fc80000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000c00000000000000000000000000000000000000000000000000000000000000100000000000000000000000000a4ad4f68d0b91cfd19687c881e50f3a00242828c00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000160000000000000000000000000000000000000000000000000000000000000000c626f72696e672d7661756c740000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002a30783030303030303030303030303030303030303030303030303030303030303030303030303030303000000000000000000000000000000000000000000000000000000000000000000000ac4c6e212a361c968f1725b4d055b47e63f80b75000000000000000000000000ac4c6e212a361c968f1725b4d055b47e63f80b75000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000000000000038d7ea4c6800000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000324" hex"5f3bd1c8000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000038b389129d8000000000000000000000000001231deb6f5749ef6ce6943a275a1d3e7486f4eae000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000000000000022b68d000000000000000000000000c10ee9031f2a0b84766a86b55a8d90f357910fb400000000000000000000000000000000000000000000000000000000000000e00000000000000000000000000000000000000000000000000000000000000204ba3f2165000000000000000000000000de7259893af7cdbc9fd806c6ba61d22d581d566700000000000000000000000000000000000000000000000000000000000008e5000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200000000000000000000000000000000000000000000000000038b389129d800000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000000000000023d2900000000000000000000000001231deb6f5749ef6ce6943a275a1d3e7486f4eae000000000000000000000000000000000000000000000000000000000000014000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000009e019d9233222f000101c02aaa39b223fe8d0a0e5c4f27ead9083c756cc201ffff06000000000004444c5dc75cb358380d2e3de08a90a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000001f400000a00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000c10ee9031f2a0b84766a86b55a8d90f357910fb4e2ce228f4a0600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000";

        BoringSwapper.TokenRoute memory tokenRoute = BoringSwapper.TokenRoute(
            getERC20(sourceChain, "WETH"),
            getERC20(sourceChain, "USDC")
        );
        tx_.targetData[1] = abi.encodeWithSelector(
            BoringSwapper.swap.selector,
            BoringSwapper.SwapConfig({
                tokenRoute: tokenRoute,
                adapter: lifiAdapter,
                quoteAsset: getAddress(sourceChain, "USDC"),
                swapData: swapData,
                slippageBps: 100,
                receiver: BoringVault(payable(getAddress(sourceChain, "boringVault")))
            })
        );

        tx_.decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        tx_.decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256 usdcBefore = getERC20(sourceChain, "USDC").balanceOf(getAddress(sourceChain, "boringVault"));
        assertEq(usdcBefore, 0);

        _submitManagerCall(manageProofs, tx_);

        uint256 usdcAfter = getERC20(sourceChain, "USDC").balanceOf(getAddress(sourceChain, "boringVault"));
        assertGt(usdcAfter, usdcBefore, "vault did not receive USDC");
        assertGt(usdcAfter, 0);
    }

    function _makeOracleConfig(address rateProvider, address intermediary, bool skipValidation) internal pure returns (BoringSwapper.RateProviderConfig memory) {
        address[] memory rateProviders = new address[](1);
        rateProviders[0] = rateProvider;
        address[] memory intermediaries = new address[](1);
        intermediaries[0] = intermediary;
        return BoringSwapper.RateProviderConfig(rateProviders, intermediaries, skipValidation);
    }
}
