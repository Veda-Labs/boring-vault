// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {BoringSwapper, SwapParams, QuoteAsset} from "src/base/Periphery/BoringSwapper.sol";
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

interface ILiFiGenericSwap {
    struct SwapData {
        address callTo;
        address approveTo;
        address sendingAssetId;
        address receivingAssetId;
        uint256 fromAmount;
        bytes callData;
        bool requiresDeposit;
    }

    function swapTokensGeneric(
        bytes32 _transactionId,
        string calldata _integrator,
        string calldata _referrer,
        address payable _receiver,
        uint256 _minAmount,
        SwapData[] calldata _swapData
    ) external payable;
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

        // Decoder
        swapperDecoder = new BoringSwapperDecoderAndSanitizer();
        _overrideDecoder(address(swapperDecoder));
    }

    // ========================================= HELPERS =========================================

    function _buildSwapContext()
        internal
        returns (bytes32[][] memory manageProofs, SwapParams memory swapParams)
    {
        address uniV3Router = getAddress(sourceChain, "uniV3Router");

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
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        // Build proofs for leafs[0] (approve WETH) and leafs[1] (swap WETH -> USDC)
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        // Encode Uniswap V3 exactInputSingle swap data
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

    function _executeSwapViaManager(
        bytes32[][] memory manageProofs,
        SwapParams memory swapParams
    ) internal {
        Tx memory tx_ = _getTxArrays(2);

        tx_.targets[0] = swapParams.tokenIn;
        tx_.targets[1] = address(boringSwapper);

        tx_.targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, address(boringSwapper), swapParams.amountIn);
        tx_.targetData[1] = abi.encodeWithSelector(BoringSwapper.swap.selector, swapParams);

        tx_.decodersAndSanitizers[0] = address(swapperDecoder);
        tx_.decodersAndSanitizers[1] = address(swapperDecoder);

        _submitManagerCall(manageProofs, tx_);
    }

    // ========================================= HAPPY PATH =========================================

    function testBasicSwap() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        boringSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);

        (bytes32[][] memory proofs, SwapParams memory swapParams) = _buildSwapContext();

        uint256 usdcBefore = ERC20(getAddress(sourceChain, "USDC")).balanceOf(address(boringVault));
        _executeSwapViaManager(proofs, swapParams);
        uint256 usdcAfter = ERC20(getAddress(sourceChain, "USDC")).balanceOf(address(boringVault));

        assertGt(usdcAfter, usdcBefore, "Vault should have received USDC");
    }

    function testLifiSwap() external {
        _setUpMainnet();

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);

        address lifi = getAddress(sourceChain, "lifi");
        address uniV3Router = getAddress(sourceChain, "uniV3Router");
        boringSwapper.setApprovedTarget(lifi, true);

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
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        // Inner Uniswap V3 calldata — LIFI will execute this on the DEX
        // Recipient is the LIFI Diamond so it can forward output to _receiver
        bytes memory uniswapCallData = abi.encodeWithSignature(
            "exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))",
            getAddress(sourceChain, "WETH"),
            getAddress(sourceChain, "USDC"),
            uint24(500),
            lifi,                // recipient = LIFI Diamond
            block.timestamp,
            1e18,
            uint256(1),
            uint160(0)
        );

        // Build LIFI SwapData array
        ILiFiGenericSwap.SwapData[] memory swapDatas = new ILiFiGenericSwap.SwapData[](1);
        swapDatas[0] = ILiFiGenericSwap.SwapData({
            callTo: uniV3Router,
            approveTo: uniV3Router,
            sendingAssetId: getAddress(sourceChain, "WETH"),
            receivingAssetId: getAddress(sourceChain, "USDC"),
            fromAmount: 1e18,
            callData: uniswapCallData,
            requiresDeposit: true
        });

        // Encode the LIFI swapTokensGeneric call
        bytes memory lifiCallData = abi.encodeWithSelector(
            ILiFiGenericSwap.swapTokensGeneric.selector,
            bytes32("boring-vault-lifi-test"),
            "boring-vault",
            "",
            payable(address(boringSwapper)),  // _receiver: LIFI sends output back to BoringSwapper
            uint256(1),                       // _minAmount
            swapDatas
        );

        SwapParams memory swapParams = SwapParams({
            tokenIn: getAddress(sourceChain, "WETH"),
            tokenOut: getAddress(sourceChain, "USDC"),
            amountIn: 1e18,
            minAmountOut: 1,
            receiver: address(boringVault),
            target: lifi,
            swapData: lifiCallData,
            useOracle: false,
            quoteAsset: QuoteAsset.USD,
            maxSlippageBps: 0
        });

        // Build Tx: approve BoringSwapper + call swap
        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[0]; // approve WETH
        tx_.manageLeafs[1] = leafs[1]; // swap WETH -> USDC

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH");
        tx_.targets[1] = address(boringSwapper);

        tx_.targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, address(boringSwapper), swapParams.amountIn);
        tx_.targetData[1] = abi.encodeWithSelector(BoringSwapper.swap.selector, swapParams);

        tx_.decodersAndSanitizers[0] = address(swapperDecoder);
        tx_.decodersAndSanitizers[1] = address(swapperDecoder);

        uint256 usdcBefore = ERC20(getAddress(sourceChain, "USDC")).balanceOf(address(boringVault));
        _submitManagerCall(manageProofs, tx_);
        uint256 usdcAfter = ERC20(getAddress(sourceChain, "USDC")).balanceOf(address(boringVault));

        assertGt(usdcAfter, usdcBefore, "Vault should have received USDC via LIFI");
    }

    // ========================================= REVERT TESTS =========================================

    function testRevert_TargetNotApproved() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        // skip setApprovedTarget
        (bytes32[][] memory proofs, SwapParams memory swapParams) = _buildSwapContext();

        vm.expectRevert(BoringSwapper.BoringSwapper__TargetNotApproved.selector);
        _executeSwapViaManager(proofs, swapParams);
    }

    function testRevert_NoSlippageProtection_ZeroMinOut() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        boringSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);
        (bytes32[][] memory proofs, SwapParams memory swapParams) = _buildSwapContext();
        swapParams.minAmountOut = 0;

        vm.expectRevert(BoringSwapper.BoringSwapper__NoSlippageProtection.selector);
        _executeSwapViaManager(proofs, swapParams);
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

        (bytes32[][] memory proofs, SwapParams memory swapParams) = _buildSwapContext();
        swapParams.useOracle = true;
        swapParams.maxSlippageBps = 10_000;

        vm.expectRevert(BoringSwapper.BoringSwapper__NoSlippageProtection.selector);
        _executeSwapViaManager(proofs, swapParams);
    }

    function testRevert_OracleNotConfigured() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        boringSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);
        // usdc oracle exists from _setUpMainnet but weth oracle does not
        (bytes32[][] memory proofs, SwapParams memory swapParams) = _buildSwapContext();
        swapParams.useOracle = true;
        swapParams.maxSlippageBps = 100;

        vm.expectRevert(BoringSwapper.BoringSwapper__OracleNotConfigured.selector);
        _executeSwapViaManager(proofs, swapParams);
    }

    function testRevert_SwapFailed() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        boringSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);
        (bytes32[][] memory proofs, SwapParams memory swapParams) = _buildSwapContext();
        swapParams.swapData = hex"dead";

        vm.expectRevert(BoringSwapper.BoringSwapper__SwapFailed.selector);
        _executeSwapViaManager(proofs, swapParams);
    }

    function testRevert_SlippageExceeded() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        boringSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);
        (bytes32[][] memory proofs, SwapParams memory swapParams) = _buildSwapContext();
        swapParams.minAmountOut = type(uint256).max;

        vm.expectRevert(BoringSwapper.BoringSwapper__SlippageExceeded.selector);
        _executeSwapViaManager(proofs, swapParams);
    }

    function testRevert_Unauthorized() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        boringSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);
        (bytes32[][] memory proofs, SwapParams memory swapParams) = _buildSwapContext();

        vm.prank(address(0xdead));
        vm.expectRevert(bytes("UNAUTHORIZED"));
        _executeSwapViaManager(proofs, swapParams);
    }
}
