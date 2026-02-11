// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {BoringSwapper, SwapParams, QuoteAsset} from "src/base/Periphery/BoringSwapper.sol";
import {BoringSwapperUManager} from "src/micro-managers/BoringSwapperUManager.sol";
import {UManager} from "src/micro-managers/UManager.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Authority} from "@solmate/auth/Auth.sol";
import {Test, console} from "@forge-std/Test.sol";

contract MockPriceFeed {
    uint256 public price;
    uint8 public decimals;

    constructor(uint256 _price, uint8 _decimals) {
        price = _price;
        decimals = _decimals;
    }

    function getPrice() external view returns (uint256, uint8) {
        return (price, decimals);
    }
}

contract BoringSwapperDecoderAndSanitizer is BaseDecoderAndSanitizer {
    function swap(SwapParams calldata params) external pure returns (bytes memory addressesFound) {
        return abi.encodePacked(
            params.tokenIn,
            params.tokenOut,
            params.receiver
        ); 
    }
}

contract BoringSwapperIntegrationTest is BaseTestIntegration {

    BoringSwapper boringSwapper;
    BoringSwapperUManager boringSwapperUManager;
    BoringSwapperDecoderAndSanitizer swapperDecoder; 

    function _setUpMainnet() internal {
        super.setUp();
        _setupChain("mainnet", 22067550);

        boringSwapper = new BoringSwapper(getAddress(sourceChain, "ETH"), address(this), Authority(address(0)));

        // Authorize the BoringVault to call swap on BoringSwapper
        boringSwapper.setAuthority(rolesAuthority);
        rolesAuthority.setRoleCapability(
            BORING_VAULT_ROLE, address(boringSwapper), BoringSwapper.swap.selector, true
        );

        boringSwapperUManager = new BoringSwapperUManager(
            address(this),
            address(manager),
            address(boringVault),
            address(boringSwapper),
            QuoteAsset.USD
        );

        rolesAuthority.setUserRole(address(boringSwapperUManager), STRATEGIST_ROLE, true);
        boringSwapperUManager.setPeriod(300);
        boringSwapperUManager.setAllowedCallsPerPeriod(10);

        // Configure USDC oracle (1 USDC = $1, 8 decimals like Chainlink)
        MockPriceFeed usdcUsdFeed = new MockPriceFeed(1e8, 8);
        boringSwapper.setTokenOracleConfig(
            getAddress(sourceChain, "USDC"),
            BoringSwapper.TokenOracleConfig({
                usdOracle: address(usdcUsdFeed),
                ethOracle: address(0),
                btcOracle: address(0)
            })
        );

        // Set rate limit for the test contract as strategist (10000 USD over 1 hour)
        boringSwapperUManager.setStrategistRateLimit(address(this), 10000e6, 3600);

        //swapper decoder and sanitizer
        swapperDecoder = new BoringSwapperDecoderAndSanitizer();
        _overrideDecoder(address(swapperDecoder));
    }

    function testBasicSwap() external {
        _setUpMainnet();

        // Fund the vault with WETH
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);

        // Approve Uniswap V3 Router as a swap target on BoringSwapper
        address uniV3Router = getAddress(sourceChain, "uniV3Router");
        boringSwapper.setApprovedTarget(uniV3Router, true);

        // Build merkle tree
        address[] memory tokensIn = new address[](2);
        tokensIn[0] = getAddress(sourceChain, "WETH");
        tokensIn[1] = getAddress(sourceChain, "USDC");

        SwapKind[] memory kindsIn = new SwapKind[](2);
        kindsIn[0] = SwapKind.BuyAndSell;
        kindsIn[1] = SwapKind.BuyAndSell;

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addBoringSwapperLeafs(leafs, address(boringSwapper), address(swapperDecoder), tokensIn, kindsIn);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(boringSwapperUManager), manageTree[manageTree.length - 1][0]);

        // Build proofs for leafs[0] (approve WETH) and leafs[1] (swap WETH -> USDC)
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory decoders = new address[](2);
        decoders[0] = address(swapperDecoder);
        decoders[1] = address(swapperDecoder);

        // Encode Uniswap V3 exactInputSingle swap data
        // exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))
        bytes memory swapData = abi.encodeWithSignature(
            "exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))",
            getAddress(sourceChain, "WETH"),  // tokenIn
            getAddress(sourceChain, "USDC"),  // tokenOut
            uint24(500),                       // fee (0.05% pool)
            address(boringSwapper),            // recipient (swapper collects, then forwards)
            block.timestamp,                   // deadline
            1e18,                              // amountIn
            uint256(1),                        // amountOutMinimum
            uint160(0)                         // sqrtPriceLimitX96 (0 = no limit)
        );

        SwapParams memory swapParams = SwapParams({
            tokenIn: getAddress(sourceChain, "WETH"),
            tokenOut: getAddress(sourceChain, "USDC"),
            amountIn: 1e18,
            minAmountOut: 1,
            receiver: address(boringVault),
            target: uniV3Router,
            swapData: swapData,
            useOracle: false,
            quoteAsset: QuoteAsset.USD,
            maxSlippageBps: 0
        });

        uint256 usdcBefore = ERC20(getAddress(sourceChain, "USDC")).balanceOf(address(boringVault));

        // Strategist interacts directly with the uManager
        boringSwapperUManager.swap(manageProofs, decoders, swapParams);

        uint256 usdcAfter = ERC20(getAddress(sourceChain, "USDC")).balanceOf(address(boringVault));
        assertGt(usdcAfter, usdcBefore, "Vault should have received USDC");
    }

    // ========================================= HELPERS =========================================

    function _buildSwapContext()
        internal
        returns (bytes32[][] memory manageProofs, address[] memory decoders, SwapParams memory swapParams)
    {
        address uniV3Router = getAddress(sourceChain, "uniV3Router");

        // build merkle tree
        address[] memory tokensIn = new address[](2);
        tokensIn[0] = getAddress(sourceChain, "WETH");
        tokensIn[1] = getAddress(sourceChain, "USDC");

        SwapKind[] memory kindsIn = new SwapKind[](2);
        kindsIn[0] = SwapKind.BuyAndSell;
        kindsIn[1] = SwapKind.BuyAndSell;

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addBoringSwapperLeafs(leafs, address(boringSwapper), address(swapperDecoder), tokensIn, kindsIn);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(boringSwapperUManager), manageTree[manageTree.length - 1][0]);

        // build proofs for leafs[0] (approve WETH) and leafs[1] (swap WETH -> USDC)
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        decoders = new address[](2);
        decoders[0] = address(swapperDecoder);
        decoders[1] = address(swapperDecoder);

        // encode uniswap v3 exactInputSingle swap data
        bytes memory swapData = abi.encodeWithSignature(
            "exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))",
            getAddress(sourceChain, "WETH"),
            getAddress(sourceChain, "USDC"),
            uint24(500),
            address(boringSwapper),
            block.timestamp,
            1e18,
            uint256(1),
            uint160(0)
        );

        swapParams = SwapParams({
            tokenIn: getAddress(sourceChain, "WETH"),
            tokenOut: getAddress(sourceChain, "USDC"),
            amountIn: 1e18,
            minAmountOut: 1,
            receiver: address(boringVault),
            target: uniV3Router,
            swapData: swapData,
            useOracle: false,
            quoteAsset: QuoteAsset.USD,
            maxSlippageBps: 0
        });
    }

    // ========================================= REVERT TESTS =========================================

    function testRevert_TargetNotApproved() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        // skip setApprovedTarget
        (bytes32[][] memory proofs, address[] memory decoders, SwapParams memory swapParams) = _buildSwapContext();

        vm.expectRevert(BoringSwapper.BoringSwapper__TargetNotApproved.selector);
        boringSwapperUManager.swap(proofs, decoders, swapParams);
    }

    function testRevert_NoSlippageProtection_ZeroMinOut() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        boringSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);
        (bytes32[][] memory proofs, address[] memory decoders, SwapParams memory swapParams) = _buildSwapContext();
        swapParams.minAmountOut = 0;

        vm.expectRevert(BoringSwapper.BoringSwapper__NoSlippageProtection.selector);
        boringSwapperUManager.swap(proofs, decoders, swapParams);
    }

    function testRevert_NoSlippageProtection_MaxSlippageTooHigh() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        boringSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);

        // configure weth oracle so we reach _calculateMinOut
        MockPriceFeed wethUsdFeed = new MockPriceFeed(2500e8, 8);
        boringSwapper.setTokenOracleConfig(
            getAddress(sourceChain, "WETH"),
            BoringSwapper.TokenOracleConfig({
                usdOracle: address(wethUsdFeed),
                ethOracle: address(0),
                btcOracle: address(0)
            })
        );

        (bytes32[][] memory proofs, address[] memory decoders, SwapParams memory swapParams) = _buildSwapContext();
        swapParams.useOracle = true;
        swapParams.maxSlippageBps = 10_000;

        vm.expectRevert(BoringSwapper.BoringSwapper__NoSlippageProtection.selector);
        boringSwapperUManager.swap(proofs, decoders, swapParams);
    }

    function testRevert_OracleNotConfigured_Swapper() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        boringSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);
        // usdc oracle exists from _setUpMainnet but weth oracle does not
        (bytes32[][] memory proofs, address[] memory decoders, SwapParams memory swapParams) = _buildSwapContext();
        swapParams.useOracle = true;
        swapParams.maxSlippageBps = 100;

        vm.expectRevert(BoringSwapper.BoringSwapper__OracleNotConfigured.selector);
        boringSwapperUManager.swap(proofs, decoders, swapParams);
    }

    function testRevert_SwapFailed() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        boringSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);
        (bytes32[][] memory proofs, address[] memory decoders, SwapParams memory swapParams) = _buildSwapContext();
        swapParams.swapData = hex"dead";

        vm.expectRevert(BoringSwapper.BoringSwapper__SwapFailed.selector);
        boringSwapperUManager.swap(proofs, decoders, swapParams);
    }

    function testRevert_SlippageExceeded() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        boringSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);
        (bytes32[][] memory proofs, address[] memory decoders, SwapParams memory swapParams) = _buildSwapContext();
        swapParams.minAmountOut = type(uint256).max;

        vm.expectRevert(BoringSwapper.BoringSwapper__SlippageExceeded.selector);
        boringSwapperUManager.swap(proofs, decoders, swapParams);
    }

    function testRevert_CallCountExceeded() external {
        _setUpMainnet();
        boringSwapperUManager.setAllowedCallsPerPeriod(1);
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        boringSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);
        (bytes32[][] memory proofs, address[] memory decoders, SwapParams memory swapParams) = _buildSwapContext();

        // first swap succeeds
        boringSwapperUManager.swap(proofs, decoders, swapParams);

        // re-deal weth for second swap
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);

        vm.expectRevert(UManager.UManager__CallCountExceeded.selector);
        boringSwapperUManager.swap(proofs, decoders, swapParams);
    }

    function testRevert_StrategistRateLimitExceeded() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        boringSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);
        // 1 wei usd limit means any real swap exceeds it
        boringSwapperUManager.setStrategistRateLimit(address(this), 1, 3600);
        (bytes32[][] memory proofs, address[] memory decoders, SwapParams memory swapParams) = _buildSwapContext();

        vm.expectRevert(BoringSwapperUManager.BoringSwapperUManager__RateLimitExceeded.selector);
        boringSwapperUManager.swap(proofs, decoders, swapParams);
    }

    function testRevert_OracleNotConfigured_UManager() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        boringSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);
        // remove usdc oracle so umanager's _getNormalizedValue fails
        boringSwapper.setTokenOracleConfig(
            getAddress(sourceChain, "USDC"),
            BoringSwapper.TokenOracleConfig({usdOracle: address(0), ethOracle: address(0), btcOracle: address(0)})
        );
        (bytes32[][] memory proofs, address[] memory decoders, SwapParams memory swapParams) = _buildSwapContext();

        vm.expectRevert(BoringSwapperUManager.BoringSwapperUManager__OracleNotConfigured.selector);
        boringSwapperUManager.swap(proofs, decoders, swapParams);
    }

    function testRevert_Unauthorized() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        boringSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);
        (bytes32[][] memory proofs, address[] memory decoders, SwapParams memory swapParams) = _buildSwapContext();

        vm.prank(address(0xdead));
        vm.expectRevert(bytes("UNAUTHORIZED"));
        boringSwapperUManager.swap(proofs, decoders, swapParams);
    }
}
