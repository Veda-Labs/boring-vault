// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract InfraredDecoderAndSanitizer {
    function stake(
        uint256 /*amount*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }

    function withdraw(
        uint256 /*amount*/
    )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }

    function getRewardForUser(address _user) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(_user);
    }

    //sends rewards to msg.sender
    function getReward() external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    //calls both getReward() and withdraw()
    function exit() external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }
}
