// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

contract OndoDecoderAndSanitizer {
    //============================== USDY INSTANT MANAGER ===============================

    function subscribe(address depositToken, uint256, /*depositAmount*/ uint256 /*minimumRwaReceived*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(depositToken);
    }

    function subscribeRebasingUSDY(address depositToken, uint256, /*depositAmount*/ uint256 /*minimumRusdyReceived*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(depositToken);
    }

    function redeem(uint256, /*rwaAmount*/ address receivingToken, uint256 /*minimumTokenReceived*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receivingToken);
    }

    function redeemRebasingUSDY(uint256, /*rusdyAmount*/ address receivingToken, uint256 /*minimumTokenReceived*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receivingToken);
    }
}
