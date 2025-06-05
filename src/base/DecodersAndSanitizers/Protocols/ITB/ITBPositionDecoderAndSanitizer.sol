// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity ^0.8.0;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

// ITB Decoders
import {ExecutableDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ITB/common/ExecutableDecoderAndSanitizer.sol";
import {WithdrawableDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/ITB/common/WithdrawableDecoderAndSanitizer.sol";

contract ITBPositionDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    ExecutableDecoderAndSanitizer,
    WithdrawableDecoderAndSanitizer
{
//============================== HANDLE FUNCTION COLLISIONS ===============================
}
