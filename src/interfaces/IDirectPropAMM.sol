// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

/// @notice Narrow DirectPropAMM taker interface used by Veda strategist integrations.
interface IDirectPropAMM {
    function baseToken() external view returns (address);

    function quoteToken() external view returns (address);

    /// @dev Ignores the caller's rounding-credit route. Use the `For` variants when the quote has to
    ///      match settlement for a specific taker, recipient, and customer ID.
    function quoteExactInput(bool baseToQuote, uint256 amountIn) external view returns (uint256 amountOut, uint256 price, uint256 updatedAt);

    function quoteExactOutput(bool baseToQuote, uint256 amountOut) external view returns (uint256 amountIn, uint256 price, uint256 updatedAt);

    /// @dev Route-aware quote. `price` and `updatedAt` are what strategist tooling must feed back as
    ///      `expectedOraclePrice` and `minimumOracleUpdatedAt`.
    function quoteExactInputFor(address taker, address recipient, bytes32 customerId, bool baseToQuote, uint256 amountIn)
        external
        view
        returns (uint256 amountOut, uint256 price, uint256 updatedAt, uint256 creditAfter);

    function quoteExactOutputFor(address taker, address recipient, bytes32 customerId, bool baseToQuote, uint256 amountOut)
        external
        view
        returns (uint256 amountIn, uint256 price, uint256 updatedAt, uint256 creditAfter);

    function roundingRouteKey(address taker, address recipient, bytes32 customerId) external view returns (bytes32);

    function roundingCredit(bytes32 routeKey) external view returns (uint256);

    function swapExactInput(
        bool baseToQuote,
        uint256 amountIn,
        uint256 minAmountOut,
        address recipient,
        bytes32 customerId,
        bytes32 tradeId,
        uint256 deadline,
        uint256 expectedOraclePrice,
        uint256 oraclePriceToleranceBps,
        uint256 minimumOracleUpdatedAt
    ) external returns (uint256 amountOut);

    function swapExactOutput(
        bool baseToQuote,
        uint256 amountOut,
        uint256 maxAmountIn,
        address recipient,
        bytes32 customerId,
        bytes32 tradeId,
        uint256 deadline,
        uint256 expectedOraclePrice,
        uint256 oraclePriceToleranceBps,
        uint256 minimumOracleUpdatedAt
    ) external returns (uint256 amountIn);
}
