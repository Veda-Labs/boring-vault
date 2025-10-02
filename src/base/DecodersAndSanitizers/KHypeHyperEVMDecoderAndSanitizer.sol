// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {AaveV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AaveV3DecoderAndSanitizer.sol";
import {NativeWrapperDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol";
import {MorphoBlueDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MorphoBlueDecoderAndSanitizer.sol"; 
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol"; 
import {CurveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CurveDecoderAndSanitizer.sol"; 
import {KinetiqDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/KinetiqDecoderAndSanitizer.sol"; 
import {PendleRouterDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/PendleRouterDecoderAndSanitizer.sol";
import {ValantisDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ValantisDecoderAndSanitizer.sol";
import {UniswapV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3DecoderAndSanitizer.sol";

contract KHypeHyperEVMDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer,
    AaveV3DecoderAndSanitizer,
    MorphoBlueDecoderAndSanitizer,
    ERC4626DecoderAndSanitizer,
    CurveDecoderAndSanitizer,
    KinetiqDecoderAndSanitizer,
    PendleRouterDecoderAndSanitizer,
    ValantisDecoderAndSanitizer,
    UniswapV3DecoderAndSanitizer
{

    constructor(address _uniswapV3NonFungiblePositionManager) 
        UniswapV3DecoderAndSanitizer(_uniswapV3NonFungiblePositionManager){}

    function deposit(uint256, address receiver) external pure virtual override(ERC4626DecoderAndSanitizer, CurveDecoderAndSanitizer) returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver);
    }

    function withdraw(uint256) external pure virtual override(CurveDecoderAndSanitizer, NativeWrapperDecoderAndSanitizer) returns (bytes memory addressesFound) {
        return addressesFound; 
    }
}
