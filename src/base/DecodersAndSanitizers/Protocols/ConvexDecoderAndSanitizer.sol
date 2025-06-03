// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract ConvexDecoderAndSanitizer {
    //============================== CONVEX ===============================

    function deposit(uint256, uint256, bool) external view virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function withdrawAndUnwrap(uint256, bool) external view virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function getReward(address _addr, bool) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_addr);
    }
}
