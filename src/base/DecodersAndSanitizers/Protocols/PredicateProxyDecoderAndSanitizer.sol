// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract PredicateProxyDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== PREDICATE PROXY ===============================

    function deposit(
        address depositAsset,
        uint256, /*depositAmount*/
        uint256, /*minimumMint*/
        address recipient,
        address teller,
        DecoderCustomTypes.PredicateMessage calldata /*predicateMessage*/
    ) external pure returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(depositAsset, recipient, teller);
    }
}
