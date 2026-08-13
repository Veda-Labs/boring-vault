// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

/// @notice Solidity mirror of the Tempo stablecoin DEX precompile ABI
///         (predeploy at 0xDEc0000000000000000000000000000000000000).
/// @dev Source of truth: tempoxyz/tempo `crates/contracts/src/precompiles/stablecoin_dex.rs`
///      at commit 194dec5c. The precompile is native code with marker bytecode at the address,
///      so high-level Solidity calls and try/catch on its custom errors behave normally.
interface ITempoStablecoinDEX {
    struct Order {
        uint128 orderId;
        address maker;
        bytes32 bookKey;
        bool isBid;
        int16 tick;
        uint128 amount;
        uint128 remaining;
        uint128 prev;
        uint128 next;
        bool isFlip;
        int16 flipTick;
    }

    struct Orderbook {
        address base;
        address quote;
        int16 bestBidTick;
        int16 bestAskTick;
    }

    // Core trading
    function createPair(address base) external returns (bytes32 key);
    function place(address token, uint128 amount, bool isBid, int16 tick) external returns (uint128 orderId);
    function placeFlip(address token, uint128 amount, bool isBid, int16 tick, int16 flipTick)
        external
        returns (uint128 orderId);
    /// @dev Only the order maker may cancel; refund is credited to the maker's INTERNAL DEX balance.
    function cancel(uint128 orderId) external;
    /// @dev Callable by anyone when the maker is no longer authorized by the escrow token's TIP-403 policy.
    function cancelStaleOrder(uint128 orderId) external;

    // Swaps (taker) — input pulled from internal balance first then wallet, output paid to caller's wallet
    function swapExactAmountIn(address tokenIn, address tokenOut, uint128 amountIn, uint128 minAmountOut)
        external
        returns (uint128 amountOut);
    function swapExactAmountOut(address tokenIn, address tokenOut, uint128 amountOut, uint128 maxAmountIn)
        external
        returns (uint128 amountIn);
    function quoteSwapExactAmountIn(address tokenIn, address tokenOut, uint128 amountIn)
        external
        view
        returns (uint128 amountOut);
    function quoteSwapExactAmountOut(address tokenIn, address tokenOut, uint128 amountOut)
        external
        view
        returns (uint128 amountIn);

    // Internal balance management
    function balanceOf(address user, address token) external view returns (uint128);
    /// @dev Moves internal DEX balance to the caller's wallet; only the balance owner can call.
    function withdraw(address token, uint128 amount) external;

    // Views
    /// @dev Reverts OrderDoesNotExist for deleted orders (fully filled OR cancelled).
    function getOrder(uint128 orderId) external view returns (Order memory);
    function pairKey(address tokenA, address tokenB) external pure returns (bytes32);
    function nextOrderId() external view returns (uint128);
    function books(bytes32 pairKey) external view returns (Orderbook memory);

    // Constants (exposed as view functions) and price conversions
    function MIN_TICK() external pure returns (int16);
    function MAX_TICK() external pure returns (int16);
    function TICK_SPACING() external pure returns (int16);
    function PRICE_SCALE() external pure returns (uint32);
    function MIN_ORDER_AMOUNT() external pure returns (uint128);
    function MIN_PRICE() external pure returns (uint32);
    function MAX_PRICE() external pure returns (uint32);
    function tickToPrice(int16 tick) external pure returns (uint32 price);
    function priceToTick(uint32 price) external pure returns (int16 tick);

    // Events
    event PairCreated(bytes32 indexed key, address indexed base, address indexed quote);
    event OrderPlaced(
        uint128 indexed orderId,
        address indexed maker,
        address indexed token,
        uint128 amount,
        bool isBid,
        int16 tick,
        bool isFlipOrder,
        int16 flipTick
    );
    event OrderFilled(
        uint128 indexed orderId, address indexed maker, address indexed taker, uint128 amountFilled, bool partialFill
    );
    event OrderCancelled(uint128 indexed orderId);

    // Errors
    error Unauthorized();
    error PairDoesNotExist();
    error PairAlreadyExists();
    error OrderDoesNotExist();
    error IdenticalTokens();
    error InvalidToken();
    error TickOutOfBounds(int16 tick);
    error InvalidTick();
    error InvalidFlipTick();
    error InsufficientBalance();
    error InsufficientLiquidity();
    error InsufficientOutput();
    error MaxInputExceeded();
    error BelowMinimumOrderSize(uint128 amount);
    error InvalidBaseToken();
    error OrderNotStale();
}

/// @notice Minimal TIP-20 surface needed by the Tempo integration.
interface ITIP20 {
    /// @notice The token's designated quote token in the pathUSD-rooted tree.
    function quoteToken() external view returns (address);
}
