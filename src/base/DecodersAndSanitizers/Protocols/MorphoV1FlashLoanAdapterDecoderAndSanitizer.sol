// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract MorphoV1FlashLoanAdapterDecoderAndSanitizer is BaseDecoderAndSanitizer {
    function morphoFlashLoan(address token, uint256, bytes calldata)
        external
        view
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(token);
    }

    function emergencyRescueTokens(address[] calldata assets, uint256[] calldata)
        external
        pure
        returns (bytes memory addressesFound)
    {
        uint256 assetsLength = assets.length;
        for (uint256 i = 0; i < assetsLength; i++) {
            addressesFound = abi.encodePacked(addressesFound, assets[i]);
        }
    }
}

