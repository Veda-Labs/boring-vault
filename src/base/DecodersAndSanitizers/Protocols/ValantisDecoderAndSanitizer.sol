// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { DecoderCustomTypes } from "src/interfaces/DecoderCustomTypes.sol";

contract ValantisDecoderAndSanitizer {
    //============================== ERRORS ===============================
    error ValantisDecoderAndSanitizer__PoolsLengthGtOne();

    // @dev sov pool
    function swap(DecoderCustomTypes.SovereignPoolSwapParams calldata _swapParams)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_swapParams.recipient, _swapParams.swapTokenOut);
    }

    // @dev universal pool
    function swap(DecoderCustomTypes.UniversalSwapParams calldata _swapParams)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_swapParams.recipient);
    }

    function deposit(
        uint256,
        /*_amount*/
        uint256,
        /*_minShares*/
        uint256,
        /*_deadline*/
        address _recipient
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_recipient);
    }

    function withdraw(
        uint256,
        /*_shares*/
        uint256,
        /*_amount0Min*/
        uint256,
        /*_amount1Min*/
        uint256,
        /*_deadline*/
        address _recipient,
        bool,
        /*_unwrapToNativeToken*/
        bool /*_isInstantWithdrawal*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_recipient);
    }

    // @dev used when `withdraw()` has `_isInstantWithdrawal` marked as `false`
    function claim(
        uint256 /*_idLPQueue*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }
}
