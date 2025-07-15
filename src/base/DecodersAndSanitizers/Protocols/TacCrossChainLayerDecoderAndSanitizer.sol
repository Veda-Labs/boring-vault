// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract TacCrossChainLayerDecoderAndSanitizer {

    function sendMessage(
        uint256 /*messageVersion*/,
        bytes calldata /*encodedMessage*/
    ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound; 
    }

    function receiveMessage(
        uint256 /*messageVersion*/,
        bytes calldata /*encodedMessage*/,
        bytes32[] calldata /*merkleProof*/,
        address feeReceiver,
        bytes calldata /*extraData*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(feeReceiver);  
    }
}
