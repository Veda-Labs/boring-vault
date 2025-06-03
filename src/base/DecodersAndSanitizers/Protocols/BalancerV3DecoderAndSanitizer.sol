// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {Permit2DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/Permit2DecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {CurveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CurveDecoderAndSanitizer.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract BalancerV3DecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    Permit2DecoderAndSanitizer,
    ERC4626DecoderAndSanitizer,
    CurveDecoderAndSanitizer
{
    //============================== ERRORS ===============================

    error BalancerV3DecoderAndSanitizer__UserDataLengthNonZero();

    //============================== Function Collisions ===============================

    function deposit(uint256, /*amount*/ address receiver)
        external
        pure
        virtual
        override(ERC4626DecoderAndSanitizer, CurveDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver);
    }

    // Router
    // Add Liquidity
    function addLiquidityProportional(
        address pool,
        uint256[] memory, /*maxAmountsIn*/
        uint256, /*exactBptAmountOut*/
        bool, /*wethIsEth*/
        bytes memory userData
    ) external pure virtual returns (bytes memory addressesFound) {
        if (userData.length > 0) revert BalancerV3DecoderAndSanitizer__UserDataLengthNonZero();
        addressesFound = abi.encodePacked(pool);
    }

    function addLiquidityUnbalanced(
        address pool,
        uint256[] memory, /*exactAmountsIn*/
        uint256, /*minBptAmountOut*/
        bool, /*wethIsEth*/
        bytes memory userData
    ) external pure virtual returns (bytes memory addressesFound) {
        if (userData.length > 0) revert BalancerV3DecoderAndSanitizer__UserDataLengthNonZero();
        addressesFound = abi.encodePacked(pool);
    }

    // if the pool is sanitized, presumably we are fine with any of the tokens being exact out, so there is no need to sanitize this address
    // and we are able to save leaf space
    function addLiquiditySingleTokenExactOut(
        address pool,
        address, /*tokenIn*/
        uint256, /*maxAmountIn*/
        uint256, /*exactBptAmountOut*/
        bool, /*wethIsEth*/
        bytes memory userData
    ) external pure virtual returns (bytes memory addressesFound) {
        if (userData.length > 0) revert BalancerV3DecoderAndSanitizer__UserDataLengthNonZero();
        addressesFound = abi.encodePacked(pool);
    }

    function addLiquidityCustom(
        address pool,
        uint256[] memory, /*maxAmountsIn*/
        uint256, /*minBptAmountOut*/
        bool, /*wethIsEth*/
        bytes memory userData
    ) external pure virtual returns (bytes memory addressesFound) {
        if (userData.length > 0) revert BalancerV3DecoderAndSanitizer__UserDataLengthNonZero();
        addressesFound = abi.encodePacked(pool);
    }

    // Remove Liquidity
    function removeLiquidityProportional(
        address pool,
        uint256, /*exactBptAmountIn*/
        uint256[] memory, /*minAmountsOut*/
        bool, /*wethIsEth*/
        bytes memory userData
    ) external pure virtual returns (bytes memory addressesFound) {
        if (userData.length > 0) revert BalancerV3DecoderAndSanitizer__UserDataLengthNonZero();
        addressesFound = abi.encodePacked(pool);
    }

    function removeLiquiditySingleTokenExactIn(
        address pool,
        uint256, /*exactBptAmountIn*/
        address, /*tokenOut*/
        uint256, /*minAmountOut*/
        bool, /*wethIsEth*/
        bytes memory userData
    ) external pure virtual returns (bytes memory addressesFound) {
        if (userData.length > 0) revert BalancerV3DecoderAndSanitizer__UserDataLengthNonZero();
        addressesFound = abi.encodePacked(pool);
    }

    function removeLiquiditySingleTokenExactOut(
        address pool,
        uint256, /*maxBptAmountIn*/
        address, /*tokenOut*/
        uint256, /*exactAmountOut*/
        bool, /*wethIsEth*/
        bytes memory userData
    ) external pure virtual returns (bytes memory addressesFound) {
        if (userData.length > 0) revert BalancerV3DecoderAndSanitizer__UserDataLengthNonZero();
        addressesFound = abi.encodePacked(pool);
    }

    function removeLiquidityCustom(
        address pool,
        uint256, /*maxBptAmountIn*/
        uint256[] memory, /*minAmountsOut*/
        bool, /*wethIsEth*/
        bytes memory userData
    ) external pure virtual returns (bytes memory addressesFound) {
        if (userData.length > 0) revert BalancerV3DecoderAndSanitizer__UserDataLengthNonZero();
        addressesFound = abi.encodePacked(pool);
    }

    function removeLiquidityRecovery(address pool, uint256, /*exactBptAmountIn*/ uint256[] memory /*minAmountsOut*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(pool);
    }

    // Swaps
    function swapSingleTokenExactIn(
        address pool,
        address, /*tokenIn*/
        address, /*tokenOut*/
        uint256, /*exactAmountIn*/
        uint256, /*minAmountOut*/
        uint256, /*deadline*/
        bool, /*wethIsEth*/
        bytes calldata userData
    ) external pure virtual returns (bytes memory addressesFound) {
        if (userData.length > 0) revert BalancerV3DecoderAndSanitizer__UserDataLengthNonZero();
        addressesFound = abi.encodePacked(pool);
    }

    function swapSingleTokenExactOut(
        address pool,
        address, /*tokenIn*/
        address, /*tokenOut*/
        uint256, /*exactAmountOut*/
        uint256, /*maxAmountIn*/
        uint256, /*deadline*/
        bool, /*wethIsEth*/
        bytes calldata userData
    ) external pure virtual returns (bytes memory addressesFound) {
        if (userData.length > 0) revert BalancerV3DecoderAndSanitizer__UserDataLengthNonZero();
        addressesFound = abi.encodePacked(pool);
    }
}
