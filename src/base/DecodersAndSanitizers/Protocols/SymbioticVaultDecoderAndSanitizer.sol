// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract SymbioticVaultDecoderAndSanitizer {
    //============================== SYMBIOTIC ===============================

    function deposit(address onBehalfOf, uint256 /*amount*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(onBehalfOf);
    }

    function withdraw(address claimer, uint256 /*amount*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(claimer);
    }

    //  Pulled from https://github.com/symbioticfi/rewards/blob/69bd269e53462c35093f40b16e24727abd110e9f/src/contracts/defaultStakerRewards/DefaultStakerRewards.sol#L232
    function claimRewards(address recipient, address, /*token*/ bytes calldata /*data*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        // We only sanitize recipient since this function only increases value for the boring vault.
        addressesFound = abi.encodePacked(recipient);
    }

    function claim(address recipient, uint256 /*epoch*/ ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(recipient);
    }

    function claimBatch(address recipient, uint256[] calldata /*epoch*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(recipient);
    }
}
