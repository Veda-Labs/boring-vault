// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { DecoderCustomTypes } from "src/interfaces/DecoderCustomTypes.sol";

contract LidoDecoderAndSanitizer {
    //============================== LIDO ===============================

    function submit(address referral) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(referral);
    }

    function wrap(uint256) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function unwrap(uint256) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function requestWithdrawals(uint256[] calldata, address _owner)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(_owner);
    }

    function claimWithdrawal(uint256) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to sanitize or return
        return addressesFound;
    }

    function claimWithdrawals(uint256[] calldata, uint256[] calldata)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        // Nothing to sanitize or return
        return addressesFound;
    }
}
