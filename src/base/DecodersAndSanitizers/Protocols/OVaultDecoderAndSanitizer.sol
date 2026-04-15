// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

abstract contract OVaultDecoderAndSanitizer is BaseDecoderAndSanitizer {
    error OVaultDecoderAndSanitizer__NonZeroLzTokenFee();

    function depositAndSend(
        uint256 _assetAmount,
        DecoderCustomTypes.SendParam calldata _sendParam,
        address _refundAddress
    ) external pure virtual returns (bytes memory addressesFound) {
        // `to` in SendParam is bytes32-padded address of composer on Ethereum
        address to = address(uint160(uint256(_sendParam.to)));

        addressesFound = abi.encodePacked(to, _refundAddress);
    }
}
