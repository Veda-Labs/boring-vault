// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {ReentrancyGuard} from "@solmate/utils/ReentrancyGuard.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {AdapterRegistry} from "src/base/Periphery/AdapterRegistry.sol";
import {IAdapter} from "src/interfaces/IAdapter.sol";
import {IPriceValidator} from "src/interfaces/IPriceValidator.sol";
import {ISwapper} from "src/interfaces/ISwapper.sol";
import {IPausable} from "src/interfaces/IPausable.sol";
import {IFeeRegistry} from "src/interfaces/IFeeRegistry.sol";
import {ISwapperTypes} from "src/interfaces/ISwapperTypes.sol";

contract BoringSwapper is Auth, ReentrancyGuard, ISwapper, IPausable {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;
    using Address for address;

    // ========================================= CONSTANTS =========================================

    /// @notice EIP-1271 magic value returned on successful signature validation
    bytes4 internal constant MAGIC_VALUE = 0x1626ba7e;

    // ========================================= STRUCTS =========================================

    struct RateProviderConfig {
        address[] rateProvider;
        address[] intermediary;
        bool skipValidation;
    }

    struct OrderRecord {
        ERC20 tokenIn;
        address adapter;
        address approvalTarget;
        address cancelTarget;
        BoringVault receiver;
        uint256 inputAmount;
        uint256 fee;
        bytes32 protocolHash;
        uint256 cancelledAt;
        address quoteAsset;
        uint256 slippageBps;
    }

    struct RateLimit {
        uint256 capacity;
        uint256 remaining;
        uint256 lastRefill;
        uint256 refillRate;
    }

    // ========================================= ERRORS =========================================

    error BoringSwapper__Paused();
    error BoringSwapper__AdapterPaused();
    error BoringSwapper__AdapterNotApproved();
    error BoringSwapper__SwapFailed();
    error BoringSwapper__RateLimitExceeded();
    error BoringSwapper__OrderNotFound();
    error BoringSwapper__HashMismatch(bytes32, bytes32);
    error BoringSwapper__OrderNotApproved();
    error BoringSwapper__CancelFailed();
    error BoringSwapper__FeeRecipientNotSet();
    error BoringSwapper__AlreadyCancelled();
    error BoringSwapper__NotCancelledOrder();
    error BoringSwapper__CancelFeeNotClaimable();
    error BoringSwapper__DuplicateOrder();
    error BoringSwapper__WrongAdapter();
    error BoringSwapper__OrderAlreadyFilled();

    // ========================================= EVENTS =========================================

    event Swapped(bytes32 indexed routeId, uint256 amountIn, uint256 amountOut, address indexed receiver);
    event OrderSubmitted(uint256 indexed orderId, bytes32 indexed routeId, uint256 amountIn, address indexed receiver);
    event OrderSwapConfig(uint256 indexed orderId, ISwapperTypes.SwapConfig swapConfig);
    event OrderCancelled(uint256 indexed orderId, uint256 refundAmount);
    event RouteUpdated(
        bytes32 indexed routeId,
        ERC20 tokenIn,
        ERC20 tokenOut,
        uint256 maxSlippageBps,
        uint256 rateLimitCapacity,
        uint256 rateLimitRefillRate
    );
    event MaxSlippageBpsUpdated(bytes32 indexed routeId, uint256 maxSlippageBps);
    event AdapterApproved(address indexed adapter, bool approved);
    event TokenBaseAssetOraclesUpdated(ERC20 indexed token);
    event BaseAssetOracleUpdated(ERC20 indexed baseAsset);
    event PriceValidatorUpdated(address newValidator);
    event RateLimitUpdated(bytes32 indexed routeId, uint256 capacity, uint256 refillRate);
    event Swept(ERC20 indexed token, address indexed vault, uint256 amount);
    event FeeReleased(uint256 indexed orderId, ERC20 indexed token, uint256 feeAmount);
    event FeesClaimed(ERC20 indexed token, uint256 feeAmount);
    event Paused();
    event Unpaused();
    event AdapterPauseToggled(address indexed adapter, bool paused);
    event FeeRegistryUpdated(address indexed newRegistry);

    // ========================================= STATE =========================================

    /// @notice global pause flag — disables all swapping when true
    bool public isPaused;

    /// @notice per-adapter pause flag — disables swapping for a specific adapter when true
    mapping(address adapter => bool paused) public adapterPaused;

    /// @notice maxSlippage per token route
    mapping(bytes32 routeId => uint256 maxSlippageBps) public maxSlippageBpsPerRoute;

    /// @notice standardized to 18 decimals
    mapping(bytes32 routeId => RateLimit) public rateLimitPerRoute;

    /// @notice stores the list of approved adapters for this swapper
    mapping(address adapter => bool approved) public approvedAdapters;
    address[] public approvedAdaptersList;

    mapping(ERC20 token => mapping(address quoteAsset => RateProviderConfig rateProviderConfig)) internal
        _baseAssetOracles;

    mapping(ERC20 baseAsset => mapping(address quoteAsset => address[] rateProvider)) public oracles;

    /// @notice principal locked against pending limit orders — decremented on cancel or release.
    mapping(ERC20 token => uint256 amount) public pendingOrderPrincipal;

    /// @notice fees locked against pending orders — decremented on cancel or release.
    mapping(ERC20 feeAsset => uint256 feeAmount) public feesInToken;

    /// @notice fees released from filled orders — the only amount claimable via claimFees.
    mapping(ERC20 feeAsset => uint256 feeAmount) public claimableFees;

    /// @notice used for order lookups and cancelling
    mapping(uint256 orderId => OrderRecord) public orderRecords;

    /// @notice tracks order hashes approved via submitOrder — only these can be filled
    mapping(bytes32 orderHash => bool approved) public approvedHashes;

    /// @notice tracks the relationship between the approved hash and the order number
    mapping(bytes32 orderHash => uint256 orderId) public hashToOrder;

    /// @notice orderId, incremented by limit orders via submitOrder()
    uint256 public orders;

    /// @notice central registry for allowed adapters
    AdapterRegistry public adapterRegistry;

    /// @notice the price validator contract validating swap routes
    IPriceValidator public priceValidator;

    /// @notice central fee registry for swap fees and routes
    IFeeRegistry public feeRegistry;

    /// @notice the Boring Vault this swapper contact is associated with
    BoringVault public boringVault;

    // ========================================= CONSTRUCTOR =========================================

    constructor(
        address _owner,
        AdapterRegistry _adapterRegistry,
        IFeeRegistry _feeRegistry,
        BoringVault _boringVault,
        IPriceValidator _priceValidator
    ) Auth(_owner, Authority(address(0))) {
        adapterRegistry = _adapterRegistry;
        feeRegistry = _feeRegistry;
        boringVault = _boringVault;
        priceValidator = _priceValidator;
    }

    // ========================================= SWAP FUNCTIONS =========================================

    /// @notice Executes an instant swap via an approved adapter protocol.
    function swap(ISwapperTypes.SwapConfig calldata swapConfig) external requiresAuth nonReentrant {
        (bytes32 key, address target, uint256 amount) = _swapPreFlightCheck(swapConfig);

        //enforce rate limit
        if (!_consumeRateLimit(key, swapConfig.tokenRoute.tokenIn, amount)) {
            revert BoringSwapper__RateLimitExceeded();
        }

        uint256 tokenBalanceDelta = _swapPostFlightCheck(swapConfig, target, amount);

        emit Swapped(key, amount, tokenBalanceDelta, address(swapConfig.receiver));
    }

    /// @notice Submits a limit order via an approved adapter protocol (e.g. CoWSwap).
    function submitOrder(ISwapperTypes.SwapConfig calldata swapConfig) external requiresAuth nonReentrant {
        (bytes32 key, IAdapter.OrderInfo memory info, uint256 orderId) = _limitOrderPreFlightCheck(swapConfig);

        //enforce rate limit
        if (!_consumeRateLimit(key, swapConfig.tokenRoute.tokenIn, info.inputAmount)) {
            revert BoringSwapper__RateLimitExceeded();
        }

        emit OrderSubmitted(orderId, key, info.inputAmount, address(swapConfig.receiver));
        emit OrderSwapConfig(orderId, swapConfig);
    }

    /// @notice Cancels a pending limit order, invalidates it on-chain, and refunds remaining tokens to the vault.
    function cancelOrder(uint256 orderId, ISwapperTypes.SwapConfig calldata swapConfig) external requiresAuth {
        _cancelOrder(orderId, swapConfig);
    }

    function replaceOrder(
        uint256 orderId,
        ISwapperTypes.SwapConfig calldata cancelConfig,
        ISwapperTypes.SwapConfig memory newConfig
    ) external requiresAuth {
        _cancelOrder(orderId, cancelConfig);

        (bytes32 key, IAdapter.OrderInfo memory info, uint256 newOrderId) = _limitOrderPreFlightCheck(newConfig);

        if (!_consumeRateLimit(key, newConfig.tokenRoute.tokenIn, info.inputAmount)) {
            revert BoringSwapper__RateLimitExceeded();
        }

        emit OrderSubmitted(newOrderId, key, info.inputAmount, address(newConfig.receiver));
        emit OrderSwapConfig(newOrderId, newConfig);
    }

    function _cancelOrder(uint256 orderId, ISwapperTypes.SwapConfig calldata swapConfig) internal {
        OrderRecord storage record = orderRecords[orderId];
        if (address(record.tokenIn) == address(0)) revert BoringSwapper__OrderNotFound();
        if (record.cancelledAt > 0) revert BoringSwapper__AlreadyCancelled();
        if (swapConfig.adapter != record.adapter) revert BoringSwapper__WrongAdapter();

        //reject any cancels after fill
        if (IAdapter(record.adapter).isFilled(swapConfig, address(this))) revert BoringSwapper__OrderAlreadyFilled();

        record.cancelledAt = block.timestamp;

        // Verify the supplied swapConfig matches the stored order, then revoke its hash
        address adapter = swapConfig.adapter;
        IAdapter.OrderInfo memory info = IAdapter(adapter).verifyLimitOrder(swapConfig, address(this));
        if (info.protocolHash != record.protocolHash) revert BoringSwapper__CancelFailed();

        //cleanup state
        approvedHashes[record.protocolHash] = false;
        delete hashToOrder[record.protocolHash];

        //on-chain cancellation via adapter. not needed for most adapters.
        (address target, bytes memory data) = IAdapter(adapter).cancelLimitOrder(swapConfig, address(this));
        if (data.length > 0) {
            if (target != record.cancelTarget) revert BoringSwapper__CancelFailed();
            (bool success,) = target.call(data);
            if (!success) revert BoringSwapper__CancelFailed();
        }

        // @dev this would need to be changed for partials, we need to somehow see how much was filled.
        //reduce accumulated approval by this order's input amount
        uint256 currentAllowance = record.tokenIn.allowance(address(this), record.approvalTarget);
        uint256 reducedAllowance = currentAllowance > record.inputAmount ? currentAllowance - record.inputAmount : 0;
        record.tokenIn.safeApprove(record.approvalTarget, 0);
        if (reducedAllowance > 0) record.tokenIn.safeApprove(record.approvalTarget, reducedAllowance);

        //@dev this needs to be reworked when we add partials 
        //refund principal only
        uint256 refund = record.inputAmount;

        //restore rate limit for the unfilled principal amount
        bytes32 routeId = getRouteId(swapConfig.tokenRoute.tokenIn, swapConfig.tokenRoute.tokenOut);
        RateLimit storage limit = rateLimitPerRoute[routeId];
        if (limit.capacity > 0) {
            _refillBucket(limit);
            uint256 normalized = (refund * 1e18) / (10 ** record.tokenIn.decimals());
            uint256 restored = limit.remaining + normalized;
            limit.remaining = restored > limit.capacity ? limit.capacity : restored;
        }
            
        pendingOrderPrincipal[record.tokenIn] -= refund;
        record.tokenIn.safeTransfer(address(record.receiver), refund);
        emit OrderCancelled(orderId, refund);
    }

    /// @notice ERC-1271 signature validation — re-validates the order at fill time.
    function isValidSignature(bytes32 _hash, bytes memory _signature) external view returns (bytes4) {
        ISwapperTypes.SwapConfig memory swapConfig = abi.decode(_signature, (ISwapperTypes.SwapConfig));
        _validateAdapter(swapConfig.adapter);

        address adapter = swapConfig.adapter;
        IAdapter.OrderInfo memory info = IAdapter(adapter).verifyLimitOrder(swapConfig, address(this));

        if (info.protocolHash != _hash) revert BoringSwapper__HashMismatch(info.protocolHash, _hash);
        if (!approvedHashes[_hash]) revert BoringSwapper__OrderNotApproved();

        //lookup the order record
        uint256 orderId = hashToOrder[_hash];
        OrderRecord memory record = orderRecords[orderId];

        IPriceValidator(priceValidator)
            .validate(
                ERC20(info.inputToken),
                ERC20(info.outputToken),
                info.inputAmount,
                info.outputAmount,
                record.quoteAsset,
                record.slippageBps
            );

        return MAGIC_VALUE;
    }

    // ========================================= ADMIN FUNCTIONS =========================================

    /// @notice Pauses all swaps and order submissions.
    function pause() external requiresAuth {
        isPaused = true;
        emit Paused();
    }

    /// @notice Unpauses all swaps and order submissions.
    function unpause() external requiresAuth {
        isPaused = false;
        emit Unpaused();
    }

    /// @notice Toggles the pause state for a specific adapter. When paused, swaps using this adapter are blocked.
    function setAdapterPaused(address adapter, bool paused) external requiresAuth {
        adapterPaused[adapter] = paused;

        emit AdapterPauseToggled(adapter, paused);
    }

    /// @notice Set the token swap route and configures its slippage and rate limit.
    function setRouteConfig(
        ERC20 tokenIn,
        ERC20 tokenOut,
        uint256 maxSlippageBps,
        uint256 rateLimitCapacity,
        uint256 rateLimitRefillRate
    ) external requiresAuth {
        bytes32 key = getRouteId(tokenIn, tokenOut);
        maxSlippageBpsPerRoute[key] = maxSlippageBps;
        rateLimitPerRoute[key] = RateLimit({
            capacity: rateLimitCapacity,
            remaining: rateLimitCapacity,
            lastRefill: block.timestamp,
            refillRate: rateLimitRefillRate
        });

        emit RouteUpdated(key, tokenIn, tokenOut, maxSlippageBps, rateLimitCapacity, rateLimitRefillRate);
    }

    /// @notice Updates the maximum slippage for a route without resetting its rate limit bucket.
    function setMaxSlippageBps(bytes32 routeId, uint256 maxSlippageBps) external requiresAuth {
        maxSlippageBpsPerRoute[routeId] = maxSlippageBps;
        emit MaxSlippageBpsUpdated(routeId, maxSlippageBps);
    }

    /// @notice Approves or revokes a specific adapter.
    function setApprovedAdapter(address adapter, bool toggle) external requiresAuth {
        if (approvedAdapters[adapter] == toggle) return;
        approvedAdapters[adapter] = toggle;

        if (toggle) {
            approvedAdaptersList.push(adapter);
        } else {
            //swap & pop to keep array length in tact, but order doesn't matter for querying
            uint256 approvedAdaptersListLength = approvedAdaptersList.length;
            for (uint256 i; i < approvedAdaptersListLength;) {
                if (approvedAdaptersList[i] == adapter) {
                    approvedAdaptersList[i] = approvedAdaptersList[approvedAdaptersListLength - 1];
                    approvedAdaptersList.pop();
                    break;
                }

                unchecked {
                    i++;
                }
            }
        }

        emit AdapterApproved(adapter, toggle);
    }

    function setTokenOracle(ERC20 token, address quoteAsset, RateProviderConfig memory config) external requiresAuth {
        _baseAssetOracles[token][quoteAsset] = config;
        emit TokenBaseAssetOraclesUpdated(token);
    }

    function setBaseAssetOracle(ERC20 intermediary, address quoteAsset, address[] memory rateProviders)
        external
        requiresAuth
    {
        oracles[intermediary][quoteAsset] = rateProviders;
        emit BaseAssetOracleUpdated(intermediary);
    }

    /// @notice Sets the price validator contract used for slippage checks.
    function setPriceValidator(IPriceValidator newValidator) external requiresAuth {
        priceValidator = newValidator;

        emit PriceValidatorUpdated(address(newValidator));
    }

    /// @notice Updates the fee registry. Restricted to a Veda-controlled address — vault admins
    ///         must NOT be granted this capability in RolesAuthority.
    function setFeeRegistry(IFeeRegistry newRegistry) external requiresAuth {
        feeRegistry = newRegistry;

        emit FeeRegistryUpdated(address(newRegistry));
    }

    /// @notice Updates the rate limit for a route without resetting the refill state.
    /// @dev If rate limiting was previously disabled (capacity == 0), remaining is initialized to the new capacity.
    function setRateLimit(bytes32 routeId, uint256 capacity, uint256 refillRate) external requiresAuth {
        RateLimit storage limit = rateLimitPerRoute[routeId];
        if (limit.capacity == 0) {
            limit.remaining = capacity;
            limit.lastRefill = block.timestamp;
        } else {
            _refillBucket(limit);
            if (limit.remaining > capacity) limit.remaining = capacity;
        }
        limit.capacity = capacity;
        limit.refillRate = refillRate;

        emit RateLimitUpdated(routeId, capacity, refillRate);
    }

    /// @notice Revokes a token approval on a given spender. Callable by admins and the vault so
    ///         strategists can include it in managed calls to clean up residual allowances after fills.
    function revokeApproval(ERC20 token, address spender) external requiresAuth {
        token.safeApprove(spender, 0);
    }

    /// @notice Reclaims any token sitting on the swapper back to a vault.
    /// @dev claimable by swapper admin
    function sweep(ERC20 token) external requiresAuth {
        uint256 locked = pendingOrderPrincipal[token] + feesInToken[token] + claimableFees[token];
        uint256 balance = token.balanceOf(address(this));
        uint256 sweepable = balance > locked ? balance - locked : 0;
        if (sweepable > 0) token.safeTransfer(address(boringVault), sweepable);

        emit Swept(token, address(boringVault), sweepable);
    }

    /// @notice Marks a filled order's fee as claimable. Called by the off-chain bot after confirming the fill.
    /// @dev Moves the fee from the locked `feesInToken` bucket into `claimableFees`. Deletes the order record.
    /// @dev fee collector is responsible for determining if the order was filled or canceled off-chain
    function releaseFee(uint256 orderId) external requiresAuth {
        OrderRecord memory record = orderRecords[orderId];
        if (address(record.tokenIn) == address(0)) revert BoringSwapper__OrderNotFound();

        //cleanup
        delete orderRecords[orderId];
        approvedHashes[record.protocolHash] = false;
        delete hashToOrder[record.protocolHash];

        // `_cancelOrder` already decremented `pendingOrderPrincipal` at cancel time — skip the second
        // decrement when releasing the fee of a cancelled order (cancel-after-fill path).
        if (record.cancelledAt == 0) {
            uint256 principalHeld = pendingOrderPrincipal[record.tokenIn];
            pendingOrderPrincipal[record.tokenIn] =
                record.inputAmount < principalHeld ? principalHeld - record.inputAmount : 0;
        }

        //if order was submitted while no fee was active, nothing to move
        if (record.fee == 0) return;

        feesInToken[record.tokenIn] -= record.fee;
        claimableFees[record.tokenIn] += record.fee;

        emit FeeReleased(orderId, record.tokenIn, record.fee);
    }

    /// @notice Claims all releasable fees for a token, sending them to the configured fee recipient.
    /// @dev Only drains `claimableFees` — locked pending-order fees are never touched.
    function claimFees(ERC20 token) external requiresAuth {
        uint256 feeAmount = claimableFees[token];
        if (feeAmount == 0) return;

        address feeRecipient = feeRegistry.getFeeRecipientLimit(address(this), token);
        if (feeRecipient == address(0)) revert BoringSwapper__FeeRecipientNotSet();

        claimableFees[token] = 0;

        token.safeTransfer(feeRecipient, feeAmount);
        emit FeesClaimed(token, feeAmount);
    }

    // ========================================= VIEW FUNCTIONS =========================================

    /// @notice Computes the deterministic route identifier for a directional token pair.
    function getRouteId(ERC20 tokenIn, ERC20 tokenOut) public pure returns (bytes32 routeId) {
        assembly {
            mstore(0x00, tokenIn)
            mstore(0x20, tokenOut)
            routeId := keccak256(0x00, 0x40)
        }
    }

    function getBaseAssetOracle(ERC20 token, address quoteAsset)
        public
        view
        returns (address[] memory, address[] memory, bool)
    {
        RateProviderConfig storage config = _baseAssetOracles[token][quoteAsset];
        return (config.rateProvider, config.intermediary, config.skipValidation);
    }

    function baseOracleLength(ERC20 baseAsset, address quoteAsset) external view returns (uint256) {
        return oracles[baseAsset][quoteAsset].length;
    }

    function version() external pure returns (string memory) {
        return "v1";
    }

    // ========================================= INTERNAL FUNCTIONS =========================================

    function _swapPreFlightCheck(ISwapperTypes.SwapConfig calldata swapConfig)
        internal
        view
        returns (bytes32, address, uint256)
    {
        _validateAdapter(swapConfig.adapter);

        address target;
        uint256 amount;
        {
            address adapter = swapConfig.adapter;

            bytes memory appended =
                abi.encodePacked(swapConfig.swapData, abi.encode(swapConfig), uint256(swapConfig.swapData.length));
            (bytes memory result) = adapter.functionStaticCall(appended);

            (target, amount) = abi.decode(result, (address, uint256));
        }

        bytes32 key = getRouteId(swapConfig.tokenRoute.tokenIn, swapConfig.tokenRoute.tokenOut);
        return (key, target, amount);
    }

    function _swapPostFlightCheck(ISwapperTypes.SwapConfig calldata swapConfig, address target, uint256 amount)
        internal
        returns (uint256)
    {
        //snapshot the balance
        uint256 tokenBalanceBefore = swapConfig.tokenRoute.tokenOut.balanceOf(address(this));
        uint256 tokenInCurrentAllowance = swapConfig.tokenRoute.tokenIn.allowance(address(this), target);

        //transfer assets from the vault to the swapper, approve target & execute
        swapConfig.tokenRoute.tokenIn.safeTransferFrom(address(swapConfig.receiver), address(this), amount);

        swapConfig.tokenRoute.tokenIn.safeApprove(target, 0);
        swapConfig.tokenRoute.tokenIn.safeApprove(target, amount + tokenInCurrentAllowance);

        (bool success,) = target.call(swapConfig.swapData);
        if (!success) revert BoringSwapper__SwapFailed();

        swapConfig.tokenRoute.tokenIn.safeApprove(target, 0); //reset to 0, even if already 0
        swapConfig.tokenRoute.tokenIn.safeApprove(target, tokenInCurrentAllowance);

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

        //charge fees if fee collection is active for this swapper
        if (feeRegistry.atomicFeeActive(address(this))) {
            uint16 feeBps = feeRegistry.getAtomicFee(
                address(this), address(swapConfig.tokenRoute.tokenIn), address(swapConfig.tokenRoute.tokenOut)
            );
            if (feeBps > 0) {
                address feeRecipient = feeRegistry.getFeeRecipientAtomic(address(this), swapConfig.tokenRoute.tokenOut);
                if (feeRecipient == address(0)) revert BoringSwapper__FeeRecipientNotSet();
                uint256 fee = tokenBalanceDelta.mulDivUp(feeBps, 10_000);
                tokenBalanceDelta -= fee;
                swapConfig.tokenRoute.tokenOut.safeTransfer(feeRecipient, fee);
            }
        }

        swapConfig.tokenRoute.tokenOut.safeTransfer(address(swapConfig.receiver), tokenBalanceDelta);

        // Return any unspent tokenIn dust to the vault, excluding locked limit order funds.
        uint256 locked = pendingOrderPrincipal[swapConfig.tokenRoute.tokenIn]
            + feesInToken[swapConfig.tokenRoute.tokenIn] + claimableFees[swapConfig.tokenRoute.tokenIn];
        uint256 balance = swapConfig.tokenRoute.tokenIn.balanceOf(address(this));
        uint256 dust = balance > locked ? balance - locked : 0;
        if (dust > 0) swapConfig.tokenRoute.tokenIn.safeTransfer(address(swapConfig.receiver), dust);

        return tokenBalanceDelta;
    }

    function _limitOrderPreFlightCheck(ISwapperTypes.SwapConfig memory swapConfig)
        internal
        returns (bytes32, IAdapter.OrderInfo memory, uint256)
    {
        _validateAdapter(swapConfig.adapter);

        address adapter = swapConfig.adapter;
        IAdapter.OrderInfo memory info = IAdapter(adapter).verifyLimitOrder(swapConfig, address(this));

        //reject byte-identical resubmissions.
        //@dev if you are hitting this, change salt or other fields to get a new hash
        if (approvedHashes[info.protocolHash]) revert BoringSwapper__DuplicateOrder();

        // Price Verification

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

        // Fee Logic

        //fees are earmarked for pickup at a later point, collected by a special role/contract that only picks up freed funds.
        uint256 limitFee;
        if (feeRegistry.limitFeeActive(address(this))) {
            uint16 feeBps = feeRegistry.getLimitFee(
                address(this), address(swapConfig.tokenRoute.tokenIn), address(swapConfig.tokenRoute.tokenOut)
            );
            if (feeBps > 0) {
                limitFee = info.inputAmount.mulDivUp(feeBps, 10_000);
                feesInToken[swapConfig.tokenRoute.tokenIn] += limitFee;
            }
        }

        // @dev !!! IMPORTANT !!!
        // vault must hold inputAmount + fee — strategist is responsible for leaving room for the fee!
        // use `getFee` on feeRegistry if you are swapping entire balances of a single token
        pendingOrderPrincipal[swapConfig.tokenRoute.tokenIn] += info.inputAmount;
        swapConfig.tokenRoute.tokenIn
            .safeTransferFrom(address(swapConfig.receiver), address(this), info.inputAmount + limitFee);

        // Order Hash Approval

        uint256 orderId = orders;
        orderRecords[orderId] = OrderRecord({
            tokenIn: swapConfig.tokenRoute.tokenIn,
            adapter: swapConfig.adapter,
            approvalTarget: info.approvalTarget,
            cancelTarget: info.cancelTarget,
            inputAmount: info.inputAmount,
            receiver: swapConfig.receiver,
            fee: limitFee,
            protocolHash: info.protocolHash,
            cancelledAt: 0,
            quoteAsset: swapConfig.quoteAsset,
            slippageBps: swapConfig.slippageBps
        });
        approvedHashes[info.protocolHash] = true;

        // Accumulate approval — multiple concurrent orders to the same approvalTarget must not
        // overwrite each other's allowance, so we add to the existing amount.
        uint256 newAllowance =
            swapConfig.tokenRoute.tokenIn.allowance(address(this), info.approvalTarget) + info.inputAmount;
        swapConfig.tokenRoute.tokenIn.safeApprove(info.approvalTarget, 0);
        swapConfig.tokenRoute.tokenIn.safeApprove(info.approvalTarget, newAllowance);

        orders += 1;

        bytes32 key = getRouteId(swapConfig.tokenRoute.tokenIn, swapConfig.tokenRoute.tokenOut);
        return (key, info, orderId);
    }

    function _validateAdapter(address adapter) internal view {
        if (isPaused) revert BoringSwapper__Paused();
        if (adapterPaused[adapter]) revert BoringSwapper__AdapterPaused();
        if (!adapterRegistry.registeredAdapters(adapter)) revert BoringSwapper__AdapterNotApproved();
        if (!approvedAdapters[adapter]) revert BoringSwapper__AdapterNotApproved();
    }

    /// @notice Consumes from the rate limit bucket for a route, normalizing the amount to 18 decimals.
    function _consumeRateLimit(bytes32 routeId, ERC20 tokenIn, uint256 amount) internal returns (bool) {
        RateLimit storage limit = rateLimitPerRoute[routeId];
        //if capacity is 0, rate limiting is disabled for this route
        if (limit.capacity == 0) return true;
        _refillBucket(limit);
        //normalize amount to 18 decimals
        uint256 normalized = (amount * 1e18) / (10 ** tokenIn.decimals());
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
