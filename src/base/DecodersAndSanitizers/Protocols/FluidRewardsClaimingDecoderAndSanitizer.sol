// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract FluidRewardsClaimingDecoderAndSanitizer {
    function claim(
        address recipient_,
        uint256, /*cumulativeAmount_*/
        uint8, /*positionType_*/
        bytes32, /*positionId_*/
        uint256, /*cycle_*/
        bytes32[] calldata, /*merkleProof_*/
        bytes memory /*metadata_*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(recipient_);
    }
}
