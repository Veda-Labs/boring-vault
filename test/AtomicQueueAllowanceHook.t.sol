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
        hook.beforeTransfer(msg.sender);
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        hook.beforeTransfer(from);

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
    MockLegacyBeforeTransferHook internal legacyHook;
    MockVault internal vault;

    address internal constant USER = address(0x1001);
    address internal constant RECIPIENT = address(0x1002);
    uint256 internal constant BALANCE = 100e18;

    function setUp() external {
        queue = new MockAtomicQueue();
        legacyHook = new MockLegacyBeforeTransferHook();
        vault = new MockVault();
        hook = new AtomicQueueAllowanceHook(
            address(this), Authority(address(0)), IERC20Allowance(address(vault)), legacyHook, address(queue)
        );
        vault.setHook(IBeforeTransferHook(address(hook)));
        vault.mint(USER, BALANCE);
    }
    function testUsesLegacyBeforeTransferSelector() external pure {
        assertEq(AtomicQueueAllowanceHook.beforeTransfer.selector, bytes4(0xe83931af));
    }


    function testQueuePullRevertsBeforeAllowanceAndBalanceChange() external {
        vm.prank(USER);
        vault.approve(address(queue), BALANCE);

        vm.expectRevert(
            abi.encodeWithSelector(AtomicQueueAllowanceHook.AtomicQueueAllowanceHook__ApprovalToBlockedSpender.selector, USER)
        );
        queue.pull(vault, USER, RECIPIENT, BALANCE);

        assertEq(vault.allowance(USER, address(queue)), BALANCE);
        assertEq(vault.balanceOf(USER), BALANCE);
        assertEq(vault.balanceOf(RECIPIENT), 0);
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

    function testLegacyHookStillEnforcesAfterAllowanceCheck() external {
        legacyHook.setShouldRevert(true);

        vm.expectRevert(MockLegacyBeforeTransferHook.MockLegacyBeforeTransferHook__TransferDenied.selector);
        vm.prank(USER);
        vault.transfer(RECIPIENT, 1);
    }
}
