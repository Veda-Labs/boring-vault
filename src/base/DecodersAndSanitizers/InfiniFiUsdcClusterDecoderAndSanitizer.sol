// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "./BaseDecoderAndSanitizer.sol";
import {MorphoBlueDecoderAndSanitizer} from "./Protocols/MorphoBlueDecoderAndSanitizer.sol";
import {ERC4626DecoderAndSanitizer} from "./Protocols/ERC4626DecoderAndSanitizer.sol";
import {NativeWrapperDecoderAndSanitizer} from "./Protocols/NativeWrapperDecoderAndSanitizer.sol";
import {InfiniDecoderAndSanitizer} from "./Protocols/InfiniDecoderAndSanitizer.sol";
import {EulerEVKDecoderAndSanitizer} from "./Protocols/EulerEVKDecoderAndSanitizer.sol";
import {MagpieDecoderAndSanitizer} from "./MagpieDecoderAndSanitizer.sol";
import {MorphoV1FlashLoanAdapterDecoderAndSanitizer} from "./Protocols/MorphoV1FlashLoanAdapterDecoderAndSanitizer.sol";

contract InfiniFiUsdcClusterDecoderAndSanitizer is
    MorphoBlueDecoderAndSanitizer,
    ERC4626DecoderAndSanitizer,
    NativeWrapperDecoderAndSanitizer,
    InfiniDecoderAndSanitizer,
    MagpieDecoderAndSanitizer,
    EulerEVKDecoderAndSanitizer,
    MorphoV1FlashLoanAdapterDecoderAndSanitizer
{
    constructor(address _magpieRouter) MagpieDecoderAndSanitizer(_magpieRouter) {}

    //============================== HANDLE FUNCTION COLLISIONS ===============================

    /**
     * @notice ERC4626 specifies a `deposit(uint256,address)`,
     *         all cases are handled the same way.
     */
    function deposit(uint256, address receiver)
        external
        pure
        override(ERC4626DecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(receiver);
    }

    /**
     * @notice NativeWrapper specifies a `deposit()`,
     *         all cases are handled the same way.
     */
    function deposit() external pure override(NativeWrapperDecoderAndSanitizer) returns (bytes memory addressesFound) {
        return addressesFound;
    }

    /**
     * @notice NativeWrapper specifies a `withdraw(uint256)`,
     *         all cases are handled the same way.
     */
    function withdraw(uint256)
        external
        pure
        override(NativeWrapperDecoderAndSanitizer)
        returns (bytes memory addressesFound)
    {
        // Nothing to sanitize or return
        return addressesFound;
    }
}
