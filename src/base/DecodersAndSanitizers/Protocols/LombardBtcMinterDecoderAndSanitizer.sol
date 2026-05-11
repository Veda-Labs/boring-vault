// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract LombardBTCMinterDecoderAndSanitizer {
    /// @notice for permissioned users
    function mint(address to, uint256 /*amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(to);
    }

    /// @notice minting directly via LTBC contract
    function mint(bytes calldata data, bytes calldata /*proofSignature*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        (,,,,, bytes memory msgBody) =
            abi.decode(data[4:], (bytes32, uint256, bytes32, address, address, bytes));
        bytes32 recipientWord;
        assembly {
            recipientWord := mload(add(msgBody, 0x44))
        }
        addressesFound = abi.encodePacked(address(uint160(uint256(recipientWord))));
    }

    /// @notice for minting using cbBTCPPM contract (on Base)
    function swapCBBTCToLBTC(uint256 /*amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    /// @notice for minting using btcbPMM contract (on BSC)
    function swapBTCBToLBTC(uint256 /*amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }
}
