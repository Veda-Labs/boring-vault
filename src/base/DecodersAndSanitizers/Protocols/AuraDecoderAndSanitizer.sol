// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract AuraDecoderAndSanitizer {
    //============================== AURA ===============================

    function getReward(address _user, bool) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_user);
    }
}
