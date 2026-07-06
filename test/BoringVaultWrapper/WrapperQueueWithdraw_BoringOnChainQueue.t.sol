// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Vm} from "@forge-std/Vm.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import {BoringVaultWrapper} from "src/base/Roles/BoringVaultWrapper.sol";
import {BVWTestBase} from "./BVWTestBase.sol";

/// @notice Tests for the wrapper-initiated queue withdrawal flow:
///         BoringVaultWrapper.requestOnChainWithdrawFromQueue()
///           → BoringOnChainQueue.requestOnChainWithdrawFor()
contract WrapperQueueWithdrawTest is BVWTestBase {
    uint8 constant QUEUE_USER_ROLE = 9;

    uint64 constant LOCK = 1 hours;

    BoringOnChainQueue queue;

    function setUp() public override {
        super.setUp();
        wrapper.setFeeConfig(feeRecipient, feeRecipient, 0, 0);
        teller.setShareLockPeriod(LOCK);

        queue = new BoringOnChainQueue(
            address(this), address(rolesAuthority), payable(address(boringVault)), address(accountant)
        );

        rolesAuthority.setRoleCapability(
            QUEUE_USER_ROLE, address(queue), BoringOnChainQueue.requestOnChainWithdraw.selector, true
        );
        rolesAuthority.setRoleCapability(
            QUEUE_USER_ROLE, address(queue), BoringOnChainQueue.requestOnChainWithdrawFor.selector, true
        );
        rolesAuthority.setRoleCapability(
            QUEUE_USER_ROLE, address(queue), BoringOnChainQueue.cancelOnChainWithdraw.selector, true
        );
        rolesAuthority.setRoleCapability(
            QUEUE_USER_ROLE, address(queue), BoringOnChainQueue.replaceOnChainWithdraw.selector, true
        );

        rolesAuthority.setUserRole(alice, QUEUE_USER_ROLE, true);
        rolesAuthority.setUserRole(bob, QUEUE_USER_ROLE, true);
        rolesAuthority.setUserRole(address(wrapper), QUEUE_USER_ROLE, true);

        // 0 bps min discount, 100 bps max discount, 1 day maturity, 1 day minimum deadline.
        queue.updateWithdrawAsset(address(baseAsset), 1 days, 1 days, 0, 100, 0);

        wrapper.setQueue(address(queue));
    }

    // ── Happy path ────────────────────────────────────────────────────────────

    /// @notice Alice burns wrapper shares via the wrapper in a single call. The queue
    ///         escrows BV shares from the wrapper but records Alice as the request owner.
    function testRequestFromQueue_HappyPath() public {
        uint256 bvAmount = 100e18;
        uint256 wShares = _wrapBV(alice, bvAmount);

        skip(LOCK + 1);

        vm.prank(alice);
        vm.recordLogs();
        bytes32 requestId = wrapper.requestOnChainWithdrawFromQueue(address(baseAsset), wShares, 0, 3 days);
        BoringOnChainQueue.OnChainWithdraw memory request = _parseRequest(vm.getRecordedLogs());

        assertTrue(requestId != bytes32(0), "request id non-zero");
        assertEq(request.user, alice, "request owned by alice");
        assertEq(request.assetOut, address(baseAsset), "asset out");
        assertEq(requestId, queue.getRequestId(request), "request id matches stored id");

        assertEq(wrapper.balanceOf(alice), 0, "wrapper shares burned");
        assertEq(boringVault.balanceOf(alice), 0, "alice has no stray BV shares");
        assertApproxEqAbs(boringVault.balanceOf(address(queue)), bvAmount, 1, "queue holds ~bvAmount BV shares");
    }

    /// @notice The wrapper-created request is equivalent to the manual two-step: burning
    ///         wrapper shares then calling requestOnChainWithdraw directly. Both paths
    ///         produce the same BV-share escrow in the queue.
    function testRequestFromQueue_EquivalentToTwoStep() public {
        uint256 bvAmount = 100e18;

        uint256 aliceWShares = _wrapBV(alice, bvAmount);
        uint256 bobWShares = _wrapBV(bob, bvAmount);

        skip(LOCK + 1);

        // Alice: one-step via wrapper.
        vm.prank(alice);
        vm.recordLogs();
        wrapper.requestOnChainWithdrawFromQueue(address(baseAsset), aliceWShares, 0, 3 days);
        BoringOnChainQueue.OnChainWithdraw memory aliceReq = _parseRequest(vm.getRecordedLogs());

        // Bob: manual two-step — redeem wrapper for BV, then queue.
        vm.startPrank(bob);
        uint256 bobBV = wrapper.redeem(bobWShares, bob, bob);
        ERC20(address(boringVault)).approve(address(queue), bobBV);
        vm.recordLogs();
        queue.requestOnChainWithdraw(address(baseAsset), uint128(bobBV), 0, 3 days);
        BoringOnChainQueue.OnChainWithdraw memory bobReq = _parseRequest(vm.getRecordedLogs());
        vm.stopPrank();

        assertEq(queue.getRequestIds().length, 2, "two pending requests");

        // Share amounts escrowed should be equal (both started with the same bvAmount).
        assertApproxEqAbs(aliceReq.amountOfShares, bobReq.amountOfShares, 1, "same BV shares escrowed");

        assertEq(wrapper.balanceOf(alice), 0, "alice wrapper shares burned");
        assertEq(wrapper.balanceOf(bob), 0, "bob wrapper shares burned");
        assertEq(boringVault.balanceOf(alice), 0, "alice has no stray BV shares");
        assertEq(boringVault.balanceOf(bob), 0, "bob has no stray BV shares");
    }

    /// @notice The wrapper-created request is a normal user request: Alice can cancel
    ///         it herself and receives the escrowed BV shares back.
    function testRequestFromQueue_UserCanCancelRequest() public {
        uint256 wShares = _wrapBV(alice, 100e18);

        skip(LOCK + 1);

        vm.prank(alice);
        vm.recordLogs();
        wrapper.requestOnChainWithdrawFromQueue(address(baseAsset), wShares, 0, 3 days);
        BoringOnChainQueue.OnChainWithdraw memory request = _parseRequest(vm.getRecordedLogs());

        uint256 queuedShares = request.amountOfShares;

        vm.prank(alice);
        queue.cancelOnChainWithdraw(request);

        assertEq(queue.getRequestIds().length, 0, "request removed");
        assertEq(boringVault.balanceOf(alice), queuedShares, "alice received queued BV shares");
    }

    /// @notice Alice can replace her wrapper-created request with new parameters
    ///         (higher discount). The old request is removed and a new one registered.
    function testRequestFromQueue_UserCanReplaceRequest() public {
        uint256 wShares = _wrapBV(alice, 100e18);

        skip(LOCK + 1);

        vm.prank(alice);
        vm.recordLogs();
        wrapper.requestOnChainWithdrawFromQueue(address(baseAsset), wShares, 0, 3 days);
        BoringOnChainQueue.OnChainWithdraw memory original = _parseRequest(vm.getRecordedLogs());

        vm.prank(alice);
        vm.recordLogs();
        // 10 bps discount — the solver pays slightly less, so amountOfAssets is reduced.
        (bytes32 oldId, bytes32 newId) = queue.replaceOnChainWithdraw(original, 10, 3 days);
        BoringOnChainQueue.OnChainWithdraw memory replaced = _parseRequest(vm.getRecordedLogs());

        assertTrue(oldId != newId, "new request id issued");
        assertEq(replaced.user, alice, "replaced request still owned by alice");
        // At 10 bps discount, amountOfAssets = amountOfAssets * (1 - 0.001) < original.
        assertLt(replaced.amountOfAssets, original.amountOfAssets, "discount reduces asset amount");
        assertEq(queue.getRequestIds().length, 1, "still one pending request");

        bytes32[] memory ids = queue.getRequestIds();
        assertEq(ids[0], newId, "new id in queue");
    }

    // ── Revert cases ──────────────────────────────────────────────────────────

    /// @notice Reverts when no queue is configured on the wrapper.
    function testRequestFromQueue_RevertsWhenQueueNotSet() public {
        // Deploy a fresh wrapper without calling setQueue.
        BoringVaultWrapper bareWrapper = new BoringVaultWrapper(
            address(this), address(boringVault), address(accountant), "Bare", "B", feeRecipient, feeRecipient, 0, 0
        );

        uint256 wShares = _wrapBV(alice, 100e18);
        skip(LOCK + 1);

        vm.prank(alice);
        vm.expectRevert(BoringVaultWrapper.BoringVaultWrapper__QueueNotSet.selector);
        bareWrapper.requestOnChainWithdrawFromQueue(address(baseAsset), wShares, 0, 3 days);
    }

    /// @notice Reverts when the share lock has not elapsed.
    function testRequestFromQueue_RevertsWhenSharesLocked() public {
        uint256 wShares = _wrapBV(alice, 100e18);
        // Lock has NOT elapsed.

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(BoringVaultWrapper.BoringVaultWrapper__SharesLocked.selector, alice));
        wrapper.requestOnChainWithdrawFromQueue(address(baseAsset), wShares, 0, 3 days);
    }

    /// @notice Reverts when the wrapper is not authorized on the queue.
    function testRequestFromQueue_RevertsWhenWrapperNotAuthorizedOnQueue() public {
        uint256 wShares = _wrapBV(alice, 100e18);
        rolesAuthority.setUserRole(address(wrapper), QUEUE_USER_ROLE, false);

        skip(LOCK + 1);

        vm.prank(alice);
        vm.expectRevert();
        wrapper.requestOnChainWithdrawFromQueue(address(baseAsset), wShares, 0, 3 days);
    }

    /// @notice Calling requestOnChainWithdrawFor directly with address(0) as user reverts.
    function testRequestOnChainWithdrawFor_RevertsOnZeroUser() public {
        uint256 bvAmount = 100e18;
        deal(address(boringVault), alice, bvAmount, true);

        vm.startPrank(alice);
        ERC20(address(boringVault)).approve(address(queue), bvAmount);
        vm.expectRevert(BoringOnChainQueue.BoringOnChainQueue__BadUser.selector);
        queue.requestOnChainWithdrawFor(address(0), address(baseAsset), uint128(bvAmount), 0, 3 days);
        vm.stopPrank();
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    function _parseRequest(Vm.Log[] memory entries)
        internal
        pure
        returns (BoringOnChainQueue.OnChainWithdraw memory request)
    {
        bytes32 eventSig = keccak256(
            "OnChainWithdrawRequested(bytes32,address,address,uint88,uint128,uint128,uint40,uint24,uint24)"
        );

        for (uint256 i; i < entries.length; ++i) {
            if (entries[i].topics[0] == eventSig) {
                request.user = address(bytes20(entries[i].topics[2] << 96));
                request.assetOut = address(bytes20(entries[i].topics[3] << 96));
                (
                    request.nonce,
                    request.amountOfShares,
                    request.amountOfAssets,
                    request.creationTime,
                    request.secondsToMaturity,
                    request.secondsToDeadline
                ) = abi.decode(entries[i].data, (uint88, uint128, uint128, uint40, uint24, uint24));
                return request;
            }
        }
        revert("OnChainWithdrawRequested event not found");
    }
}
