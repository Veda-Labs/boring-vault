// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {TellerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol";
import {OFTDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {BalancerV2DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/BalancerV2DecoderAndSanitizer.sol";
import {CurveDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CurveDecoderAndSanitizer.sol";
import {SiloDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SiloDecoderAndSanitizer.sol"; 
import {ERC4626DecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/ERC4626DecoderAndSanitizer.sol"; 
import {LBTCBridgeDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/LBTCBridgeDecoderAndSanitizer.sol"; 

contract SonicLBTCvSonicDecoderAndSanitizer is
    BaseDecoderAndSanitizer,
    TellerDecoderAndSanitizer,
    OFTDecoderAndSanitizer,
    BalancerV2DecoderAndSanitizer,
    CurveDecoderAndSanitizer,
    SiloDecoderAndSanitizer,
    LBTCBridgeDecoderAndSanitizer
{
 /**
     * @notice BalancerV2 and Curve all specify a `deposit(uint256,address)`,
     *         all cases are handled the same way.
     */
    function deposit(uint256, address receiver)
        external
        pure
        override(BalancerV2DecoderAndSanitizer, CurveDecoderAndSanitizer, ERC4626DecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver);
    }

    /**
     * @notice BalancerV2 and Curve all specify a `withdraw(uint256)`,
     *         all cases are handled the same way.
     */
    function withdraw(uint256)
        external
        pure
        override(
            BalancerV2DecoderAndSanitizer,
            CurveDecoderAndSanitizer
        )
        returns (bytes memory addressesFound)
    {
        // Nothing to sanitize or return
        return addressesFound;
    }

}
