// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {BoringSwapper, SwapParams, QuoteAsset} from "src/base/Periphery/BoringSwapper.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
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
        _setUpMainnetAtBlock(22067550);
    }

    function _setUpMainnetAtBlock(uint256 blockNumber) internal {
        super.setUp();
        _setupChain("mainnet", blockNumber);

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

        // Configure WETH oracle (~$2000, close to block price)
        MockPriceFeed wethUsdFeed = new MockPriceFeed(2000e8, 8);
        boringSwapper.setTokenOracleConfig(
            getAddress(sourceChain, "WETH"),
            BoringSwapper.TokenOracleConfig({
                usdOracle: address(wethUsdFeed),
                ethOracle: address(0),
                btcOracle: address(0)
            })
        );

        // Decoder
        swapperDecoder = new BoringSwapperDecoderAndSanitizer();
        _overrideDecoder(address(swapperDecoder));
    }

    // ========================================= HELPERS =========================================

    function _buildUniswapSwapContext()
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

        (bytes32[][] memory proofs, SwapParams memory swapParams) = _buildUniswapSwapContext();

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

    function testNativeEthSwap() external {
        _setUpMainnet();
        uint256 amountIn = 10e18;
        deal(address(boringVault), amountIn);

        address uniV3Router = getAddress(sourceChain, "uniV3Router");
        boringSwapper.setApprovedTarget(uniV3Router, true);

        // Build merkle leaf manually — no approve leaf (can't approve ETH), swap needs canSendValue = true
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        leafs[0] = ManageLeaf(
            address(boringSwapper),
            true, // canSendValue
            "swap((address,address,uint256,uint256,address,address,bytes,bool,uint8,uint256))",
            new address[](3),
            "BoringSwapper Native ETH swap",
            address(swapperDecoder)
        );
        leafs[0].argumentAddresses[0] = getAddress(sourceChain, "ETH"); // tokenIn = NATIVE
        leafs[0].argumentAddresses[1] = getAddress(sourceChain, "USDC"); // tokenOut
        leafs[0].argumentAddresses[2] = address(boringVault); // receiver

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        // Uniswap V3 exactInputSingle — tokenIn = WETH (router wraps ETH internally)
        bytes memory swapData = abi.encodeWithSignature(
            "exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))",
            getAddress(sourceChain, "WETH"),
            getAddress(sourceChain, "USDC"),
            uint24(500),
            address(boringSwapper),
            block.timestamp,
            amountIn,
            uint256(1),
            uint160(0)
        );

        SwapParams memory swapParams = SwapParams({
            tokenIn: getAddress(sourceChain, "ETH"), // NATIVE
            tokenOut: getAddress(sourceChain, "USDC"),
            amountIn: amountIn,
            minAmountOut: 1,
            receiver: address(boringVault),
            target: uniV3Router,
            swapData: swapData,
            useOracle: false,
            quoteAsset: QuoteAsset.USD,
            maxSlippageBps: 0
        });

        Tx memory tx_ = _getTxArrays(1);
        tx_.targets[0] = address(boringSwapper);
        tx_.targetData[0] = abi.encodeWithSelector(BoringSwapper.swap.selector, swapParams);
        tx_.decodersAndSanitizers[0] = address(swapperDecoder);
        tx_.values[0] = amountIn;

        uint256 usdcBefore = ERC20(getAddress(sourceChain, "USDC")).balanceOf(address(boringVault));
        _submitManagerCall(manageProofs, tx_);
        uint256 usdcAfter = ERC20(getAddress(sourceChain, "USDC")).balanceOf(address(boringVault));

        assertGt(usdcAfter, usdcBefore, "Vault should have received USDC from native ETH swap");
    }

    function testOneInchSwap() external {
        _setUpMainnetAtBlock(23671018);
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 2_000e18);

        address aggregationRouterV5 = getAddress(sourceChain, "aggregationRouterV5");
        boringSwapper.setApprovedTarget(aggregationRouterV5, true);

        // Build merkle tree with WETH and WEETH
        address[] memory tokensIn = new address[](2);
        tokensIn[0] = getAddress(sourceChain, "WETH");
        tokensIn[1] = getAddress(sourceChain, "WEETH");

        SwapKind[] memory kindsIn = new SwapKind[](2);
        kindsIn[0] = SwapKind.BuyAndSell;
        kindsIn[1] = SwapKind.BuyAndSell;

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addBoringSwapperLeafs(leafs, address(boringSwapper), address(swapperDecoder), tokensIn, kindsIn);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0]; // approve WETH
        manageLeafs[1] = leafs[1]; // swap WETH -> WEETH
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        // Build 1inch swap calldata
        address oneInchExecutor = 0x8C864D0c8E476Bf9eb9d620C10E1296fb0E2F940;

        DecoderCustomTypes.SwapDescription memory swapDesc = DecoderCustomTypes.SwapDescription({
            srcToken: getAddress(sourceChain, "WETH"),
            dstToken: getAddress(sourceChain, "WEETH"),
            srcReceiver: payable(oneInchExecutor),
            dstReceiver: payable(address(boringSwapper)),
            amount: 2000e18,
            minReturnAmount: 1,
            flags: 4
        });

        bytes memory data = hex"0000000000000000000000000000000000000002520002240001da00001a0020d6bdbf78c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200a0c9e75c4800000000000000000000000000000029000000090000000000000000000000000000000000000000000001880000ec0000b05100db74dfdd3bb46be8ce6c33dc9d82777bcfc3ded5c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200443df0212400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000014101c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200042e1a7d4d0000000000000000000000000000000000000000000000000000000000000000416086f874212335af27c41cdb855c2255543d1499ce00242668dfaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000008c864d0c8e476bf9eb9d620c10e1296fb0e2f94000a0f2fa6b66cd5fe23c85820f7b72d0926fc9b05b43e359b7ee0000000000000000000000000000000000000000000000646a08526a24695c2e00000000000000000003ea6740d11d1f80a06c4eca27cd5fe23c85820f7b72d0926fc9b05b43e359b7ee1111111254eeb25477b68fb85ed929f73a960582";

        bytes memory oneInchCallData = abi.encodeWithSignature(
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)",
            oneInchExecutor,
            swapDesc,
            "",
            data
        );

        SwapParams memory swapParams = SwapParams({
            tokenIn: getAddress(sourceChain, "WETH"),
            tokenOut: getAddress(sourceChain, "WEETH"),
            amountIn: 2000e18,
            minAmountOut: 1,
            receiver: address(boringVault),
            target: aggregationRouterV5,
            swapData: oneInchCallData,
            useOracle: false,
            quoteAsset: QuoteAsset.USD,
            maxSlippageBps: 0
        });

        Tx memory tx_ = _getTxArrays(2);
        tx_.targets[0] = getAddress(sourceChain, "WETH");
        tx_.targets[1] = address(boringSwapper);
        tx_.targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, address(boringSwapper), 2000e18);
        tx_.targetData[1] = abi.encodeWithSelector(BoringSwapper.swap.selector, swapParams);
        tx_.decodersAndSanitizers[0] = address(swapperDecoder);
        tx_.decodersAndSanitizers[1] = address(swapperDecoder);

        uint256 weethBefore = ERC20(getAddress(sourceChain, "WEETH")).balanceOf(address(boringVault));
        _submitManagerCall(manageProofs, tx_);
        uint256 weethAfter = ERC20(getAddress(sourceChain, "WEETH")).balanceOf(address(boringVault));

        assertGt(weethAfter, weethBefore, "Vault should have received WEETH via 1inch");
    }

    function testOdosSwap() external {
        _setUpMainnetAtBlock(22140604);
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e6);

        address odosRouterV2 = getAddress(sourceChain, "odosRouterV2");
        boringSwapper.setApprovedTarget(odosRouterV2, true);

        // Build merkle tree with USDC and WETH
        address[] memory tokensIn = new address[](2);
        tokensIn[0] = getAddress(sourceChain, "USDC");
        tokensIn[1] = getAddress(sourceChain, "WETH");

        SwapKind[] memory kindsIn = new SwapKind[](2);
        kindsIn[0] = SwapKind.BuyAndSell;
        kindsIn[1] = SwapKind.BuyAndSell;

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addBoringSwapperLeafs(leafs, address(boringSwapper), address(swapperDecoder), tokensIn, kindsIn);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0]; // approve USDC
        manageLeafs[1] = leafs[1]; // swap USDC -> WETH
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        // Build Odos swap calldata
        address odosExecutor = 0xd768d1Fe6Ef1449A54F9409400fe9d0E4954ea3F;

        DecoderCustomTypes.swapTokenInfo memory swapInfo = DecoderCustomTypes.swapTokenInfo({
            inputToken: getAddress(sourceChain, "USDC"),
            inputAmount: 100e6, // 100 USDC
            inputReceiver: odosExecutor,
            outputToken: getAddress(sourceChain, "WETH"),
            outputQuote: 44870662095406488,
            outputMin: 1,
            outputReceiver: address(boringSwapper)
        });

        bytes memory pathDefinition = hex"010203000d0101010201ff00000000000000000000000000000000000000000088e6a0c2ddd26feeb64f039a2c41296fcb3f5640a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000";

        bytes memory odosCallData = abi.encodeWithSignature(
            "swap((address,uint256,address,address,uint256,uint256,address),bytes,address,uint32)",
            swapInfo,
            pathDefinition,
            odosExecutor,
            0
        );

        SwapParams memory swapParams = SwapParams({
            tokenIn: getAddress(sourceChain, "USDC"),
            tokenOut: getAddress(sourceChain, "WETH"),
            amountIn: 100e6, // 100 USDC
            minAmountOut: 1,
            receiver: address(boringVault),
            target: odosRouterV2,
            swapData: odosCallData,
            useOracle: false,
            quoteAsset: QuoteAsset.USD,
            maxSlippageBps: 0
        });

        Tx memory tx_ = _getTxArrays(2);
        tx_.targets[0] = getAddress(sourceChain, "USDC");
        tx_.targets[1] = address(boringSwapper);
        tx_.targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, address(boringSwapper), type(uint256).max);
        tx_.targetData[1] = abi.encodeWithSelector(BoringSwapper.swap.selector, swapParams);
        tx_.decodersAndSanitizers[0] = address(swapperDecoder);
        tx_.decodersAndSanitizers[1] = address(swapperDecoder);

        uint256 wethBefore = ERC20(getAddress(sourceChain, "WETH")).balanceOf(address(boringVault));
        _submitManagerCall(manageProofs, tx_);
        uint256 wethAfter = ERC20(getAddress(sourceChain, "WETH")).balanceOf(address(boringVault));

        assertGt(wethAfter, wethBefore, "Vault should have received WETH via Odos");
    }

    function testOracleSwap() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        boringSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);

        (bytes32[][] memory proofs, SwapParams memory swapParams) = _buildUniswapSwapContext();
        swapParams.useOracle = true;
        swapParams.maxSlippageBps = 500; // 5%

        uint256 usdcBefore = ERC20(getAddress(sourceChain, "USDC")).balanceOf(address(boringVault));
        _executeSwapViaManager(proofs, swapParams);
        uint256 usdcAfter = ERC20(getAddress(sourceChain, "USDC")).balanceOf(address(boringVault));

        assertGt(usdcAfter, usdcBefore, "Vault should have received USDC with oracle-based slippage");
    }

    function testOracleSwap_SlippageTooTight() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        boringSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);

        // Override WETH oracle with deliberately high price ($3500 vs ~$2500 market)
        MockPriceFeed wethUsdFeed = new MockPriceFeed(3500e8, 8);
        boringSwapper.setTokenOracleConfig(
            getAddress(sourceChain, "WETH"),
            BoringSwapper.TokenOracleConfig({
                usdOracle: address(wethUsdFeed),
                ethOracle: address(0),
                btcOracle: address(0)
            })
        );

        (bytes32[][] memory proofs, SwapParams memory swapParams) = _buildUniswapSwapContext();
        swapParams.useOracle = true;
        swapParams.maxSlippageBps = 1; // 0.01% — impossibly tight

        vm.expectRevert(BoringSwapper.BoringSwapper__SlippageExceeded.selector);
        _executeSwapViaManager(proofs, swapParams);
    }

    // ========================================= REVERT TESTS =========================================

    function testRevert_TargetNotApproved() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        // skip setApprovedTarget
        (bytes32[][] memory proofs, SwapParams memory swapParams) = _buildUniswapSwapContext();

        vm.expectRevert(BoringSwapper.BoringSwapper__TargetNotApproved.selector);
        _executeSwapViaManager(proofs, swapParams);
    }

    function testRevert_NoSlippageProtection_ZeroMinOut() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        boringSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);
        (bytes32[][] memory proofs, SwapParams memory swapParams) = _buildUniswapSwapContext();
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

        (bytes32[][] memory proofs, SwapParams memory swapParams) = _buildUniswapSwapContext();
        swapParams.useOracle = true;
        swapParams.maxSlippageBps = 10_000;

        vm.expectRevert(BoringSwapper.BoringSwapper__NoSlippageProtection.selector);
        _executeSwapViaManager(proofs, swapParams);
    }

    function testRevert_OracleNotConfigured() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        boringSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);
        // Clear WETH oracle so it's not configured
        boringSwapper.setTokenOracleConfig(
            getAddress(sourceChain, "WETH"),
            BoringSwapper.TokenOracleConfig({usdOracle: address(0), ethOracle: address(0), btcOracle: address(0)})
        );
        (bytes32[][] memory proofs, SwapParams memory swapParams) = _buildUniswapSwapContext();
        swapParams.useOracle = true;
        swapParams.maxSlippageBps = 100;

        vm.expectRevert(BoringSwapper.BoringSwapper__OracleNotConfigured.selector);
        _executeSwapViaManager(proofs, swapParams);
    }

    function testRevert_SwapFailed() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        boringSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);
        (bytes32[][] memory proofs, SwapParams memory swapParams) = _buildUniswapSwapContext();
        swapParams.swapData = hex"dead";

        vm.expectRevert(BoringSwapper.BoringSwapper__SwapFailed.selector);
        _executeSwapViaManager(proofs, swapParams);
    }

    function testRevert_SlippageExceeded() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        boringSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);
        (bytes32[][] memory proofs, SwapParams memory swapParams) = _buildUniswapSwapContext();
        swapParams.minAmountOut = type(uint256).max;

        vm.expectRevert(BoringSwapper.BoringSwapper__SlippageExceeded.selector);
        _executeSwapViaManager(proofs, swapParams);
    }

    function testRevert_Unauthorized() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        boringSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);
        (bytes32[][] memory proofs, SwapParams memory swapParams) = _buildUniswapSwapContext();

        vm.prank(address(0xdead));
        vm.expectRevert(bytes("UNAUTHORIZED"));
        _executeSwapViaManager(proofs, swapParams);
    }
}
