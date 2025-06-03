// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {INonFungiblePositionManager} from "src/interfaces/RawDataDecoderAndSanitizerInterfaces.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract BGTRewardVaultDecoderAndSanitizer {
    function stake(uint256 /*amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function delegateStake(address account, uint256 /*amount*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(account);
    }

    function withdraw(uint256 /*amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function delegateWithdraw(address account, uint256 /*amount*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(account);
    }

    function getReward(address account, address recipient)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(account, recipient);
    }

    function exit(address recipient) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(recipient);
    }

    function setOperator(address _operator) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_operator);
    }
}
