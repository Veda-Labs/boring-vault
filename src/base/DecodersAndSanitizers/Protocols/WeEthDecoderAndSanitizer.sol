// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract WeETHDecoderAndSanitizer {
    //add the registry to check for whitelisted assets?
    function deposit(
        address tokenIn,
        uint256,
        /*amountIn*/
        uint256,
        /*minAmountOut*/
        address referral
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(tokenIn, referral);
    }
}
