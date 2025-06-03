// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol";

contract UltraYieldDecoderAndSanitizer is ERC4626DecoderAndSanitizer {
    function requestRedeem(uint256 /*shares*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function deposit(uint256 /*assets*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function mint(uint256 /*shares*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function withdraw(uint256 /*assets*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function redeem(uint256 /*shares*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }
}
