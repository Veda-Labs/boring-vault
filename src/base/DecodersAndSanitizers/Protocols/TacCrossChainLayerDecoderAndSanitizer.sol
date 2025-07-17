// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract TacCrossChainLayerDecoderAndSanitizer {

    error TacCrossChainLayerDecoderAndSanitizer__InvalidLength(); 
    error TacCrossChainLayerDecoderAndSanitizer__TvmBytesLengthTooShort(); 
    error TacCrossChainLayerDecoderAndSanitizer__MessageVersionNotOne(); 
    error TacCrossChainLayerDecoderAndSanitizer__NFTLengthNonZero(); 

    function sendMessage(
        uint256 messageVersion,
        bytes calldata encodedMessage
    ) external pure virtual returns (bytes memory addressesFound) {
        if (messageVersion != 1) revert TacCrossChainLayerDecoderAndSanitizer__MessageVersionNotOne();
        DecoderCustomTypes.OutMessageV1 memory messageV1 = abi.decode(encodedMessage, (DecoderCustomTypes.OutMessageV1));
        if (messageV1.toBridge.length > 1) revert TacCrossChainLayerDecoderAndSanitizer__InvalidLength();
        if (messageV1.toBridgeNFT.length > 0) revert TacCrossChainLayerDecoderAndSanitizer__NFTLengthNonZero();
    
        // Convert ton address to bytes
        bytes memory tvmBytes = bytes(messageV1.tvmTarget);
    
        // Sanity check
        if (tvmBytes.length < 20) revert TacCrossChainLayerDecoderAndSanitizer__TvmBytesLengthTooShort();

        // Extract first address (bytes 0-19)
        address tvmTarget0;
        assembly {
            tvmTarget0 := mload(add(tvmBytes, 20)) // Read 32 bytes, take rightmost 20 (bytes 0-19)
        }
    
        // Extract second address (bytes 20-39) if available
        address tvmTarget1;
        if (tvmBytes.length > 20) {
            assembly {
                tvmTarget1 := mload(add(tvmBytes, 40)) // Read 32 bytes, take rightmost 20 (bytes 20-39)
            }
        }
    
        // Extract third address (bytes 40+) if available
        address tvmTarget2;
        if (tvmBytes.length > 40) {
            assembly {
                tvmTarget2 := mload(add(tvmBytes, 60)) // Read 32 bytes, take rightmost 20 (bytes 40-59)
            }
        }
     
    
        addressesFound = abi.encodePacked(tvmTarget0, tvmTarget1, tvmTarget2, messageV1.toBridge[0].evmAddress);
    }


}
