// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";


abstract contract BeraborrowDecoderAndSanitizer is BaseDecoderAndSanitizer {

    // ========================================= ERRORS ==================================
    error BeraborrowDecoderAndSanitizer__PredepositLengthGtZero(); 
    error BeraborrowDecoderAndSanitizer__PayloadLengthGtZero(); 

    /// @dev we intentionally do not sanitize the hints here
    function openDenVault(DecoderCustomTypes.OpenDenVaultParams memory params) external pure virtual returns (bytes memory addressesFound) {
        if (params._preDeposit.length > 0) revert BeraborrowDecoderAndSanitizer__PredepositLengthGtZero(); 
        addressesFound = abi.encodePacked(params.denManager, params.collVault); 
    }

    function adjustDenVault(DecoderCustomTypes.AdjustDenVaultParams memory params) external pure virtual returns (bytes memory addressesFound) {
        if (params._preDeposit.length > 0) revert BeraborrowDecoderAndSanitizer__PredepositLengthGtZero(); 
        addressesFound = abi.encodePacked(params.denManager, params.collVault); 
    }

    function closeDenVault(
        address denManager,
        address collVault,
        uint256 /*minAssetsWithdrawn*/,
        uint256 /*collIndex*/,
        bool /*unwrap*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(denManager, collVault);  
    }

    // ========================================= Managed Vault Functions ==================================
    function deposit(uint256 /*assets*/, address receiver, DecoderCustomTypes.AddCollParams memory /*params*/) external pure virtual returns (bytes memory addressesFound) {   
        // upper hint and lower hint are addresses, but will not be sanitized
        addressesFound = abi.encodePacked(receiver);
    }

    function redeemIntent(uint256 /*shares*/, address receiver, address owner) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver, owner);
    }

    function cancelWithdrawalIntent(uint256 /*epoch*/, uint256 /*sharesToCancel*/, address receiver) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver);
    }

    function withdrawFromEpoch(
        uint256 /*epoch*/,
        address receiver,
        DecoderCustomTypes.ExternalRebalanceParams calldata unwrapParams
    ) external pure virtual returns (bytes memory addressesFound) {
        if (unwrapParams.payload.length > 0) revert BeraborrowDecoderAndSanitizer__PayloadLengthGtZero(); 
        addressesFound = abi.encodePacked(receiver, unwrapParams.swapper);  
    }

}
