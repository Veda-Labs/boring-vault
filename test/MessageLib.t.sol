// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MessageLib} from "src/base/Roles/CrossChain/ShareMover/MessageLib.sol";
import {Test} from "@forge-std/Test.sol";

contract MessageLibTest is Test {
    function testEncodeDecodeRoundTrip() external {
        MessageLib.Message memory message = MessageLib.Message({
            recipient: bytes32(uint256(uint160(address(0xBEEF)))),
            amount: 12345
        });

        bytes memory encoded = MessageLib.encodeMessage(message);
        assertEq(encoded.length, MessageLib.MESSAGE_SIZE);

        MessageLib.Message memory decoded = MessageLib.decodeMessage(encoded);
        assertEq(decoded.recipient, message.recipient, "recipient mismatch");
        assertEq(decoded.amount, message.amount, "amount mismatch");
    }

    function testDecodeInvalidLengthReverts() external {
        bytes memory bad = new bytes(MessageLib.MESSAGE_SIZE - 1);
        vm.expectRevert(MessageLib.MessageLib__InvalidLength.selector);
        MessageLib.decodeMessage(bad);
    }

    function testConvertAmountDecimalsScaleUp() external {
        uint128 amount = 1e18; // 1 with 18 decimals
        uint128 converted = MessageLib.convertAmountDecimals(amount, 18, 20);
        assertEq(converted, amount * 100, "scaled up incorrectly");
    }

    function testConvertAmountDecimalsScaleDown() external {
        uint128 amount = 1234500; // 1.2345 with 6 decimals
        uint128 converted = MessageLib.convertAmountDecimals(amount, 6, 4);
        assertEq(converted, 12345, "scaled down incorrectly");
    }

    function testConvertAmountDecimalsDustReverts() external {
        uint128 amount = 1; // too small to survive scaling down
        vm.expectRevert(MessageLib.MessageLib__DustAmount.selector);
        MessageLib.convertAmountDecimals(amount, 18, 6);
    }

    function testConvertAmountDecimalsOverflowReverts() external {
        uint128 amount = type(uint128).max;
        // Scaling up by 2 decimals will certainly overflow
        vm.expectRevert(MessageLib.MessageLib__ArithmeticOverflow.selector);
        MessageLib.convertAmountDecimals(amount, 18, 27);
    }

    function testAddressHelpers() external {
        address user = address(0x123456);
        bytes32 padded = MessageLib.padEvmAddress(user);
        assertTrue(MessageLib.isValidPaddedEvmAddress(padded), "padded address marked invalid");
        assertEq(MessageLib.extractEvmAddress(padded), user, "extracted address mismatch");
    }
} 