// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract HoneyDecoderAndSanitizer {
    //=========================== Honey Factor (Vault Router) ============================
    function mint(address asset, uint256, /*amount*/ address receiver)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(asset, receiver);
    }

    function redeem(address asset, uint256, /*honeyAmount*/ address receiver)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(asset, receiver);
    }
}
