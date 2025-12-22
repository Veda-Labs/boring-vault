// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { BaseDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import { CCIPDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/CCIPDecoderAndSanitizer.sol";
import {
    ArbitrumNativeBridgeDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/ArbitrumNativeBridgeDecoderAndSanitizer.sol";
import { OFTDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {
    StandardBridgeDecoderAndSanitizer,
    DecoderCustomTypes
} from "src/base/DecodersAndSanitizers/Protocols/StandardBridgeDecoderAndSanitizer.sol";
import {
    MantleStandardBridgeDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/MantleStandardBridgeDecoderAndSanitizer.sol";
import {
    LineaBridgeDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/LineaBridgeDecoderAndSanitizer.sol";
import {
    ScrollBridgeDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/ScrollBridgeDecoderAndSanitizer.sol";
import {
    LidoStandardBridgeDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/LidoStandardBridgeDecoderAndSanitizer.sol";
import {
    HyperlaneDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/HyperlaneDecoderAndSanitizer.sol";

contract BridgingDecoderAndSanitizer is
    ArbitrumNativeBridgeDecoderAndSanitizer,
    CCIPDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    StandardBridgeDecoderAndSanitizer,
    MantleStandardBridgeDecoderAndSanitizer,
    LineaBridgeDecoderAndSanitizer,
    ScrollBridgeDecoderAndSanitizer,
    LidoStandardBridgeDecoderAndSanitizer,
    HyperlaneDecoderAndSanitizer,
    BaseDecoderAndSanitizer
{
    //============================== HANDLE FUNCTION COLLISIONS ===============================

    function proveWithdrawalTransaction(
        DecoderCustomTypes.WithdrawalTransaction calldata _tx,
        uint256, /*_l2OutputIndex*/
        DecoderCustomTypes.OutputRootProof calldata, /*_outputRootProof*/
        bytes[] calldata /*_withdrawalProof*/
    )
        external
        pure
        override (StandardBridgeDecoderAndSanitizer, LidoStandardBridgeDecoderAndSanitizer)
        returns (bytes memory sensitiveArguments)
    {
        sensitiveArguments = abi.encodePacked(_tx.sender, _tx.target);
    }

    function finalizeWithdrawalTransaction(DecoderCustomTypes.WithdrawalTransaction calldata _tx)
        external
        pure
        override (StandardBridgeDecoderAndSanitizer, LidoStandardBridgeDecoderAndSanitizer)
        returns (bytes memory sensitiveArguments)
    {
        sensitiveArguments = abi.encodePacked(_tx.sender, _tx.target);
    }
}
