// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

abstract contract HourglassDecoderAndSanitizer {
    // Hourglass Vault Interactions

    function deposit(uint256, /*amount*/ bool /*receiveSplit*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }

    function redeem(uint256 /*amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function redeemPrincipal(uint256 /*amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }
}
