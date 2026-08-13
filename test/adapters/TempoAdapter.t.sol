// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {TempoTestBase} from "test/adapters/TempoTestBase.sol";
import {BoringSwapper} from "src/base/Periphery/BoringSwapper.sol";
import {ISwapperTypes} from "src/interfaces/ISwapperTypes.sol";
import {TempoAdapter} from "src/base/Periphery/adapters/TempoAdapter.sol";
import {ITempoStablecoinDEX} from "src/interfaces/ITempoStablecoinDEX.sol";
import {IAdapter} from "src/interfaces/IAdapter.sol";

/// @notice Full-stack fork tests for Tempo exact-input market swaps.
contract TempoAdapterTest is TempoTestBase {
    // ============================================ Market orders ============================================

    /// user flow: vault sells BASE into a resting bid, output lands in vault
    function testSwap_ExactIn() external {
        vm.prank(lp);
        DEX.place(address(BASE), 1_000e6, true, 0);

        uint256 vaultBaseBefore = BASE.balanceOf(address(boringVault));
        uint256 vaultQuoteBefore = QUOTE.balanceOf(address(boringVault));

        swapper.swap(_marketConfig(BASE, QUOTE, abi.encodeCall(DEX.swapExactAmountIn, (address(BASE), address(QUOTE), 500e6, 495e6))));

        assertEq(BASE.balanceOf(address(boringVault)), vaultBaseBefore - 500e6, "vault base spent");
        assertEq(QUOTE.balanceOf(address(boringVault)), vaultQuoteBefore + 500e6, "vault received quote");
        assertEq(BASE.balanceOf(address(swapper)), 0, "no wallet dust");
        assertEq(QUOTE.balanceOf(address(swapper)), 0, "no wallet dust");
        assertEq(DEX.balanceOf(address(swapper), address(BASE)), 0, "no internal balance");
        assertEq(DEX.balanceOf(address(swapper), address(QUOTE)), 0, "no internal balance");
        assertEq(BASE.allowance(address(swapper), address(DEX)), 0, "allowance reset");
    }

    /// failure path: DEX revert (output below min) surfaces as SwapFailed, no funds move
    function testSwap_RevertOutputBelowMin_NoFundsMove() external {
        vm.prank(lp);
        DEX.place(address(BASE), 1_000e6, true, 0);

        uint256 vaultBaseBefore = BASE.balanceOf(address(boringVault));

        vm.expectRevert(BoringSwapper.BoringSwapper__SwapFailed.selector);
        swapper.swap(_marketConfig(BASE, QUOTE, abi.encodeCall(DEX.swapExactAmountIn, (address(BASE), address(QUOTE), 500e6, 501e6))));

        assertEq(BASE.balanceOf(address(boringVault)), vaultBaseBefore, "no funds moved on failed swap");
    }

    /// failure path: no liquidity at all
    function testSwap_RevertInsufficientLiquidity() external {
        vm.expectRevert(BoringSwapper.BoringSwapper__SwapFailed.selector);
        swapper.swap(_marketConfig(BASE, QUOTE, abi.encodeCall(DEX.swapExactAmountIn, (address(BASE), address(QUOTE), 500e6, 1))));
    }

    /// I3: calldata token endpoints must match the approved route
    function testSwap_RevertTokenMismatch() external {
        vm.expectRevert(IAdapter.Adapter__TokenInMismatch.selector);
        swapper.swap(_marketConfig(BASE, QUOTE, abi.encodeCall(DEX.swapExactAmountIn, (address(QUOTE), address(BASE), 500e6, 1))));

        vm.expectRevert(IAdapter.Adapter__TokenOutMismatch.selector);
        swapper.swap(_marketConfig(BASE, QUOTE, abi.encodeCall(DEX.swapExactAmountIn, (address(BASE), address(BASE), 500e6, 1))));
    }

    /// I1: the adapter mirrors ONLY the exact-input swap selector — unsupported market,
    /// maker, and balance DEX calls cannot be smuggled through the market-swap flow.
    function testSwap_AdapterExposesNoUnsupportedSelectors() external {
        bytes[] memory forbidden = new bytes[](6);
        forbidden[0] = abi.encodeCall(DEX.swapExactAmountOut, (address(BASE), address(QUOTE), 200e6, 210e6));
        forbidden[1] = abi.encodeCall(DEX.place, (address(BASE), 200e6, false, 0));
        forbidden[2] = abi.encodeCall(DEX.placeFlip, (address(BASE), 200e6, false, 0, -10));
        forbidden[3] = abi.encodeCall(DEX.withdraw, (address(BASE), 1));
        forbidden[4] = abi.encodeCall(DEX.cancel, (uint128(1)));
        forbidden[5] = abi.encodeCall(DEX.createPair, (address(BASE)));

        for (uint256 i; i < forbidden.length; i++) {
            vm.expectRevert();
            swapper.swap(_marketConfig(BASE, QUOTE, forbidden[i]));
        }
    }

    /// I1/I2: mirrored selector matches the DEX ABI exactly and the adapter pins the DEX target
    function testAdapter_MarketSelectorAndTarget() external view {
        assertEq(TempoAdapter.swapExactAmountIn.selector, ITempoStablecoinDEX.swapExactAmountIn.selector, "selector mirror");

        ISwapperTypes.SwapConfig memory config = _marketConfig(BASE, QUOTE, abi.encodeCall(DEX.swapExactAmountIn, (address(BASE), address(QUOTE), 500e6, 1)));
        bytes memory appended = abi.encodePacked(config.swapData, abi.encode(config), uint256(config.swapData.length));
        (bool ok, bytes memory ret) = address(adapter).staticcall(appended);
        assertTrue(ok, "adapter staticcall");
        (address target, uint256 amount) = abi.decode(ret, (address, uint256));
        assertEq(target, address(DEX), "I2: market target is the DEX");
        assertEq(amount, 500e6, "pull amount = amountIn");
    }
}
