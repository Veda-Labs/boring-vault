// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract UsualMoneyDecoderAndSanitizer is BaseDecoderAndSanitizer {
    //============================== Usual Money ===============================

    //USD0 and USD0++ Functions
    function mint(uint256 /*amountUsd0*/ ) external pure virtual returns (bytes memory sensitiveArgumentsFound) {
        return sensitiveArgumentsFound;
    }

    function unwrap() external pure virtual returns (bytes memory sensitiveArgumentsFound) {
        return sensitiveArgumentsFound;
    }

    function unlockUsd0ppFloorPrice(uint256 /*usd0ppAmount*/ )
        external
        pure
        virtual
        returns (bytes memory sensitiveArgumentsFound)
    {
        return sensitiveArgumentsFound;
    }

    // Swapper Engine Functions (0xB969B0d14F7682bAF37ba7c364b351B830a812B2) //
    function depositUSDC(uint256 /*amountToDeposit*/ )
        external
        pure
        virtual
        returns (bytes memory sensitiveArgumentsFound)
    {
        return sensitiveArgumentsFound;
    }

    function provideUsd0ReceiveUSDC(
        address recipient,
        uint256, /*amountUsdcToTakeInNativeDecimals*/
        uint256[] memory, /*orderIdsToTake*/
        bool /*partialMatchingAllowed*/
    ) external pure virtual returns (bytes memory sensitiveArgumentsFound) {
        return abi.encodePacked(recipient);
    }

    function swapUsd0(
        address recipient,
        uint256, /*amountUsd0ToProvideInWad*/
        uint256[] memory, /*orderIdsToTake*/
        bool /*partialMatchingAllowed*/
    ) external pure virtual returns (bytes memory sensitiveArgumentsFound) {
        return abi.encodePacked(recipient);
    }

    function withdrawUSDC(uint256 /*orderToCancel*/ )
        external
        pure
        virtual
        returns (bytes memory sensitveArgumentsFound)
    {
        return sensitveArgumentsFound;
    }
}
