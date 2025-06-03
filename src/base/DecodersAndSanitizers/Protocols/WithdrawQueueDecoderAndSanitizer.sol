// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract WithdrawQueueDecoderAndSanitizer {
    // BoringOnChainQueue.sol
    function requestOnChainWithdraw(address asset, uint128, uint16, uint24)
        external
        pure
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(asset);
    }
}
