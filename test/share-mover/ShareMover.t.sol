// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test} from "@forge-std/Test.sol";
import {MockVault} from "test/mocks/MockVault.sol";
import {DummyShareMover} from "test/mocks/DummyShareMover.sol";
import {MessageLib} from "src/base/Roles/CrossChain/ShareMover/MessageLib.sol";
import {ShareMover} from "src/base/Roles/CrossChain/ShareMover/ShareMover.sol";

contract ShareMoverTest is Test {
    MockVault vault;
    DummyShareMover mover;

    address user = address(0xBEEF);
    uint96 constant INITIAL_SHARES = 1_000e6; // using 6 decimals for simplicity

    function setUp() external {
        vault = new MockVault(6);
        mover = new DummyShareMover(address(vault), 1 ether);

        // Mint shares to user for testing
        vault.mint(user, INITIAL_SHARES);

        // Approve mover to transfer all shares on behalf of user
        vm.prank(user);
        vault.approve(address(mover), type(uint256).max);
    }

    function testBridgeSuccessful() external {
        uint96 amount = 100e6;
        bytes32 recipient = bytes32(uint256(uint160(address(0xCAFE))));
        bytes memory wildcard = hex"deadbeef";

        // Instead of expectEmit with unknown messageId, we can just rely on successful execution.

        vm.prank(user);
        mover.bridge(amount, recipient, wildcard);

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
        mover.bridge(0, recipient, "");
    }

    function testBridgeInvalidRecipientReverts() external {
        vm.prank(user);
        vm.expectRevert(ShareMover.ShareMover__InvalidRecipient.selector);
        mover.bridge(100, bytes32(0), "");
    }

    function testBridgeInsufficientBalanceReverts() external {
        bytes32 recipient = bytes32(uint256(uint160(address(2))));
        vm.prank(user);
        vm.expectRevert(ShareMover.ShareMover__InsufficientBalance.selector);
        mover.bridge(INITIAL_SHARES + 1, recipient, "");
    }
}

// ============================ PERMIT FLOW TESTS ============================

contract ShareMoverPermitTest is Test {
    MockVault vault;
    DummyShareMover mover;
    address user = address(0xBEEF);

    function setUp() external {
        vault = new MockVault(6);
        mover = new DummyShareMover(address(vault), 1 ether);
        vault.mint(user, 1e12);
    }

    function testBridgeWithPermitSuccess() external {
        vault.setPermitBehavior(false); // permit will succeed
        vm.prank(user);
        mover.bridgeWithPermit(1e6, bytes32(uint256(uint160(user))), "", 0, 0, 0, 0);
        assertTrue(vault.permitCalled(), "permit not called");

        // Verify balances updated correctly
        assertEq(vault.balanceOf(user), 1e12 - 1e6, "User balance not reduced");
        assertEq(vault.balanceOf(address(mover)), 0, "Mover should burn its shares");
    }

    function testBridgeWithPermitReverts() external {
        vault.setPermitBehavior(true); // force permit fail
        vm.prank(user);
        vm.expectRevert(ShareMover.ShareMover__InvalidPermit.selector);
        mover.bridgeWithPermit(1e6, bytes32(uint256(uint160(user))), "", 0, 0, 0, 0);
    }
} 