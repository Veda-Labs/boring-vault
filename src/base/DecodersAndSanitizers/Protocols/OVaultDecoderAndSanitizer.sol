// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

abstract contract OVaultDecoderAndSanitizer is BaseDecoderAndSanitizer {
    error OVaultDecoderAndSanitizer__NonZeroLzTokenFee();

    /**
     * @notice Decode OFT send() with compose message.
     * @dev Extracts:
     *   - `to` field from SendParam (bytes32 → address): must be the whitelisted composer
     *   - `refundAddress`: the address receiving unused LZ fee refund
     *
     * Signature: send(
     *     (uint32,bytes32,uint256,uint256,bytes,bytes,bytes) sendParam,
     *     (uint256,uint256) messagingFee,
     *     address refundAddress
     * )
     */
    function send(
        DecoderCustomTypes.SendParam calldata _sendParam,
        DecoderCustomTypes.MessagingFee calldata _messagingFee,
        address _refundAddress
    ) external pure virtual returns (bytes memory addressesFound) {
        // Enforce no lzToken fee — vault should only pay native
        if (_messagingFee.lzTokenFee != 0) revert OVaultDecoderAndSanitizer__NonZeroLzTokenFee();

        // `to` in SendParam is bytes32-padded address of composer on Ethereum
        address to = address(uint160(uint256(_sendParam.to)));

        addressesFound = abi.encodePacked(to, _refundAddress);
    }
}
