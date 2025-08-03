// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract CCTPDecoderAndSanitizer is BaseDecoderAndSanitizer {

    function depositForBurn(
        uint256, /*amount*/
        uint32 destinationDomain,
        bytes32 mintRecipient,
        address burnToken,
        bytes32 destinationCaller,
        uint256, /*maxFee*/
        uint32 /*minFinalityThreshold*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(
            address(uint160(destinationDomain)),
            address(uint160(uint256(mintRecipient))),
            burnToken,
            address(uint160(uint256(destinationCaller)))
        );
    }

    function receiveMessage(bytes calldata message, bytes calldata attestation)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        //nothing to sanitize
        return addressesFound;
    }
}
