// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {OdosDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/OdosDecoderAndSanitizer.sol";
import {OneInchDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OneInchDecoderAndSanitizer.sol";
import {CCTPDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CCTPDecoderAndSanitizer.sol";
import {SyrupDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SyrupDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {EthenaWithdrawDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/EthenaWithdrawDecoderAndSanitizer.sol";

contract SentoraUSDCMainnetDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    OdosDecoderAndSanitizer,
    OneInchDecoderAndSanitizer,
    CCTPDecoderAndSanitizer,
    SyrupDecoderAndSanitizer,
    ERC4626DecoderAndSanitizer,
    EthenaWithdrawDecoderAndSanitizer
{
    constructor(address _odosRouter)
        OdosDecoderAndSanitizer(_odosRouter)
    {}
}