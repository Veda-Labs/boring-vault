// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {
    BaseDecoderAndSanitizer,
    DecoderCustomTypes
} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {
    StandardBridgeDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/StandardBridgeDecoderAndSanitizer.sol";
import {
    UniswapV4DecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/UniswapV4DecoderAndSanitizer.sol";
import {
    NativeWrapperDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol";
import {
    LidoStandardBridgeDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/LidoStandardBridgeDecoderAndSanitizer.sol";
import {
    MorphoBlueDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/MorphoBlueDecoderAndSanitizer.sol";
import { ERC4626DecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import { TellerDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol";
import { OFTDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import { OdosDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/OdosDecoderAndSanitizer.sol";
import { OneInchDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/OneInchDecoderAndSanitizer.sol";
import { EulerEVKDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/EulerEVKDecoderAndSanitizer.sol";
import {
    UniswapV2DecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/UniswapV2DecoderAndSanitizer.sol";

contract GoldenGooseUnichainDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    StandardBridgeDecoderAndSanitizer,
    UniswapV4DecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer,
    LidoStandardBridgeDecoderAndSanitizer,
    MorphoBlueDecoderAndSanitizer,
    ERC4626DecoderAndSanitizer,
    TellerDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    OdosDecoderAndSanitizer,
    OneInchDecoderAndSanitizer,
    EulerEVKDecoderAndSanitizer,
    UniswapV2DecoderAndSanitizer
{
    constructor(address _uniswapV4PositionManager, address _odosRouter)
        UniswapV4DecoderAndSanitizer(_uniswapV4PositionManager)
        OdosDecoderAndSanitizer(_odosRouter)
    { }

    function finalizeWithdrawalTransaction(DecoderCustomTypes.WithdrawalTransaction calldata _tx)
        external
        pure
        override (StandardBridgeDecoderAndSanitizer, LidoStandardBridgeDecoderAndSanitizer)
        returns (bytes memory sensitiveArguments)
    {
        sensitiveArguments = abi.encodePacked(_tx.sender, _tx.target);
    }

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
}

