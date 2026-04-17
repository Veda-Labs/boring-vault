// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {AaveV3DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/AaveV3DecoderAndSanitizer.sol";

contract HyperLendDecoderAndSanitizer is AaveV3DecoderAndSanitizer {
    //============================== HyperLend Rewards Distributor ===============================

    /**
     *  @notice We intentionally do not report claims.token since it is not important for the security of the call.
     *          HyperLend's merkle proofs bound what's claimable. Tokens are only transferred to msg.sender (the vault)
     */
    function claim(
        DecoderCustomTypes.Claim[] calldata /*claims*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }
}
