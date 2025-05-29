// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";


abstract contract AgglayerDecoderAndSanitizer is BaseDecoderAndSanitizer {

    //============================== ERRORS ===============================
    error AgglayerDecoderAndSanitizer__PermitDataNonZero(); 

     function bridgeAsset(
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 /*amount*/,
        address token,
        bool /*forceUpdateGlobalExitRoot*/,
        bytes calldata permitData
    ) external pure virtual returns (bytes memory addressesFound) {
        if (permitData.length > 0) revert AgglayerDecoderAndSanitizer__PermitDataNonZero(); 

        addressesFound = abi.encodePacked(address(uint160(destinationNetwork)), destinationAddress, token); 
    }
    
    //tree depth: https://github.com/agglayer/ulxly-contracts/blob/ac153f7ca70d41f113820c5441363038a33baaef/contracts/v2/lib/DepositContractBase.sol#L15
    /// @notice metadata here is token metadata does not need to be sanitized or checked for length, etc
    function claimAsset(
        bytes32[32] calldata /*smtProofLocalExitRoot*/,
        bytes32[32] calldata /*smtProofRollupExitRoot*/,
        uint256 /*globalIndex*/,
        bytes32 /*mainnetExitRoot*/,
        bytes32 /*rollupExitRoot*/,
        uint32 originNetwork,
        address originTokenAddress,
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 /*amount*/,
        bytes calldata /*metadata*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(address(uint160(originNetwork)), originTokenAddress, address(uint160(destinationNetwork)), destinationAddress); 
    }

    function bridgeMessage(
        uint32 destinationNetwork,
        address destinationAddress,
        bool /*forceUpdateGlobalExitRoot*/,
        bytes calldata metadata
    ) external pure virtual returns (bytes memory addressesFound) {
        (address token, /*uint256 amount*/) = abi.decode(metadata, (address, uint256)); 
        addressesFound = abi.encodePacked(address(uint160(destinationNetwork)), destinationAddress, token); 
    }

    function bridgeMessageWETH(
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 /*amountWETH*/,
        bool /*forceUpdateGlobalExitRoot*/,
        bytes calldata metadata
    ) external pure virtual returns (bytes memory addressesFound) {
        (address token, /*uint256 amount*/) = abi.decode(metadata, (address, uint256)); 
        addressesFound = abi.encodePacked(address(uint160(destinationNetwork)), destinationAddress, token);
    }
    
    function claimMessage(
        bytes32[32] calldata /*smtProofLocalExitRoot*/,
        bytes32[32] calldata /*smtProofRollupExitRoot*/,
        uint256 /*globalIndex*/,
        bytes32 /*mainnetExitRoot*/,
        bytes32 /*rollupExitRoot*/,
        uint32 originNetwork,
        address originAddress,
        uint32 destinationNetwork,
        address destinationAddress,
        uint256 /*amount*/,
        bytes calldata metadata
    ) external pure virtual returns (bytes memory addressesFound) {
        (address token, /*uint256 amount*/) = abi.decode(metadata, (address, uint256)); 
        addressesFound = abi.encodePacked(address(uint160(originNetwork)), originAddress, address(uint160(destinationNetwork)), destinationAddress, token); 
    }
}
