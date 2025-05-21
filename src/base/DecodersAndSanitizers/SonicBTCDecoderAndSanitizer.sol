pragma solidity 0.8.21;

import {SonicDepositDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SonicDepositDecoderAndSanitizer.sol";
import {TellerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol"; 
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol"; 
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol"; 
import {UniswapV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UniswapV3DecoderAndSanitizer.sol";
import {OneInchDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OneInchDecoderAndSanitizer.sol";
import {AaveV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AaveV3DecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";
contract SonicBTCDecoderAndSanitizer is 
    BaseDecoderAndSanitizer,
    SonicDepositDecoderAndSanitizer,
    TellerDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    UniswapV3DecoderAndSanitizer,
    OneInchDecoderAndSanitizer,
    AaveV3DecoderAndSanitizer,
    ERC4626DecoderAndSanitizer
{
    constructor(address _uniswapV3NonFungiblePositionManager)
        UniswapV3DecoderAndSanitizer(_uniswapV3NonFungiblePositionManager)
    {}
 }
