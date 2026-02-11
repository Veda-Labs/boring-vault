// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {UManager, FixedPointMathLib, ManagerWithMerkleVerification, ERC20} from "src/micro-managers/UManager.sol";
import {BoringSwapper, SwapParams, QuoteAsset} from "src/base/Periphery/BoringSwapper.sol";
import {IPriceFeed} from "src/interfaces/IPriceFeed.sol";

/**
 * Required Merkle Root Leaves
 * - ERC20 approves with `boringSwapper` spender.
 * - BoringSwapper.swap(params), with all desired token paths.
 */
contract BoringSwapperUManager is UManager {
    using FixedPointMathLib for uint256;

    // ========================================= STRUCTS =========================================

    /**
     * @notice Per-strategist rate limit state with linear decay.
     * @param amountInFlight The amount (in quote terms) in the current window.
     * @param lastUpdated Timestamp of the last rate limit check or update.
     * @param limit Maximum allowed value (in quote terms) per window.
     * @param window Duration of the rate limiting window in seconds.
     */
    struct StrategistRateLimit {
        uint256 amountInFlight;
        uint256 lastUpdated;
        uint256 limit;
        uint256 window;
    }

    // ========================================= STATE =========================================

    mapping(address => StrategistRateLimit) public strategistRateLimits;

    //============================== ERRORS ===============================

    error BoringSwapperUManager__RateLimitExceeded();
    error BoringSwapperUManager__OracleNotConfigured();

    //============================== EVENTS ===============================

    event StrategistRateLimitSet(address indexed strategist, uint256 limit, uint256 window);

    //============================== IMMUTABLES ===============================

    BoringSwapper internal immutable boringSwapper;
    QuoteAsset internal immutable rateLimitQuoteAsset;

    constructor(
        address _owner,
        address _manager,
        address _boringVault,
        address _boringSwapper,
        QuoteAsset _rateLimitQuoteAsset
    ) UManager(_owner, _manager, _boringVault) {
        boringSwapper = BoringSwapper(payable(_boringSwapper));
        rateLimitQuoteAsset = _rateLimitQuoteAsset;
    }

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @notice Sets the rate limit for a strategist.
     * @dev Callable by MULTISIG_ROLE. Checkpoints existing state to avoid retroactive decay changes.
     */
    function setStrategistRateLimit(address strategist, uint256 limit, uint256 window) external requiresAuth {
        // Checkpoint the existing rate limit so we don't retroactively apply the new decay rate.
        _checkAndUpdateStrategistRateLimit(strategist, 0);

        StrategistRateLimit storage rl = strategistRateLimits[strategist];
        rl.limit = limit;
        rl.window = window;

        emit StrategistRateLimitSet(strategist, limit, window);
    }

    // ========================================= VIEW FUNCTIONS =========================================

    /**
     * @notice Returns the current in-flight amount and remaining capacity for a strategist.
     */
    function getStrategistAmountCanBeSwapped(address strategist)
        external
        view
        returns (uint256 currentAmountInFlight, uint256 amountCanBeSwapped)
    {
        StrategistRateLimit memory rl = strategistRateLimits[strategist];
        return _amountCanBeSwapped(rl.amountInFlight, rl.lastUpdated, rl.limit, rl.window);
    }

    // ========================================= SWAP =========================================

    /**
     * @notice Routes a swap through BoringSwapper with per-strategist amount-based rate limiting.
     * @param manageProofs Manage proofs: 1 proof if tokenIn is NATIVE (swap only), 2 proofs if ERC20 (approve + swap).
     * @param decodersAndSanitizers Decoders: 1 if tokenIn is NATIVE, 2 if ERC20.
     * @param swapParams The swap parameters to pass to BoringSwapper
     * @dev Callable by STRATEGIST_ROLE.
     */
    function swap(
        bytes32[][] calldata manageProofs,
        address[] calldata decodersAndSanitizers,
        SwapParams calldata swapParams
    ) external requiresAuth enforceRateLimit {
        // 1. Snapshot tokenOut balance before swap (NATIVE-aware).
        uint256 tokenOutBalanceBefore = _getBalance(swapParams.tokenOut);

        // 2. Build manage call arrays — branch on tokenIn == NATIVE.
        if (swapParams.tokenIn == boringSwapper.NATIVE()) {
            // No approve needed; single call with ETH value.
            address[] memory targets = new address[](1);
            bytes[] memory targetData = new bytes[](1);
            uint256[] memory values = new uint256[](1);
            targets[0] = address(boringSwapper);
            targetData[0] = abi.encodeWithSelector(BoringSwapper.swap.selector, swapParams);
            values[0] = swapParams.amountIn;

            manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        } else {
            // ERC20: approve + swap (2 proofs/decoders).
            address[] memory targets = new address[](2);
            bytes[] memory targetData = new bytes[](2);
            uint256[] memory values = new uint256[](2);

            targets[0] = swapParams.tokenIn;
            targetData[0] =
                abi.encodeWithSelector(ERC20.approve.selector, address(boringSwapper), swapParams.amountIn);

            targets[1] = address(boringSwapper);
            targetData[1] = abi.encodeWithSelector(BoringSwapper.swap.selector, swapParams);

            manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        }

        // 3. Measure actual output received and enforce per-strategist rate limit.
        uint256 amountOut = _getBalance(swapParams.tokenOut) - tokenOutBalanceBefore;
        uint256 normalizedValue = _getNormalizedValue(swapParams.tokenOut, amountOut);
        _checkAndUpdateStrategistRateLimit(msg.sender, normalizedValue);

        // 4. Revoke leftover approval if any remains (skip if tokenIn is NATIVE).
        if (swapParams.tokenIn != boringSwapper.NATIVE()) {
            if (ERC20(swapParams.tokenIn).allowance(boringVault, address(boringSwapper)) > 0) {
                bytes32[][] memory revokeProof = new bytes32[][](1);
                revokeProof[0] = manageProofs[0];
                address[] memory revokeDecoders = new address[](1);
                revokeDecoders[0] = decodersAndSanitizers[0];
                address[] memory targets = new address[](1);
                bytes[] memory targetData = new bytes[](1);
                uint256[] memory values = new uint256[](1);
                targets[0] = swapParams.tokenIn;
                targetData[0] = abi.encodeWithSelector(ERC20.approve.selector, address(boringSwapper), 0);

                manager.manageVaultWithMerkleVerification(revokeProof, revokeDecoders, targets, targetData, values);
            }
        }
    }

    // ========================================= HELPERS =========================================

    function _getBalance(address token) internal view returns (uint256) {
        if (token == boringSwapper.NATIVE()) return boringVault.balance;
        return ERC20(token).balanceOf(boringVault);
    }

    // ========================================= INTERNAL =========================================

    /**
     * @notice Converts amountOut of tokenOut to a normalized value in terms of rateLimitQuoteAsset.
     * @dev Uses BoringSwapper's oracle config to look up the price feed for the token.
     */
    function _getNormalizedValue(address tokenOut, uint256 amountOut) internal view returns (uint256) {
        (address usdOracle, address ethOracle, address btcOracle) = boringSwapper.tokenOracleConfigs(tokenOut);

        address oracle;
        if (rateLimitQuoteAsset == QuoteAsset.USD) oracle = usdOracle;
        else if (rateLimitQuoteAsset == QuoteAsset.ETH) oracle = ethOracle;
        else oracle = btcOracle;

        if (oracle == address(0)) revert BoringSwapperUManager__OracleNotConfigured();

        (uint256 price, uint8 oracleDecimals) = IPriceFeed(oracle).getPrice();
        if (price == 0) revert BoringSwapperUManager__OracleNotConfigured();

        uint8 tokenDecimals = tokenOut == boringSwapper.NATIVE() ? 18 : ERC20(tokenOut).decimals();

        // value = amountOut * price / 10^(tokenDecimals + oracleDecimals)
        return amountOut.mulDivDown(price, 10 ** (uint256(tokenDecimals) + uint256(oracleDecimals)));
    }

    /**
     * @notice Computes current in-flight amount and available capacity using linear decay.
     */
    function _amountCanBeSwapped(
        uint256 _amountInFlight,
        uint256 _lastUpdated,
        uint256 _limit,
        uint256 _window
    ) internal view returns (uint256 currentAmountInFlight, uint256 amountCanBeSwapped) {
        uint256 timeSinceLastUpdate = block.timestamp - _lastUpdated;
        if (timeSinceLastUpdate >= _window) {
            currentAmountInFlight = 0;
            amountCanBeSwapped = _limit;
        } else {
            uint256 decay = _limit.mulDivDown(timeSinceLastUpdate, _window);
            currentAmountInFlight = _amountInFlight <= decay ? 0 : _amountInFlight - decay;
            amountCanBeSwapped = _limit <= currentAmountInFlight ? 0 : _limit - currentAmountInFlight;
        }
    }

    /**
     * @notice Checks and updates the per-strategist rate limit.
     * @dev Reverts if amount exceeds available capacity. Pass amount=0 to checkpoint without consuming capacity.
     */
    function _checkAndUpdateStrategistRateLimit(address strategist, uint256 amount) internal {
        StrategistRateLimit storage rl = strategistRateLimits[strategist];

        (uint256 currentAmountInFlight, uint256 amountCanBeSwapped) =
            _amountCanBeSwapped(rl.amountInFlight, rl.lastUpdated, rl.limit, rl.window);
        if (amount > amountCanBeSwapped) revert BoringSwapperUManager__RateLimitExceeded();

        rl.amountInFlight = currentAmountInFlight + amount;
        rl.lastUpdated = block.timestamp;
    }
}
