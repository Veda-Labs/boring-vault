// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract ElixirClaimingDecoderAndSanitizer is BaseDecoderAndSanitizer {

    function claim(uint256 /*_amount*/, bytes32[] calldata /*_merkleProof*/, bytes calldata /*_signature*/) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound; 
    }
}
