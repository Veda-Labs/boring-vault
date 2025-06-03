// SPDX-License-Identifier: UNLICENSED
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
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(recipient_);
    }
}
