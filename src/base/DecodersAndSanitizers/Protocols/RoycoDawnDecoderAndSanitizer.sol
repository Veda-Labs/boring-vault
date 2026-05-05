// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract RoycoDawnDecoderAndSanitizer is BaseDecoderAndSanitizer {
    // RoycoEntryPoint deposit flow

    function requestDeposit(address tranche, uint256, address receiver, uint64)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(tranche, receiver);
    }

    function executeDeposit(address user, uint256, uint256)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(user);
    }

    function executeDeposits(address[] calldata users, uint256[] calldata, uint256[] calldata)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        for (uint256 i; i < users.length; ++i) {
            addressesFound = abi.encodePacked(addressesFound, users[i]);
        }
    }

    function cancelDepositRequest(uint256, address receiver)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver);
    }

    function cancelDepositRequests(uint256[] calldata, address receiver)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver);
    }

    // RoycoEntryPoint redemption flow

    function requestRedemption(address tranche, uint256, address receiver, uint64)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(tranche, receiver);
    }

    function executeRedemption(address user, uint256, uint256)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(user);
    }

    function executeRedemptions(address[] calldata users, uint256[] calldata, uint256[] calldata)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        for (uint256 i; i < users.length; ++i) {
            addressesFound = abi.encodePacked(addressesFound, users[i]);
        }
    }

    function cancelRedemptionRequest(uint256, address receiver)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver);
    }

    function cancelRedemptionRequests(uint256[] calldata, address receiver)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver);
    }
}
