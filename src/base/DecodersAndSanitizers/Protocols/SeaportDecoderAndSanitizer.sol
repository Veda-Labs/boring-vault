// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;


import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

abstract contract SeaportDecoderAndSanitizer {

    function fulfillOrder(DecoderCustomTypes.Order order, bytes32 fulfillerConduitKey) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;  
    }
}
