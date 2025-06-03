// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract SyrupDecoderAndSanitizer {
    //============================== SYRUP ===============================

    // Call to SyrupRouter, instantly deposits
    function deposit(
        uint256, /*amount*/
        bytes32 /*depositData_*/ // "0:itb" for into the block or "0:okx" for okx, only used for event
    ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    // Call to Maple Pool (syrupUSDC and syrupUSDT), queues shares for withdrawal (must be processed)
    function requestRedeem(uint256, /*shares_*/ address owner_)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(owner_);
    }

    // Call to Maple Pool (syrupUSDC and syrupUSDT), cancels redemption requests and returns shares
    function removeShares(uint256, /*shares_*/ address owner_)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(owner_);
    }
}
