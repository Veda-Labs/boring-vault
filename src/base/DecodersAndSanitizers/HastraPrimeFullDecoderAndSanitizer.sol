// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
// Last audited: boring-vault-fixes@40627627d0e68e8a5361f82e6fddaecedd357876 — file:audit/0xmacro-veda-106.pdf
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {HastraPrimeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/HastraPrimeDecoderAndSanitizer.sol";

contract HastraPrimeFullDecoderAndSanitizer is BaseDecoderAndSanitizer, HastraPrimeDecoderAndSanitizer {}
