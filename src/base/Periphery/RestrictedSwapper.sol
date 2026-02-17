// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ReentrancyGuard} from "@solmate/utils/ReentrancyGuard.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {IPriceFeed} from "src/interfaces/IPriceFeed.sol";
import {SwapParams, QuoteAsset} from "src/base/Periphery/BoringSwapper.sol";

contract RestrictedSwapper is Auth, ReentrancyGuard {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    // ========================================= STRUCTS =========================================

    struct TokenOracleConfig {
        address usdOracle;
        address ethOracle;
        address btcOracle;
    }

    // ========================================= STATE =========================================

    mapping(address token => TokenOracleConfig config) public tokenOracleConfigs;
    mapping(address => bool) public approvedTargets;

    uint256 public maxSlippageCeilingBps;
    uint256 public maxSwapAmountNormalized;

    //============================== ERRORS ===============================

    error RestrictedSwapper__SwapFailed();
    error RestrictedSwapper__SlippageExceeded();
    error RestrictedSwapper__NativeTransferFailed();
    error RestrictedSwapper__NoSlippageProtection();
    error RestrictedSwapper__TargetNotApproved();
    error RestrictedSwapper__OracleNotConfigured();
    error RestrictedSwapper__NotEnoughNative();
    error RestrictedSwapper__SlippageExceedsCeiling();
    error RestrictedSwapper__SwapAmountExceedsMax();
    error RestrictedSwapper__MaxSlippageCeilingNotSet();
    error RestrictedSwapper__MaxSwapAmountNotSet();

    //============================== EVENTS ===============================

    event Swap(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address target
    );
    event TargetApprovalUpdated(address indexed target, bool approved);
    event TokenOracleConfigUpdated(address indexed token);
    event MaxSlippageCeilingBpsUpdated(uint256 maxSlippageCeilingBps);
    event MaxSwapAmountNormalizedUpdated(uint256 maxSwapAmountNormalized);

    //============================== IMMUTABLES ===============================

    address public immutable NATIVE;
    QuoteAsset public immutable normalizeQuoteAsset;

    constructor(
        address _NATIVE,
        address _owner,
        Authority _auth,
        QuoteAsset _normalizeQuoteAsset
    ) Auth(_owner, _auth) {
        NATIVE = _NATIVE;
        normalizeQuoteAsset = _normalizeQuoteAsset;
    }

    receive() external payable {}

    // ========================================= ADMIN FUNCTIONS =========================================

    function setApprovedTarget(address target, bool approved) external requiresAuth {
        approvedTargets[target] = approved;
        emit TargetApprovalUpdated(target, approved);
    }

    function setTokenOracleConfig(address token, TokenOracleConfig calldata config) external requiresAuth {
        tokenOracleConfigs[token] = config;
        emit TokenOracleConfigUpdated(token);
    }

    function setMaxSlippageCeilingBps(uint256 _maxSlippageCeilingBps) external requiresAuth {
        if (_maxSlippageCeilingBps >= 10_000) revert RestrictedSwapper__NoSlippageProtection();
        maxSlippageCeilingBps = _maxSlippageCeilingBps;
        emit MaxSlippageCeilingBpsUpdated(_maxSlippageCeilingBps);
    }

    function setMaxSwapAmountNormalized(uint256 _maxSwapAmountNormalized) external requiresAuth {
        maxSwapAmountNormalized = _maxSwapAmountNormalized;
        emit MaxSwapAmountNormalizedUpdated(_maxSwapAmountNormalized);
    }

    // ========================================= SWAP =========================================

    function swap(SwapParams calldata params) public payable requiresAuth nonReentrant {
        if (!approvedTargets[params.target]) revert RestrictedSwapper__TargetNotApproved();
        if (maxSlippageCeilingBps == 0) revert RestrictedSwapper__MaxSlippageCeilingNotSet();
        if (maxSwapAmountNormalized == 0) revert RestrictedSwapper__MaxSwapAmountNotSet();
        if (params.maxSlippageBps > maxSlippageCeilingBps) revert RestrictedSwapper__SlippageExceedsCeiling();

        //always use oracle (ignore params.useOracle)
        uint256 minRequired = _calculateMinOut(params);

        //normalize amountIn and check against max
        uint256 normalizedAmountIn = _getNormalizedValue(params.tokenIn, params.amountIn);
        if (normalizedAmountIn > maxSwapAmountNormalized) revert RestrictedSwapper__SwapAmountExceedsMax();

        uint256 outBefore = _balanceOf(params.tokenOut);

        if (params.tokenIn == NATIVE) {
            if (msg.value != params.amountIn) revert RestrictedSwapper__NotEnoughNative();
        } else {
            ERC20(params.tokenIn).safeTransferFrom(msg.sender, address(this), params.amountIn);
            ERC20(params.tokenIn).approve(params.target, params.amountIn);
        }

        (bool success,) = params.target.call{value: params.tokenIn == NATIVE ? params.amountIn : 0}(params.swapData);
        if (!success) revert RestrictedSwapper__SwapFailed();

        uint256 amountOut = _balanceOf(params.tokenOut) - outBefore;
        if (amountOut < minRequired) revert RestrictedSwapper__SlippageExceeded();

        //clear any approvals
        if (params.tokenIn != NATIVE) ERC20(params.tokenIn).approve(params.target, 0);

        //send output tokens
        if (params.tokenOut != NATIVE) {
            ERC20(params.tokenOut).safeTransfer(params.receiver, amountOut);
        } else {
            (bool sent,) = params.receiver.call{value: amountOut}("");
            if (!sent) revert RestrictedSwapper__NativeTransferFailed();
        }

        //return dust
        uint256 remainingIn = _balanceOf(params.tokenIn);
        if (remainingIn > 0) {
            if (params.tokenIn != NATIVE) {
                ERC20(params.tokenIn).safeTransfer(msg.sender, remainingIn);
            } else {
                (bool sent,) = msg.sender.call{value: remainingIn}("");
                if (!sent) revert RestrictedSwapper__NativeTransferFailed();
            }
        }

        emit Swap(params.tokenIn, params.tokenOut, params.amountIn, amountOut, params.target);
    }

    // ========================================= HELPERS =========================================

    function _balanceOf(address token) internal view returns (uint256) {
        if (token == NATIVE) return address(this).balance;
        return ERC20(token).balanceOf(address(this));
    }

    function _calculateMinOut(SwapParams calldata params) internal view returns (uint256) {
        if (params.maxSlippageBps >= 10_000) revert RestrictedSwapper__NoSlippageProtection();
        (uint256 numerator, uint256 denominator) = _getOracleQuote(
            params.tokenIn, params.tokenOut, params.amountIn, params.quoteAsset
        );
        return numerator.mulDivDown(10_000 - params.maxSlippageBps, denominator * 10_000);
    }

    function _getOracleQuote(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        QuoteAsset quoteAsset
    ) internal view returns (uint256 numerator, uint256 denominator) {
        address oracleIn = _getOracle(tokenIn, quoteAsset);
        address oracleOut = _getOracle(tokenOut, quoteAsset);
        if (oracleIn == address(0) || oracleOut == address(0)) revert RestrictedSwapper__OracleNotConfigured();

        {
            (uint256 priceIn,) = IPriceFeed(oracleIn).getPrice();
            (uint256 priceOut, uint8 oracleDecimalsOut) = IPriceFeed(oracleOut).getPrice();
            uint8 decimalsOut = tokenOut == NATIVE ? 18 : ERC20(tokenOut).decimals();
            numerator = amountIn.mulDivDown(priceIn, priceOut) * (10 ** decimalsOut) * (10 ** oracleDecimalsOut);
        }
        {
            (, uint8 oracleDecimalsIn) = IPriceFeed(oracleIn).getPrice();
            uint8 decimalsIn = tokenIn == NATIVE ? 18 : ERC20(tokenIn).decimals();
            denominator = (10 ** decimalsIn) * (10 ** oracleDecimalsIn);
        }
    }

    function _getOracle(address token, QuoteAsset quoteAsset) internal view returns (address) {
        TokenOracleConfig storage config = tokenOracleConfigs[token];
        if (quoteAsset == QuoteAsset.USD) return config.usdOracle;
        if (quoteAsset == QuoteAsset.ETH) return config.ethOracle;
        return config.btcOracle;
    }

    function _getNormalizedValue(address token, uint256 amount) internal view returns (uint256) {
        address oracle = _getOracle(token, normalizeQuoteAsset);
        if (oracle == address(0)) revert RestrictedSwapper__OracleNotConfigured();

        (uint256 price, uint8 oracleDecimals) = IPriceFeed(oracle).getPrice();
        uint8 tokenDecimals = token == NATIVE ? 18 : ERC20(token).decimals();

        return amount.mulDivDown(price, 10 ** (uint256(tokenDecimals) + uint256(oracleDecimals)));
    }
}
