// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";

abstract contract Hlp0DecoderAndSanitizer is BaseDecoderAndSanitizer, ERC4626DecoderAndSanitizer {
    function requestRedeem(uint256 _amountOfHlp) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }
}
