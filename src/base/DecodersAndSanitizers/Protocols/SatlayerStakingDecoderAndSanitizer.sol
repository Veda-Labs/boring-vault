// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract SatlayerStakingDecoderAndSanitizer {
    //============================== Satlayer STAKING ===============================

    function depositFor(address _token, address _for, uint256 /*_amount*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_token, _for);
    }

    function withdraw(address _token, uint256 /*_amount*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_token);
    }
}
