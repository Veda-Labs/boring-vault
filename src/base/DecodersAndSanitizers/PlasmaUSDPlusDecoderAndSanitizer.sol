// SPDX-License-Identifier: SEL-1.0
// Last audited: boring-vault@4c9c671bb965899728167102a0e3ac22f4aabf7a — https://macroaudits.com/library/audits/sevenSeas-39
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {OneInchDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OneInchDecoderAndSanitizer.sol";
import {OdosDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OdosDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {EthenaWithdrawDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/EthenaWithdrawDecoderAndSanitizer.sol";
import {TellerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol";

contract PlasmaUSDPlusDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    ERC4626DecoderAndSanitizer,
    OneInchDecoderAndSanitizer,
    OdosDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    EthenaWithdrawDecoderAndSanitizer,
    TellerDecoderAndSanitizer
{
    constructor(address _odosRouter) OdosDecoderAndSanitizer(_odosRouter) {}
}
