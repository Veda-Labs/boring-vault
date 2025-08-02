// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "./BaseDecoderAndSanitizer.sol";

abstract contract MagpieDecoderAndSanitizer is BaseDecoderAndSanitizer {
    // Reference to the OdosRouterV2 contract
    address internal immutable magpieRouter; //temp

    constructor(address _magpieRouter) {
        magpieRouter = _magpieRouter;
    }

    function swapWithMagpieSignature(bytes calldata /*pathDefinition*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }
}
