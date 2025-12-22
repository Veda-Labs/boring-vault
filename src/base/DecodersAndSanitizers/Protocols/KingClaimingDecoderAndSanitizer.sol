// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { BaseDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract KingClaimingDecoderAndSanitizer {
    function claim(
        address account,
        uint256, /*cumulativeAmount*/
        bytes32, /*expectedMerkleRoot*/
        bytes32[] calldata /*merkleProof*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(account);
    }

    function deposit(
        address[] memory,
        /*_tokens*/
        uint256[] memory,
        /*_amounts*/
        address _receiver
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        //deposit tokens are gated by KING + oracles
        addressesFound = abi.encodePacked(addressesFound, _receiver);
    }

    function redeem(
        uint256 /*vaultShares*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        // Nothing to sanitize.
        return addressesFound;
    }
}
