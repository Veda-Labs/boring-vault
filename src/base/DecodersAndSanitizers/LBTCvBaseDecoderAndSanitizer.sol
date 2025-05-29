// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {UniswapV3SwapRouter02DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3SwapRouter02DecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
import {NativeWrapperDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/NativeWrapperDecoderAndSanitizer.sol";
import {OneInchDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OneInchDecoderAndSanitizer.sol";
import {PendleRouterDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/PendleRouterDecoderAndSanitizer.sol";
import {AaveV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AaveV3DecoderAndSanitizer.sol";
import {CCIPDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CCIPDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {MerklDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MerklDecoderAndSanitizer.sol";
import {OdosDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OdosDecoderAndSanitizer.sol"; 
import {LBTCBridgeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/LBTCBridgeDecoderAndSanitizer.sol"; 

contract LBTCvBaseDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    UniswapV3SwapRouter02DecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer,
    OneInchDecoderAndSanitizer,
    PendleRouterDecoderAndSanitizer,
    AaveV3DecoderAndSanitizer,
    CCIPDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    MerklDecoderAndSanitizer,
    ERC4626DecoderAndSanitizer,
    OdosDecoderAndSanitizer,
    LBTCBridgeDecoderAndSanitizer
{
    constructor(address _uniswapV3NonFungiblePositionManager, address _odosRouter)
        UniswapV3SwapRouter02DecoderAndSanitizer(_uniswapV3NonFungiblePositionManager)
        OdosDecoderAndSanitizer(_odosRouter)
    {}

    //============================== HANDLE FUNCTION COLLISIONS ===============================

}
