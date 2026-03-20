// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {
    TellerWithMultiAssetSupport,
    DepositParams,
    ComplianceData
} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {PrincipalCheckpoint} from "src/base/Roles/TellerWithMultiAssetSupportLib.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract MockWETH is ERC20 {
    constructor() ERC20("Wrapped Ether", "WETH", 18) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract PrincipalHistoryFuzzTest is Test {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    MockWETH public weth;
    BoringVault public vault;
    AccountantWithRateProviders public accountant;
    TellerWithMultiAssetSupport public teller;
    RolesAuthority public roles;

    uint256 internal constant ONE_SHARE = 1e18;

    function setUp() public {
        weth = new MockWETH();
        vault = new BoringVault(address(this), "Boring Vault", "BV", 18);
        accountant = new AccountantWithRateProviders(
            address(this), address(vault), vm.addr(7777), 1e18, address(weth), 1.001e4, 0.999e4, 1, 0, 0
        );
        teller = new TellerWithMultiAssetSupport(address(this), address(vault), address(accountant), address(weth));
        roles = new RolesAuthority(address(this), Authority(address(0)));

        vault.setAuthority(roles);
        accountant.setAuthority(roles);
        teller.setAuthority(roles);

        roles.setRoleCapability(7, address(vault), BoringVault.enter.selector, true);
        roles.setRoleCapability(8, address(vault), BoringVault.exit.selector, true);
        roles.setPublicCapability(address(teller), TellerWithMultiAssetSupport.deposit.selector, true);
        roles.setPublicCapability(address(teller), TellerWithMultiAssetSupport.withdraw.selector, true);
        roles.setUserRole(address(teller), 7, true);
        roles.setUserRole(address(teller), 8, true);
        roles.setUserRole(address(this), 1, true);
        roles.setRoleCapability(1, address(accountant), AccountantWithRateProviders.updateExchangeRate.selector, true);
        roles.setRoleCapability(1, address(accountant), AccountantWithRateProviders.unpause.selector, true);

        teller.updateAssetData(ERC20(address(weth)), true, true, 0);
    }

    // ========================================= HELPERS =========================================

    function _setRate(uint96 rate) internal {
        skip(1);
        accountant.updateExchangeRate(rate);
        accountant.unpause();
    }

    function _boundRate(uint256 seed) internal pure returns (uint96) {
        return uint96(bound(seed, 0.01e18, 100e18));
    }

    function _fundVault(uint256 amount) internal {
        weth.mint(address(vault), amount);
    }

    function _depositAs(address user, uint256 amount) internal returns (uint256 shares) {
        weth.mint(user, amount);
        vm.startPrank(user);
        ERC20(address(weth)).safeApprove(address(vault), amount);
        shares = teller.deposit(DepositParams(ERC20(address(weth)), amount, 0, user), address(0), ComplianceData(0, ""));
        vm.stopPrank();
    }

    function _withdrawAs(address user, uint256 shareAmount) internal {
        vm.prank(user);
        teller.withdraw(ERC20(address(weth)), shareAmount, 0, user);
    }

    function _lastCheckpoint(address user) internal view returns (PrincipalCheckpoint memory) {
        PrincipalCheckpoint[] memory h = teller.getPrincipalHistory(user);
        return h[h.length - 1];
    }

    /// @notice Max deposit amount that keeps withdrawal base value within uint104
    /// when the rate changes from depositRate to withdrawRate.
    /// withdrawal baseValue = amount * withdrawRate / depositRate, must fit in uint104.
    function _maxSafeAmount(uint96 depositRate, uint96 withdrawRate) internal pure returns (uint256) {
        if (withdrawRate <= depositRate) return uint256(type(uint104).max);
        return uint256(type(uint104).max) * uint256(depositRate) / uint256(withdrawRate);
    }

    function _assertMonotonicHistory(address user) internal {
        PrincipalCheckpoint[] memory history = teller.getPrincipalHistory(user);
        for (uint256 i = 1; i < history.length; ++i) {
            assertGe(
                history[i].cumulativeDeposits,
                history[i - 1].cumulativeDeposits,
                "cumulative deposits must be non-decreasing"
            );
            assertGe(
                history[i].cumulativeWithdrawals,
                history[i - 1].cumulativeWithdrawals,
                "cumulative withdrawals must be non-decreasing"
            );
        }
    }

    // ============================== FUZZ: full withdraw => withdrawals >= deposits ==============================

    /// @notice After a full deposit+withdraw cycle at any rate, cumulativeWithdrawals >= cumulativeDeposits.
    /// This is the core invariant that prevents phantom principal in the off-chain reward calculation.
    function testFuzz_FullWithdraw_WithdrawalsGteDeposits(uint256 amount, uint256 rateSeed) external {
        uint96 rate = _boundRate(rateSeed);
        amount = bound(amount, 1e6, 1e30);
        _setRate(rate);
        _fundVault(amount * 2);

        address user = vm.addr(100);
        uint256 shares = _depositAs(user, amount);
        _withdrawAs(user, shares);

        PrincipalCheckpoint memory last = _lastCheckpoint(user);
        assertGe(last.cumulativeWithdrawals, last.cumulativeDeposits, "full withdraw: withdrawals >= deposits");
    }

    // ============================== FUZZ: repeated cycles => no phantom principal ==============================

    /// @notice Repeated deposit+withdraw cycles at any rate never accumulate phantom positive principal.
    /// Rounding asymmetry (deposits round down, withdrawals round up) must prevent dust accumulation.
    function testFuzz_RepeatedCycles_NoPhantomPrincipal(uint256 amount, uint256 rateSeed, uint8 cycleCount) external {
        uint96 rate = _boundRate(rateSeed);
        amount = bound(amount, 1e6, 1e24);
        uint256 cycles = bound(uint256(cycleCount), 1, 20);
        _setRate(rate);

        address user = vm.addr(100);

        for (uint256 i; i < cycles; ++i) {
            _fundVault(amount * 2);
            uint256 shares = _depositAs(user, amount);
            _withdrawAs(user, shares);
        }

        PrincipalCheckpoint memory last = _lastCheckpoint(user);
        assertGe(last.cumulativeWithdrawals, last.cumulativeDeposits, "repeated cycles: no phantom principal");
    }

    // ============================== FUZZ: yield (rate increase) => withdrawals >= deposits ==============================

    /// @notice Deposit at one rate, rate increases (yield), withdraw at higher rate.
    /// Withdrawals must still >= deposits since the user is withdrawing more base value than deposited.
    function testFuzz_Yield_WithdrawalsExceedDeposits(uint256 amount, uint256 depositRateSeed, uint256 withdrawRateSeed)
        external
    {
        uint96 depositRate = _boundRate(depositRateSeed);
        uint96 withdrawRate = uint96(bound(withdrawRateSeed, uint256(depositRate), 100e18));
        // Bound amount so withdrawal base value fits in uint104 (avoids truncation, tested separately)
        uint256 maxSafe = _maxSafeAmount(depositRate, withdrawRate);
        amount = bound(amount, 1e6, maxSafe > 1e6 ? maxSafe : 1e6);

        _setRate(depositRate);
        address user = vm.addr(100);
        uint256 shares = _depositAs(user, amount);

        _setRate(withdrawRate);
        uint256 maxWithdrawValue = shares.mulDivUp(uint256(withdrawRate), ONE_SHARE);
        _fundVault(maxWithdrawValue + 1e18);
        _withdrawAs(user, shares);

        PrincipalCheckpoint memory last = _lastCheckpoint(user);
        assertGe(last.cumulativeWithdrawals, last.cumulativeDeposits, "yield: withdrawals >= deposits");
    }

    // ============================== FUZZ: partial withdraw => principal decreases ==============================

    /// @notice A partial withdrawal must always increase cumulativeWithdrawals without touching cumulativeDeposits.
    function testFuzz_PartialWithdraw_PrincipalDecreases(uint256 amount, uint256 rateSeed, uint256 fractionSeed)
        external
    {
        uint96 rate = _boundRate(rateSeed);
        // Use large enough minimum to guarantee shares >= 2 at max rate (100e18)
        amount = bound(amount, 1e8, 1e30);
        _setRate(rate);
        _fundVault(amount * 2);

        address user = vm.addr(100);
        uint256 shares = _depositAs(user, amount);
        vm.assume(shares >= 2);

        uint256 withdrawShares = bound(fractionSeed, 1, shares - 1);

        PrincipalCheckpoint memory before_ = _lastCheckpoint(user);
        _withdrawAs(user, withdrawShares);
        PrincipalCheckpoint memory after_ = _lastCheckpoint(user);

        assertGt(after_.cumulativeWithdrawals, before_.cumulativeWithdrawals, "partial: withdrawals increased");
        assertEq(after_.cumulativeDeposits, before_.cumulativeDeposits, "partial: deposits unchanged");
    }

    // ============================== FUZZ: transfer receiver => zero deposits ==============================

    /// @notice A user who receives shares via transfer must never get cumulativeDeposits inflated.
    /// Their principal remains 0, so they earn no incentive rewards on transferred shares.
    function testFuzz_Transfer_ReceiverZeroDeposits(uint256 amount, uint256 transferSeed) external {
        amount = bound(amount, 1e6, 1e30);
        vault.setBeforeTransferHook(address(teller));

        address alice = vm.addr(101);
        address bob = vm.addr(102);

        uint256 shares = _depositAs(alice, amount);
        uint256 transferAmount = bound(transferSeed, 1, shares);

        vm.prank(alice);
        vault.transfer(bob, transferAmount);

        PrincipalCheckpoint memory bobLast = _lastCheckpoint(bob);
        assertEq(bobLast.cumulativeDeposits, 0, "transfer receiver: zero deposits");
        assertEq(bobLast.cumulativeWithdrawals, 0, "transfer receiver: zero withdrawals");
        assertGt(vault.balanceOf(bob), 0, "bob holds shares");
    }

    // ============================== FUZZ: transfer + full withdraw => no underflow ==============================

    /// @notice User receives shares via transfer (never deposited), then withdraws everything.
    /// cumulativeWithdrawals > cumulativeDeposits (which is 0). Must not revert.
    function testFuzz_TransferThenWithdraw_NoUnderflow(uint256 amount, uint256 rateSeed) external {
        uint96 rate = _boundRate(rateSeed);
        amount = bound(amount, 1e6, 1e30);
        _setRate(rate);
        vault.setBeforeTransferHook(address(teller));

        address alice = vm.addr(101);
        address bob = vm.addr(102);

        uint256 shares = _depositAs(alice, amount);
        vm.prank(alice);
        vault.transfer(bob, shares);

        // Bob withdraws everything — never deposited, so withdrawals > deposits
        uint256 maxWithdrawValue = shares.mulDivUp(uint256(rate), ONE_SHARE);
        _fundVault(maxWithdrawValue + 1e18);
        _withdrawAs(bob, shares);

        PrincipalCheckpoint memory bobLast = _lastCheckpoint(bob);
        assertEq(bobLast.cumulativeDeposits, 0, "bob never deposited");
        assertGt(bobLast.cumulativeWithdrawals, 0, "bob withdrew nonzero base value");
    }

    // ============================== FUZZ: mixed operations => monotonic checkpoints ==============================

    /// @notice Deposits, transfers, rate changes, and withdrawals: cumulative values never decrease.
    function testFuzz_MixedOps_MonotonicCheckpoints(
        uint256 amount,
        uint256 depositRateSeed,
        uint256 withdrawRateSeed,
        uint256 transferFractionSeed
    ) external {
        uint96 depositRate = _boundRate(depositRateSeed);
        uint96 withdrawRate = _boundRate(withdrawRateSeed);
        // Bob can accumulate up to 1.5x amount in shares via transfer, so divide by 2 for safety
        uint256 maxSafe = _maxSafeAmount(depositRate, withdrawRate) / 2;
        if (maxSafe < 1e8) maxSafe = 1e8;
        amount = bound(amount, 1e8, maxSafe > 1e28 ? 1e28 : maxSafe);

        _setRate(depositRate);
        vault.setBeforeTransferHook(address(teller));

        address alice = vm.addr(101);
        address bob = vm.addr(102);

        uint256 aliceShares = _depositAs(alice, amount);
        _depositAs(bob, amount / 2);

        // Alice transfers some shares to Bob
        uint256 transferShares = bound(transferFractionSeed, 0, aliceShares);
        if (transferShares > 0) {
            vm.prank(alice);
            vault.transfer(bob, transferShares);
        }

        // Rate changes, then full withdrawals
        _setRate(withdrawRate);
        uint256 maxRate = depositRate > withdrawRate ? depositRate : withdrawRate;
        uint256 totalShares = vault.totalSupply();
        _fundVault(totalShares.mulDivUp(uint256(maxRate), ONE_SHARE) + 1e18);

        uint256 aliceBal = vault.balanceOf(alice);
        uint256 bobBal = vault.balanceOf(bob);
        if (aliceBal > 0) _withdrawAs(alice, aliceBal);
        if (bobBal > 0) _withdrawAs(bob, bobBal);

        _assertMonotonicHistory(alice);
        _assertMonotonicHistory(bob);
    }

    // ============================== FUZZ: repeated cycles with varying rates ==============================

    /// @notice Each cycle deposits and withdraws at the same rate, but the rate changes between cycles.
    /// Since each individual cycle satisfies w_up >= d_down at its own rate, the cumulative invariant holds.
    function testFuzz_RepeatedCycles_VaryingRates_NoPhantomPrincipal(
        uint256 amount,
        uint256 rateSeed1,
        uint256 rateSeed2,
        uint256 rateSeed3,
        uint8 cycleCount
    ) external {
        uint96[3] memory rates = [_boundRate(rateSeed1), _boundRate(rateSeed2), _boundRate(rateSeed3)];
        amount = bound(amount, 1e6, 1e24);
        uint256 cycles = bound(uint256(cycleCount), 2, 15);

        address user = vm.addr(100);

        for (uint256 i; i < cycles; ++i) {
            uint96 rate = rates[i % 3];
            _setRate(rate);
            _fundVault(amount * 2);
            uint256 shares = _depositAs(user, amount);
            _withdrawAs(user, shares);
        }

        PrincipalCheckpoint memory last = _lastCheckpoint(user);
        assertGe(last.cumulativeWithdrawals, last.cumulativeDeposits, "varying-rate cycles: no phantom principal");
        _assertMonotonicHistory(user);
    }

    // ============================== FUZZ: rate decrease => no panic ==============================

    /// @notice Deposit at a higher rate, rate drops, then full withdraw at lower rate.
    /// cumulativeWithdrawals may be < cumulativeDeposits (real loss), but must not panic or underflow.
    function testFuzz_FullWithdraw_RateDecrease_NoPanic(uint256 amount, uint256 highRateSeed, uint256 lowRateSeed)
        external
    {
        uint96 highRate = uint96(bound(highRateSeed, 0.02e18, 100e18));
        uint96 lowRate = uint96(bound(lowRateSeed, 0.01e18, uint256(highRate) - 1));
        amount = bound(amount, 1e6, uint256(type(uint104).max));

        _setRate(highRate);
        address user = vm.addr(100);
        uint256 shares = _depositAs(user, amount);

        _setRate(lowRate);
        uint256 maxWithdrawValue = shares.mulDivUp(uint256(lowRate), ONE_SHARE);
        _fundVault(maxWithdrawValue + 1e18);
        _withdrawAs(user, shares);

        // No panic/revert is the primary assertion. Also verify monotonicity.
        _assertMonotonicHistory(user);

        // Verify the math: withdrawal base value reflects the lower rate
        PrincipalCheckpoint memory last = _lastCheckpoint(user);
        assertGt(last.cumulativeWithdrawals, 0, "withdrawal recorded");
        assertGt(last.cumulativeDeposits, 0, "deposit recorded");
    }

    // ============================== FUZZ: multiple deposits at different rates, full withdraw ==============================

    /// @notice Accumulate deposits at 3 different rates, then withdraw everything at a 4th rate.
    /// When the withdrawal rate >= max deposit rate, the invariant w >= d must hold.
    function testFuzz_MultipleDeposits_DifferentRates_FullWithdraw(
        uint256 amount,
        uint256 rateSeed1,
        uint256 rateSeed2,
        uint256 withdrawRateSeed
    ) external {
        uint96[2] memory dRates = [_boundRate(rateSeed1), _boundRate(rateSeed2)];
        uint96 maxDRate = dRates[0] > dRates[1] ? dRates[0] : dRates[1];
        uint96 withdrawRate = uint96(bound(withdrawRateSeed, uint256(maxDRate), 100e18));

        // Bound amount so cumulative fits in uint104
        uint256 effectiveMax = _maxSafeAmount(dRates[0], withdrawRate);
        {
            uint256 m2 = _maxSafeAmount(dRates[1], withdrawRate);
            if (m2 < effectiveMax) effectiveMax = m2;
        }
        effectiveMax = effectiveMax / 2;
        if (effectiveMax < 1e6) effectiveMax = 1e6;
        amount = bound(amount, 1e6, effectiveMax > 1e24 ? 1e24 : effectiveMax);

        address user = vm.addr(100);

        // 2 deposits at different rates, track total shares
        _setRate(dRates[0]);
        uint256 totalShares = _depositAs(user, amount);
        _setRate(dRates[1]);
        totalShares += _depositAs(user, amount);

        // Withdraw everything at withdrawRate >= maxDepositRate
        _setRate(withdrawRate);
        _fundVault(totalShares.mulDivUp(uint256(withdrawRate), ONE_SHARE) + 1e18);
        _withdrawAs(user, totalShares);

        PrincipalCheckpoint memory last = _lastCheckpoint(user);
        assertGe(
            last.cumulativeWithdrawals, last.cumulativeDeposits, "multi-deposit full withdraw at higher rate: w >= d"
        );
        _assertMonotonicHistory(user);
    }

    // ============================== FUZZ: partial withdrawals across rate changes ==============================

    /// @notice Interleave partial withdrawals with rate changes. Verify monotonicity and no underflow.
    function testFuzz_PartialWithdraws_AcrossRateChanges_Monotonic(
        uint256 amount,
        uint256 rateSeed1,
        uint256 rateSeed2,
        uint256 rateSeed3
    ) external {
        uint96 r1 = _boundRate(rateSeed1);
        uint96 r2 = _boundRate(rateSeed2);
        uint96 r3 = _boundRate(rateSeed3);
        // Keep amount conservative to avoid uint104 overflow across rate changes
        amount = bound(amount, 1e8, 1e20);

        _setRate(r1);
        address user = vm.addr(100);
        uint256 shares = _depositAs(user, amount);
        vm.assume(shares >= 4);

        // Fund vault generously based on max rate to cover all withdrawals
        uint96 maxRate = r1 > r2 ? (r1 > r3 ? r1 : r3) : (r2 > r3 ? r2 : r3);
        _fundVault(shares.mulDivUp(uint256(maxRate), ONE_SHARE) + 1e18);

        // Partial withdraw at r1
        _withdrawAs(user, shares / 4);

        // Rate changes, another partial withdraw
        _setRate(r2);
        _withdrawAs(user, shares / 4);

        // Rate changes again, withdraw remainder
        _setRate(r3);
        uint256 remaining = vault.balanceOf(user);
        if (remaining > 0) {
            _withdrawAs(user, remaining);
        }

        _assertMonotonicHistory(user);

        // After full withdrawal, verify no shares remain
        assertEq(vault.balanceOf(user), 0, "all shares withdrawn");
    }

    // ============================== FUZZ: deposit+withdraw same non-trivial rate, repeated with different amounts ==============================

    /// @notice Varying deposit amounts at the same non-trivial rate. Tests that rounding dust
    /// from different-sized deposits doesn't accumulate into phantom principal.
    function testFuzz_VaryingAmounts_SameRate_NoPhantomPrincipal(
        uint256 amountSeed1,
        uint256 amountSeed2,
        uint256 amountSeed3,
        uint256 rateSeed
    ) external {
        uint96 rate = _boundRate(rateSeed);
        uint256 a1 = bound(amountSeed1, 1e6, 1e24);
        uint256 a2 = bound(amountSeed2, 1e6, 1e24);
        uint256 a3 = bound(amountSeed3, 1e6, 1e24);

        _setRate(rate);
        address user = vm.addr(100);

        // Cycle 1
        _fundVault(a1 * 2);
        uint256 s1 = _depositAs(user, a1);
        _withdrawAs(user, s1);

        // Cycle 2
        _fundVault(a2 * 2);
        uint256 s2 = _depositAs(user, a2);
        _withdrawAs(user, s2);

        // Cycle 3
        _fundVault(a3 * 2);
        uint256 s3 = _depositAs(user, a3);
        _withdrawAs(user, s3);

        PrincipalCheckpoint memory last = _lastCheckpoint(user);
        assertGe(last.cumulativeWithdrawals, last.cumulativeDeposits, "varying amounts same rate: no phantom principal");
    }

    // ============================== FUZZ: extreme rate swing (0.01x to 100x) ==============================

    /// @notice Deposit at minimum rate, withdraw at maximum rate — 10,000x swing.
    /// Tests that the invariant holds even under extreme rate appreciation.
    function testFuzz_ExtremeRateSwing_UpInvariant(uint256 amount) external {
        amount = bound(amount, 1e6, 1e18);
        uint96 lowRate = 0.01e18;
        uint96 highRate = 100e18;

        _setRate(lowRate);
        address user = vm.addr(100);
        uint256 shares = _depositAs(user, amount);

        _setRate(highRate);
        uint256 needed = shares.mulDivUp(uint256(highRate), ONE_SHARE);
        _fundVault(needed + 1e18);
        _withdrawAs(user, shares);

        PrincipalCheckpoint memory last = _lastCheckpoint(user);
        assertGe(last.cumulativeWithdrawals, last.cumulativeDeposits, "extreme swing up: w >= d");
    }

    /// @notice Deposit at maximum rate, withdraw at minimum rate — 10,000x drop.
    /// The invariant w >= d will NOT hold (real loss). Verify no panic.
    function testFuzz_ExtremeRateSwing_DownNoPanic(uint256 amount) external {
        amount = bound(amount, 1e6, 1e18);
        uint96 highRate = 100e18;
        uint96 lowRate = 0.01e18;

        _setRate(highRate);
        address user = vm.addr(100);
        uint256 shares = _depositAs(user, amount);

        _setRate(lowRate);
        uint256 needed = shares.mulDivUp(uint256(lowRate), ONE_SHARE);
        _fundVault(needed + 1e18);
        _withdrawAs(user, shares);

        PrincipalCheckpoint memory last = _lastCheckpoint(user);
        // Real loss: deposit recorded at high rate, withdrawal at low rate
        assertGt(last.cumulativeDeposits, last.cumulativeWithdrawals, "extreme swing down: real loss");
        _assertMonotonicHistory(user);
    }

    // ============================== FUZZ: double-rounding boundary amounts ==============================

    /// @notice Rates that don't divide evenly into 1e18 cause maximum rounding loss.
    /// Tests rate = 3e18 (1/3 ratio) which is pathological for integer division.
    function testFuzz_PathologicalRate_ThirdsNoPhantom(uint256 amount) external {
        uint96 rate = 3e18;
        amount = bound(amount, 3, 1e24);

        _setRate(rate);
        _fundVault(amount * 2);

        address user = vm.addr(100);
        uint256 shares = _depositAs(user, amount);
        if (shares == 0) return; // dust deposit, skip
        _withdrawAs(user, shares);

        PrincipalCheckpoint memory last = _lastCheckpoint(user);
        assertGe(last.cumulativeWithdrawals, last.cumulativeDeposits, "rate=3: w >= d");
    }

    /// @notice Rate = 7e18 (1/7 ratio) — another pathological case for rounding.
    function testFuzz_PathologicalRate_SeventhsNoPhantom(uint256 amount) external {
        uint96 rate = 7e18;
        amount = bound(amount, 7, 1e24);

        _setRate(rate);
        _fundVault(amount * 2);

        address user = vm.addr(100);
        uint256 shares = _depositAs(user, amount);
        if (shares == 0) return;
        _withdrawAs(user, shares);

        PrincipalCheckpoint memory last = _lastCheckpoint(user);
        assertGe(last.cumulativeWithdrawals, last.cumulativeDeposits, "rate=7: w >= d");
    }

    /// @notice Rate that's 1 wei above 1e18. Minimal deviation from 1:1 to test rounding sensitivity.
    function testFuzz_RateOneWeiAboveUnity(uint256 amount) external {
        uint96 rate = uint96(1e18 + 1);
        amount = bound(amount, 1, 1e24);

        _setRate(rate);
        _fundVault(amount * 2);

        address user = vm.addr(100);
        uint256 shares = _depositAs(user, amount);
        if (shares == 0) return;
        _withdrawAs(user, shares);

        PrincipalCheckpoint memory last = _lastCheckpoint(user);
        assertGe(last.cumulativeWithdrawals, last.cumulativeDeposits, "rate=1e18+1: w >= d");
    }

    // ============================== FUZZ: dust deposits (near-zero shares) ==============================

    /// @notice Very small deposits that produce 0 or 1 share. These are the rounding worst case.
    /// At high rates, small amounts can round to 0 shares entirely.
    function testFuzz_DustDeposit_ZeroShareBehavior(uint256 amount, uint256 rateSeed) external {
        uint96 rate = uint96(bound(rateSeed, 1e18, 100e18));
        // Amount small enough to potentially round to 0 shares
        amount = bound(amount, 1, uint256(rate) / 1e18);

        _setRate(rate);
        address user = vm.addr(100);
        weth.mint(user, amount);
        vm.startPrank(user);
        ERC20(address(weth)).safeApprove(address(vault), amount);
        uint256 shares =
            teller.deposit(DepositParams(ERC20(address(weth)), amount, 0, user), address(0), ComplianceData(0, ""));
        vm.stopPrank();

        if (shares == 0) {
            // Zero-share deposit: checkpoint should still be created but with 0 baseValue
            PrincipalCheckpoint[] memory h = teller.getPrincipalHistory(user);
            if (h.length > 0) {
                assertEq(h[h.length - 1].cumulativeDeposits, 0, "zero-share deposit: 0 principal");
            }
        } else {
            // Got shares, verify normal invariant
            _fundVault(amount * 100);
            _withdrawAs(user, shares);
            PrincipalCheckpoint memory last = _lastCheckpoint(user);
            assertGe(last.cumulativeWithdrawals, last.cumulativeDeposits, "dust deposit: w >= d");
        }
    }

    // ============================== FUZZ: single share deposit/withdraw ==============================

    /// @notice Deposit exactly 1 share worth at various rates. This is the minimal non-zero deposit.
    function testFuzz_SingleShare_NoPhantomPrincipal(uint256 rateSeed) external {
        uint96 rate = _boundRate(rateSeed);
        // Amount that produces exactly 1 share: need amount >= rate/1e18 (rounded up)
        uint256 amount = (uint256(rate) + 1e18 - 1) / 1e18;

        _setRate(rate);
        _fundVault(amount * 10);

        address user = vm.addr(100);
        uint256 shares = _depositAs(user, amount);
        // Should get at least 1 share
        assertGe(shares, 1, "at least 1 share");
        _withdrawAs(user, shares);

        PrincipalCheckpoint memory last = _lastCheckpoint(user);
        assertGe(last.cumulativeWithdrawals, last.cumulativeDeposits, "single share: w >= d");
    }

    // ============================== FUZZ: same-block multi-operations ==============================

    /// @notice Multiple deposits in the same block (same timestamp). Each creates a separate
    /// checkpoint entry. Verify cumulative accounting is correct.
    function testFuzz_SameBlock_MultiDeposit_ThenFullWithdraw(uint256 a1Seed, uint256 a2Seed, uint256 rateSeed)
        external
    {
        uint96 rate = _boundRate(rateSeed);
        uint256 a1 = bound(a1Seed, 1e6, 1e20);
        uint256 a2 = bound(a2Seed, 1e6, 1e20);

        _setRate(rate);
        address user = vm.addr(100);

        // Two deposits in same block (no skip)
        uint256 s1 = _depositAs(user, a1);
        uint256 s2 = _depositAs(user, a2);

        // Both checkpoints should have same timestamp
        PrincipalCheckpoint[] memory h = teller.getPrincipalHistory(user);
        assertEq(h.length, 2, "two checkpoints");
        assertEq(h[0].timestamp, h[1].timestamp, "same timestamp");
        assertGt(h[1].cumulativeDeposits, h[0].cumulativeDeposits, "cumulative increased");

        // Full withdraw
        _fundVault((s1 + s2).mulDivUp(uint256(rate), ONE_SHARE) + 1e18);
        _withdrawAs(user, s1 + s2);

        PrincipalCheckpoint memory last = _lastCheckpoint(user);
        assertGe(last.cumulativeWithdrawals, last.cumulativeDeposits, "same-block multi-deposit: w >= d");
    }

    // ============================== FUZZ: transfer out then fresh deposit+withdraw ==============================

    /// @notice Sender transfers all shares, then makes a fresh deposit and withdraws.
    /// Cumulative deposits include BOTH the old and new deposit. After withdrawing only
    /// the new shares, w < d is expected (the transferred shares inflate d).
    function testFuzz_TransferOut_ThenDeposit_ResidualPrincipal(uint256 amount, uint256 rateSeed) external {
        uint96 rate = _boundRate(rateSeed);
        amount = bound(amount, 1e6, 1e24);

        _setRate(rate);
        vault.setBeforeTransferHook(address(teller));

        address alice = vm.addr(101);
        address bob = vm.addr(102);

        // Alice deposits and transfers ALL to Bob
        uint256 shares1 = _depositAs(alice, amount);
        vm.prank(alice);
        vault.transfer(bob, shares1);

        assertEq(vault.balanceOf(alice), 0, "alice has 0 shares after transfer");

        // Alice deposits fresh
        uint256 shares2 = _depositAs(alice, amount);
        _fundVault(shares2.mulDivUp(uint256(rate), ONE_SHARE) + 1e18);
        _withdrawAs(alice, shares2);

        PrincipalCheckpoint memory last = _lastCheckpoint(alice);
        // Alice's cumulative deposits include BOTH deposits, but she only withdrew the second.
        // So cumulativeDeposits > cumulativeWithdrawals — this is expected, not a bug.
        assertGt(last.cumulativeDeposits, 0, "deposits include both");
        _assertMonotonicHistory(alice);
    }

    // ============================== FUZZ: transfer receiver deposits then withdraws all ==============================

    /// @notice Bob receives shares via transfer, then deposits fresh, then withdraws everything.
    /// His cumulativeDeposits only reflects his direct deposit, not the transfer.
    function testFuzz_TransferReceiver_DepositThenWithdrawAll(uint256 amount, uint256 rateSeed) external {
        uint96 rate = _boundRate(rateSeed);
        amount = bound(amount, 1e6, 1e24);

        _setRate(rate);
        vault.setBeforeTransferHook(address(teller));

        address alice = vm.addr(101);
        address bob = vm.addr(102);

        uint256 aliceShares = _depositAs(alice, amount);
        vm.prank(alice);
        vault.transfer(bob, aliceShares);

        // Bob deposits fresh
        _depositAs(bob, amount);
        uint256 totalBobShares = vault.balanceOf(bob);

        _fundVault(totalBobShares.mulDivUp(uint256(rate), ONE_SHARE) + 1e18);
        _withdrawAs(bob, totalBobShares);

        PrincipalCheckpoint memory last = _lastCheckpoint(bob);
        // Bob's withdrawal base value covers transferred + deposited shares, but
        // his cumulativeDeposits only reflects the direct deposit
        assertGt(last.cumulativeWithdrawals, last.cumulativeDeposits, "receiver: w > d due to transfer");
        _assertMonotonicHistory(bob);
    }

    // ============================== FUZZ: many cycles at pathological rate ==============================

    /// @notice 50 deposit+withdraw cycles at a rate that maximizes rounding per operation.
    /// Verifies rounding dust stays bounded and doesn't accumulate into phantom principal.
    function testFuzz_ManyCycles_PathologicalRate(uint256 amount, uint256 rateSeed) external {
        // Use rates that are worst for rounding: primes * 1e18
        uint96 rate = uint96(bound(rateSeed, 0.01e18, 100e18));
        amount = bound(amount, 1e8, 1e20);

        _setRate(rate);
        address user = vm.addr(100);

        for (uint256 i; i < 50; ++i) {
            _fundVault(amount * 2);
            uint256 shares = _depositAs(user, amount);
            if (shares == 0) continue;
            _withdrawAs(user, shares);
        }

        PrincipalCheckpoint memory last = _lastCheckpoint(user);
        assertGe(last.cumulativeWithdrawals, last.cumulativeDeposits, "50 cycles: no phantom principal");

        // Verify the overshoot is bounded: at most 1 wei per cycle
        uint256 overshoot = last.cumulativeWithdrawals - last.cumulativeDeposits;
        assertLe(overshoot, 50, "overshoot bounded by cycle count");
    }

    // ============================== FUZZ: alternating rate direction between cycles ==============================

    /// @notice Rate oscillates up and down between deposit/withdraw cycles.
    /// Each cycle deposits and withdraws at the SAME rate, but rate alternates between two values.
    function testFuzz_AlternatingRates_NoPhantomPrincipal(uint256 amount, uint256 rateSeed1, uint256 rateSeed2)
        external
    {
        uint96 rHigh = uint96(bound(rateSeed1, 1e18, 100e18));
        uint96 rLow = uint96(bound(rateSeed2, 0.01e18, uint256(rHigh)));
        amount = bound(amount, 1e6, 1e22);

        address user = vm.addr(100);

        for (uint256 i; i < 10; ++i) {
            uint96 rate = (i % 2 == 0) ? rHigh : rLow;
            _setRate(rate);
            _fundVault(amount * 2);
            uint256 shares = _depositAs(user, amount);
            if (shares == 0) continue;
            _withdrawAs(user, shares);
        }

        PrincipalCheckpoint memory last = _lastCheckpoint(user);
        assertGe(last.cumulativeWithdrawals, last.cumulativeDeposits, "alternating rates: no phantom principal");
    }

    // ============================== FUZZ: deposit at rate R, partial withdraw at R, rate changes, withdraw rest ==============================

    /// @notice Split withdrawal across rate change boundary. First half at deposit rate,
    /// second half at different rate. Tests that partial withdraw rounding at each rate
    /// doesn't break the cumulative invariant when combined.
    function testFuzz_SplitWithdrawAcrossRateChange_SameOrHigher(uint256 amount, uint256 rateSeed1, uint256 rateSeed2)
        external
    {
        uint96 r1 = _boundRate(rateSeed1);
        uint96 r2 = uint96(bound(rateSeed2, uint256(r1), 100e18)); // r2 >= r1
        amount = bound(amount, 1e8, 1e22);

        _setRate(r1);
        address user = vm.addr(100);
        uint256 shares = _depositAs(user, amount);
        vm.assume(shares >= 2);

        _fundVault(shares.mulDivUp(uint256(r2), ONE_SHARE) + 1e18);

        // Withdraw half at r1
        uint256 half = shares / 2;
        _withdrawAs(user, half);

        // Rate changes up, withdraw rest
        _setRate(r2);
        uint256 remaining = vault.balanceOf(user);
        _withdrawAs(user, remaining);

        PrincipalCheckpoint memory last = _lastCheckpoint(user);
        // r2 >= r1: second half withdrawal at higher rate, should satisfy invariant
        assertGe(last.cumulativeWithdrawals, last.cumulativeDeposits, "split withdraw (rate up): w >= d");
    }

    // ============================== FUZZ: deposit+withdraw rounding delta never exceeds 1 wei ==============================

    /// @notice For a single deposit+withdraw at the same rate, the difference between
    /// cumulativeWithdrawals and cumulativeDeposits should be exactly 0 or 1 wei.
    /// This verifies the rounding is tight, not wastefully overcompensating.
    function testFuzz_SingleCycle_RoundingDelta_AtMostOne(uint256 amount, uint256 rateSeed) external {
        uint96 rate = _boundRate(rateSeed);
        amount = bound(amount, 1e6, 1e28);

        _setRate(rate);
        _fundVault(amount * 2);

        address user = vm.addr(100);
        uint256 shares = _depositAs(user, amount);
        vm.assume(shares > 0);
        _withdrawAs(user, shares);

        PrincipalCheckpoint memory last = _lastCheckpoint(user);
        uint256 delta = last.cumulativeWithdrawals - last.cumulativeDeposits;
        assertLe(delta, 1, "single cycle: rounding delta is at most 1 wei");
    }

    // ============================== FUZZ: two users same deposit, verify checkpoint isolation ==============================

    /// @notice Two users deposit the same amount at the same rate. Verify their checkpoints
    /// are completely independent — one user's operations don't affect the other.
    function testFuzz_TwoUsers_CheckpointIsolation(uint256 amount, uint256 rateSeed) external {
        uint96 rate = _boundRate(rateSeed);
        amount = bound(amount, 1e6, 1e24);

        _setRate(rate);
        _fundVault(amount * 10);

        address alice = vm.addr(101);
        address bob = vm.addr(102);

        uint256 aliceShares = _depositAs(alice, amount);
        uint256 bobShares = _depositAs(bob, amount);

        // Only Alice withdraws
        _withdrawAs(alice, aliceShares);

        PrincipalCheckpoint memory aliceLast = _lastCheckpoint(alice);
        PrincipalCheckpoint memory bobLast = _lastCheckpoint(bob);

        // Alice: w >= d after full withdraw
        assertGe(aliceLast.cumulativeWithdrawals, aliceLast.cumulativeDeposits, "alice: w >= d");
        // Bob: no withdrawals yet
        assertEq(bobLast.cumulativeWithdrawals, 0, "bob: no withdrawals");
        assertGt(bobLast.cumulativeDeposits, 0, "bob: has deposits");

        // Bob withdraws
        _withdrawAs(bob, bobShares);
        bobLast = _lastCheckpoint(bob);
        assertGe(bobLast.cumulativeWithdrawals, bobLast.cumulativeDeposits, "bob: w >= d");
        // Same deposits and withdrawals for both (same amount, same rate)
        assertEq(aliceLast.cumulativeDeposits, bobLast.cumulativeDeposits, "same deposit baseValue");
        assertEq(aliceLast.cumulativeWithdrawals, bobLast.cumulativeWithdrawals, "same withdrawal baseValue");
    }

    // ============================== FUZZ: withdraw exactly 1 share at various rates ==============================

    /// @notice Withdrawing a single share should always produce a valid checkpoint
    /// and never cause arithmetic issues regardless of rate.
    function testFuzz_WithdrawSingleShare_NoPanic(uint256 amount, uint256 rateSeed) external {
        uint96 rate = _boundRate(rateSeed);
        amount = bound(amount, 1e8, 1e24);

        _setRate(rate);
        _fundVault(amount * 2);

        address user = vm.addr(100);
        uint256 shares = _depositAs(user, amount);
        vm.assume(shares >= 2);

        // Withdraw exactly 1 share
        _withdrawAs(user, 1);

        PrincipalCheckpoint memory last = _lastCheckpoint(user);
        assertGt(last.cumulativeWithdrawals, 0, "1-share withdraw recorded");
        _assertMonotonicHistory(user);
    }

    // ============================== FUZZ: deposit rounding loss is conservative ==============================

    /// @notice Verify that the deposit checkpoint baseValue is always <= the actual deposit amount.
    /// This confirms rounding is conservative (records less, not more).
    function testFuzz_DepositBaseValue_NeverExceedsAmount(uint256 amount, uint256 rateSeed) external {
        uint96 rate = _boundRate(rateSeed);
        amount = bound(amount, 1, 1e28);

        _setRate(rate);

        address user = vm.addr(100);
        weth.mint(user, amount);
        vm.startPrank(user);
        ERC20(address(weth)).safeApprove(address(vault), amount);
        teller.deposit(DepositParams(ERC20(address(weth)), amount, 0, user), address(0), ComplianceData(0, ""));
        vm.stopPrank();

        PrincipalCheckpoint[] memory h = teller.getPrincipalHistory(user);
        if (h.length > 0) {
            assertLe(uint256(h[h.length - 1].cumulativeDeposits), amount, "deposit baseValue <= actual deposit amount");
        }
    }

    // ============================== FUZZ: rapid deposit+withdraw+deposit+withdraw same block ==============================

    /// @notice Two full cycles in the same block at the same rate.
    /// Tests that same-timestamp checkpoints accumulate correctly.
    function testFuzz_TwoCyclesSameBlock(uint256 amount, uint256 rateSeed) external {
        uint96 rate = _boundRate(rateSeed);
        amount = bound(amount, 1e6, 1e22);

        _setRate(rate);
        _fundVault(amount * 10);

        address user = vm.addr(100);

        // Cycle 1 (no time advance)
        uint256 s1 = _depositAs(user, amount);
        if (s1 > 0) _withdrawAs(user, s1);

        // Cycle 2 (same block)
        uint256 s2 = _depositAs(user, amount);
        if (s2 > 0) _withdrawAs(user, s2);

        PrincipalCheckpoint memory last = _lastCheckpoint(user);
        assertGe(last.cumulativeWithdrawals, last.cumulativeDeposits, "two cycles same block: w >= d");
    }

    // ============================== SHARE PRICE TESTS ==============================

    /// @notice Deposit checkpoint records the current exchange rate as sharePrice.
    function testFuzz_SharePrice_RecordedOnDeposit(uint256 amount, uint256 rateSeed) external {
        uint96 rate = _boundRate(rateSeed);
        amount = bound(amount, 1e6, 1e28);
        _setRate(rate);

        address user = vm.addr(100);
        _depositAs(user, amount);

        PrincipalCheckpoint memory cp = _lastCheckpoint(user);
        assertEq(cp.sharePrice, uint256(rate), "deposit checkpoint must record current rate");
    }

    /// @notice Withdrawal checkpoint records the rate at withdrawal time, not deposit time.
    function testFuzz_SharePrice_RecordedOnWithdraw(uint256 amount, uint256 depositRateSeed, uint256 withdrawRateSeed)
        external
    {
        uint96 depositRate = _boundRate(depositRateSeed);
        uint96 withdrawRate = _boundRate(withdrawRateSeed);
        amount = bound(amount, 1e6, 1e24);

        _setRate(depositRate);
        address user = vm.addr(100);
        uint256 shares = _depositAs(user, amount);

        _setRate(withdrawRate);
        _fundVault(shares * 200);
        _withdrawAs(user, shares);

        PrincipalCheckpoint memory last = _lastCheckpoint(user);
        assertEq(last.sharePrice, uint256(withdrawRate), "withdraw checkpoint must record withdrawal rate");
    }

    /// @notice Each checkpoint in a multi-operation sequence records the rate at its own time.
    function testFuzz_SharePrice_TracksRateChanges(uint256 amount, uint256 rateSeed1, uint256 rateSeed2) external {
        uint96 r1 = _boundRate(rateSeed1);
        uint96 r2 = _boundRate(rateSeed2);
        amount = bound(amount, 1e6, 1e22);

        address user = vm.addr(100);

        _setRate(r1);
        _depositAs(user, amount);

        _setRate(r2);
        _depositAs(user, amount);

        PrincipalCheckpoint[] memory h = teller.getPrincipalHistory(user);
        assertEq(h.length, 2, "two checkpoints");
        assertEq(h[0].sharePrice, uint256(r1), "first checkpoint has first rate");
        assertEq(h[1].sharePrice, uint256(r2), "second checkpoint has second rate");
    }

    /// @notice Transfer checkpoint records current rate as sharePrice.
    function testFuzz_SharePrice_RecordedOnTransfer(uint256 amount, uint256 depositRateSeed, uint256 transferRateSeed)
        external
    {
        uint96 depositRate = _boundRate(depositRateSeed);
        uint96 transferRate = _boundRate(transferRateSeed);
        amount = bound(amount, 1e6, 1e24);

        _setRate(depositRate);
        vault.setBeforeTransferHook(address(teller));

        address alice = vm.addr(101);
        address bob = vm.addr(102);

        uint256 shares = _depositAs(alice, amount);

        _setRate(transferRate);
        vm.prank(alice);
        vault.transfer(bob, shares);

        // Bob's checkpoint from receiving the transfer should have the transfer-time rate
        PrincipalCheckpoint memory bobCp = _lastCheckpoint(bob);
        assertEq(bobCp.sharePrice, uint256(transferRate), "transfer checkpoint records transfer-time rate");

        // Alice's latest checkpoint (from the transfer) should also have the transfer-time rate
        PrincipalCheckpoint memory aliceCp = _lastCheckpoint(alice);
        assertEq(aliceCp.sharePrice, uint256(transferRate), "sender transfer checkpoint records transfer-time rate");
    }

    /// @notice Repeated transfer checkpoints that get coalesced still update sharePrice.
    function testFuzz_SharePrice_UpdatedOnCoalescedTransfer(uint256 amount, uint256 rateSeed1, uint256 rateSeed2)
        external
    {
        uint96 r1 = _boundRate(rateSeed1);
        uint96 r2 = _boundRate(rateSeed2);
        amount = bound(amount, 1e6, 1e22);

        _setRate(r1);
        vault.setBeforeTransferHook(address(teller));

        address alice = vm.addr(101);
        address bob = vm.addr(102);
        address carol = vm.addr(103);

        uint256 shares = _depositAs(alice, amount);
        vm.assume(shares >= 3);

        // First transfer: creates a transfer checkpoint for alice
        vm.prank(alice);
        vault.transfer(bob, shares / 3);

        // Rate changes
        _setRate(r2);

        // Second transfer: should coalesce alice's transfer checkpoint but update sharePrice
        vm.prank(alice);
        vault.transfer(carol, shares / 3);

        PrincipalCheckpoint memory aliceLast = _lastCheckpoint(alice);
        assertEq(aliceLast.sharePrice, uint256(r2), "coalesced transfer checkpoint has latest rate");
    }

    // ============================== CONCRETE: uint104 cumulative overflow reverts safely ==============================

    /// @notice Cumulative deposits across multiple smaller deposits can exceed uint104 max.
    /// The checked += on uint104 reverts, preventing silent corruption.
    function test_CumulativeOverflow_Uint104_Reverts() external {
        uint256 perDeposit = uint256(type(uint104).max) / 2 + 1;
        _fundVault(perDeposit * 4);

        address user = vm.addr(100);

        // First deposit: fits in uint104
        _depositAs(user, perDeposit);
        PrincipalCheckpoint memory first = _lastCheckpoint(user);
        assertGt(first.cumulativeDeposits, 0, "first deposit recorded");

        // Second deposit: cumulative would exceed uint104 max, must revert
        weth.mint(user, perDeposit);
        vm.startPrank(user);
        ERC20(address(weth)).safeApprove(address(vault), perDeposit);

        vm.expectRevert();
        teller.deposit(DepositParams(ERC20(address(weth)), perDeposit, 0, user), address(0), ComplianceData(0, ""));
        vm.stopPrank();
    }
}
