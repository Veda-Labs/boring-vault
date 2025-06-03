// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract UniswapV2DecoderAndSanitizer {
    //============================== ERRORS ===============================
    error UniswapV2DecoderAndSanitizer__PathTooLong();

    //Decoder and Sanitizer will only direct swaps between tokenA/tokenB
    function swapExactTokensForTokens(
        uint256, /*amountIn*/
        uint256, /*amountOutMin*/
        address[] calldata path,
        address to,
        uint256 /*deadline*/
    ) external pure returns (bytes memory addressesFound) {
        if (path.length > 2) revert UniswapV2DecoderAndSanitizer__PathTooLong();
        addressesFound = abi.encodePacked(path[0], path[1], to);
    }

    function swapTokensForExactTokens(
        uint256, /*amountOut*/
        uint256, /*amountInMax*/
        address[] calldata path,
        address to,
        uint256 /*deadline*/
    ) external pure returns (bytes memory addressesFound) {
        if (path.length > 2) revert UniswapV2DecoderAndSanitizer__PathTooLong();
        addressesFound = abi.encodePacked(path[0], path[1], to);
    }

    function swapExactETHForTokens(uint256, /*amountOutMin*/ address[] calldata path, address to, uint256 /*deadline*/ )
        external
        pure
        returns (bytes memory addressesFound)
    {
        if (path.length > 2) revert UniswapV2DecoderAndSanitizer__PathTooLong();
        addressesFound = abi.encodePacked(path[0], path[1], to);
    }

    function swapExactTokensForETH(
        uint256, /*amountIn*/
        uint256, /*amountOutMin*/
        address[] calldata path,
        address to,
        uint256 /*deadline*/
    ) external pure returns (bytes memory addressesFound) {
        if (path.length > 2) revert UniswapV2DecoderAndSanitizer__PathTooLong();
        addressesFound = abi.encodePacked(path[0], path[1], to);
    }

    function swapTokensForExactETH(
        uint256, /*amountOut*/
        uint256, /*amountInMax*/
        address[] calldata path,
        address to,
        uint256 /*deadline*/
    ) external pure returns (bytes memory addressesFound) {
        if (path.length > 2) revert UniswapV2DecoderAndSanitizer__PathTooLong();
        addressesFound = abi.encodePacked(path[0], path[1], to);
    }

    function swapETHForExactTokens(uint256, /*amountOut*/ address[] calldata path, address to, uint256 /*deadline*/ )
        external
        pure
        returns (bytes memory addressesFound)
    {
        if (path.length > 2) revert UniswapV2DecoderAndSanitizer__PathTooLong();
        addressesFound = abi.encodePacked(path[0], path[1], to);
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256, /*amountADesired*/
        uint256, /*amountBDesired*/
        uint256, /*amountAMin*/
        uint256, /*amountBMin*/
        address to,
        uint256 /*deadline*/
    ) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(tokenA, tokenB, to);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256, /*liquidity*/
        uint256, /*amountAMin*/
        uint256, /*amountBMin*/
        address to,
        uint256 /*deadline*/
    ) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(tokenA, tokenB, to);
    }

    function addLiquidityETH(
        address token,
        uint256, /*amountTokenDesired*/
        uint256, /*amountTokenMin*/
        uint256, /*amountETHMin*/
        address to,
        uint256 /*deadline*/
    ) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(token, to);
    }

    function removeLiquidityETH(
        address token,
        uint256, /*liquidity*/
        uint256, /*amountAMin*/
        uint256, /*amountETHMin*/
        address to,
        uint256 /*deadline*/
    ) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(token, to);
    }
}
