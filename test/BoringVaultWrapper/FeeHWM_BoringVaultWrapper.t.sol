// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test} from "@forge-std/Test.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";

import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {BoringVaultWrapper} from "src/base/Roles/BoringVaultWrapper.sol";
import {MockERC20} from "src/helper/MockERC20.sol";

/**
 * @title  Regression tests for two performance-fee HWM bugs.
 *
 * Bug 1 — HWM frozen when performanceFee = 0
 *   _pendingFeeShares() only calls getRateSafe() / advances the HWM inside the
 *   `if (perfFee > 0)` guard. While the fee is disabled the HWM stagnates, so
 *   re-enabling the fee retroactively charges performance fees on all appreciation
 *   that accumulated during the zero-fee window.
 *
 * Bug 2 — No HWM reset after a drawdown
 *   When the BV rate drops below the HWM there is no admin function to lower the
 *   mark. Performance fees are permanently frozen until the original HWM is fully
 *   recovered, even while the vault is generating new positive returns.
 *
 * Each test asserts the *desired* (correct) behaviour.
 * On unpatched code, Bug-1 tests fail on their assertions.
 * Bug-2 tests fail to compile because resetHighWaterMark() does not exist yet.
 */
contract FeeHWM_BoringVaultWrapper_Test is Test {
    using FixedPointMathLib for uint256;

    // ── Roles ─────────────────────────────────────────────────────────────────
    uint8 constant MINTER_ROLE  = 7;
    uint8 constant BURNER_ROLE  = 8;
    uint8 constant WRAPPER_ROLE = 55;

    // ── Contracts ─────────────────────────────────────────────────────────────
    MockERC20                       baseAsset;
    BoringVault                     boringVault;
    AccountantWithRateProviders     accountant;
    TellerWithMultiAssetSupport     teller;
    BoringVaultWrapper              wrapper;
    RolesAuthority                  rolesAuthority;

    // ── Addresses ─────────────────────────────────────────────────────────────
    address feeRecipient = makeAddr("feeRecipient");
    address alice        = makeAddr("alice");
    address unauthorized = makeAddr("unauthorized");
    address payoutAddr   = makeAddr("payoutAddr");

    uint16 constant PERF_FEE = 1_000; // 10 %

    // =========================================================================
    //                              SET UP
    // =========================================================================

    function setUp() public {
        baseAsset   = new MockERC20("WETH", "WETH", 18);
        boringVault = new BoringVault(address(this), "BV", "BV", 18);

        // No BV-level platform or performance fee — keeps wrapper fee math clean
        // and ensures _applyBvFees() is always a no-op (feesOwed == 0).
        // allowedUpper = 110 %, allowedLower = 90 %, minDelay = 1 s.
        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), payoutAddr,
            1e18, address(baseAsset), 1.1e4, 0.9e4, 1, 0, 0
        );
        teller = new TellerWithMultiAssetSupport(
            address(this), address(boringVault), address(accountant), address(baseAsset)
        );
        wrapper = new BoringVaultWrapper(
            address(this), address(boringVault), address(accountant),
            address(teller), "Partner Vault", "PV"
        );

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);
        accountant.setAuthority(rolesAuthority);
        teller.setAuthority(rolesAuthority);
        wrapper.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(MINTER_ROLE,  address(boringVault), BoringVault.enter.selector,    true);
        rolesAuthority.setRoleCapability(BURNER_ROLE,  address(boringVault), BoringVault.exit.selector,     true);
        rolesAuthority.setRoleCapability(WRAPPER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkDeposit.selector,  true);
        rolesAuthority.setRoleCapability(WRAPPER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector, true);

        rolesAuthority.setUserRole(address(teller),  MINTER_ROLE,  true);
        rolesAuthority.setUserRole(address(teller),  BURNER_ROLE,  true);
        rolesAuthority.setUserRole(address(wrapper), WRAPPER_ROLE, true);

        teller.updateAssetData(baseAsset, true, true, 0);
        accountant.setRateProviderData(baseAsset, true, address(0));
    }

    // =========================================================================
    //                              HELPERS
    // =========================================================================

    /// Mint BV shares directly to `user` and have them wrap via deposit().
    function _deposit(address user, uint256 bvAmount) internal {
        deal(address(boringVault), user, bvAmount, true);
        vm.startPrank(user);
        ERC20(address(boringVault)).approve(address(wrapper), bvAmount);
        wrapper.deposit(bvAmount, user);
        vm.stopPrank();
    }

    /// Advance time by 1 s (satisfying minDelay) then push a new exchange rate.
    function _setRate(uint96 newRate) internal {
        skip(1);
        accountant.updateExchangeRate(newRate);
    }

    // =========================================================================
    //                   Bug 1 — HWM frozen when performanceFee = 0
    // =========================================================================

    /**
     * @dev The HWM must advance whenever the rate rises, regardless of whether
     *      performanceFee is currently zero.
     *
     *      DESIRED:  performanceHighWaterMark == 1.2e18 after accrueFees() during
     *                the zero-fee window.
     *      BUGGY:    HWM stays at 1.1e18 because _pendingFeeShares() skips the
     *                getRateSafe() call when perfFee == 0.
     */
    function test_bug1_HWMFrozenDuringZeroFeeWindow() public {
        wrapper.setFeeConfig(feeRecipient, 0, PERF_FEE);
        _deposit(alice, 100e18);

        // Rate 1.0 → 1.1: legitimate accrual, HWM advances to 1.1.
        _setRate(1.1e18);
        wrapper.accrueFees();
        assertEq(wrapper.performanceHighWaterMark(), 1.1e18, "pre: HWM = 1.1");

        // Admin disables the performance fee.
        wrapper.setFeeConfig(feeRecipient, 0, 0);
        assertEq(wrapper.performanceFee(), 0, "pre: perfFee = 0");

        // Rate 1.1 → 1.2 during the zero-fee window.
        _setRate(1.2e18);
        wrapper.accrueFees(); // anyone can call this to advance the HWM

        // FIX:  HWM == 1.2e18  (HWM tracked unconditionally)
        // BUG:  HWM == 1.1e18  (HWM frozen because perfFee == 0)
        assertEq(
            wrapper.performanceHighWaterMark(), 1.2e18,
            "HWM must advance to 1.2 even while performanceFee = 0"
        );
    }

    /**
     * @dev Full exploit scenario: admin zeros the fee, vault appreciates, admin
     *      re-enables the fee, and the first interaction retroactively charges
     *      performance fees on the zero-fee appreciation.
     *
     *      DESIRED:  no new fee shares after re-enable (nothing has appreciated
     *                above the already-updated HWM).
     *      BUGGY:    fee shares are minted on the 1.1 → 1.2 window that
     *                accumulated while performanceFee was 0.
     */
    function test_bug1_RetroactiveFeeOnReEnable() public {
        wrapper.setFeeConfig(feeRecipient, 0, PERF_FEE);
        _deposit(alice, 100e18);

        // Rate 1.0 → 1.1: legitimate accrual, some fee shares minted.
        _setRate(1.1e18);
        wrapper.accrueFees(); // HWM → 1.1, fee minted
        uint256 feesAtSettle = wrapper.balanceOf(feeRecipient);
        assertGt(feesAtSettle, 0, "pre: legitimate perf fee at 1.1");

        // Admin disables fee. _accrueFees() inside setFeeConfig runs with the
        // OLD perfFee = 10 % but rate == HWM so no extra shares are minted.
        wrapper.setFeeConfig(feeRecipient, 0, 0);
        assertEq(wrapper.performanceHighWaterMark(), 1.1e18, "pre: HWM = 1.1");

        // Rate 1.1 → 1.2 during zero-fee window. No interactions.
        _setRate(1.2e18);

        // Admin re-enables. setFeeConfig calls _accrueFees() with the OLD perfFee = 0.
        //   BUG:  HWM stays at 1.1 (getRateSafe() skipped). After this call
        //         performanceFee = 10 % with HWM still at 1.1.
        //   FIX:  _accrueFees() advances HWM to 1.2 unconditionally. After this call
        //         performanceFee = 10 % and HWM = 1.2.
        wrapper.setFeeConfig(feeRecipient, 0, PERF_FEE);

        // Rate hasn't moved since re-enable: the next accrueFees() must be a no-op.
        uint256 feesBefore = wrapper.balanceOf(feeRecipient);
        wrapper.accrueFees();
        uint256 feesAfter  = wrapper.balanceOf(feeRecipient);

        // FIX:  feesAfter == feesBefore  (HWM was already at 1.2, nothing to charge)
        // BUG:  feesAfter  > feesBefore  (retroactive fee on 1.1 → 1.2 window)
        assertEq(feesAfter, feesBefore, "no retroactive perf fee on zero-fee window");
    }

    // =========================================================================
    //                   Bug 2 — No HWM reset after a drawdown
    // =========================================================================

    /**
     * @dev After a genuine drawdown (rate at least MIN_HWM_RESET_DRAWDOWN_BPS below
     *      the HWM), resetHighWaterMark() lowers the HWM to the trough rate and
     *      re-enables performance fee accrual on all future appreciation.
     *
     *      Rate path (all steps within the ±10 % accountant bounds):
     *        1.0  →  1.1   rise,  HWM = 1.1, fees charged
     *             →  0.99  drawdown (exactly −10 % = the minimum threshold boundary)
     *             resetHighWaterMark() at trough → HWM = 0.99
     *             →  1.089 rise above new HWM → fees resume
     */
    function test_bug2_ResetHighWaterMark() public {
        wrapper.setFeeConfig(feeRecipient, 0, PERF_FEE);
        _deposit(alice, 100e18);

        // ── Rise: fees charged, HWM = 1.1 ────────────────────────────────────
        _setRate(1.1e18);
        wrapper.accrueFees();
        assertEq(wrapper.performanceHighWaterMark(), 1.1e18, "pre: HWM = 1.1");
        assertGt(wrapper.balanceOf(feeRecipient), 0, "pre: legitimate perf fee at 1.1");

        // ── Drawdown: 1.1 → 0.99 (exactly −10 %, the threshold boundary) ─────
        // Threshold check is strict (>), so being exactly at 10 % is allowed.
        _setRate(0.99e18);
        wrapper.accrueFees();
        assertEq(wrapper.performanceHighWaterMark(), 1.1e18, "HWM frozen during drawdown");

        // Confirm fees are dead at the trough.
        uint256 feesAtTrough = wrapper.balanceOf(feeRecipient);
        wrapper.accrueFees();
        assertEq(wrapper.balanceOf(feeRecipient), feesAtTrough, "perf fees frozen below HWM");

        // ── Admin resets HWM to trough rate ──────────────────────────────────
        wrapper.resetHighWaterMark();
        assertEq(wrapper.performanceHighWaterMark(), 0.99e18, "HWM reset to 0.99");
        assertLt(wrapper.performanceHighWaterMark(), 1.1e18, "HWM below old watermark");

        // ── Rise above new HWM: fees resume ───────────────────────────────────
        // 0.99 → 1.089 is exactly +10 %, within bounds and above the new HWM.
        _setRate(1.089e18);
        uint256 feesPreResume = wrapper.balanceOf(feeRecipient);
        wrapper.accrueFees();
        assertGt(wrapper.balanceOf(feeRecipient), feesPreResume, "perf fees resume after reset");
    }

    /**
     * @dev resetHighWaterMark() must be auth-gated.
     */
    function test_bug2_ResetRequiresAuth() public {
        wrapper.setFeeConfig(feeRecipient, 0, PERF_FEE);
        _deposit(alice, 100e18);

        vm.prank(unauthorized);
        vm.expectRevert();
        wrapper.resetHighWaterMark();
    }

    /**
     * @dev Calling resetHighWaterMark() when rate >= HWM must revert with
     *      HWMResetNotNeeded. The normal _accrueFees() path handles upward movement;
     *      calling reset in this regime would silently skip fee collection.
     */
    function test_bug2_ResetReverts_WhenRateAtOrAboveHWM() public {
        wrapper.setFeeConfig(feeRecipient, 0, PERF_FEE);
        _deposit(alice, 100e18);

        _setRate(1.1e18);
        wrapper.accrueFees(); // HWM → 1.1, rate == HWM

        vm.expectRevert(BoringVaultWrapper.BoringVaultWrapper__HWMResetNotNeeded.selector);
        wrapper.resetHighWaterMark();
    }

    /**
     * @dev Resetting when the drawdown is real but shallower than
     *      MIN_HWM_RESET_DRAWDOWN_BPS must revert with DrawdownTooSmall.
     *      Here: rate = 1.06, HWM = 1.1 → drop ≈ 3.6 %, below the 10 % threshold.
     *
     *      This prevents an admin from calling during a minor dip and then
     *      collecting performance fees on the immediate recovery.
     */
    function test_bug2_ResetReverts_DrawdownTooSmall() public {
        wrapper.setFeeConfig(feeRecipient, 0, PERF_FEE);
        _deposit(alice, 100e18);

        _setRate(1.1e18);
        wrapper.accrueFees(); // HWM = 1.1

        // 1.1 → 1.06: a real drop but only ~3.6 % below HWM, under the 10 % minimum.
        _setRate(1.06e18);

        vm.expectRevert(BoringVaultWrapper.BoringVaultWrapper__DrawdownTooSmall.selector);
        wrapper.resetHighWaterMark();
    }
}
