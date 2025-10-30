// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {UniswapV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3DecoderAndSanitizer.sol";
import {KodiakIslandDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/KodiakIslandDecoderAndSanitizer.sol";
import {DolomiteDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/DolomiteDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {GoldiVaultDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/GoldiVaultDecoderAndSanitizer.sol";
import {BeraETHDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BeraETHDecoderAndSanitizer.sol";
import {InfraredDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/InfraredDecoderAndSanitizer.sol";
import {TellerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol";
import {WeETHDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/WeEthDecoderAndSanitizer.sol";
import {OogaBoogaDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OogaBoogaDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {HoneyDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/HoneyDecoderAndSanitizer.sol";
import {NativeWrapperDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol";
import {BeraborrowDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BeraborrowDecoderAndSanitizer.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract BerachainDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    UniswapV3DecoderAndSanitizer,
    KodiakIslandDecoderAndSanitizer,
    DolomiteDecoderAndSanitizer,
    ERC4626DecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer,
    GoldiVaultDecoderAndSanitizer,
    BeraETHDecoderAndSanitizer,
    InfraredDecoderAndSanitizer,
    TellerDecoderAndSanitizer,
    WeETHDecoderAndSanitizer,
    OogaBoogaDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    HoneyDecoderAndSanitizer,
    BeraborrowDecoderAndSanitizer
{
    constructor(address _nonFungiblePositionManager, address _dolomiteMargin)
        UniswapV3DecoderAndSanitizer(_nonFungiblePositionManager)
        DolomiteDecoderAndSanitizer(_dolomiteMargin)
    {}

    function withdraw(uint256)
        external
        pure
        override(NativeWrapperDecoderAndSanitizer, InfraredDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        // Nothing to sanitizer or return
        return addressesFound;
    }

    function deposit(address tokenIn, uint256, /*amountIn*/ uint256, /*minAmountOut*/ address referral)
        external
        pure
        override(WeETHDecoderAndSanitizer, TellerDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(tokenIn, referral);
    }
}
