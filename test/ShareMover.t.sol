// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test} from "@forge-std/Test.sol";
import {MockVault} from "test/mocks/MockVault.sol";
import {DummyShareMover} from "test/mocks/DummyShareMover.sol";
import {MessageLib} from "src/base/Roles/CrossChain/ShareMover/MessageLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ShareMover} from "src/base/Roles/CrossChain/ShareMover/ShareMover.sol";

contract ShareMoverTest is Test {
    MockVault vault;
    DummyShareMover mover;

    address user = address(0xBEEF);
    uint96 constant INITIAL_SHARES = 1_000e6; // using 6 decimals for simplicity

    function setUp() external {
        vault = new MockVault(6);
        mover = new DummyShareMover(address(vault));

        // Mint shares to user for testing
        vault.mint(user, INITIAL_SHARES);
    }

    function testBridgeSuccessful() external {
        uint96 amount = 100e6;
        bytes32 recipient = bytes32(uint256(uint160(address(0xCAFE))));
        bytes memory wildcard = hex"deadbeef";

        // Instead of expectEmit with unknown messageId, we can just rely on successful execution.

        vm.prank(user);
        mover.bridge(amount, 1, recipient, wildcard, ERC20(address(0))); // using native fee token (address(0))

        // Verify balances
        assertEq(vault.balanceOf(user), INITIAL_SHARES - amount, "User balance not reduced");
        assertEq(vault.balanceOf(address(mover)), 0, "Mover should burn its shares");

        // Verify that DummyShareMover stored correct vars
        (bytes32 lastRecip, uint128 lastAmt) = mover.lastMessage();
        assertEq(lastRecip, recipient, "recipient mismatch");
        assertEq(lastAmt, uint128(amount), "amount mismatch");
    }

    function testBridgeZeroSharesReverts() external {
        bytes32 recipient = bytes32(uint256(uint160(address(1))));
        vm.prank(user);
        vm.expectRevert(ShareMover.ShareMover__ZeroShares.selector);
        mover.bridge(0, 1, recipient, "", ERC20(address(0)));
    }

    function testBridgeInvalidRecipientReverts() external {
        vm.prank(user);
        vm.expectRevert(ShareMover.ShareMover__InvalidRecipient.selector);
        mover.bridge(100, 1, bytes32(0), "", ERC20(address(0)));
    }

    function testBridgeInsufficientBalanceReverts() external {
        bytes32 recipient = bytes32(uint256(uint160(address(2))));
        vm.prank(user);
        vm.expectRevert(ShareMover.ShareMover__InsufficientBalance.selector);
        mover.bridge(INITIAL_SHARES + 1, 1, recipient, "", ERC20(address(0)));
    }
} 