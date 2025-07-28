// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {SonicGatewayDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SonicGatewayDecoderAndSanitizer.sol"; 
import {OdosDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OdosDecoderAndSanitizer.sol"; 
import {AaveV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AaveV3DecoderAndSanitizer.sol"; 
import {SiloDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SiloDecoderAndSanitizer.sol"; 
import {MerklDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MerklDecoderAndSanitizer.sol"; 
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol"; 
import {NativeWrapperDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol"; 
import {CCTPDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CCTPDecoderAndSanitizer.sol";

contract SonicVaultDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    SonicGatewayDecoderAndSanitizer,
    OdosDecoderAndSanitizer,
    AaveV3DecoderAndSanitizer,
    SiloDecoderAndSanitizer,
    MerklDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer,
    CCTPDecoderAndSanitizer
{
    constructor(address _odosRouter) OdosDecoderAndSanitizer(_odosRouter){} 
}
