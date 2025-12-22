// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {TreehouseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TreehouseDecoderAndSanitizer.sol";
import {CurveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CurveDecoderAndSanitizer.sol";

contract OnlyTreehouseDecoderAndSanitizer is
    TreehouseDecoderAndSanitizer,
    CurveDecoderAndSanitizer,
    BaseDecoderAndSanitizer
{
    //============================== HANDLE FUNCTION COLLISIONS ===============================

    }
