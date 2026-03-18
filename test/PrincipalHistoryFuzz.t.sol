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
        shares = teller.deposit(
            DepositParams(ERC20(address(weth)), amount, 0, address(0)), address(0), ComplianceData(0, "")
        );
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
        teller.deposit(
            DepositParams(ERC20(address(weth)), perDeposit, 0, address(0)), address(0), ComplianceData(0, "")
        );
        vm.stopPrank();
    }
}
