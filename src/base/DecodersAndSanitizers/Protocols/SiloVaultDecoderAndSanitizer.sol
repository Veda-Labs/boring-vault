// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";

contract SiloVaultDecoderAndSanitizer is ERC4626DecoderAndSanitizer {
    function claimRewards() external pure virtual returns (bytes memory addressesFound) {
        //nothing to sanitize
        return addressesFound;
    }
}
