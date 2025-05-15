// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract rFLRDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== rFLR ===============================
    function claimRewards(uint256[] calldata, /*_projectIds*/ uint256 /*_month*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }

    function withdraw(uint128, /*_amount*/ bool /*_wrap*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }

    function withdrawAll(bool /*_wrap*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }
}
