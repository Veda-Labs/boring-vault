// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract EthenaWithdrawDecoderAndSanitizer {
    //============================== Ethena Withdraw ===============================

    function cooldownAssets(uint256 /*assets*/ ) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to do.
    }

    function cooldownShares(uint256 /*shares*/ ) external pure virtual returns (bytes memory addressesFound) {
        // Nothing to do.
    }

    function unstake(address receiver) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(receiver);
    }
}
