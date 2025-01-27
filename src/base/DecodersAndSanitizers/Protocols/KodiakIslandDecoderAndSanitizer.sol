// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";


abstract contract KodiakIslandDecoderAndSanitizer is BaseDecoderAndSanitizer {

    function addLiquidity(
        address island,     // Address of the Kodiak Island
        uint256 /*amount0Max*/,       // Maximum amount of token0 willing to deposit
        uint256 /*amount1Max*/,       // Maximum amount of token1 willing to deposit
        uint256 /*amount0Min*/,       // Minimum acceptable token0 deposit (slippage protection)
        uint256 /*amount1Min*/,       // Minimum acceptable token1 deposit (slippage protection)
        uint256 /*amountSharesMin*/,  // Minimum IslandTokens to receive
        address receiver          // Address to receive LP tokens
    ) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(island, receiver); 
    }

    function addLiquidityNative(
        address island,     // Address of the Kodiak Island
        uint256 /*amount0Max*/,       // Maximum BERA amount
        uint256 /*amount1Max*/,       // Maximum token amount
        uint256 /*amount0Min*/,       // Minimum BERA deposit
        uint256 /*amount1Min*/,       // Minimum token deposit
        uint256 /*amountSharesMin*/,  // Minimum LP tokens to receive
        address receiver          // Address to receive LP tokens
    ) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(island, receiver); 
    }
    
    function removeLiquidity(
        address island,
        uint256 /*burnAmount*/,
        uint256 /*amount0Min*/,
        uint256 /*amount1Min*/,
        address receiver
    ) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(island, receiver); 
    }

    function removeLiquidityNative(
        address island,
        uint256 /*burnAmount*/,
        uint256 /*amount0Min*/,
        uint256 /*amount1Min*/,
        address payable receiver
    ) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(island, receiver); 
    }
}
