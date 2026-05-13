// SPDX-License-Identifier: SEL-1.0
// Last audited: boring-vault@4c9c671bb965899728167102a0e3ac22f4aabf7a — https://macroaudits.com/library/audits/sevenSeas-39
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract SonicGatewayDecoderAndSanitizer {
    ////////////////// Sonic Gateway //////////////////

    //bridges mainnet -> sonic
    function deposit(uint96, /*uid*/ address token, uint256 /*amount*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(token);
    }

    //bridges sonic -> mainnet
    function withdraw(uint96, /*uid*/ address token, uint256 /*amount*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(token);
    }

    function claim(uint256, /*id*/ address token, uint256, /*amount*/ bytes calldata /*proof*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(token);
    }

    //if the bridge is "dead", we can cancel our deposit if needed
    function cancelDepositWhileDead(uint256, /*id*/ address token, uint256, /*amount*/ bytes calldata /*proof*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(token);
    }
}
