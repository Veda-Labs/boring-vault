// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MessageLib} from "src/base/Roles/CrossChain/ShareMover/MessageLib.sol";

/// @title MessageLibHarness
/// @notice Exposes pure functions of MessageLib via external calls so that `vm.expectRevert` works reliably.
contract MessageLibHarness {
    function decode(bytes calldata data) external pure returns (MessageLib.Message memory) {
        return MessageLib.decodeMessage(data);
    }

    function convert(
        uint128 amount,
        uint8 fromDecimals,
        uint8 toDecimals
    ) external pure returns (uint128) {
        return MessageLib.convertAmountDecimals(amount, fromDecimals, toDecimals);
    }
} 