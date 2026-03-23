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
}

