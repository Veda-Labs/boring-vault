// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {Permit2DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/Permit2DecoderAndSanitizer.sol";

contract GlueXDecoderAndSanitizer is Permit2DecoderAndSanitizer {

    function swap(
        address executor,
        DecoderCustomTypes.RouteDescription calldata desc,
        DecoderCustomTypes.Interaction[] calldata /*interactions*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(
            executor, 
            desc.inputToken, 
            desc.outputToken, 
            desc.outputReceiver,
            desc.partnerAddress
        ); 
    }
}
