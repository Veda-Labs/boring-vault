// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {UniswapV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3DecoderAndSanitizer.sol";
import {KodiakIslandDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/KodiakIslandDecoderAndSanitizer.sol";
import {DolomiteDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/DolomiteDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {GoldiVaultDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/GoldiVaultDecoderAndSanitizer.sol";
import {BeraETHDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BeraETHDecoderAndSanitizer.sol";
import {InfraredDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/InfraredDecoderAndSanitizer.sol"; 
import {TellerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol"; 


contract BerachainDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    UniswapV3DecoderAndSanitizer,
    KodiakIslandDecoderAndSanitizer,
    DolomiteDecoderAndSanitizer,
    ERC4626DecoderAndSanitizer,
    GoldiVaultDecoderAndSanitizer,
    BeraETHDecoderAndSanitizer,
    InfraredDecoderAndSanitizer,
    TellerDecoderAndSanitizer
{
    constructor(address _nonFungiblePositionManager, address _dolomiteMargin)
        UniswapV3DecoderAndSanitizer(_nonFungiblePositionManager)
        DolomiteDecoderAndSanitizer(_dolomiteMargin)
    {}
}
