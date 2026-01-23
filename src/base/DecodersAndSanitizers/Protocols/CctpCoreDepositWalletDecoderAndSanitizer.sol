// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract CctpCoreDepositWalletDecoderAndSanitizer is BaseDecoderAndSanitizer {
    function deposit(uint256, uint32 destinationDex) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(address(uint160(destinationDex)));
    }
}
