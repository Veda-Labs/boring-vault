// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract LZMultiCallDecoderAndSanitizer is BaseDecoderAndSanitizer {
    // LZMultiCall.execute((address,uint256,bytes)[],bytes32) — selector 0x571d3dc7
    // Sanitizes the batch by pinning every inner Call.target into the Merkle leaf.
    function execute(DecoderCustomTypes.LZCall[] calldata _calls, bytes32 /*_quoteId*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        for (uint256 i; i < _calls.length; ++i) {
            addressesFound = abi.encodePacked(addressesFound, _calls[i].target);
        }
    }
}
