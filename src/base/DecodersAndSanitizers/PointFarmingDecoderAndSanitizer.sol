// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { BaseDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {
    EigenLayerLSTStakingDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/EigenLayerLSTStakingDecoderAndSanitizer.sol";
import {
    SwellSimpleStakingDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/SwellSimpleStakingDecoderAndSanitizer.sol";
import {
    ZircuitSimpleStakingDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/ZircuitSimpleStakingDecoderAndSanitizer.sol";
import {
    MantleStandardBridgeDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/MantleStandardBridgeDecoderAndSanitizer.sol";
import {
    ScrollBridgeDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/ScrollBridgeDecoderAndSanitizer.sol";
import {
    LineaBridgeDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/LineaBridgeDecoderAndSanitizer.sol";
import {
    StandardBridgeDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/StandardBridgeDecoderAndSanitizer.sol";
import { KarakDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/KarakDecoderAndSanitizer.sol";
import { OFTDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {
    SatlayerStakingDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/SatlayerStakingDecoderAndSanitizer.sol";
import {
    CornStakingDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/CornStakingDecoderAndSanitizer.sol";

contract PointFarmingDecoderAndSanitizer is
    EigenLayerLSTStakingDecoderAndSanitizer,
    SwellSimpleStakingDecoderAndSanitizer,
    KarakDecoderAndSanitizer,
    ZircuitSimpleStakingDecoderAndSanitizer,
    StandardBridgeDecoderAndSanitizer,
    LineaBridgeDecoderAndSanitizer,
    MantleStandardBridgeDecoderAndSanitizer,
    ScrollBridgeDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    SatlayerStakingDecoderAndSanitizer,
    CornStakingDecoderAndSanitizer,
    BaseDecoderAndSanitizer
{
    //============================== HANDLE FUNCTION COLLISIONS ===============================

    function withdraw(
        address _token,
        uint256 /*_amount*/
    )
        external
        pure
        override (ZircuitSimpleStakingDecoderAndSanitizer, SatlayerStakingDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_token);
    }

    function depositFor(
        address _token,
        address _for,
        uint256 /*_amount*/
    )
        external
        pure
        override (ZircuitSimpleStakingDecoderAndSanitizer, SatlayerStakingDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_token, _for);
    }
}
