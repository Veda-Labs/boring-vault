// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
// Last audited: boring-vault@68694c5594146666f6ffeb301aa61286c99e8484 — file:audit/0xmacro-veda-96.pdf
pragma solidity 0.8.21;

import {ISwapperTypes} from "src/interfaces/ISwapperTypes.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IAdapter} from "src/interfaces/IAdapter.sol";
import {BaseAdapter} from "src/base/Periphery/adapters/BaseAdapter.sol";

/// @notice MARKET-ORDER adapter for Tempo's native stablecoin DEX (the TIP-20 exchange
///         predeploy). Limit orders live in the separate TempoLimitOrderAdapter so they can be
///         approved/rolled out independently of market swaps.
///
/// Mirrors the DEX's exact-input taker selector and nothing else. The DEX has no recipient parameter —
/// output tokens are transferred to the caller, which is the swapper, so the post-flight
/// balance-delta check works unmodified. Routing (direct pair or multi-hop through quote
/// tokens / pathUSD) happens inside the DEX; the adapter only pins the route endpoints.
/// This adapter MUST NOT mirror any other DEX selector (place/placeFlip/withdraw/cancel/
/// createPair): a match would let the market-swap flow execute maker/balance operations and
/// strand funds in the DEX's internal balance.
contract TempoAdapter is IAdapter, BaseAdapter {
    //============================== Immutables ===============================

    /// @notice Tempo stablecoin DEX predeploy.
    address public immutable TEMPO_DEX;

    constructor(address _tempoDex) {
        TEMPO_DEX = _tempoDex;
    }

    //============================== Market Orders ===============================

    /// @notice Mirrors ITempoStablecoinDEX.swapExactAmountIn — sell a fixed input amount.
    function swapExactAmountIn(
        address tokenIn,
        address tokenOut,
        uint128 amountIn,
        uint128 /*minAmountOut*/
    )
        external
        view
        returns (address, uint256)
    {
        ISwapperTypes.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(tokenIn) != swapConfig.tokenRoute.tokenIn) revert Adapter__TokenInMismatch();
        if (ERC20(tokenOut) != swapConfig.tokenRoute.tokenOut) revert Adapter__TokenOutMismatch();

        return (TEMPO_DEX, amountIn);
    }

    //============================== Limit Orders (unsupported) ===============================

    function verifyLimitOrder(ISwapperTypes.SwapConfig calldata, address) external pure returns (OrderInfo memory) {
        revert Adapter__LimitOrdersNotSupported();
    }

    function cancelLimitOrder(
        ISwapperTypes.SwapConfig calldata,
        address,
        bytes calldata,
        /*cancelData*/
        bytes calldata /*context*/
    )
        external
        pure
        returns (address, bytes memory)
    {
        revert Adapter__LimitOrdersNotSupported();
    }

    function filledAmount(
        ISwapperTypes.SwapConfig calldata,
        address,
        bytes calldata /*context*/
    )
        external
        pure
        returns (uint256)
    {
        revert Adapter__LimitOrdersNotSupported();
    }

    function version() external pure returns (string memory) {
        return "v1";
    }
}
