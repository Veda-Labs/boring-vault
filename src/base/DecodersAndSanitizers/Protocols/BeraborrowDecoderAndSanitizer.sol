// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract BeraborrowDecoderAndSanitizer is BaseDecoderAndSanitizer {
    // ========================================= ERRORS ==================================
    error BeraborrowDecoderAndSanitizer__PredepositLengthGtZero();

    /// @dev we intentionally do not sanitize the hints here
    function openDenVault(DecoderCustomTypes.OpenDenVaultParams memory params)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        if (params._preDeposit.length > 0) revert BeraborrowDecoderAndSanitizer__PredepositLengthGtZero();
        addressesFound = abi.encodePacked(params.denManager, params.collVault);
    }

    function adjustDenVault(DecoderCustomTypes.AdjustDenVaultParams memory params)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        if (params._preDeposit.length > 0) revert BeraborrowDecoderAndSanitizer__PredepositLengthGtZero();
        addressesFound = abi.encodePacked(params.denManager, params.collVault);
    }

    function closeDenVault(
        address denManager,
        address collVault,
        uint256, /*minAssetsWithdrawn*/
        uint256, /*collIndex*/
        bool /*unwrap*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(denManager, collVault);
    }
}
