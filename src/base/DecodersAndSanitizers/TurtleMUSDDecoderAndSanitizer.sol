// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {NativeWrapperDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol";
import {OneInchDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OneInchDecoderAndSanitizer.sol";
import {OdosDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OdosDecoderAndSanitizer.sol";
import {EulerEVKDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/EulerEVKDecoderAndSanitizer.sol";
import {wSwellUnwrappingDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/wSwellUnwrappingDecoderAndSanitizer.sol";
import {PancakeSwapV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/PancakeSwapV3DecoderAndSanitizer.sol";
import {PendleRouterDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/PendleRouterDecoderAndSanitizer.sol";
import {MerklDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MerklDecoderAndSanitizer.sol";

contract TurtleMUSDDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer,
    OneInchDecoderAndSanitizer,
    OdosDecoderAndSanitizer,
    EulerEVKDecoderAndSanitizer,
    wSwellUnwrappingDecoderAndSanitizer,
    PancakeSwapV3DecoderAndSanitizer,
    PendleRouterDecoderAndSanitizer,
    MerklDecoderAndSanitizer
{
    constructor(
        address _odosRouter,
        address _pancakeSwapV3NonFungiblePositionManager,
        address _pancakeSwapV3MasterChef
    )
        OdosDecoderAndSanitizer(_odosRouter)
        PancakeSwapV3DecoderAndSanitizer(_pancakeSwapV3NonFungiblePositionManager, _pancakeSwapV3MasterChef)
    {}
}
