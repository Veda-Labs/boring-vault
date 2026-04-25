// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract LZMultiCallDecoderAndSanitizer is BaseDecoderAndSanitizer {
    // LZMultiCall.execute((address,uint256,bytes)[],bytes32) — selector 0x571d3dc7
    // Sanitizes the batch by pinning every inner Call.target into the Merkle leaf.
    function execute(
        DecoderCustomTypes.LZCall[] calldata _calls,
        bytes32 /*_quoteId*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        for (uint256 i; i < _calls.length; ++i) {
            addressesFound = abi.encodePacked(addressesFound, _calls[i].target);

            // if this onner call is OFTAdapter.send(SendParam, MessagingFee, address),
            // pin SendParam.to as the 5th per-call address
            if (_calls[i].data.length >= 4 && bytes4(_calls[i].data[:4]) == bytes4(0xc7c7f5b3)) {
                (DecoderCustomTypes.SendParam memory sp,,) = abi.decode(
                    _calls[i].data[4:], (DecoderCustomTypes.SendParam, DecoderCustomTypes.MessagingFee, address)
                );
                addressesFound = abi.encodePacked(addressesFound, address(uint160(uint256(sp.to))));
            }
        }
    }
}
