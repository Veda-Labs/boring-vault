// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseTestIntegration} from "test/integrations/BaseTestIntegration.t.sol";
import {RestrictedSwapper} from "src/base/Periphery/RestrictedSwapper.sol";
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

contract RestrictedSwapperDecoderAndSanitizer is BaseDecoderAndSanitizer {
    function swap(SwapParams calldata params) external pure returns (bytes memory addressesFound) {
        return abi.encodePacked(
            params.tokenIn,
            params.tokenOut,
            params.receiver
        );
    }
}

contract RestrictedSwapperIntegrationTest is BaseTestIntegration {

    RestrictedSwapper restrictedSwapper;
    RestrictedSwapperDecoderAndSanitizer swapperDecoder;
    MockPriceFeed wethUsdFeed;
    MockPriceFeed usdcUsdFeed;
    address nativeAddress;

    function _setUpMainnet() internal {
        super.setUp();
        _setupChain("mainnet", 22067550);

        nativeAddress = getAddress(sourceChain, "ETH");

        restrictedSwapper = new RestrictedSwapper(
            nativeAddress,
            address(this),
            Authority(address(0))
        );

        // Authorize the BoringVault to call swap on RestrictedSwapper
        restrictedSwapper.setAuthority(rolesAuthority);
        rolesAuthority.setRoleCapability(
            BORING_VAULT_ROLE, address(restrictedSwapper), BoringSwapper.swap.selector, true
        );

        // Configure oracles (Chainlink-style 8 decimals)
        // Use a price close to the on-chain rate at block 22067550 (~$1800)
        wethUsdFeed = new MockPriceFeed(1800e8, 8);
        usdcUsdFeed = new MockPriceFeed(1e8, 8);

        restrictedSwapper.setTokenOracleConfig(
            getAddress(sourceChain, "WETH"),
            BoringSwapper.TokenOracleConfig({
                usdOracle: address(wethUsdFeed),
                ethOracle: address(0),
                btcOracle: address(0)
            })
        );
        restrictedSwapper.setTokenOracleConfig(
            getAddress(sourceChain, "USDC"),
            BoringSwapper.TokenOracleConfig({
                usdOracle: address(usdcUsdFeed),
                ethOracle: address(0),
                btcOracle: address(0)
            })
        );

        // Set admin restrictions
        restrictedSwapper.setMaxSlippageCeilingBps(500); // 5%
        restrictedSwapper.setMaxSwapAmountNormalized(10_000); // $10,000 normalized

        // Decoder
        swapperDecoder = new RestrictedSwapperDecoderAndSanitizer();
        _overrideDecoder(address(swapperDecoder));
    }

    // ========================================= HELPERS =========================================

    function _buildSwapContext()
        internal
        returns (bytes32[][] memory manageProofs, address[] memory decoders, SwapParams memory swapParams)
    {
        address uniV3Router = getAddress(sourceChain, "uniV3Router");

        // Build merkle tree — reuses _addBoringSwapperLeafs (same swap signature)
        address[] memory tokensIn = new address[](2);
        tokensIn[0] = getAddress(sourceChain, "WETH");
        tokensIn[1] = getAddress(sourceChain, "USDC");

        SwapKind[] memory kindsIn = new SwapKind[](2);
        kindsIn[0] = SwapKind.BuyAndSell;
        kindsIn[1] = SwapKind.BuyAndSell;

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addBoringSwapperLeafs(leafs, address(restrictedSwapper), address(swapperDecoder), tokensIn, kindsIn);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        // Set merkle root for the test contract directly (no UManager)
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        // Build proofs for leafs[0] (approve WETH) and leafs[1] (swap WETH -> USDC)
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        decoders = new address[](2);
        decoders[0] = address(swapperDecoder);
        decoders[1] = address(swapperDecoder);

        // Encode Uniswap V3 exactInputSingle swap data
        bytes memory swapData = abi.encodeWithSignature(
            "exactInputSingle((address,address,uint24,address,uint256,uint256,uint256,uint160))",
            getAddress(sourceChain, "WETH"),
            getAddress(sourceChain, "USDC"),
            uint24(500),
            address(restrictedSwapper),
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
            useOracle: true,
            quoteAsset: QuoteAsset.USD,
            maxSlippageBps: 500 // 5%
        });
    }

    function _executeSwapViaManager(
        bytes32[][] memory manageProofs,
        address[] memory decoders,
        SwapParams memory swapParams
    ) internal {
        if (swapParams.tokenIn == nativeAddress) {
            address[] memory targets = new address[](1);
            bytes[] memory targetData = new bytes[](1);
            uint256[] memory values = new uint256[](1);
            targets[0] = address(restrictedSwapper);
            targetData[0] = abi.encodeWithSelector(BoringSwapper.swap.selector, swapParams);
            values[0] = swapParams.amountIn;
            manager.manageVaultWithMerkleVerification(manageProofs, decoders, targets, targetData, values);
        } else {
            address[] memory targets = new address[](2);
            bytes[] memory targetData = new bytes[](2);
            uint256[] memory values = new uint256[](2);

            targets[0] = swapParams.tokenIn;
            targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, address(restrictedSwapper), swapParams.amountIn);

            targets[1] = address(restrictedSwapper);
            targetData[1] = abi.encodeWithSelector(BoringSwapper.swap.selector, swapParams);

            manager.manageVaultWithMerkleVerification(manageProofs, decoders, targets, targetData, values);
        }
    }

    // ========================================= HAPPY PATH =========================================

    function testBasicSwap() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        restrictedSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);

        (bytes32[][] memory proofs, address[] memory decoders, SwapParams memory swapParams) = _buildSwapContext();

        uint256 usdcBefore = ERC20(getAddress(sourceChain, "USDC")).balanceOf(address(boringVault));
        _executeSwapViaManager(proofs, decoders, swapParams);
        uint256 usdcAfter = ERC20(getAddress(sourceChain, "USDC")).balanceOf(address(boringVault));

        assertGt(usdcAfter, usdcBefore, "Vault should have received USDC");
    }

    // ========================================= REVERT TESTS =========================================

    function testRevert_SlippageExceedsCeiling() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        restrictedSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);

        (bytes32[][] memory proofs, address[] memory decoders, SwapParams memory swapParams) = _buildSwapContext();
        swapParams.maxSlippageBps = 600; // exceeds 500 ceiling

        vm.expectRevert(BoringSwapper.BoringSwapper__SlippageExceedsCeiling.selector);
        _executeSwapViaManager(proofs, decoders, swapParams);
    }

    function testRevert_SwapAmountExceedsMax() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 100e18);
        restrictedSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);
        // Set very low max: $1
        restrictedSwapper.setMaxSwapAmountNormalized(1);

        (bytes32[][] memory proofs, address[] memory decoders, SwapParams memory swapParams) = _buildSwapContext();

        vm.expectRevert(BoringSwapper.BoringSwapper__SwapAmountExceedsMax.selector);
        _executeSwapViaManager(proofs, decoders, swapParams);
    }

    function testRevert_MaxSlippageCeilingNotSet() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        restrictedSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);
        // Reset ceiling to 0
        restrictedSwapper.setMaxSlippageCeilingBps(0);

        (bytes32[][] memory proofs, address[] memory decoders, SwapParams memory swapParams) = _buildSwapContext();

        vm.expectRevert(RestrictedSwapper.RestrictedSwapper__MaxSlippageCeilingNotSet.selector);
        _executeSwapViaManager(proofs, decoders, swapParams);
    }

    function testRevert_MaxSwapAmountNotSet() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        restrictedSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);
        // Reset max swap amount to 0
        restrictedSwapper.setMaxSwapAmountNormalized(0);

        (bytes32[][] memory proofs, address[] memory decoders, SwapParams memory swapParams) = _buildSwapContext();

        vm.expectRevert(RestrictedSwapper.RestrictedSwapper__MaxSwapAmountNotSet.selector);
        _executeSwapViaManager(proofs, decoders, swapParams);
    }

    function testRevert_OracleNotConfigured() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        restrictedSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);
        // Remove WETH oracle
        restrictedSwapper.setTokenOracleConfig(
            getAddress(sourceChain, "WETH"),
            BoringSwapper.TokenOracleConfig({usdOracle: address(0), ethOracle: address(0), btcOracle: address(0)})
        );

        (bytes32[][] memory proofs, address[] memory decoders, SwapParams memory swapParams) = _buildSwapContext();

        vm.expectRevert(BoringSwapper.BoringSwapper__OracleNotConfigured.selector);
        _executeSwapViaManager(proofs, decoders, swapParams);
    }

    function testRevert_TargetNotApproved() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        // Skip setApprovedTarget
        (bytes32[][] memory proofs, address[] memory decoders, SwapParams memory swapParams) = _buildSwapContext();

        vm.expectRevert(BoringSwapper.BoringSwapper__TargetNotApproved.selector);
        _executeSwapViaManager(proofs, decoders, swapParams);
    }

    function testRevert_SwapFailed() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        restrictedSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);

        (bytes32[][] memory proofs, address[] memory decoders, SwapParams memory swapParams) = _buildSwapContext();
        swapParams.swapData = hex"dead";

        vm.expectRevert(BoringSwapper.BoringSwapper__SwapFailed.selector);
        _executeSwapViaManager(proofs, decoders, swapParams);
    }

    function testRevert_Unauthorized() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        restrictedSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);

        (bytes32[][] memory proofs, address[] memory decoders, SwapParams memory swapParams) = _buildSwapContext();

        vm.prank(address(0xdead));
        vm.expectRevert(bytes("UNAUTHORIZED"));
        _executeSwapViaManager(proofs, decoders, swapParams);
    }

    function testOracleAlwaysUsed() external {
        _setUpMainnet();
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);
        restrictedSwapper.setApprovedTarget(getAddress(sourceChain, "uniV3Router"), true);

        (bytes32[][] memory proofs, address[] memory decoders, SwapParams memory swapParams) = _buildSwapContext();
        // Set useOracle to false — RestrictedSwapper should still use oracle
        swapParams.useOracle = false;

        uint256 usdcBefore = ERC20(getAddress(sourceChain, "USDC")).balanceOf(address(boringVault));
        _executeSwapViaManager(proofs, decoders, swapParams);
        uint256 usdcAfter = ERC20(getAddress(sourceChain, "USDC")).balanceOf(address(boringVault));

        assertGt(usdcAfter, usdcBefore, "Vault should have received USDC (oracle used regardless of useOracle flag)");
    }

    function testLifiSwap() external {
        _setUpMainnet();

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 10e18);

        address lifi = getAddress(sourceChain, "lifi");
        address uniV3Router = getAddress(sourceChain, "uniV3Router");
        restrictedSwapper.setApprovedTarget(lifi, true);

        // Build merkle tree
        address[] memory tokensIn = new address[](2);
        tokensIn[0] = getAddress(sourceChain, "WETH");
        tokensIn[1] = getAddress(sourceChain, "USDC");

        SwapKind[] memory kindsIn = new SwapKind[](2);
        kindsIn[0] = SwapKind.BuyAndSell;
        kindsIn[1] = SwapKind.BuyAndSell;

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addBoringSwapperLeafs(leafs, address(restrictedSwapper), address(swapperDecoder), tokensIn, kindsIn);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        // Inner Uniswap V3 calldata — LIFI will execute this on the DEX
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
            payable(address(restrictedSwapper)),  // _receiver: LIFI sends output back to RestrictedSwapper
            uint256(1),                           // _minAmount
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
            useOracle: true,
            quoteAsset: QuoteAsset.USD,
            maxSlippageBps: 500
        });

        // Build Tx: approve RestrictedSwapper + call swap
        Tx memory tx_ = _getTxArrays(2);

        tx_.manageLeafs[0] = leafs[0]; // approve WETH
        tx_.manageLeafs[1] = leafs[1]; // swap WETH -> USDC

        bytes32[][] memory manageProofs = _getProofsUsingTree(tx_.manageLeafs, manageTree);

        tx_.targets[0] = getAddress(sourceChain, "WETH");
        tx_.targets[1] = address(restrictedSwapper);

        tx_.targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, address(restrictedSwapper), swapParams.amountIn);
        tx_.targetData[1] = abi.encodeWithSelector(BoringSwapper.swap.selector, swapParams);

        tx_.decodersAndSanitizers[0] = address(swapperDecoder);
        tx_.decodersAndSanitizers[1] = address(swapperDecoder);

        uint256 usdcBefore = ERC20(getAddress(sourceChain, "USDC")).balanceOf(address(boringVault));
        _submitManagerCall(manageProofs, tx_);
        uint256 usdcAfter = ERC20(getAddress(sourceChain, "USDC")).balanceOf(address(boringVault));

        assertGt(usdcAfter, usdcBefore, "Vault should have received USDC via LIFI");
    }
}
