// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract TacCrossChainLayerDecoderAndSanitizer {

    error TacCrossChainLayerDecoderAndSanitizer__InvalidLength(); 
    error TacCrossChainLayerDecoderAndSanitizer__TvmBytesLengthTooShort(); 
   
    function sendMessage(
        uint256 /*messageVersion*/,
        bytes calldata encodedMessage
    ) external pure virtual returns (bytes memory addressesFound) {
        DecoderCustomTypes.OutMessageV1 memory messageV1 = abi.decode(encodedMessage, (DecoderCustomTypes.OutMessageV1));
        if (messageV1.toBridge.length > 1) revert TacCrossChainLayerDecoderAndSanitizer__InvalidLength(); 
        
        //convert ton address to bytes 
        bytes memory tvmBytes = bytes(messageV1.tvmTarget);
        
        //sanity check
        if (tvmBytes.length < 20) revert TacCrossChainLayerDecoderAndSanitizer__TvmBytesLengthTooShort(); 

        address tvmTarget0;
        assembly {
            tvmTarget0 := mload(add(tvmBytes, 32)) 
        }
        
        // Extract second address (bytes 20-39) if available
        address tvmTarget1;
        if (tvmBytes.length >= 40) {
            assembly {
                tvmTarget1 := mload(add(tvmBytes, 52)) // skip length prefix + 20 bytes
            }
        }

        addressesFound = abi.encodePacked(tvmTarget0, tvmTarget1, messageV1.toBridge[0].evmAddress); 
    }
}
