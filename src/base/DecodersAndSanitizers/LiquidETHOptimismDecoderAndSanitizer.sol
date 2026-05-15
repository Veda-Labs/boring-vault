// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {CCTPDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CCTPDecoderAndSanitizer.sol";
import {StandardBridgeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/StandardBridgeDecoderAndSanitizer.sol";
import {TellerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol";
import {NativeWrapperDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol";
import {EtherFiDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/EtherFiDecoderAndSanitizer.sol";


contract LiquidETHOptimismDecoderAndSanitizer is 
    BaseDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    CCTPDecoderAndSanitizer,
    StandardBridgeDecoderAndSanitizer,
    TellerDecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer,
    EtherFiDecoderAndSanitizer
{
   function deposit() external pure override (EtherFiDecoderAndSanitizer, NativeWrapperDecoderAndSanitizer) returns (bytes memory addressesFound) {
        return addressesFound;
    }
}
