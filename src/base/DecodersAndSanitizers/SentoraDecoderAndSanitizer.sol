// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {
    ITBBasePositionDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/ITB/ITBBasePositionDecoderAndSanitizer.sol";
import { OdosDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/OdosDecoderAndSanitizer.sol";
import { OneInchDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/OneInchDecoderAndSanitizer.sol";

contract SentoraDecoderAndSanitizer is
    ITBBasePositionDecoderAndSanitizer,
    OdosDecoderAndSanitizer,
    OneInchDecoderAndSanitizer
{
    constructor(address _odosRouter) OdosDecoderAndSanitizer(_odosRouter) { }
}
