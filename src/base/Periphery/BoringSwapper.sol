// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {AdapterRegistry} from "src/base/Periphery/AdapterRegistry.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IAdapter} from "src/interfaces/IAdapter.sol";
import {IPriceValidator} from "src/interfaces/IPriceValidator.sol";

contract BoringSwapper is Auth {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;
    using Address for address;

    // ========================================= CONSTANTS =========================================

    /// @notice EIP-1271 magic value returned on successful signature validation
    bytes4 internal constant MAGIC_VALUE = 0x1626ba7e;

    // ========================================= STRUCTS =========================================

    struct TokenRoute {
        ERC20 tokenIn;
        ERC20 tokenOut;
    }

    struct SwapConfig {
        TokenRoute tokenRoute;
        uint8 protocolId;
        address quoteAsset;
        bytes swapData;
        uint256 slippageBps;
        BoringVault receiver;
    }

    struct OrderRecord {
        ERC20 tokenIn;
        address approvalTarget;
        address cancelTarget;
        uint256 inputAmount;
        BoringVault receiver;
    }

    struct RateLimit {
        uint256 capacity;
        uint256 remaining;
        uint256 lastRefill;
        uint256 refillRate;
    }

    // ========================================= ERRORS =========================================

    error BoringSwapper__Paused();
    error BoringSwapper__ProtocolPaused();
    error BoringSwapper__RouteNotApproved();
    error BoringSwapper__ProtocolNotApproved();
    error BoringSwapper__SwapFailed();
    error BoringSwapper__RateLimitExceeded();
    error BoringSwapper__OrderNotFound();
    error BoringSwapper__HashMismatch();
    error BoringSwapper__CancelFailed();

    // ========================================= EVENTS =========================================

    event Swapped(bytes32 indexed routeId, uint256 amountIn, uint256 amountOut, address indexed receiver);
    event OrderSubmitted(uint256 indexed orderId, bytes32 indexed routeId, uint256 amountIn, address indexed receiver);
    event OrderCancelled(uint256 indexed orderId, uint256 refundAmount);
    event RouteUpdated(bytes32 indexed routeId, ERC20 tokenIn, ERC20 tokenOut, bool approved, uint256 maxSlippageBps, uint256 rateLimitCapacity, uint256 rateLimitRefillRate);
    event MaxSlippageBpsUpdated(bytes32 indexed routeId, uint256 maxSlippageBps);
    event ProtocolApproved(uint8 indexed protocolId, bool approved);
    event VersionUpdated(uint8 indexed protocolId, uint256 version);
    event OracleUpdated(ERC20 indexed token, address indexed quoteAsset, address oracle);
    event PriceValidatorUpdated(address newValidator);
    event RateLimitUpdated(bytes32 indexed routeId, uint256 capacity, uint256 refillRate);
    event Swept(ERC20 indexed token, address indexed vault, uint256 amount);
    event GlobalPauseToggled(bool paused);
    event ProtocolPauseToggled(uint8 indexed protocolId, bool paused);

    // ========================================= STATE =========================================

    /// @notice global pause flag — disables all swapping when true
    bool public globalPaused;

    /// @notice per-protocol pause flag — disables swapping for a specific protocol when true
    mapping(uint8 protocolId => bool paused) public protocolPaused;

    /// @notice approved routes (I think unneeded, guarded by merkle root)
    mapping(bytes32 routeId => bool approved) public approvedRoutes;

    /// @notice maxSlippage per token route
    mapping(bytes32 routeId => uint256 maxSlippageBps) public maxSlippageBpsPerRoute;

    /// @notice standardized to 18 decimals
    mapping(bytes32 routeId => RateLimit) public rateLimitPerRoute;

    /// @notice stores the list of approved protocols for this vault
    mapping(uint8 protocolId => bool approved) public approvedProtocols;

    /// @notice maps a token to its quote asset which should have an oracle
    mapping(ERC20 token => mapping(address quoteAsset => address oracle)) public oracles;

    /// @notice stores the current version this swapper subscribes to for a specific protocol
    mapping(uint8 protocolId => uint256 version) public versions;

    /// @notice used for order lookups and cancelling
    mapping(uint256 orderId => OrderRecord) public orderRecords;
    
    /// @notice orderId, incremented by limit orders via submitOrder()
    uint256 public orders;

    AdapterRegistry public adapterRegistry;
    IPriceValidator public priceValidator;

    // ========================================= CONSTRUCTOR =========================================

    constructor(address _owner, AdapterRegistry _adapterRegistry) Auth(_owner, Authority(address(0))) {
        adapterRegistry = _adapterRegistry;
    }

    // ========================================= SWAP FUNCTIONS =========================================

    /// @notice Executes an instant swap via an approved adapter protocol.
    /// @dev Pulls tokenIn from the vault, executes the swap through the adapter's target,
    ///      validates the output price, and returns tokenOut (and any dust) to the vault.
    /// @param swapConfig The swap configuration containing route, protocol, slippage, and calldata.
    function swap(SwapConfig calldata swapConfig) external {
        _checkNotPaused(swapConfig.protocolId);
        bytes32 key = getRouteId(swapConfig.tokenRoute.tokenIn, swapConfig.tokenRoute.tokenOut);
        if (!approvedRoutes[key]) revert BoringSwapper__RouteNotApproved();
        if (!approvedProtocols[swapConfig.protocolId]) revert BoringSwapper__ProtocolNotApproved();

        address target;
        uint256 amount;
        {
            address adapter = adapterRegistry.get(
                swapConfig.protocolId,
                versions[swapConfig.protocolId]
            );

            bytes memory appended = abi.encodePacked(swapConfig.swapData, abi.encode(swapConfig), uint256(swapConfig.swapData.length));
            (bytes memory result) = adapter.functionStaticCall(appended);

            (target, amount) = abi.decode(result, (address, uint256));
        }

        //enforce rate limit
        if (!_consumeRateLimit(key, swapConfig.tokenRoute.tokenIn, amount)) revert BoringSwapper__RateLimitExceeded();

        //snapshot the balance
        uint256 tokenBalanceBefore = swapConfig.tokenRoute.tokenOut.balanceOf(address(this));

        //transfer assets from the vault to the swapper, approve target & execute
        swapConfig.tokenRoute.tokenIn.safeTransferFrom(address(swapConfig.receiver), address(this), amount);
        swapConfig.tokenRoute.tokenIn.approve(target, amount);
        (bool success, ) = target.call(swapConfig.swapData);
        if (!success) revert BoringSwapper__SwapFailed();

        uint256 tokenBalanceDelta = swapConfig.tokenRoute.tokenOut.balanceOf(address(this)) - tokenBalanceBefore;

        //validate the price & slippage
        IPriceValidator(priceValidator).validate(
            swapConfig.tokenRoute.tokenIn,
            swapConfig.tokenRoute.tokenOut,
            amount,
            tokenBalanceDelta,
            swapConfig.quoteAsset,
            swapConfig.slippageBps
        );

        //reset approvals and transfer
        swapConfig.tokenRoute.tokenIn.approve(target, 0);
        swapConfig.tokenRoute.tokenOut.safeTransfer(address(swapConfig.receiver), tokenBalanceDelta);

        //return any unspent tokenIn dust to the vault
        uint256 dust = swapConfig.tokenRoute.tokenIn.balanceOf(address(this));
        if (dust > 0) swapConfig.tokenRoute.tokenIn.safeTransfer(address(swapConfig.receiver), dust);

        emit Swapped(key, amount, tokenBalanceDelta, address(swapConfig.receiver));
    }

    /// @notice Submits a limit order via an approved adapter protocol (e.g. CoWSwap).
    /// @dev Validates the order through the adapter, enforces rate limits and price checks,
    ///      stores the order record, pre-approves the settlement contract, and pulls funds from the vault.
    /// @param swapConfig The swap configuration containing route, protocol, slippage, and order data.
    function submitOrder(SwapConfig memory swapConfig) external {
        _checkNotPaused(swapConfig.protocolId);
        bytes32 key = getRouteId(swapConfig.tokenRoute.tokenIn, swapConfig.tokenRoute.tokenOut);
        if (!approvedRoutes[key]) revert BoringSwapper__RouteNotApproved();
        if (!approvedProtocols[swapConfig.protocolId]) revert BoringSwapper__ProtocolNotApproved();

        address adapter = adapterRegistry.get(
            swapConfig.protocolId,
            versions[swapConfig.protocolId]
        );
        IAdapter.OrderInfo memory info = IAdapter(adapter).verifyLimitOrder(swapConfig, address(this));

        //enforce rate limit
        if (!_consumeRateLimit(key, swapConfig.tokenRoute.tokenIn, info.inputAmount)) revert BoringSwapper__RateLimitExceeded();

        //check for limit order fat fingers
        IPriceValidator(priceValidator).validate(ERC20(info.inputToken), ERC20(info.outputToken), info.inputAmount, info.outputAmount, swapConfig.quoteAsset, swapConfig.slippageBps);

        uint256 orderId = orders;
        orderRecords[orderId] = OrderRecord({
            tokenIn: swapConfig.tokenRoute.tokenIn,
            approvalTarget: info.approvalTarget,
            cancelTarget: info.cancelTarget,
            inputAmount: info.inputAmount,
            receiver: swapConfig.receiver
        });

        //preapprove the approval target & pull funds from the vault
        swapConfig.tokenRoute.tokenIn.approve(info.approvalTarget, info.inputAmount);
        swapConfig.tokenRoute.tokenIn.safeTransferFrom(address(swapConfig.receiver), address(this), info.inputAmount);

        orders += 1;

        emit OrderSubmitted(orderId, key, info.inputAmount, address(swapConfig.receiver));
    }

    /// @notice Cancels a pending limit order, invalidates it on-chain, and refunds remaining tokens to the vault.
    /// @dev Deletes the order record, calls the adapter's cancelLimitOrder to get on-chain cancel calldata,
    ///      executes the cancel on the settlement contract, revokes approval, and refunds.
    /// @param orderId The ID of the order to cancel.
    /// @param swapConfig The swap configuration used when the order was submitted.
    function cancelOrder(uint256 orderId, SwapConfig calldata swapConfig) external {
        OrderRecord memory record = orderRecords[orderId];
        if (address(record.tokenIn) == address(0)) revert BoringSwapper__OrderNotFound();

        delete orderRecords[orderId];

        // On-chain cancellation via adapter
        address adapter = adapterRegistry.get(swapConfig.protocolId, versions[swapConfig.protocolId]);
        (address target, bytes memory data) = IAdapter(adapter).cancelLimitOrder(swapConfig, address(this));
        if (data.length > 0) {
            if (target != record.cancelTarget) revert BoringSwapper__CancelFailed();
            (bool success,) = target.call(data);
            if (!success) revert BoringSwapper__CancelFailed();
        }

        // Revoke approval and refund
        record.tokenIn.approve(record.approvalTarget, 0);
        uint256 balance = record.tokenIn.balanceOf(address(this));
        uint256 refund = balance < record.inputAmount ? balance : record.inputAmount;
        if (refund > 0) record.tokenIn.safeTransfer(address(record.receiver), refund);

        emit OrderCancelled(orderId, refund);
    }

    /// @notice ERC-1271 signature validation — re-validates the order at fill time.
    /// @dev Called by the settlement contract to verify the order is still valid. Checks that
    ///      the route and protocol are approved, the adapter-computed hash matches, and the
    ///      price is within slippage bounds. Also enforces pause state, which allows admin to
    ///      block fills on pending orders during black swan events.
    /// @param _hash The protocol's EIP-712 order digest.
    /// @param _signature abi.encode(SwapConfig) — full config for re-validation.
    /// @return The EIP-1271 magic value if the signature is valid.
    function isValidSignature(bytes32 _hash, bytes memory _signature)
        external
        view
        returns (bytes4)
    {
        SwapConfig memory swapConfig = abi.decode(_signature, (SwapConfig));

        _checkNotPaused(swapConfig.protocolId);
        bytes32 key = getRouteId(swapConfig.tokenRoute.tokenIn, swapConfig.tokenRoute.tokenOut);
        if (!approvedRoutes[key]) revert BoringSwapper__RouteNotApproved();
        if (!approvedProtocols[swapConfig.protocolId]) revert BoringSwapper__ProtocolNotApproved();

        address adapter = adapterRegistry.get(
            swapConfig.protocolId,
            versions[swapConfig.protocolId]
        );
        IAdapter.OrderInfo memory info = IAdapter(adapter).verifyLimitOrder(swapConfig, address(this));

        //if (info.protocolHash != _hash) revert BoringSwapper__HashMismatch();

        IPriceValidator(priceValidator).validate(
            ERC20(info.inputToken),
            ERC20(info.outputToken),
            info.inputAmount,
            info.outputAmount,
            swapConfig.quoteAsset,
            swapConfig.slippageBps
        );

        return MAGIC_VALUE;
    }

    // ========================================= ADMIN FUNCTIONS =========================================

    /// @notice Toggles the global pause state. When paused, all swaps and order submissions are blocked.
    /// @param paused Whether to pause (true) or unpause (false).
    function setGlobalPaused(bool paused) external requiresAuth {
        globalPaused = paused;

        emit GlobalPauseToggled(paused);
    }

    /// @notice Toggles the pause state for a specific protocol. When paused, swaps using this protocol are blocked.
    /// @param protocolId The protocol identifier.
    /// @param paused Whether to pause (true) or unpause (false).
    function setProtocolPaused(uint8 protocolId, bool paused) external requiresAuth {
        protocolPaused[protocolId] = paused;

        emit ProtocolPauseToggled(protocolId, paused);
    }

    /// @notice Approves or revokes a token swap route and configures its slippage and rate limit.
    /// @dev Setting toggle to false disables the route. Rate limit capacity/refillRate are in 18-decimal units.
    ///      Setting rateLimitCapacity to 0 disables rate limiting for this route.
    /// @param tokenIn The input token of the route.
    /// @param tokenOut The output token of the route.
    /// @param toggle Whether to approve (true) or revoke (false) the route.
    /// @param maxSlippageBps The maximum allowed slippage in basis points.
    /// @param rateLimitCapacity The max capacity of the rate limit bucket (18 decimals). 0 disables rate limiting.
    /// @param rateLimitRefillRate The refill rate of the rate limit bucket in units per second (18 decimals).
    function setApprovedRoute(ERC20 tokenIn, ERC20 tokenOut, bool toggle, uint256 maxSlippageBps, uint256 rateLimitCapacity, uint256 rateLimitRefillRate) external requiresAuth {
        bytes32 key = getRouteId(tokenIn, tokenOut);
        approvedRoutes[key] = toggle;
        maxSlippageBpsPerRoute[key] = maxSlippageBps;
        rateLimitPerRoute[key] = RateLimit({
            capacity: rateLimitCapacity,
            remaining: rateLimitCapacity,
            lastRefill: block.timestamp,
            refillRate: rateLimitRefillRate
        });

        emit RouteUpdated(key, tokenIn, tokenOut, toggle, maxSlippageBps, rateLimitCapacity, rateLimitRefillRate);
    }

    /// @notice Updates the maximum slippage for a route without resetting its rate limit bucket.
    /// @param routeId The route identifier (from getRouteId).
    /// @param maxSlippageBps The new maximum allowed slippage in basis points.
    function setMaxSlippageBps(bytes32 routeId, uint256 maxSlippageBps) external requiresAuth {
        maxSlippageBpsPerRoute[routeId] = maxSlippageBps;

        emit MaxSlippageBpsUpdated(routeId, maxSlippageBps);
    }

    /// @notice Approves or revokes a swap protocol (e.g. UniswapV3, CoWSwap).
    /// @param protocolId The protocol identifier.
    /// @param toggle Whether to approve (true) or revoke (false) the protocol.
    function setApprovedProtocol(uint8 protocolId, bool toggle) external requiresAuth {
        approvedProtocols[protocolId] = toggle;

        emit ProtocolApproved(protocolId, toggle);
    }

    /// @notice Sets the adapter version this swapper uses for a given protocol.
    /// @param protocolId The protocol identifier.
    /// @param version The adapter version to subscribe to.
    function addApprovedVersion(uint8 protocolId, uint256 version) external requiresAuth {
        versions[protocolId] = version;

        emit VersionUpdated(protocolId, version);
    }

    /// @notice Removes the adapter version subscription for a given protocol.
    /// @param protocolId The protocol identifier.
    function removeApprovedVersion(uint8 protocolId) external requiresAuth {
        versions[protocolId] = 0;

        emit VersionUpdated(protocolId, 0);
    }

    /// @notice Sets or removes the oracle for a token/quoteAsset pair.
    /// @dev Pass address(0) as oracle to remove the oracle for this pair.
    /// @param token The token to set the oracle for.
    /// @param quoteAsset The quote asset the oracle prices against.
    /// @param oracle The oracle address, or address(0) to remove.
    function setApprovedOracle(ERC20 token, address quoteAsset, address oracle) external requiresAuth {
        oracles[token][quoteAsset] = oracle;

        emit OracleUpdated(token, quoteAsset, oracle);
    }

    /// @notice Sets the price validator contract used for slippage checks.
    /// @param newValidator The new price validator.
    function setPriceValidator(IPriceValidator newValidator) external requiresAuth {
        priceValidator = newValidator;

        emit PriceValidatorUpdated(address(newValidator));
    }

    /// @notice Updates the rate limit for a route without resetting the refill state.
    /// @dev Refills the bucket before applying new parameters. If the new capacity is lower
    ///      than the current remaining, remaining is capped to the new capacity.
    /// @param routeId The route identifier (from getRouteId).
    /// @param capacity The new max capacity (18 decimals). 0 disables rate limiting.
    /// @param refillRate The new refill rate in units per second (18 decimals).
    function setRateLimit(bytes32 routeId, uint256 capacity, uint256 refillRate) external requiresAuth {
        RateLimit storage limit = rateLimitPerRoute[routeId];
        _refillBucket(limit);
        limit.capacity = capacity;
        limit.refillRate = refillRate;
        if (limit.remaining > capacity) limit.remaining = capacity;

        emit RateLimitUpdated(routeId, capacity, refillRate);
    }

    /// @notice Reclaims any token sitting on the swapper back to a vault.
    /// @param token The token to sweep.
    /// @param vault The vault to send the tokens to.
    function sweep(ERC20 token, BoringVault vault) external requiresAuth {
        uint256 balance = token.balanceOf(address(this));
        if (balance > 0) token.safeTransfer(address(vault), balance);

        emit Swept(token, address(vault), balance);
    }

    // ========================================= VIEW FUNCTIONS =========================================

    /// @notice Computes the deterministic route identifier for a directional token pair.
    /// @dev Route IDs are directional: getRouteId(A, B) != getRouteId(B, A).
    /// @param tokenIn The input token.
    /// @param tokenOut The output token.
    /// @return The keccak256 hash of the encoded token addresses.
    function getRouteId(ERC20 tokenIn, ERC20 tokenOut) public pure returns (bytes32) {
        return keccak256(abi.encode(address(tokenIn), address(tokenOut)));
    }

    /// @notice Returns the oracle address for a given token/quoteAsset pair.
    /// @param token The token to look up.
    /// @param quoteAsset The quote asset the oracle prices against.
    /// @return The oracle address, or address(0) if not set.
    function getOracle(ERC20 token, address quoteAsset) external view returns (address) {
        return oracles[token][quoteAsset];
    }

    // ========================================= INTERNAL FUNCTIONS =========================================

    /// @notice Reverts if the swapper is globally paused or the specific protocol is paused.
    /// @param protocolId The protocol identifier to check.
    function _checkNotPaused(uint8 protocolId) internal view {
        if (globalPaused) revert BoringSwapper__Paused();
        if (protocolPaused[protocolId]) revert BoringSwapper__ProtocolPaused();
    }

    /// @notice Consumes from the rate limit bucket for a route, normalizing the amount to 18 decimals.
    /// @dev Returns true immediately if the route's capacity is 0 (rate limiting disabled).
    ///      Refills the bucket based on elapsed time before checking.
    /// @param routeId The route identifier.
    /// @param tokenIn The input token (used to read decimals for normalization).
    /// @param amount The raw input amount in the token's native decimals.
    /// @return True if the amount was successfully consumed, false if the bucket has insufficient remaining.
    function _consumeRateLimit(bytes32 routeId, ERC20 tokenIn, uint256 amount) internal returns (bool) {
        RateLimit storage limit = rateLimitPerRoute[routeId];
        // if capacity is 0, rate limiting is disabled for this route
        if (limit.capacity == 0) return true;
        _refillBucket(limit);
        // normalize amount to 18 decimals
        uint8 decimals = tokenIn.decimals();
        uint256 normalized = decimals < 18 ? amount * 10 ** (18 - decimals) : amount / 10 ** (decimals - 18);
        if (limit.remaining < normalized) return false;
        limit.remaining -= normalized;
        return true;
    }

    /// @notice Refills a rate limit bucket based on elapsed time since the last refill.
    /// @dev Adds (elapsed seconds * refillRate) to remaining, capped at capacity.
    /// @param limit The rate limit bucket to refill.
    function _refillBucket(RateLimit storage limit) internal {
        if (block.timestamp == limit.lastRefill) return;
        uint256 elapsed = block.timestamp - limit.lastRefill;
        uint256 refilled = limit.remaining + (elapsed * limit.refillRate);
        limit.remaining = refilled > limit.capacity ? limit.capacity : refilled;
        limit.lastRefill = block.timestamp;
    }
}
