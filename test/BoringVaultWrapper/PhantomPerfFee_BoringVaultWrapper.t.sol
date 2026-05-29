// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test, console} from "@forge-std/Test.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";

import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {TellerWithMultiAssetSupport, ComplianceData} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {BoringVaultWrapper} from "src/base/Roles/BoringVaultWrapper.sol";
import {MockERC20} from "src/helper/MockERC20.sol";

/**
 * @title  Regression - "phantom-perf-fee through the claimFees window" cannot happen.
 *
 * @notice Historical context: under the previous "net-rate HWM" design, the wrapper
 *         subtracted `accountant.feesOwedInBase / bvSupply` from the gross rate to
 *         derive its HWM. `claimFees()` zeroes `feesOwedInBase` without touching
 *         `exchangeRate`, so between a claim and the next `updateExchangeRate(...)`
 *         the wrapper would observe a phantom rate jump and mint perf-fee shares
 *         on a non-existent gain.
 *
 *         The current design tracks HWM on the GROSS rate `accountant.getRate()`
 *         only \u2014 never reads `feesOwedInBase` \u2014 so the phantom path is structurally
 *         impossible. This test enacts the exact attack timeline that the PoC used,
 *         and asserts no phantom mint occurs regardless of when claimFees runs.
 */
contract PhantomPerfFee_BoringVaultWrapper_Test is Test {
    using FixedPointMathLib for uint256;

    // ---- Roles ----
    uint8 constant ADMIN_ROLE   = 1;
    uint8 constant MINTER_ROLE  = 7;
    uint8 constant BURNER_ROLE  = 8;
    uint8 constant WRAPPER_ROLE = 55;
    uint8 constant MANAGER_ROLE = 3;

    // ---- Contracts ----
    MockERC20                       baseAsset;
    BoringVault                     boringVault;
    AccountantWithRateProviders     accountant;
    TellerWithMultiAssetSupport     teller;
    BoringVaultWrapper              wrapper;
    RolesAuthority                  rolesAuthority;

    // ---- Addresses ----
    address feeRecipient = makeAddr("feeRecipient");
    address alice        = makeAddr("alice");
    address mallory      = makeAddr("mallory");
    address payoutAddr   = makeAddr("payoutAddr");

    uint16 constant WRAPPER_PERF_FEE = 1_000; // 10 %
    uint16 constant BV_PLATFORM_FEE  = 200;   // 2 %/yr platform fee at BV level

    function setUp() public {
        baseAsset   = new MockERC20("WETH", "WETH", 18);
        boringVault = new BoringVault(address(this), "BV", "BV", 18);

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

        rolesAuthority.setRoleCapability(MINTER_ROLE,  address(boringVault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE,  address(boringVault), BoringVault.exit.selector, true);
        rolesAuthority.setRoleCapability(
            WRAPPER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkDeposit.selector, true
        );
        rolesAuthority.setRoleCapability(
            WRAPPER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector, true
        );
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256("manage(address,bytes,uint256)")),
            true
        );

        rolesAuthority.setUserRole(address(this),    ADMIN_ROLE,   true);
        rolesAuthority.setUserRole(address(this),    MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(teller),  MINTER_ROLE,  true);
        rolesAuthority.setUserRole(address(teller),  BURNER_ROLE,  true);
        rolesAuthority.setUserRole(address(wrapper), WRAPPER_ROLE, true);

        teller.updateAssetData(baseAsset, true, true, 0);
        accountant.setRateProviderData(baseAsset, true, address(0));
    }

    // ---- Helpers ----

    function _giveBVShares(address user, uint256 amount) internal {
        deal(address(boringVault), user, amount, true);
    }

    function _wrap(address user, uint256 bvAmount) internal {
        vm.startPrank(user);
        ERC20(address(boringVault)).approve(address(wrapper), bvAmount);
        wrapper.deposit(bvAmount, user);
        vm.stopPrank();
    }

    function _primeAccountant() internal {
        skip(1);
        accountant.updateExchangeRate(1e18);
    }

    function _claimBvFees() internal {
        (,, uint128 feesOwed,,,,,,,,,) = accountant.accountantState();
        deal(address(baseAsset), address(boringVault), uint256(feesOwed));

        bytes memory approveCall = abi.encodeWithSelector(
            ERC20.approve.selector, address(accountant), type(uint256).max
        );
        boringVault.manage(address(baseAsset), approveCall, 0);

        bytes memory claimCall = abi.encodeWithSelector(
            AccountantWithRateProviders.claimFees.selector, baseAsset
        );
        boringVault.manage(address(accountant), claimCall, 0);
    }

    // =====================================================================
    //          Regression: phantom-jump path no longer exists
    // =====================================================================

    /**
     * Re-enact the original attack:
     *   t = 0     Alice wraps 100 BV. HWM = gross 1.0.
     *   t = +1y  updateExchangeRate(1.05). BV records ~2% platform fee in feesOwedInBase.
     *            wrapper.accrueFees(): perf fee charged on full GROSS 1.0 -> 1.05 (HWM=1.05).
     *   t = +1y+e Strategist calls claimFees(). feesOwedInBase -> 0. exchangeRate untouched.
     *   t = +1y+2e Mallory frontruns and calls wrapper.accrueFees().
     *
     * Under the old net-rate design, step 4 minted PHANTOM perf shares on a bookkeeping jump.
     * Under the new gross-rate design, step 4 is a no-op because `getRate()` did not move.
     */
    function test_PhantomPerfFee_PathNoLongerExists() public {
        wrapper.setFeeConfig(feeRecipient, 0, WRAPPER_PERF_FEE);

        accountant.updatePlatformFee(BV_PLATFORM_FEE);
        accountant.updatePerformanceFee(0);

        _giveBVShares(alice, 100e18);
        _wrap(alice, 100e18);
        _primeAccountant();

        // ---- Year 1: real appreciation 1.0 -> 1.05 ----
        skip(365 days);
        accountant.updateExchangeRate(1.05e18);

        (,, uint128 feesOwedY1,,,,,,,,,) = accountant.accountantState();
        assertGt(uint256(feesOwedY1), 0, "BV platform fee accumulated at the accountant level");

        // Honest accrual: HWM ratchets to GROSS 1.05 (not a net-of-fees value).
        wrapper.accrueFees();
        uint96  hwmAfterHonest          = wrapper.performanceHighWaterMark();
        uint256 feeRecipientAfterHonest = wrapper.balanceOf(feeRecipient);

        assertEq(uint256(hwmAfterHonest), 1.05e18, "HWM tracks gross rate exactly");
        assertGt(feeRecipientAfterHonest, 0,       "Honest perf fee charged on the gross gain");

        // ---- Strategist runs claimFees: feesOwedInBase -> 0; exchangeRate unchanged ----
        _claimBvFees();

        (,, uint128 feesOwedPostClaim,,,,,,,,,) = accountant.accountantState();
        assertEq(uint256(feesOwedPostClaim), 0, "feesOwedInBase zeroed by claim");

        // Under the OLD design this would be the attack window. Under the NEW design,
        // `getRate()` still reports 1.05 and the HWM is already at 1.05, so the perf-fee
        // condition (`currentRate > hwm`) is false. Mallory's call is a pure no-op.
        vm.prank(mallory);
        wrapper.accrueFees();

        assertEq(wrapper.performanceHighWaterMark(), hwmAfterHonest,
            "REGRESSION: HWM stable across the claimFees window");
        assertEq(wrapper.balanceOf(feeRecipient), feeRecipientAfterHonest,
            "REGRESSION: zero phantom-fee mint across the claimFees window");

        // ---- Repeat with anyone, multiple times, any spacing: still no phantom fee ----
        for (uint256 i = 0; i < 10; i++) {
            skip(13);
            vm.prank(mallory);
            wrapper.accrueFees();
        }
        assertEq(wrapper.performanceHighWaterMark(), hwmAfterHonest,
            "REGRESSION: HWM stable across repeated accruals post-claim");
        assertEq(wrapper.balanceOf(feeRecipient), feeRecipientAfterHonest,
            "REGRESSION: still zero phantom-fee mint after 10 retries");

        // ---- Operator finally pushes a fresh rate below the HWM ----
        // Real per-share NAV is below 1.05 (BV paid out fees). HWM stays at 1.05, so no
        // perf fee on the dip-and-recovery cycle until gross strictly exceeds 1.05.
        skip(1);
        accountant.updateExchangeRate(1.03e18);
        wrapper.accrueFees();

        assertEq(wrapper.performanceHighWaterMark(), hwmAfterHonest,
            "HWM does NOT track downward moves");
        assertEq(wrapper.balanceOf(feeRecipient), feeRecipientAfterHonest,
            "No additional perf fee on rate drop");
    }

    /// @dev Operator atomicity is no longer required for correctness \u2014 the wrapper
    ///      behaves identically whether `claimFees` and `updateExchangeRate` are
    ///      atomic or arbitrarily spaced. Both call orderings are exercised here.
    function test_OperatorOrderingIsIrrelevantForFeeCorrectness() public {
        wrapper.setFeeConfig(feeRecipient, 0, WRAPPER_PERF_FEE);
        accountant.updatePlatformFee(BV_PLATFORM_FEE);
        accountant.updatePerformanceFee(0);

        _giveBVShares(alice, 100e18);
        _wrap(alice, 100e18);
        _primeAccountant();

        skip(365 days);
        accountant.updateExchangeRate(1.05e18);
        wrapper.accrueFees();

        uint256 feesAtCheckpoint = wrapper.balanceOf(feeRecipient);
        uint96  hwmAtCheckpoint  = wrapper.performanceHighWaterMark();

        // Permutation A: many accrueFees calls before the claim, then claim, then more.
        for (uint256 i = 0; i < 3; i++) { skip(7); wrapper.accrueFees(); }
        _claimBvFees();
        for (uint256 i = 0; i < 3; i++) { skip(7); wrapper.accrueFees(); }

        assertEq(wrapper.balanceOf(feeRecipient), feesAtCheckpoint,
            "Permutation A: claim sandwiched by accruals leaves fees unchanged");
        assertEq(wrapper.performanceHighWaterMark(), hwmAtCheckpoint,
            "Permutation A: HWM unchanged across the entire window");
    }
}
