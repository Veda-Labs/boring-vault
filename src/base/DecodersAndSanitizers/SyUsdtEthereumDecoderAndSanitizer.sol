// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "./BaseDecoderAndSanitizer.sol";
import {NativeWrapperDecoderAndSanitizer} from "./Protocols/NativeWrapperDecoderAndSanitizer.sol";
import {BridgingDecoderAndSanitizer} from "./BridgingDecoderAndSanitizer.sol";
import {TellerDecoderAndSanitizer} from "./Protocols/TellerDecoderAndSanitizer.sol";
import {MagpieDecoderAndSanitizer} from "./MagpieDecoderAndSanitizer.sol";

contract SyUsdtEthereumDecoderAndSanitizer is
    NativeWrapperDecoderAndSanitizer,
    MagpieDecoderAndSanitizer,
    TellerDecoderAndSanitizer,
    BridgingDecoderAndSanitizer
{
    constructor(address _flyTradeRouterV3) MagpieDecoderAndSanitizer(_flyTradeRouterV3) {}

    // handle function collisions

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
