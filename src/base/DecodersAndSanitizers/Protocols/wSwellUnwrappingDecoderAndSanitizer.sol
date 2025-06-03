// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract wSwellUnwrappingDecoderAndSanitizer {
    //============================== ETHERFI ===============================

    function withdrawToByLockTimestamp(address account, uint256, /*lockTimestamp*/ bool /*allowRemainderLoss*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(account);
    }

    function withdrawToByLockTimestamps(
        address account,
        uint256[] memory, /*lockTimetamp*/
        bool /*allowRemainderLoss*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(account);
    }
}
