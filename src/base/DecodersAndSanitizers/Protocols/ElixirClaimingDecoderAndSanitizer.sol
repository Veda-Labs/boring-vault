// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract ElixirClaimingDecoderAndSanitizer is BaseDecoderAndSanitizer {
    function claim(
        uint256,
        /*_amount*/
        bytes32[] calldata,
        /*_merkleProof*/
        bytes calldata /*_signature*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }
}
