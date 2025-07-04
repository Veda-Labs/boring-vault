// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract MantleDecoderAndSanitizer {
    //============================== MANTLE ===============================

    // Call stake here 0xe3cBd06D7dadB3F4e6557bAb7EdD924CD1489E8f called mantleLspStaking in MainnetAddresses
    function stake(uint256 /*minMETHAmount*/ ) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    // Call unstakeRequest 0xe3cBd06D7dadB3F4e6557bAb7EdD924CD1489E8f
    function unstakeRequest(uint128, /*methAmount*/ uint128 /*minETHAmount*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        // Nothing to sanitize or return
        return addressesFound;
    }

    // Call claimUnstakeRequest 0xe3cBd06D7dadB3F4e6557bAb7EdD924CD1489E8f
    function claimUnstakeRequest(uint256 /*unstakeRequestID*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        // Nothing to sanitize or return
        return addressesFound;
    }
}
