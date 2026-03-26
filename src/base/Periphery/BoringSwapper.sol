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
import {ISwapper} from "src/interfaces/ISwapper.sol";

contract BoringSwapper is Auth, ISwapper {
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

    struct RateProviderConfig {
        address[] rateProvider;
        address[] intermediary;
        bool skipValidation;
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
    error BoringSwapper__HashMismatch(bytes32, bytes32);
    error BoringSwapper__OrderNotApproved();
    error BoringSwapper__CancelFailed();

    // ========================================= EVENTS =========================================

    event Swapped(bytes32 indexed routeId, uint256 amountIn, uint256 amountOut, address indexed receiver);
    event OrderSubmitted(uint256 indexed orderId, bytes32 indexed routeId, uint256 amountIn, address indexed receiver);
    event OrderCancelled(uint256 indexed orderId, uint256 refundAmount);
    event RouteUpdated(
        bytes32 indexed routeId,
        ERC20 tokenIn,
        ERC20 tokenOut,
        bool approved,
        uint256 maxSlippageBps,
        uint256 rateLimitCapacity,
        uint256 rateLimitRefillRate
    );
    event MaxSlippageBpsUpdated(bytes32 indexed routeId, uint256 maxSlippageBps);
    event ProtocolApproved(uint8 indexed protocolId, bool approved);
    event VersionUpdated(uint8 indexed protocolId, uint256 version);
    event TokenBaseAssetOraclesUpdated(ERC20 indexed token);
    event BaseAssetOracleUpdated(ERC20 indexed baseAsset);
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

    mapping(ERC20 token => mapping(address quoteAsset => RateProviderConfig rateProviderConfig)) internal
        _baseAssetOracles;

    mapping(ERC20 baseAsset => mapping(address quoteAsset => address[] rateProvider)) public oracles;

    /// @notice stores the current version this swapper subscribes to for a specific protocol
    mapping(uint8 protocolId => uint256 version) public versions;

    /// @notice used for order lookups and cancelling
    mapping(uint256 orderId => OrderRecord) public orderRecords;

    /// @notice tracks order hashes approved via submitOrder — only these can be filled
    mapping(bytes32 orderHash => bool approved) public approvedHashes;

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
    function swap(SwapConfig calldata swapConfig) external {
        (bytes32 key, address target, uint256 amount) = _swapPreFlightCheck(swapConfig);

        //enforce rate limit
        if (!_consumeRateLimit(key, swapConfig.tokenRoute.tokenIn, amount)) {
            revert BoringSwapper__RateLimitExceeded();
        }

        uint256 tokenBalanceDelta = _swapPostFlightCheck(swapConfig, target, amount);

        emit Swapped(key, amount, tokenBalanceDelta, address(swapConfig.receiver));
    }

    function _swapPreFlightCheck(SwapConfig calldata swapConfig) internal view returns (bytes32, address, uint256) {
        _checkNotPaused(swapConfig.protocolId);
        bytes32 key = getRouteId(swapConfig.tokenRoute.tokenIn, swapConfig.tokenRoute.tokenOut);
        if (!approvedRoutes[key]) revert BoringSwapper__RouteNotApproved();
        if (!approvedProtocols[swapConfig.protocolId]) revert BoringSwapper__ProtocolNotApproved();

        address target;
        uint256 amount;
        {
            address adapter = adapterRegistry.get(swapConfig.protocolId, versions[swapConfig.protocolId]);

            bytes memory appended =
                abi.encodePacked(swapConfig.swapData, abi.encode(swapConfig), uint256(swapConfig.swapData.length));
            (bytes memory result) = adapter.functionStaticCall(appended);

            (target, amount) = abi.decode(result, (address, uint256));
        }

        return (key, target, amount);
    }

    function _swapPostFlightCheck(
        SwapConfig calldata swapConfig,
        address target,
        uint256 amount
    ) internal returns (uint256) {
        //snapshot the balance
        uint256 tokenBalanceBefore = swapConfig.tokenRoute.tokenOut.balanceOf(address(this));

        //transfer assets from the vault to the swapper, approve target & execute
        swapConfig.tokenRoute.tokenIn.safeTransferFrom(address(swapConfig.receiver), address(this), amount);
        swapConfig.tokenRoute.tokenIn.approve(target, amount);
        (bool success,) = target.call(swapConfig.swapData);
        if (!success) revert BoringSwapper__SwapFailed();

        uint256 tokenBalanceDelta = swapConfig.tokenRoute.tokenOut.balanceOf(address(this)) - tokenBalanceBefore;

        //validate the price & slippage
        IPriceValidator(priceValidator)
            .validate(
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

        return tokenBalanceDelta;
    }

    /// @notice Submits a limit order via an approved adapter protocol (e.g. CoWSwap).
    function submitOrder(SwapConfig memory swapConfig) external {
        (bytes32 key, IAdapter.OrderInfo memory info, uint256 orderId) =
            _limitOrderPreFlightCheck(swapConfig);

        //enforce rate limit
        if (!_consumeRateLimit(key, swapConfig.tokenRoute.tokenIn, info.inputAmount)) {
            revert BoringSwapper__RateLimitExceeded();
        }

        emit OrderSubmitted(orderId, key, info.inputAmount, address(swapConfig.receiver));
    }

    function _limitOrderPreFlightCheck(SwapConfig memory swapConfig)
        internal
        returns (bytes32, IAdapter.OrderInfo memory, uint256)
    {
        _checkNotPaused(swapConfig.protocolId);
        bytes32 key = getRouteId(swapConfig.tokenRoute.tokenIn, swapConfig.tokenRoute.tokenOut);
        if (!approvedRoutes[key]) revert BoringSwapper__RouteNotApproved();
        if (!approvedProtocols[swapConfig.protocolId]) revert BoringSwapper__ProtocolNotApproved();

        address adapter = adapterRegistry.get(swapConfig.protocolId, versions[swapConfig.protocolId]);
        IAdapter.OrderInfo memory info = IAdapter(adapter).verifyLimitOrder(swapConfig, address(this));

        //check for limit order fat fingers
        IPriceValidator(priceValidator)
            .validate(
                ERC20(info.inputToken),
                ERC20(info.outputToken),
                info.inputAmount,
                info.outputAmount,
                swapConfig.quoteAsset,
                swapConfig.slippageBps
            );

        uint256 orderId = orders;
        orderRecords[orderId] = OrderRecord({
            tokenIn: swapConfig.tokenRoute.tokenIn,
            approvalTarget: info.approvalTarget,
            cancelTarget: info.cancelTarget,
            inputAmount: info.inputAmount,
            receiver: swapConfig.receiver
        });
        approvedHashes[info.protocolHash] = true;

        //preapprove the approval target & pull funds from the vault
        swapConfig.tokenRoute.tokenIn.approve(info.approvalTarget, info.inputAmount);
        swapConfig.tokenRoute.tokenIn.safeTransferFrom(address(swapConfig.receiver), address(this), info.inputAmount);

        orders += 1;

        return (key, info, orderId);
    }

    /// @notice Cancels a pending limit order, invalidates it on-chain, and refunds remaining tokens to the vault.
    function cancelOrder(uint256 orderId, SwapConfig calldata swapConfig) external {
        OrderRecord memory record = orderRecords[orderId];
        if (address(record.tokenIn) == address(0)) revert BoringSwapper__OrderNotFound();

        delete orderRecords[orderId];

        // Revoke the approved hash
        address adapter = adapterRegistry.get(swapConfig.protocolId, versions[swapConfig.protocolId]);
        IAdapter.OrderInfo memory info = IAdapter(adapter).verifyLimitOrder(swapConfig, address(this));
        approvedHashes[info.protocolHash] = false;

        // On-chain cancellation via adapter
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

        //TODO refund the rate limit if cancelled. Need logic to tell which one.

        emit OrderCancelled(orderId, refund);
    }

    /// @notice ERC-1271 signature validation — re-validates the order at fill time.
    function isValidSignature(bytes32 _hash, bytes memory _signature) external view returns (bytes4) {
        SwapConfig memory swapConfig = abi.decode(_signature, (SwapConfig));

        _checkNotPaused(swapConfig.protocolId);
        bytes32 key = getRouteId(swapConfig.tokenRoute.tokenIn, swapConfig.tokenRoute.tokenOut);
        if (!approvedRoutes[key]) revert BoringSwapper__RouteNotApproved();
        if (!approvedProtocols[swapConfig.protocolId]) revert BoringSwapper__ProtocolNotApproved();

        address adapter = adapterRegistry.get(swapConfig.protocolId, versions[swapConfig.protocolId]);
        IAdapter.OrderInfo memory info = IAdapter(adapter).verifyLimitOrder(swapConfig, address(this));

        if (info.protocolHash != _hash) revert BoringSwapper__HashMismatch(info.protocolHash, _hash);
        if (!approvedHashes[_hash]) revert BoringSwapper__OrderNotApproved();

        IPriceValidator(priceValidator)
            .validate(
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
    function setGlobalPaused(bool paused) external requiresAuth {
        globalPaused = paused;

        emit GlobalPauseToggled(paused);
    }

    /// @notice Toggles the pause state for a specific protocol. When paused, swaps using this protocol are blocked.
    function setProtocolPaused(uint8 protocolId, bool paused) external requiresAuth {
        protocolPaused[protocolId] = paused;

        emit ProtocolPauseToggled(protocolId, paused);
    }

    /// @notice Approves or revokes a token swap route and configures its slippage and rate limit.
    function setApprovedRoute(
        ERC20 tokenIn,
        ERC20 tokenOut,
        bool toggle,
        uint256 maxSlippageBps,
        uint256 rateLimitCapacity,
        uint256 rateLimitRefillRate
    ) external requiresAuth {
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
    function setMaxSlippageBps(bytes32 routeId, uint256 maxSlippageBps) external requiresAuth {
        maxSlippageBpsPerRoute[routeId] = maxSlippageBps;
        emit MaxSlippageBpsUpdated(routeId, maxSlippageBps);
    }

    /// @notice Approves or revokes a swap protocol (e.g. UniswapV3, CoWSwap).
    function setApprovedProtocol(uint8 protocolId, bool toggle) external requiresAuth {
        approvedProtocols[protocolId] = toggle;

        emit ProtocolApproved(protocolId, toggle);
    }

    /// @notice Sets the adapter version this swapper uses for a given protocol.
    function addApprovedVersion(uint8 protocolId, uint256 version) external requiresAuth {
        versions[protocolId] = version;

        emit VersionUpdated(protocolId, version);
    }

    /// @notice Removes the adapter version subscription for a given protocol.
    function removeApprovedVersion(uint8 protocolId) external requiresAuth {
        versions[protocolId] = 0;

        emit VersionUpdated(protocolId, 0);
    }

    function setTokenOracle(ERC20 token, address quoteAsset, RateProviderConfig memory config) external requiresAuth {
        _baseAssetOracles[token][quoteAsset] = config;
    }

    function setBaseAssetOracle(ERC20 intermediary, address quoteAsset, address[] memory rateProviders)
        external
        requiresAuth
    {
        oracles[intermediary][quoteAsset] = rateProviders;
    }

    /// @notice Sets the price validator contract used for slippage checks.
    function setPriceValidator(IPriceValidator newValidator) external requiresAuth {
        priceValidator = newValidator;

        emit PriceValidatorUpdated(address(newValidator));
    }

    /// @notice Updates the rate limit for a route without resetting the refill state.
    function setRateLimit(bytes32 routeId, uint256 capacity, uint256 refillRate) external requiresAuth {
        RateLimit storage limit = rateLimitPerRoute[routeId];
        _refillBucket(limit);
        limit.capacity = capacity;
        limit.refillRate = refillRate;
        if (limit.remaining > capacity) limit.remaining = capacity;

        emit RateLimitUpdated(routeId, capacity, refillRate);
    }

    /// @notice Reclaims any token sitting on the swapper back to a vault.
    function sweep(ERC20 token, BoringVault vault) external requiresAuth {
        uint256 balance = token.balanceOf(address(this));
        if (balance > 0) token.safeTransfer(address(vault), balance);

        emit Swept(token, address(vault), balance);
    }

    // ========================================= VIEW FUNCTIONS =========================================

    /// @notice Computes the deterministic route identifier for a directional token pair.
    function getRouteId(ERC20 tokenIn, ERC20 tokenOut) public pure returns (bytes32) {
        return keccak256(abi.encode(address(tokenIn), address(tokenOut)));
    }

    function getBaseAssetOracle(ERC20 token, address quoteAsset)
        public
        view
        returns (address[] memory, address[] memory, bool)
    {
        RateProviderConfig storage config = _baseAssetOracles[token][quoteAsset];
        return (config.rateProvider, config.intermediary, config.skipValidation);
    }

    // ========================================= INTERNAL FUNCTIONS =========================================

    /// @notice Reverts if the swapper is globally paused or the specific protocol is paused.
    function _checkNotPaused(uint8 protocolId) internal view {
        if (globalPaused) revert BoringSwapper__Paused();
        if (protocolPaused[protocolId]) revert BoringSwapper__ProtocolPaused();
    }

    /// @notice Consumes from the rate limit bucket for a route, normalizing the amount to 18 decimals.
    function _consumeRateLimit(bytes32 routeId, ERC20 tokenIn, uint256 amount)
        internal
        returns (bool)
    {
        RateLimit storage limit = rateLimitPerRoute[routeId];
        //if capacity is 0, rate limiting is disabled for this route
        if (limit.capacity == 0) return true;
        _refillBucket(limit);
        //normalize amount to 18 decimals
        uint8 decimals = tokenIn.decimals();
        uint256 normalized = decimals < 18 ? amount * 10 ** (18 - decimals) : amount / 10 ** (decimals - 18);
        if (limit.remaining < normalized) return false;
        limit.remaining -= normalized;
        return true;
    }

    /// @notice Refills a rate limit bucket based on elapsed time since the last refill.
    function _refillBucket(RateLimit storage limit) internal {
        if (block.timestamp == limit.lastRefill) return;
        uint256 elapsed = block.timestamp - limit.lastRefill;
        uint256 refilled = limit.remaining + (elapsed * limit.refillRate);
        limit.remaining = refilled > limit.capacity ? limit.capacity : refilled;
        limit.lastRefill = block.timestamp;
    }
}
