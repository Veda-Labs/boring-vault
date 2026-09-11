// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Test} from "@forge-std/Test.sol";
import {AtomicQueueAllowanceHook, IERC20Allowance, ILegacyBeforeTransferHook} from "src/base/Roles/AtomicQueueAllowanceHook.sol";
import {Authority} from "@solmate/auth/Auth.sol";

interface IBeforeTransferHook {
    function beforeTransfer(address from) external view;
    function beforeTransfer(address from, address to, address operator) external view;
}

contract MockLegacyBeforeTransferHook is ILegacyBeforeTransferHook {
    error MockLegacyBeforeTransferHook__TransferDenied();

    bool public shouldRevert;

    function setShouldRevert(bool _shouldRevert) external {
        shouldRevert = _shouldRevert;
    }

    function beforeTransfer(address) external view {
        if (shouldRevert) revert MockLegacyBeforeTransferHook__TransferDenied();
    }

    function beforeTransfer(address, address, address) external view {
        if (shouldRevert) revert MockLegacyBeforeTransferHook__TransferDenied();
    }
}

contract MockVault is IERC20Allowance {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    IBeforeTransferHook public hook;

    function setHook(IBeforeTransferHook _hook) external {
        hook = _hook;
    }

    function mint(address account, uint256 amount) external {
        balanceOf[account] += amount;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        hook.beforeTransfer(msg.sender, to, msg.sender);
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        hook.beforeTransfer(from, to, msg.sender);

        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) allowance[from][msg.sender] = allowed - amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract MockAtomicQueue {
    function pull(MockVault vault, address from, address to, uint256 amount) external {
        vault.transferFrom(from, to, amount);
    }
}

contract AtomicQueueAllowanceHookTest is Test {
    AtomicQueueAllowanceHook internal hook;
    MockAtomicQueue internal queue;
    MockAtomicQueue internal queue2;
    MockLegacyBeforeTransferHook internal legacyHook;
    MockVault internal vault;

    address internal constant USER = address(0x1001);
    address internal constant RECIPIENT = address(0x1002);
    uint256 internal constant BALANCE = 100e18;

    function setUp() external {
        queue = new MockAtomicQueue();
        queue2 = new MockAtomicQueue();
        legacyHook = new MockLegacyBeforeTransferHook();
        vault = new MockVault();
        hook = new AtomicQueueAllowanceHook(
            address(this), Authority(address(0)), IERC20Allowance(address(vault)), legacyHook, address(queue)
        );
        vault.setHook(IBeforeTransferHook(address(hook)));
        vault.mint(USER, BALANCE);
    }
    function testUsesBothBeforeTransferSelectors() external pure {
        assertEq(bytes4(keccak256("beforeTransfer(address)")), bytes4(0xe83931af));
        assertEq(bytes4(keccak256("beforeTransfer(address,address,address)")), bytes4(0xabd626b0));
    }
    function testCannotExceedMaximumBlockedSpenders() external {
        uint256 maxSpenders = hook.MAX_BLOCKED_SPENDERS();
        for (uint256 i = 1; i < maxSpenders; ++i) {
            hook.addBlockedSpender(vm.addr(i));
        }
        assertEq(hook.getBlockedSpenders().length, maxSpenders);

        vm.expectRevert(
            abi.encodeWithSelector(AtomicQueueAllowanceHook.AtomicQueueAllowanceHook__TooManyBlockedSpenders.selector)
        );
        hook.addBlockedSpender(vm.addr(maxSpenders));
    }

    function testLegacyOneArgumentSelectorStillDelegates() external {
        legacyHook.setShouldRevert(true);

        vm.expectRevert(MockLegacyBeforeTransferHook.MockLegacyBeforeTransferHook__TransferDenied.selector);
        hook.beforeTransfer(USER);
    }



    function testQueuePullRevertsBeforeAllowanceAndBalanceChange() external {
        vm.prank(USER);
        vault.approve(address(queue), BALANCE);

        vm.expectRevert(
            abi.encodeWithSelector(
                AtomicQueueAllowanceHook.AtomicQueueAllowanceHook__ApprovalToBlockedSpender.selector, USER, address(queue)
            )
        );
        queue.pull(vault, USER, RECIPIENT, BALANCE);

        assertEq(vault.allowance(USER, address(queue)), BALANCE);
        assertEq(vault.balanceOf(USER), BALANCE);
        assertEq(vault.balanceOf(RECIPIENT), 0);
    }
    function testMultipleBlockedSpendersCanBeAddedAndRemoved() external {
        hook.addBlockedSpender(address(queue2));
        assertTrue(hook.isBlockedSpender(address(queue)));
        assertTrue(hook.isBlockedSpender(address(queue2)));
        assertEq(hook.blockedSpenders(0), address(queue));
        assertEq(hook.blockedSpenders(1), address(queue2));

        vm.startPrank(USER);
        vault.approve(address(queue), BALANCE);
        vault.approve(address(queue2), BALANCE);
        vm.stopPrank();

        vm.expectRevert(
            abi.encodeWithSelector(
                AtomicQueueAllowanceHook.AtomicQueueAllowanceHook__ApprovalToBlockedSpender.selector, USER, address(queue)
            )
        );
        queue2.pull(vault, USER, RECIPIENT, BALANCE);

        vm.prank(USER);
        vault.approve(address(queue), 0);
        vm.expectRevert(
            abi.encodeWithSelector(
                AtomicQueueAllowanceHook.AtomicQueueAllowanceHook__ApprovalToBlockedSpender.selector, USER, address(queue2)
            )
        );
        queue2.pull(vault, USER, RECIPIENT, BALANCE);

        hook.removeBlockedSpender(address(queue2));
        queue2.pull(vault, USER, RECIPIENT, BALANCE);
        assertFalse(hook.isBlockedSpender(address(queue2)));
        assertEq(vault.balanceOf(RECIPIENT), BALANCE);

        vm.prank(USER);
        vault.approve(address(queue), BALANCE);
        vm.expectRevert(
            abi.encodeWithSelector(
                AtomicQueueAllowanceHook.AtomicQueueAllowanceHook__ApprovalToBlockedSpender.selector, USER, address(queue)
            )
        );
        queue.pull(vault, USER, RECIPIENT, 1);
    }


    function testRevokingQueueApprovalRestoresTransfers() external {
        vm.startPrank(USER);
        vault.approve(address(queue), BALANCE);
        vault.approve(address(queue), 0);
        vault.transfer(RECIPIENT, BALANCE);
        vm.stopPrank();

        assertEq(vault.allowance(USER, address(queue)), 0);
        assertEq(vault.balanceOf(USER), 0);
        assertEq(vault.balanceOf(RECIPIENT), BALANCE);
    }

    function testThreeArgumentSelectorStillDelegates() external {
        legacyHook.setShouldRevert(true);

        vm.expectRevert(MockLegacyBeforeTransferHook.MockLegacyBeforeTransferHook__TransferDenied.selector);
        vm.prank(USER);
        vault.transfer(RECIPIENT, 1);
    }
}
