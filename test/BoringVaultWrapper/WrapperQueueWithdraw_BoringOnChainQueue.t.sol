// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";

import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {BoringOnChainQueue, IERC4626Minimal} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import {BoringVaultWrapper} from "src/base/Roles/BoringVaultWrapper.sol";
import {BVWTestBase} from "./BVWTestBase.sol";

/// @notice Happy-path tests for requestOnChainWithdrawFromWrapper().
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

        // Grant users permission to call both request paths on the queue.
        rolesAuthority.setRoleCapability(
            QUEUE_USER_ROLE, address(queue), BoringOnChainQueue.requestOnChainWithdraw.selector, true
        );
        rolesAuthority.setRoleCapability(
            QUEUE_USER_ROLE, address(queue), BoringOnChainQueue.requestOnChainWithdrawFromWrapper.selector, true
        );
        rolesAuthority.setUserRole(alice, QUEUE_USER_ROLE, true);

        // 0 bps discount, 1 day maturity, 1 day minimum deadline.
        queue.updateWithdrawAsset(address(baseAsset), 1 days, 1 days, 0, 0, 0);

        wrapper.setQueue(address(queue));
    }

    // ── Happy path ────────────────────────────────────────────────────────────

    /// @notice Alice holds wrapper shares, waits out the share lock, then calls
    ///         requestOnChainWithdrawFromWrapper in a single transaction. Her
    ///         wrapper shares are burned, the equivalent BV shares land in the
    ///         queue, and a valid withdrawal request is recorded.
    function testRequestFromWrapper_HappyPath() public {
        uint256 bvAmount = 100e18;
        uint256 wShares = _wrapBV(alice, bvAmount);

        skip(LOCK + 1);

        // Alice approves the queue to pull her wrapper shares.
        vm.startPrank(alice);
        wrapper.approve(address(queue), wShares);
        bytes32 requestId = queue.requestOnChainWithdrawFromWrapper(
            IERC4626Minimal(address(wrapper)), address(baseAsset), wShares, 0, 3 days
        );
        vm.stopPrank();

        // Request was created.
        assertTrue(requestId != bytes32(0), "request id non-zero");

        // Wrapper shares fully consumed.
        assertEq(wrapper.balanceOf(alice), 0, "wrapper shares burned");

        // BV shares escrowed in the queue.
        uint256 queueBV = boringVault.balanceOf(address(queue));
        assertGt(queueBV, 0, "queue holds BV shares");
        assertApproxEqAbs(queueBV, bvAmount, 1, "queue holds ~bvAmount BV shares");

        // Request is retrievable from the queue.
        bytes32[] memory ids = queue.getRequestIds();
        assertEq(ids.length, 1, "one pending request");
        assertEq(ids[0], requestId, "stored request id matches");

        // Alice's BV balance is zero (shares were held by the wrapper, now in queue).
        assertEq(boringVault.balanceOf(alice), 0, "alice has no stray BV shares");
    }

    /// @notice Sanity check: two-step (redeem wrapper → queue BV shares manually)
    ///         and one-step (requestOnChainWithdrawFromWrapper) produce equivalent
    ///         queue states.
    function testRequestFromWrapper_EquivalentToTwoStep() public {
        uint256 bvAmount = 100e18;

        // Alice: one-step path.
        uint256 aliceWShares = _wrapBV(alice, bvAmount);

        // Bob: two-step path.
        uint256 bobWShares = _wrapBV(bob, bvAmount);

        rolesAuthority.setUserRole(bob, QUEUE_USER_ROLE, true);

        skip(LOCK + 1);

        // Alice one-step.
        vm.startPrank(alice);
        wrapper.approve(address(queue), aliceWShares);
        bytes32 aliceId = queue.requestOnChainWithdrawFromWrapper(
            IERC4626Minimal(address(wrapper)), address(baseAsset), aliceWShares, 0, 3 days
        );
        vm.stopPrank();

        // Bob two-step: redeem wrapper shares for BV shares, then queue.
        vm.startPrank(bob);
        uint256 bobBV = wrapper.redeem(bobWShares, bob, bob);
        ERC20(address(boringVault)).approve(address(queue), bobBV);
        bytes32 bobId = queue.requestOnChainWithdraw(address(baseAsset), uint128(bobBV), 0, 3 days);
        vm.stopPrank();

        // Both requests are in the queue.
        bytes32[] memory ids = queue.getRequestIds();
        assertEq(ids.length, 2, "two pending requests");

        // Requests are distinct.
        assertTrue(aliceId != bobId, "requests are distinct");

        // Both holders end up with zero wrapper and zero BV balances.
        assertEq(wrapper.balanceOf(alice), 0, "alice wrapper shares burned");
        assertEq(wrapper.balanceOf(bob), 0, "bob wrapper shares burned");
        assertEq(boringVault.balanceOf(alice), 0, "alice has no BV shares");
        assertEq(boringVault.balanceOf(bob), 0, "bob has no BV shares");
    }

    // ── Revert cases ──────────────────────────────────────────────────────────

    /// @notice Providing a wrapper whose underlying asset is NOT the BoringVault reverts.
    function testRequestFromWrapper_RevertsOnMismatchedWrapper() public {
        // Deploy a second vault + its own accountant + a wrapper over that vault.
        // asset() on decoyWrapper will be decoyVault, which != queue's boringVault.
        BoringVault decoyVault = new BoringVault(address(this), "Decoy", "DV", 18);
        AccountantWithRateProviders decoyAccountant = new AccountantWithRateProviders(
            address(this), address(decoyVault), payoutAddress, 1e18, address(baseAsset), 1.1e4, 0.9e4, 1, 0, 0
        );
        BoringVaultWrapper decoyWrapper = new BoringVaultWrapper(
            address(this),
            address(decoyVault),
            address(decoyAccountant),
            "Decoy",
            "DW",
            feeRecipient,
            feeRecipient,
            0,
            0
        );

        vm.prank(alice);
        vm.expectRevert(BoringOnChainQueue.BoringOnChainQueue__BadWrapper.selector);
        queue.requestOnChainWithdrawFromWrapper(
            IERC4626Minimal(address(decoyWrapper)), address(baseAsset), 1e18, 0, 3 days
        );
    }

    /// @notice Calling while the wrapper share lock is still active reverts.
    function testRequestFromWrapper_RevertsWhenSharesLocked() public {
        uint256 wShares = _wrapBV(alice, 100e18);

        vm.startPrank(alice);
        wrapper.approve(address(queue), wShares);
        // Lock has NOT elapsed — wrapper.redeem will revert with SharesLocked.
        vm.expectRevert(abi.encodeWithSelector(BoringVaultWrapper.BoringVaultWrapper__SharesLocked.selector, alice));
        queue.requestOnChainWithdrawFromWrapper(
            IERC4626Minimal(address(wrapper)), address(baseAsset), wShares, 0, 3 days
        );
        vm.stopPrank();
    }

    /// @notice A wrapper cannot reenter another queue mutation while its redeem is in progress.
    function testRequestFromWrapper_RevertsOnWrapperReentrantRequest() public {
        ReentrantRequestWrapper maliciousWrapper = new ReentrantRequestWrapper(queue, boringVault, address(baseAsset));
        uint256 shares = 1e18;

        _giveBVShares(address(maliciousWrapper), shares);
        rolesAuthority.setUserRole(address(maliciousWrapper), QUEUE_USER_ROLE, true);

        vm.prank(alice);
        vm.expectRevert(BoringOnChainQueue.BoringOnChainQueue__WrapperReentrancy.selector);
        queue.requestOnChainWithdrawFromWrapper(
            IERC4626Minimal(address(maliciousWrapper)), address(baseAsset), shares, 0, 3 days
        );
    }
}

contract ReentrantRequestWrapper {
    BoringOnChainQueue internal immutable queue;
    BoringVault internal immutable boringVault;
    address internal immutable assetOut;

    constructor(BoringOnChainQueue _queue, BoringVault _boringVault, address _assetOut) {
        queue = _queue;
        boringVault = _boringVault;
        assetOut = _assetOut;
    }

    function asset() external view returns (address) {
        return address(boringVault);
    }

    function redeem(uint256 shares, address, address) external returns (uint256) {
        boringVault.approve(address(queue), shares);
        queue.requestOnChainWithdraw(assetOut, uint128(shares), 0, 3 days);
        return shares;
    }
}
