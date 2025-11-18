// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract RedSnwapperDecoderAndSanitizer {

    function snwap(
        address tokenIn,
        uint256 /*amountIn*/,
        address recipient,
        address tokenOut,
        uint256 /*amountOutMin*/,
        address executor,
        bytes calldata /*executorData*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(tokenIn, recipient, tokenOut, executor); 
    } 

}
