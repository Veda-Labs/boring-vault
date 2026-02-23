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

enum QuoteAsset { USD, ETH, BTC }

struct SwapParams {
    address tokenIn;
    address tokenOut;
    uint256 amountIn;
    uint256 minAmountOut;
    address receiver;
    address target;
    bytes swapData;
    bool useOracle;
    QuoteAsset quoteAsset;
    uint256 maxSlippageBps;
}

contract BoringSwapper is Auth, ReentrancyGuard {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    // ========================================= STRUCTS =========================================

    struct TokenOracleConfig {
        address usdOracle;
        address ethOracle;
        address btcOracle;
    }

    // ========================================= STATE =========================================

    address public immutable NATIVE;

    mapping(address token => TokenOracleConfig config) public tokenOracleConfigs;
    mapping(address => bool) public approvedTargets;

    uint256 public maxSlippageCeilingBps;
    uint256 public maxSwapAmountNormalized;

    // ========================================= EVENTS =========================================

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

    // ========================================= ERRORS =========================================

    error BoringSwapper__SwapFailed();
    error BoringSwapper__SlippageExceeded();
    error BoringSwapper__NativeTransferFailed();
    error BoringSwapper__NoSlippageProtection();
    error BoringSwapper__TargetNotApproved();
    error BoringSwapper__OracleNotConfigured();
    error BoringSwapper__NotEnoughNative();
    error BoringSwapper__SlippageExceedsCeiling();
    error BoringSwapper__SwapAmountExceedsMax();

    // ========================================= CONSTRUCTOR =========================================

    constructor(address _NATIVE, address _owner, Authority _auth) Auth(_owner, _auth) {
        NATIVE = _NATIVE;
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
        if (_maxSlippageCeilingBps >= 10_000) revert BoringSwapper__NoSlippageProtection();
        maxSlippageCeilingBps = _maxSlippageCeilingBps;
        emit MaxSlippageCeilingBpsUpdated(_maxSlippageCeilingBps);
    }

    function setMaxSwapAmountNormalized(uint256 _maxSwapAmountNormalized) external requiresAuth {
        maxSwapAmountNormalized = _maxSwapAmountNormalized;
        emit MaxSwapAmountNormalizedUpdated(_maxSwapAmountNormalized);
    }

    // ========================================= EXTERNAL/PUBLIC FUNCTIONS =========================================

    function swap(SwapParams calldata params) public payable virtual requiresAuth nonReentrant {
        _validateSwap(params);
        uint256 minRequired = _resolveMinOut(params);
        _executeSwap(params, minRequired);
    }

    // ========================================= VIEW FUNCTIONS =========================================
    
    function version() external view returns (string memory) {
        return "V0.1"; 
    }

    // ========================================= INTERNAL =========================================

    function _executeSwap(SwapParams calldata params, uint256 minRequired) internal virtual {
        uint256 outBefore = _balanceOf(params.tokenOut);

        if (params.tokenIn == NATIVE) {
         if (msg.value != params.amountIn) revert BoringSwapper__NotEnoughNative();
        } else {
            ERC20(params.tokenIn).safeTransferFrom(msg.sender, address(this), params.amountIn);
            ERC20(params.tokenIn).approve(params.target, params.amountIn);
        }

        (bool success,) = params.target.call{value: params.tokenIn == NATIVE ? params.amountIn : 0}(params.swapData);
        if (!success) revert BoringSwapper__SwapFailed();

        uint256 amountOut = _balanceOf(params.tokenOut) - outBefore;
        if (amountOut < minRequired) revert BoringSwapper__SlippageExceeded();

        // Clear approvals
        if (params.tokenIn != NATIVE) ERC20(params.tokenIn).approve(params.target, 0);

        // Send output tokens
        if (params.tokenOut != NATIVE) {
            ERC20(params.tokenOut).safeTransfer(params.receiver, amountOut);
        } else {
            (bool sent,) = params.receiver.call{value: amountOut}("");
            if (!sent) revert BoringSwapper__NativeTransferFailed();
        }

        // Return dust
        uint256 remainingIn = _balanceOf(params.tokenIn);
        if (remainingIn > 0) {
            if (params.tokenIn != NATIVE) {
                ERC20(params.tokenIn).safeTransfer(msg.sender, remainingIn);
            } else {
                (bool sent,) = msg.sender.call{value: remainingIn}("");
                if (!sent) revert BoringSwapper__NativeTransferFailed();
            }
        }

        emit Swap(params.tokenIn, params.tokenOut, params.amountIn, amountOut, params.target);
    }

    // ========================================= INTERNAL VIEW/PURE =========================================

    function _validateSwap(SwapParams calldata params) internal view virtual {
        if (!approvedTargets[params.target]) revert BoringSwapper__TargetNotApproved();
        if (maxSlippageCeilingBps > 0 && params.maxSlippageBps > maxSlippageCeilingBps) {
            revert BoringSwapper__SlippageExceedsCeiling();
        }
        if (maxSwapAmountNormalized > 0) {
            uint256 normalized = _getNormalizedValue(params.tokenIn, params.amountIn, params.quoteAsset);
            if (normalized > maxSwapAmountNormalized) revert BoringSwapper__SwapAmountExceedsMax();
        }
    }

    function _resolveMinOut(SwapParams calldata params) internal view virtual returns (uint256) {
        if (params.useOracle) return _calculateMinOut(params);
        if (params.minAmountOut == 0) revert BoringSwapper__NoSlippageProtection();
        return params.minAmountOut;
    }

    function _balanceOf(address token) internal view returns (uint256) {
        if (token == NATIVE) return address(this).balance;
        return ERC20(token).balanceOf(address(this));
    }

    function _calculateMinOut(SwapParams calldata params) internal view returns (uint256) {
        if (params.maxSlippageBps >= 10_000) revert BoringSwapper__NoSlippageProtection();
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
        if (oracleIn == address(0) || oracleOut == address(0)) revert BoringSwapper__OracleNotConfigured();

        // expectedOut = amountIn * priceIn * 10^decimalsOut * 10^oracleDecimalsOut
        //             / (priceOut * 10^decimalsIn * 10^oracleDecimalsIn)
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

    function _getNormalizedValue(address token, uint256 amount, QuoteAsset quoteAsset) internal view returns (uint256) {
        address oracle = _getOracle(token, quoteAsset);
        if (oracle == address(0)) revert BoringSwapper__OracleNotConfigured();

        (uint256 price, uint8 oracleDecimals) = IPriceFeed(oracle).getPrice();
        uint8 tokenDecimals = token == NATIVE ? 18 : ERC20(token).decimals();

        return amount.mulDivDown(price, 10 ** (uint256(tokenDecimals) + uint256(oracleDecimals)));
    }
}
