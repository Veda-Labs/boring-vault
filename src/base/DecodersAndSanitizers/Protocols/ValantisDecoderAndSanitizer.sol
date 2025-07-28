// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract ValantisDecoderAndSanitizer {
    //============================== ERRORS ===============================
    error ValantisDecoderAndSanitizer__PoolsLengthGtOne(); 

    //function swap(DecoderCustomTypes.DirectSwapParams calldata _directSwapParams) external virtual returns (bytes memory addressesFound) {
    //    //limit swaps to the LSTs (kHYPE/WHYPE)
    //    if (_directSwapParams.pools.length > 1) revert ValantisDecoderAndSanitizer__PoolsLengthGtOne(); 
    //   
    //    address payloadRecipient = _directSwapParams.isUniversalPool == true ? 
    //        _decodeUniversalPayload(_directSwapParams.payload) : 
    //        _decodeSovereignPayload(_directSwapParams.payload)
    //    ;  
    //    
    //    addressesFound = abi.encodePacked(
    //        _directSwapParams.pools[0],  
    //        payloadRecipient,
    //        _directSwapParams.tokenIn,
    //        _directSwapParams.tokenOut,
    //        _directSwapParams.recipient
    //    ); 
    //}
    
    // @dev sov pool
    function swap(DecoderCustomTypes.SovereignPoolSwapParams calldata _swapParams) external virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_swapParams.recipient, _swapParams.swapTokenOut); 
    }
    
    // @dev universal pool
    function swap(DecoderCustomTypes.UniversalSwapParams calldata _swapParams) external virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_swapParams.recipient); 
    }
    
    function deposit(uint256 /*_amount*/, uint256 /*_minShares*/, uint256 /*_deadline*/, address _recipient) external virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_recipient); 
    }
    
    function withdraw(
        uint256 /*_shares*/,
        uint256 /*_amount0Min*/,
        uint256 /*_amount1Min*/,
        uint256 /*_deadline*/,
        address _recipient,
        bool /*_unwrapToNativeToken*/,
        bool /*_isInstantWithdrawal*/
    ) external virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_recipient); 
    }
    
    // @dev used when `withdraw()` has `_isInstantWithdrawal` marked as `false`
    function claim(uint256 /*_idLPQueue*/) external virtual returns (bytes memory addressesFound) {
        return addressesFound; 
    }

    //function _decodeUniversalPayload(bytes payload) internal view returns (address) {
    //    DecoderCustomTypes.UniversalPoolSwapPayload memory payloadStruct = abi.decode(payload, (DecoderCustomTypes.UniversalPoolSwapPayload));
    //    return payloadStruct.recipient; 
    //}

    //function _decodeSovereignPayload(bytes payload) internal view returns (address) {
    //    DecoderCustomTypes.SovereignPoolSwapPayload memory payloadStruct = abi.decode(payload, (DecoderCustomTypes.SovereignPoolSwapPayload));
    //    return payloadStruct.recipient; 
    //}
}


