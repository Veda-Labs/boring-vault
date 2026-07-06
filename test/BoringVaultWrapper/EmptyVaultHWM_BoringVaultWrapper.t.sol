// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BoringVaultWrapper} from "src/base/Roles/BoringVaultWrapper.sol";
import {BVWTestBase} from "./BVWTestBase.sol";

/**
 * @title  Regression tests for the empty-vault performance-fee HWM bug.
 *
 * Finding — HWM frozen while totalSupply() == 0
 *   _accrueFees() and _pendingFeeShares() both early-return without advancing
 *   performanceHighWaterMark when supply is zero. Any BV-rate appreciation that
 *   happens while the wrapper holds no shares (the window between deployment and
 *   the first deposit, or any period after a full exit) is therefore later
 *   charged as a performance fee against the next depositor — who entered at the
 *   already-appreciated rate and never earned that gain.
 *
 * Each test asserts the *desired* (correct) behaviour: on the current (buggy)
 * code they FAIL; after advancing the HWM in the zero-supply branch they PASS.
 */
contract EmptyVaultHWM_BoringVaultWrapper_Test is BVWTestBase {
    uint16 constant PERF_FEE = 1_000; // 10%

    function setUp() public override {
        super.setUp();
        // Enable the performance fee; management fee stays 0 to isolate perf accrual.
        wrapper.setFeeConfig(feeRecipient, feeRecipient, 0, PERF_FEE);
    }

    /// Advance time by 1s (satisfies the accountant minDelay) then push a new rate.
    function _setRate(uint96 newRate) internal {
        skip(1);
        accountant.updateExchangeRate(newRate);
    }

    // =========================================================================
    //          Direct HWM assertion: the zero-supply poke must track the rate
    // =========================================================================

    /**
     * @dev While the wrapper is empty, accrueFees() must still advance the HWM so
     *      it keeps tracking accountant.getRate() continuously (matching the
     *      constructor's HWM seeding and the zero-fee-window handling).
     *
     *      DESIRED: HWM == 1.1e18 after the empty-window poke.
     *      BUGGY:   HWM stays at 1.0e18 because _accrueFees() returns early on
     *               totalSupply() == 0 without touching the HWM.
     */
    function test_finding_HWMTracksRateWhileSupplyZero() public {
        assertEq(wrapper.totalSupply(), 0, "pre: wrapper empty");
        assertEq(wrapper.performanceHighWaterMark(), 1e18, "pre: HWM seeded at 1.0");

        // Rate rises 1.0 -> 1.1 while nobody is invested.
        _setRate(1.1e18);
        wrapper.accrueFees(); // permissionless poke

        assertEq(wrapper.performanceHighWaterMark(), 1.1e18, "HWM must track the rate even while the wrapper is empty");
    }

    // =========================================================================
    //          Economic impact: first depositor must not be retro-charged
    // =========================================================================

    /**
     * @dev Full scenario, no attacker required: the vault appreciates while empty,
     *      then the first user deposits at the appreciated rate. The next accrual
     *      must NOT mint any performance fee, because that appreciation predates
     *      the depositor and they never earned it.
     *
     *      DESIRED: feeRecipient balance stays 0 after the first deposit + accrual.
     *      BUGGY:   perf-fee shares are minted on the 1.0 -> 1.1 empty window,
     *               diluting the fresh depositor to the fee recipient.
     */
    function test_finding_NoPerfFeeOnPreDepositAppreciation() public {
        // Rate rises 1.0 -> 1.1 with the wrapper still empty.
        _setRate(1.1e18);

        // First depositor enters at the already-appreciated rate 1.1.
        _wrapBV(alice, 100e18);
        assertGt(wrapper.balanceOf(alice), 0, "pre: alice holds wrapper shares");
        assertEq(wrapper.balanceOf(feeRecipient), 0, "pre: no fee minted at deposit");

        // Rate is unchanged since alice entered, so accrual must be a no-op.
        uint256 feesBefore = wrapper.balanceOf(feeRecipient);
        wrapper.accrueFees();
        uint256 feesAfter = wrapper.balanceOf(feeRecipient);

        assertEq(feesAfter, feesBefore, "no performance fee may be charged on appreciation that predates the depositor");
    }

    /**
     * @dev Same defect via the full-exit-then-re-enter window. After all holders
     *      leave, the wrapper is empty again; appreciation during that gap must
     *      not be charged to the next entrant.
     *
     *      DESIRED: no perf fee minted to feeRecipient for the empty-window gain.
     *      BUGGY:   the re-entrant is retro-charged for the 1.1 -> 1.21 window.
     */
    function test_finding_NoPerfFeeAfterFullExitWindow() public {
        // Alice enters at 1.0, rate rises to 1.1, she is legitimately charged.
        _wrapBV(alice, 100e18);
        _setRate(1.1e18);
        wrapper.accrueFees();
        assertEq(wrapper.performanceHighWaterMark(), 1.1e18, "pre: HWM at 1.1");

        // Everyone fully exits -> wrapper empties (alice, and the fee recipient
        // who now holds the legitimate 1.0 -> 1.1 perf-fee shares). Balances are
        // read first so the prank is not consumed by argument evaluation.
        uint256 aliceShares = wrapper.balanceOf(alice);
        vm.prank(alice);
        wrapper.redeem(aliceShares, alice, alice);

        uint256 feeShares = wrapper.balanceOf(feeRecipient);
        vm.prank(feeRecipient);
        wrapper.redeem(feeShares, feeRecipient, feeRecipient);

        assertEq(wrapper.totalSupply(), 0, "pre: wrapper empty after exit");

        // Rate rises 1.1 -> 1.21 while empty (no holders to earn it).
        _setRate(1.21e18);

        // Bob enters at 1.21; the following accrual must not charge him for the gap.
        _wrapBV(bob, 100e18);
        uint256 feesBefore = wrapper.balanceOf(feeRecipient);
        wrapper.accrueFees();
        uint256 feesAfter = wrapper.balanceOf(feeRecipient);

        assertEq(feesAfter, feesBefore, "re-entrant must not be charged for appreciation during the empty window");
    }
}
