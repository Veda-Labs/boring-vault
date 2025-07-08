// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MessageLib} from "src/base/Roles/CrossChain/ShareMover/MessageLib.sol";
import {Test} from "@forge-std/Test.sol";
import {MessageLibHarness} from "test/mocks/MessageLibHarness.sol";

contract MessageLibTest is Test {
    MessageLibHarness harness;

    function setUp() external {
        harness = new MessageLibHarness();
    }

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
        vm.expectRevert();
        harness.decode(bad);
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
        vm.expectRevert();
        harness.convert(amount, 18, 6);
    }

    function testConvertAmountDecimalsOverflowReverts() external {
        uint128 amount = type(uint128).max;
        vm.expectRevert();
        harness.convert(amount, 18, 27);
    }

    function testAddressHelpers() external {
        address user = address(0x123456);
        bytes32 padded = MessageLib.padEvmAddress(user);
        assertTrue(MessageLib.isValidPaddedEvmAddress(padded), "padded address marked invalid");
        assertEq(MessageLib.extractEvmAddress(padded), user, "extracted address mismatch");
    }
}

// ===========================  FUZZ TESTS  ===========================

contract MessageLibFuzzTest is Test {
    MessageLibHarness internal harness;

    function setUp() public {
        harness = new MessageLibHarness();
    }

    /*//////////////////////////////////////////////////////////////
                             ENCODE / DECODE
    //////////////////////////////////////////////////////////////*/

    function testFuzz_encodeDecode(bytes32 recipient, uint128 amount) external {
        vm.assume(recipient != bytes32(0));
        vm.assume(amount > 0);

        MessageLib.Message memory msgIn = MessageLib.Message({recipient: recipient, amount: amount});
        bytes memory encoded = MessageLib.encodeMessage(msgIn);
        MessageLib.Message memory msgOut = MessageLib.decodeMessage(encoded);

        assertEq(msgOut.recipient, recipient, "recipient mismatch");
        assertEq(msgOut.amount, amount, "amount mismatch");
    }

    /*//////////////////////////////////////////////////////////////
                           DECIMAL CONVERSION
    //////////////////////////////////////////////////////////////*/

    function testFuzz_decimalRoundTrip(
        uint128 amount,
        uint8 fromDecimals,
        uint8 delta
    ) external {
        vm.assume(amount > 0);
        vm.assume(fromDecimals <= 27);
        vm.assume(delta <= 9);

        uint8 toDecimals = fromDecimals + delta;
        vm.assume(toDecimals <= 27);

        uint256 mul = 10 ** uint256(delta);
        uint256 prod;
        unchecked {
            prod = uint256(amount) * mul;
        }
        vm.assume(prod <= type(uint128).max);

        uint128 scaledUp = harness.convert(amount, fromDecimals, toDecimals);
        uint128 roundTripped = harness.convert(scaledUp, toDecimals, fromDecimals);
        assertEq(roundTripped, amount, "round-trip mismatch");
    }

    function testFuzz_decimalDustProtection(
        uint128 amount,
        uint8 fromDecimals,
        uint8 delta
    ) external {
        vm.assume(amount > 0);
        vm.assume(fromDecimals > 0 && fromDecimals <= 27);
        vm.assume(delta > 0 && delta <= fromDecimals);

        uint8 toDecimals = fromDecimals - delta;
        uint256 divisor = 10 ** uint256(delta);

        uint256 scaled = amount / divisor;
        vm.assume(scaled <= type(uint128).max);
        uint128 expected = uint128(scaled);

        if (expected == 0) {
            vm.expectRevert();
            harness.convert(amount, fromDecimals, toDecimals);
        } else {
            uint128 got = harness.convert(amount, fromDecimals, toDecimals);
            assertEq(got, expected, "scale-down mismatch");
        }
    }

    /*//////////////////////////////////////////////////////////////
                              ADDRESS HELPERS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_addressHelpers(address user) external {
        vm.assume(user != address(0));
        bytes32 padded = MessageLib.padEvmAddress(user);

        assertTrue(MessageLib.isValidPaddedEvmAddress(padded), "invalid padded address");
        assertEq(MessageLib.extractEvmAddress(padded), user, "extracted address mismatch");
    }
} 