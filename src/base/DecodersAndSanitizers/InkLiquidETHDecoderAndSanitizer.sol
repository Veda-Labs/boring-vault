// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {NativeWrapperDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol";
import {AaveV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AaveV3DecoderAndSanitizer.sol";
import {VelodromeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/VelodromeDecoderAndSanitizer.sol";
import {MerklDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MerklDecoderAndSanitizer.sol";
import {EtherFiDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/EtherFiDecoderAndSanitizer.sol";
import {StandardBridgeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/StandardBridgeDecoderAndSanitizer.sol";

contract InkLiquidETHDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer,
    AaveV3DecoderAndSanitizer,
    VelodromeDecoderAndSanitizer,
    MerklDecoderAndSanitizer,
    EtherFiDecoderAndSanitizer,
    StandardBridgeDecoderAndSanitizer
{
    constructor(address _velodromeNFT)
        VelodromeDecoderAndSanitizer(_velodromeNFT)
    {}

    function deposit() external override (EtherFiDecoderAndSanitizer, NativeWrapperDecoderAndSanitizer) pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function withdraw(uint256) external override (VelodromeDecoderAndSanitizer, NativeWrapperDecoderAndSanitizer) pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }
}
