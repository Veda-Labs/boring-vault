// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test} from "@forge-std/Test.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";

import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {
    TellerWithMultiAssetSupport,
    ComplianceData,
    DepositParams
} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {BoringVaultWrapper} from "src/base/Roles/BoringVaultWrapper.sol";
import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import {MockERC20} from "src/helper/MockERC20.sol";

/// @notice Wrapper-layer share lock + queue-disabled redeemAsset behavior.
contract ShareLockAndQueueTest is Test {
    uint8 constant ADMIN_ROLE = 1;
    uint8 constant MINTER_ROLE = 7;
    uint8 constant BURNER_ROLE = 8;
    uint8 constant WRAPPER_ROLE = 55;
    uint8 constant SETTER_ROLE = 2;
    uint8 constant QUEUE_USER_ROLE = 9; // may call queue.requestOnChainWithdraw
    uint8 constant DEPOSITOR_ROLE = 10; // may call teller.deposit (public path)

    MockERC20 baseAsset;
    BoringVault boringVault;
    AccountantWithRateProviders accountant;
    TellerWithMultiAssetSupport teller;
    BoringVaultWrapper wrapper;
    RolesAuthority rolesAuthority;

    address feeRecipient = makeAddr("feeRecipient");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address carol = makeAddr("carol");
    address payoutAddress = makeAddr("payoutAddress");

    uint64 constant LOCK = 1 hours;

    function setUp() public {
        baseAsset = new MockERC20("Wrapped Ether", "WETH", 18);
        boringVault = new BoringVault(address(this), "Test Boring Vault", "TBV", 18);
        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), payoutAddress, 1e18, address(baseAsset), 1.1e4, 0.9e4, 1, 0, 0
        );
        teller = new TellerWithMultiAssetSupport(
            address(this), address(boringVault), address(accountant), address(baseAsset)
        );
        wrapper = new BoringVaultWrapper(
            address(this), address(boringVault), address(accountant), address(teller), "Partner Vault", "PV"
        );

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);
        accountant.setAuthority(rolesAuthority);
        teller.setAuthority(rolesAuthority);
        wrapper.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(MINTER_ROLE, address(boringVault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(boringVault), BoringVault.exit.selector, true);
        rolesAuthority.setRoleCapability(
            WRAPPER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkDeposit.selector, true
        );
        rolesAuthority.setRoleCapability(
            WRAPPER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.updateAssetData.selector, true
        );
        rolesAuthority.setRoleCapability(
            SETTER_ROLE, address(teller), TellerWithMultiAssetSupport.setShareLockPeriod.selector, true
        );

        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(this), SETTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);
        rolesAuthority.setUserRole(address(wrapper), WRAPPER_ROLE, true);

        teller.updateAssetData(baseAsset, true, true, 0);
        accountant.setRateProviderData(baseAsset, true, address(0));
        wrapper.setFeeConfig(feeRecipient, 0, 0);

        // The wrapper sources its lock period from the BV's live beforeTransfer hook,
        // so wire the teller as the hook and set the 1h period there.
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(boringVault), BoringVault.setBeforeTransferHook.selector, true
        );
        boringVault.setBeforeTransferHook(address(teller));
        teller.setShareLockPeriod(LOCK);
    }

    function _giveBVShares(address user, uint256 amount) internal {
        deal(address(boringVault), user, amount, true);
    }

    function _wrapBV(address user, uint256 bvAmount) internal returns (uint256 wShares) {
        vm.startPrank(user);
        ERC20(address(boringVault)).approve(address(wrapper), bvAmount);
        wShares = wrapper.deposit(bvAmount, user);
        vm.stopPrank();
    }

    // ── Lock is recorded on deposit / mint / depositAsset ──────────────────────

    function testDepositSetsLock() public {
        _giveBVShares(alice, 100e18);
        _wrapBV(alice, 100e18);
        assertEq(wrapper.shareUnlockTime(alice), uint64(block.timestamp) + LOCK, "deposit sets lock");
    }

    function testMintSetsLock() public {
        _giveBVShares(alice, 100e18);
        vm.startPrank(alice);
        ERC20(address(boringVault)).approve(address(wrapper), 100e18);
        wrapper.mint(100e18 * 1e6, alice);
        vm.stopPrank();
        assertEq(wrapper.shareUnlockTime(alice), uint64(block.timestamp) + LOCK, "mint sets lock");
    }

    function testDepositAssetSetsLock() public {
        deal(address(baseAsset), alice, 100e18);
        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), 100e18);
        wrapper.depositAsset(baseAsset, 100e18, 0, alice, ComplianceData(0, ""));
        vm.stopPrank();
        assertEq(wrapper.shareUnlockTime(alice), uint64(block.timestamp) + LOCK, "depositAsset sets lock");
    }

    // ── receiver == caller invariant (anti-grief / anti-bypass) ────────────────

    /// @notice Bob cannot deposit on Alice's behalf to refresh her lock. Allowing it
    ///         would let any third party perpetually re-lock a victim's whole balance
    ///         with dust.
    function testDepositToOtherReceiverReverts() public {
        _giveBVShares(bob, 100e18);
        vm.startPrank(bob);
        ERC20(address(boringVault)).approve(address(wrapper), 100e18);
        vm.expectRevert(BoringVaultWrapper.BoringVaultWrapper__ReceiverMustBeCaller.selector);
        wrapper.deposit(100e18, alice);
        vm.stopPrank();
    }

    function testMintToOtherReceiverReverts() public {
        _giveBVShares(bob, 100e18);
        vm.startPrank(bob);
        ERC20(address(boringVault)).approve(address(wrapper), 100e18);
        vm.expectRevert(BoringVaultWrapper.BoringVaultWrapper__ReceiverMustBeCaller.selector);
        wrapper.mint(1e6, alice);
        vm.stopPrank();
    }

    function testDepositAssetToOtherReceiverReverts() public {
        deal(address(baseAsset), bob, 100e18);
        vm.startPrank(bob);
        baseAsset.approve(address(wrapper), 100e18);
        vm.expectRevert(BoringVaultWrapper.BoringVaultWrapper__ReceiverMustBeCaller.selector);
        wrapper.depositAsset(baseAsset, 100e18, 0, alice, ComplianceData(0, ""));
        vm.stopPrank();
    }

    /// @notice Grief is impossible end-to-end: Alice deposits, her lock elapses, and a
    ///         later third-party deposit attempt cannot push her unlock back out, so
    ///         she can still exit.
    function testThirdPartyCannotRefreshVictimLock() public {
        _giveBVShares(alice, 100e18);
        uint256 wShares = _wrapBV(alice, 100e18);
        uint64 unlockAfterAlice = wrapper.shareUnlockTime(alice);

        skip(LOCK + 1); // Alice's lock elapses.

        // Bob's attempt to re-lock Alice reverts; her unlock time is untouched.
        _giveBVShares(bob, 1e18);
        vm.startPrank(bob);
        ERC20(address(boringVault)).approve(address(wrapper), 1e18);
        vm.expectRevert(BoringVaultWrapper.BoringVaultWrapper__ReceiverMustBeCaller.selector);
        wrapper.deposit(1e18, alice);
        vm.stopPrank();

        assertEq(wrapper.shareUnlockTime(alice), unlockAfterAlice, "victim lock not refreshed");

        // Alice exits freely.
        vm.prank(alice);
        wrapper.redeem(wShares, alice, alice);
        assertEq(wrapper.balanceOf(alice), 0, "victim can still exit");
    }

    /// @notice The symmetric concern: routing a deposit through a helper contract
    ///         (msg.sender != receiver) is rejected too, so it cannot be used to mint
    ///         unlocked shares to the attacker.
    function testHelperContractDepositCannotBypassLock() public {
        DepositHelper helper = new DepositHelper(wrapper, ERC20(address(boringVault)));
        _giveBVShares(address(helper), 100e18);

        vm.expectRevert(BoringVaultWrapper.BoringVaultWrapper__ReceiverMustBeCaller.selector);
        helper.depositTo(100e18, bob);
    }

    // ── Transfers are gated by the lock ────────────────────────────────────────

    function testTransferBlockedDuringLock() public {
        _giveBVShares(alice, 100e18);
        uint256 wShares = _wrapBV(alice, 100e18);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(BoringVaultWrapper.BoringVaultWrapper__SharesLocked.selector, alice));
        wrapper.transfer(bob, wShares);

        skip(LOCK + 1);
        vm.prank(alice);
        assertTrue(wrapper.transfer(bob, wShares), "transfer succeeds after lock");
        assertEq(wrapper.balanceOf(bob), wShares, "bob received shares");
    }

    function testTransferFromBlockedDuringLock() public {
        _giveBVShares(alice, 100e18);
        uint256 wShares = _wrapBV(alice, 100e18);

        vm.prank(alice);
        wrapper.approve(bob, wShares);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(BoringVaultWrapper.BoringVaultWrapper__SharesLocked.selector, alice));
        wrapper.transferFrom(alice, bob, wShares);

        skip(LOCK + 1);
        vm.prank(bob);
        assertTrue(wrapper.transferFrom(alice, bob, wShares), "transferFrom succeeds after lock");
    }

    // ── Lock extends, never shortens ───────────────────────────────────────────

    function testLockExtendsNeverShortens() public {
        _giveBVShares(alice, 200e18);
        _wrapBV(alice, 100e18);
        uint64 firstUnlock = wrapper.shareUnlockTime(alice);

        // A shorter lock period set later must not shorten the existing lock.
        teller.setShareLockPeriod(1 minutes);
        _wrapBV(alice, 100e18);
        assertEq(wrapper.shareUnlockTime(alice), firstUnlock, "shorter new lock does not shorten existing");

        // Time passes a bit, then a fresh full-length deposit extends the lock.
        skip(30 minutes);
        teller.setShareLockPeriod(LOCK);
        _giveBVShares(alice, 50e18);
        _wrapBV(alice, 50e18);
        assertEq(wrapper.shareUnlockTime(alice), uint64(block.timestamp) + LOCK, "later deposit extends lock");
        assertGt(wrapper.shareUnlockTime(alice), firstUnlock, "lock extended");
    }

    // ── Period snapshotted at deposit, not read live at exit ───────────────────

    function testLockPeriodSnapshottedNotLive() public {
        _giveBVShares(alice, 100e18);
        uint256 wShares = _wrapBV(alice, 100e18);
        uint64 unlockAtDeposit = wrapper.shareUnlockTime(alice);

        // Admin lengthens the teller period after Alice deposited; her snapshot is unchanged.
        teller.setShareLockPeriod(3 days); // MAX_SHARE_LOCK_PERIOD
        assertEq(
            wrapper.shareUnlockTime(alice), unlockAtDeposit, "existing lock unaffected by later setShareLockPeriod"
        );

        // She can still exit once her original (shorter) window elapses.
        skip(LOCK + 1);
        vm.prank(alice);
        wrapper.redeem(wShares, alice, alice);
        assertEq(wrapper.balanceOf(alice), 0, "exit honors snapshotted period, not live one");
    }

    // ── Queue disables redeemAsset ─────────────────────────────────────────────

    function testRedeemAssetDisabledWhenQueueSet() public {
        deal(address(baseAsset), alice, 100e18);
        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), 100e18);
        uint256 wShares = wrapper.depositAsset(baseAsset, 100e18, 0, alice, ComplianceData(0, ""));
        vm.stopPrank();

        BoringOnChainQueue q = new BoringOnChainQueue(
            address(this), address(rolesAuthority), payable(address(boringVault)), address(accountant)
        );
        wrapper.setQueue(address(q));
        assertEq(wrapper.queue(), address(q), "queue set");

        skip(LOCK + 1); // past the lock so the only revert reason is the queue

        vm.prank(alice);
        vm.expectRevert(BoringVaultWrapper.BoringVaultWrapper__RedeemAssetDisabledWithQueue.selector);
        wrapper.redeemAsset(baseAsset, wShares, 0, alice, alice);

        // Plain ERC4626 redeem (returns BV shares) still works — not a bypass.
        vm.prank(alice);
        uint256 bvBack = wrapper.redeem(wShares, alice, alice);
        assertApproxEqAbs(bvBack, 100e18, 1, "redeem to BV shares works under queue");
    }

    function testSetQueueCanBeCleared() public {
        BoringOnChainQueue q = new BoringOnChainQueue(
            address(this), address(rolesAuthority), payable(address(boringVault)), address(accountant)
        );
        wrapper.setQueue(address(q));
        wrapper.setQueue(address(0));
        assertEq(wrapper.queue(), address(0), "queue cleared");

        // redeemAsset re-enabled.
        deal(address(baseAsset), alice, 100e18);
        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), 100e18);
        uint256 wShares = wrapper.depositAsset(baseAsset, 100e18, 0, alice, ComplianceData(0, ""));
        vm.stopPrank();
        skip(LOCK + 1);
        vm.prank(alice);
        uint256 baseOut = wrapper.redeemAsset(baseAsset, wShares, 0, alice, alice);
        assertApproxEqAbs(baseOut, 100e18, 1, "redeemAsset works after queue cleared");
    }

    function testSetQueueRejectsMismatchedVault() public {
        BoringVault decoyVault = new BoringVault(address(this), "Decoy", "DV", 18);
        BoringOnChainQueue badQueue = new BoringOnChainQueue(
            address(this), address(rolesAuthority), payable(address(decoyVault)), address(accountant)
        );
        vm.expectRevert(BoringVaultWrapper.BoringVaultWrapper__BadQueue.selector);
        wrapper.setQueue(address(badQueue));
    }

    // ── No lock when teller period is zero (regression for default config) ─────

    function testNoLockWhenPeriodZero() public {
        teller.setShareLockPeriod(0);
        _giveBVShares(alice, 100e18);
        uint256 wShares = _wrapBV(alice, 100e18);
        assertEq(wrapper.shareUnlockTime(alice), 0, "no lock recorded");

        vm.prank(alice);
        wrapper.redeem(wShares, alice, alice); // succeeds immediately
        assertEq(wrapper.balanceOf(alice), 0, "immediate exit with zero lock period");
    }

    /// @notice The wrapper sources its lock period from the BV's live beforeTransfer
    ///         hook, so it tracks whatever the BV actually enforces -- even if that
    ///         is a different teller than the wrapper's own `teller` reference.
    function testLockSourcedFromLiveBVHookNotTellerField() public {
        // A second teller with a DIFFERENT lock period becomes the BV's hook.
        TellerWithMultiAssetSupport teller2 = new TellerWithMultiAssetSupport(
            address(this), address(boringVault), address(accountant), address(baseAsset)
        );
        teller2.setAuthority(rolesAuthority);
        rolesAuthority.setRoleCapability(
            SETTER_ROLE, address(teller2), TellerWithMultiAssetSupport.setShareLockPeriod.selector, true
        );
        teller2.setShareLockPeriod(2 hours);
        boringVault.setBeforeTransferHook(address(teller2));

        _giveBVShares(alice, 100e18);
        _wrapBV(alice, 100e18);

        // Lock follows the BV's live hook (teller2 = 2h), not the wrapper's teller (1h).
        assertEq(uint256(teller.shareLockPeriod()), 1 hours, "wrapper's teller field still 1h");
        assertEq(wrapper.shareUnlockTime(alice), uint64(block.timestamp) + 2 hours, "lock derived from BV's live hook");
    }

    /// @notice When the BV enforces no lock (no hook wired), the wrapper applies none
    ///         either -- it is always exactly the BV's enforced period.
    function testNoLockWhenBVHookUnset() public {
        boringVault.setBeforeTransferHook(address(0));

        _giveBVShares(alice, 100e18);
        uint256 wShares = _wrapBV(alice, 100e18);
        assertEq(wrapper.shareUnlockTime(alice), 0, "no lock when BV has no hook");

        vm.prank(alice);
        wrapper.redeem(wShares, alice, alice); // immediate exit
        assertEq(wrapper.balanceOf(alice), 0, "exits immediately when BV enforces no lock");
    }

    // =========================================================================
    //          Two-step queue exit: redeem -> BV shares -> queue yourself
    // =========================================================================

    /// @dev Deploy a real BoringQueue, wire the BV beforeTransfer hook (so the BV
    ///      share lock is actually enforced on transfers), allow base-asset
    ///      withdrawals, grant the queue-request role, and attach the queue to the
    ///      wrapper. Returns the queue.
    function _deployAndWireQueue() internal returns (BoringOnChainQueue q) {
        q = new BoringOnChainQueue(
            address(this), address(rolesAuthority), payable(address(boringVault)), address(accountant)
        );

        // Production-like: BV transfers consult the Teller hook (lock + deny + allowlist).
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(boringVault), BoringVault.setBeforeTransferHook.selector, true
        );
        boringVault.setBeforeTransferHook(address(teller));

        // Admin configures the withdraw asset; users may request withdrawals.
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(q), BoringOnChainQueue.updateWithdrawAsset.selector, true);
        rolesAuthority.setRoleCapability(
            QUEUE_USER_ROLE, address(q), BoringOnChainQueue.requestOnChainWithdraw.selector, true
        );
        rolesAuthority.setUserRole(alice, QUEUE_USER_ROLE, true);
        rolesAuthority.setUserRole(carol, QUEUE_USER_ROLE, true);

        // discount fixed at 0, 1d maturity, deadline >= 1d.
        q.updateWithdrawAsset(address(baseAsset), 1 days, 1 days, 0, 0, 0);

        wrapper.setQueue(address(q));
    }

    /// @notice A wrapper user who redeems to BV shares is NOT stamped with a BV-level
    ///         lock (the lock is only set on the public deposit path, never on a
    ///         plain transfer), so they can queue immediately. The holding period was
    ///         already enforced one layer up by the wrapper share lock.
    function testWrapperUserCanQueueImmediatelyAfterRedeem() public {
        BoringOnChainQueue q = _deployAndWireQueue();

        _giveBVShares(alice, 100e18);
        uint256 wShares = _wrapBV(alice, 100e18);

        // Wrapper lock must elapse before alice can redeem to BV shares.
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(BoringVaultWrapper.BoringVaultWrapper__SharesLocked.selector, alice));
        wrapper.redeem(wShares, alice, alice);

        skip(LOCK + 1);

        vm.prank(alice);
        uint256 bvBack = wrapper.redeem(wShares, alice, alice);
        assertApproxEqAbs(bvBack, 100e18, 1, "alice receives BV shares");

        // Receiving BV shares via transfer did NOT stamp a BV-level lock on alice.
        (,,, uint64 aliceBvUnlock) = teller.beforeTransferData(alice);
        assertEq(aliceBvUnlock, 0, "no BV-level lock stamped on wrapper redeemer");

        // She can queue the BV shares immediately.
        vm.startPrank(alice);
        ERC20(address(boringVault)).approve(address(q), bvBack);
        bytes32 requestId = q.requestOnChainWithdraw(address(baseAsset), uint128(bvBack), 0, 3 days);
        vm.stopPrank();

        assertTrue(requestId != bytes32(0), "request created");
        assertEq(boringVault.balanceOf(alice), 0, "BV shares escrowed in queue");
        assertEq(boringVault.balanceOf(address(q)), bvBack, "queue holds the shares");
    }

    /// @notice Contrast: a holder whose BV shares carry an active BV-level lock
    ///         (e.g. from a direct public deposit) CANNOT requestOnChainWithdraw —
    ///         the share transfer into the queue trips the Teller's beforeTransfer
    ///         lock check. It succeeds once the lock elapses.
    function testBvLockedHolderCannotRequestOnChainWithdraw() public {
        BoringOnChainQueue q = _deployAndWireQueue();

        // Carol may use the public deposit path (which stamps the BV share lock).
        rolesAuthority.setRoleCapability(
            DEPOSITOR_ROLE, address(teller), TellerWithMultiAssetSupport.deposit.selector, true
        );
        rolesAuthority.setUserRole(carol, DEPOSITOR_ROLE, true);

        deal(address(baseAsset), carol, 100e18);
        vm.startPrank(carol);
        baseAsset.approve(address(boringVault), 100e18);
        uint256 bvShares = teller.deposit(
            DepositParams(ERC20(address(baseAsset)), 100e18, 0), carol, address(0), ComplianceData(0, "")
        );
        vm.stopPrank();

        // Carol is BV-locked.
        (,,, uint64 carolUnlock) = teller.beforeTransferData(carol);
        assertEq(carolUnlock, uint64(block.timestamp) + LOCK, "carol BV-locked by public deposit");

        // Root cause: the Teller hook rejects moving carol's locked shares into the queue.
        vm.expectRevert(abi.encodeWithSignature("TellerWithMultiAssetSupport__SharesAreLocked()"));
        teller.beforeTransfer(carol, address(q), address(q));

        // Observable effect: the request reverts. The queue pulls shares via solmate
        // SafeTransferLib, which surfaces the failed transfer as TRANSFER_FROM_FAILED.
        vm.startPrank(carol);
        ERC20(address(boringVault)).approve(address(q), bvShares);
        vm.expectRevert(bytes("TRANSFER_FROM_FAILED"));
        q.requestOnChainWithdraw(address(baseAsset), uint128(bvShares), 0, 3 days);
        vm.stopPrank();

        // After the lock elapses, the request succeeds.
        skip(LOCK + 1);
        vm.startPrank(carol);
        bytes32 requestId = q.requestOnChainWithdraw(address(baseAsset), uint128(bvShares), 0, 3 days);
        vm.stopPrank();

        assertTrue(requestId != bytes32(0), "request created after lock elapses");
        assertEq(boringVault.balanceOf(address(q)), bvShares, "queue holds carol's shares");
    }

    // =========================================================================
    //   End-to-end user story: BV lock 1h + wrapper lock 1h + queue.
    //   Alice deposits through the wrapper, waits out the 1h lock, then redeems
    //   and requests the on-chain withdrawal in the SAME tx-block — no extra wait.
    // =========================================================================

    function testEndToEnd_WaitLockThenRedeemAndQueueSameBlock() public {
        BoringOnChainQueue q = _deployAndWireQueue();

        // ── Preconditions: both layers locked at 1 hour, BV enforcement live ──
        assertEq(uint256(teller.shareLockPeriod()), 1 hours, "BV/Teller share lock = 1h");
        assertEq(address(boringVault.hook()), address(teller), "BV beforeTransfer hook is live");
        assertEq(wrapper.queue(), address(q), "queue associated with wrapper");

        // ── Alice deposits THROUGH the wrapper (raw asset path) ───────────────
        uint256 amount = 100e18;
        deal(address(baseAsset), alice, amount);
        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), amount);
        uint256 wShares = wrapper.depositAsset(baseAsset, amount, 0, alice, ComplianceData(0, ""));
        vm.stopPrank();

        uint256 depositTime = block.timestamp;
        assertEq(wrapper.shareUnlockTime(alice), uint64(depositTime + 1 hours), "wrapper locks alice for 1h");

        // ── During the lock, she cannot exit ──────────────────────────────────
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(BoringVaultWrapper.BoringVaultWrapper__SharesLocked.selector, alice));
        wrapper.redeem(wShares, alice, alice);

        // ── Exactly 1 hour passes ─────────────────────────────────────────────
        vm.warp(depositTime + 1 hours);
        uint256 tAfterLock = block.timestamp;

        // ── She redeems to BV shares AND queues the withdrawal in the same block
        vm.startPrank(alice);
        uint256 bvBack = wrapper.redeem(wShares, alice, alice);
        ERC20(address(boringVault)).approve(address(q), bvBack);
        bytes32 requestId = q.requestOnChainWithdraw(address(baseAsset), uint128(bvBack), 0, 3 days);
        vm.stopPrank();

        // ── No additional waiting was needed past the 1h lock ─────────────────
        assertEq(block.timestamp, tAfterLock, "redeem + queue happened with zero extra wait");
        assertApproxEqAbs(bvBack, amount, 1, "alice redeemed her BV shares");
        assertTrue(requestId != bytes32(0), "on-chain withdraw request created right away");
        assertEq(boringVault.balanceOf(alice), 0, "BV shares escrowed into the queue");
        assertEq(boringVault.balanceOf(address(q)), bvBack, "queue holds alice's shares");

        // Sanity: receiving BV shares from the wrapper never stamped a BV-level lock.
        (,,, uint64 aliceBvUnlock) = teller.beforeTransferData(alice);
        assertEq(aliceBvUnlock, 0, "no second lock imposed at the BV layer");
    }
}

/// @notice Minimal contract that pulls BV shares and deposits into the wrapper with an
///         arbitrary receiver -- the shape of a lock-bypass attempt (msg.sender != receiver).
contract DepositHelper {
    BoringVaultWrapper immutable wrapper;
    ERC20 immutable bvShare;

    constructor(BoringVaultWrapper _wrapper, ERC20 _bvShare) {
        wrapper = _wrapper;
        bvShare = _bvShare;
    }

    function depositTo(uint256 assets, address receiver) external returns (uint256) {
        bvShare.approve(address(wrapper), assets);
        return wrapper.deposit(assets, receiver);
    }
}
