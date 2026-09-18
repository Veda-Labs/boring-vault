// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
// Last audited: boring-vault-fixes@0816dda2622b051d1a417d9a9a093fe6cbebbd49 — file:audit/0xmacro-veda-103.pdf
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {DirectPropAMMDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/DirectPropAMMDecoderAndSanitizer.sol";

/// @notice Deployable decoder for the Tempo DirectPropAMM direct strategist path.
/// @dev BaseDecoderAndSanitizer supplies `approve(address,uint256)` for the pair-token allowance leaves
///      and the fallback that reverts on any selector not mirrored here.
contract TempoDirectPropAMMDecoderAndSanitizer is BaseDecoderAndSanitizer, DirectPropAMMDecoderAndSanitizer {}
