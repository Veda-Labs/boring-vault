// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test, console} from "@forge-std/Test.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";

import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {TellerWithMultiAssetSupport, ComplianceData} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {BoringVaultWrapper} from "src/base/Roles/BoringVaultWrapper.sol";
import {MockERC20} from "src/helper/MockERC20.sol";

contract BoringVaultWrapperTest is Test {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    // ── Role IDs ───────────────────────────────────────────────────────────────
    uint8 constant ADMIN_ROLE = 1;
    uint8 constant MINTER_ROLE = 7;
    uint8 constant BURNER_ROLE = 8;
    uint8 constant WRAPPER_ROLE = 55; // may call bulkDeposit + bulkWithdraw
    uint8 constant SETTER_ROLE = 2; // for setShareLockPeriod (share-lock test only)

    // ── Contracts ──────────────────────────────────────────────────────────────
    MockERC20 baseAsset; // 18-decimal stand-in for WETH / USDC
    BoringVault boringVault;
    AccountantWithRateProviders accountant;
    TellerWithMultiAssetSupport teller;
    BoringVaultWrapper wrapper;
    RolesAuthority rolesAuthority;

    // ── Addresses ─────────────────────────────────────────────────────────────
    address feeRecipient = makeAddr("feeRecipient");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address payoutAddress = makeAddr("payoutAddress");

    // ── Fee parameters ─────────────────────────────────────────────────────────
    uint16 constant MGMT_FEE = 200; // 2 % per year
    uint16 constant PERF_FEE = 1_000; // 10 % on gains

    // ── Share scaling (mirrors BoringVaultWrapper.DECIMALS_OFFSET) ────────────
    /// @dev Wrapper shares are scaled 10**DECIMALS_OFFSET larger than BV shares due
    ///      to OZ ERC4626 virtual-offset (inflation-attack protection).
    uint256 constant SHARE_SCALE = 1e6;

    // =========================================================================
    //                              SET UP
    // =========================================================================

    function setUp() public {
        // ── Deploy base asset ────────────────────────────────────────────────
        baseAsset = new MockERC20("Wrapped Ether", "WETH", 18);

        // ── Deploy BoringVault (18 dec) ───────────────────────────────────────
        boringVault = new BoringVault(address(this), "Test Boring Vault", "TBV", 18);

        // ── Deploy Accountant ────────────────────────────────────────────────
        //    startingExchangeRate = 1e18 (1 BV share ≙ 1 baseAsset)
        //    allowedUpper = 110 %, allowedLower = 90 %, minDelay = 1s
        //    No platform or performance fee at the BV level.
        accountant = new AccountantWithRateProviders(
            address(this),
            address(boringVault),
            payoutAddress,
            1e18, // startingExchangeRate
            address(baseAsset),
            1.1e4, // allowedExchangeRateChangeUpper
            0.9e4, // allowedExchangeRateChangeLower
            1, // minimumUpdateDelayInSeconds
            0, // platformFee
            0 // performanceFee
        );

        // ── Deploy Teller ────────────────────────────────────────────────────
        teller = new TellerWithMultiAssetSupport(
            address(this), address(boringVault), address(accountant), address(baseAsset)
        );

        // ── Deploy BoringVaultWrapper ────────────────────────────────────────────
        wrapper = new BoringVaultWrapper(
            address(this), address(boringVault), address(accountant), address(teller), "Partner Vault", "PV"
        );

        // ── Wire RolesAuthority ───────────────────────────────────────────────
        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));

        boringVault.setAuthority(rolesAuthority);
        accountant.setAuthority(rolesAuthority);
        teller.setAuthority(rolesAuthority);
        wrapper.setAuthority(rolesAuthority);

        // Teller may enter/exit the BoringVault
        rolesAuthority.setRoleCapability(MINTER_ROLE, address(boringVault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(boringVault), BoringVault.exit.selector, true);

        // Admin may configure the Teller
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.updateAssetData.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.bulkDeposit.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector, true
        );

        // Wrapper may call bulkDeposit (depositAsset) and bulkWithdraw (redeemAsset)
        rolesAuthority.setRoleCapability(
            WRAPPER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkDeposit.selector, true
        );
        rolesAuthority.setRoleCapability(
            WRAPPER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector, true
        );

        // Assign roles
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);
        rolesAuthority.setUserRole(address(wrapper), WRAPPER_ROLE, true);

        // Admin may set share lock period
        rolesAuthority.setRoleCapability(
            SETTER_ROLE, address(teller), TellerWithMultiAssetSupport.setShareLockPeriod.selector, true
        );
        rolesAuthority.setUserRole(address(this), SETTER_ROLE, true);

        // Configure Teller asset + Accountant rate provider
        teller.updateAssetData(baseAsset, true, true, 0);
        accountant.setRateProviderData(baseAsset, true, address(0));

        // Initialise fee configuration (recipient + rates).
        wrapper.setFeeConfig(feeRecipient, MGMT_FEE, PERF_FEE);
    }

    // =========================================================================
    //                            HELPERS
    // =========================================================================

    /// @dev Use Foundry's deal to directly credit a user with BoringVault shares,
    ///      bypassing the Teller.  Sufficient for all tests that only care about
    ///      wrapper-level share arithmetic.
    function _giveBVShares(address user, uint256 amount) internal {
        deal(address(boringVault), user, amount, true);
    }

    /// @dev Approve + deposit BV shares into the wrapper in one call.
    function _wrapBV(address user, uint256 bvAmount) internal returns (uint256 wrapperShares) {
        vm.startPrank(user);
        ERC20(address(boringVault)).approve(address(wrapper), bvAmount);
        wrapperShares = wrapper.deposit(bvAmount, user);
        vm.stopPrank();
    }

    // =========================================================================
    //                   1. FIRST DEPOSIT — 1 : 1 seeding
    // =========================================================================

    function testFirstDepositSeeds1to1() public {
        uint256 bvAmount = 100e18;
        _giveBVShares(alice, bvAmount);

        uint256 wShares = _wrapBV(alice, bvAmount);

        assertEq(wShares, bvAmount * SHARE_SCALE, "First deposit: wrapper shares == BV * SHARE_SCALE");
        assertEq(wrapper.balanceOf(alice), bvAmount * SHARE_SCALE, "Alice wrapper balance");
        assertEq(wrapper.totalAssets(), bvAmount, "Wrapper holds all BV shares");
        assertEq(wrapper.totalSupply(), bvAmount * SHARE_SCALE, "Total wrapper supply");
    }

    // =========================================================================
    //                   2. DEPOSIT THEN REDEEM (no time, no fees)
    // =========================================================================

    function testDepositAndRedeemNoFees() public {
        uint256 bvAmount = 50e18;
        _giveBVShares(alice, bvAmount);

        uint256 wShares = _wrapBV(alice, bvAmount);

        vm.prank(alice);
        uint256 bvBack = wrapper.redeem(wShares, alice, alice);

        assertEq(bvBack, bvAmount, "Redeem returns all BV shares");
        assertEq(wrapper.totalSupply(), 0, "Supply zero after full redeem");
        assertEq(wrapper.totalAssets(), 0, "Assets zero after full redeem");
        assertEq(boringVault.balanceOf(alice), bvAmount, "Alice holds original BV shares");
    }

    // =========================================================================
    //                   3. TWO DEPOSITORS — proportional shares
    // =========================================================================

    function testTwoDepositorsProportionalShares() public {
        _giveBVShares(alice, 100e18);
        _giveBVShares(bob, 100e18);

        _wrapBV(alice, 100e18);
        _wrapBV(bob, 100e18);

        // No time → no fees → perfect 50/50 split (each holds 100e18 BV worth = 100e18 * SHARE_SCALE wrapper shares)
        assertEq(wrapper.balanceOf(alice), 100e18 * SHARE_SCALE, "Alice wrapper shares");
        assertEq(wrapper.balanceOf(bob), 100e18 * SHARE_SCALE, "Bob wrapper shares");
        assertEq(wrapper.totalAssets(), 200e18, "Total BV shares held");
        assertEq(wrapper.totalSupply(), 200e18 * SHARE_SCALE, "Total wrapper supply");

        // Each user is entitled to ~half the underlying. Use their actual share balance.
        assertApproxEqAbs(wrapper.convertToAssets(wrapper.balanceOf(alice)), 100e18, 1, "Alice BV entitlement");
        assertApproxEqAbs(wrapper.convertToAssets(wrapper.balanceOf(bob)), 100e18, 1, "Bob BV entitlement");
    }

    // =========================================================================
    //                   4. MANAGEMENT FEE — full year
    // =========================================================================

    function testManagementFeeFullYear() public {
        _giveBVShares(alice, 100e18);
        _wrapBV(alice, 100e18);

        uint256 supplyBefore = wrapper.totalSupply(); // 100e18

        skip(365 days);
        wrapper.accrueFees();

        // Expected fee shares: supply × rate × elapsed / (1e4 × 365 days) = 100e18 × 0.02 = 2e18
        uint256 expectedFeeShares = supplyBefore.mulDivDown(uint256(MGMT_FEE) * 365 days, uint256(1e4) * 365 days);

        assertApproxEqAbs(wrapper.balanceOf(feeRecipient), expectedFeeShares, 1e9, "Fee recipient shares after 1 year");

        // Total BV shares held is unchanged — fees are dilution, not extraction
        assertEq(wrapper.totalAssets(), 100e18, "BV assets unchanged");

        // Alice's entitlement is now slightly less than 100 BV shares
        assertLt(wrapper.convertToAssets(100e18), 100e18, "Alice entitlement diluted by fee");
    }

    // =========================================================================
    //                   5. MANAGEMENT FEE — half year (linear accrual)
    // =========================================================================

    function testManagementFeeHalfYear() public {
        _giveBVShares(alice, 100e18);
        _wrapBV(alice, 100e18);

        uint256 supplyBefore = wrapper.totalSupply();

        skip(365 days / 2);
        wrapper.accrueFees();

        uint256 expectedFeeShares = supplyBefore.mulDivDown(uint256(MGMT_FEE) * (365 days / 2), uint256(1e4) * 365 days);

        assertApproxEqAbs(wrapper.balanceOf(feeRecipient), expectedFeeShares, 1e9, "Half-year management fee shares");
    }

    // =========================================================================
    //                   6. PERFORMANCE FEE — on BV price appreciation
    // =========================================================================

    function testPerformanceFeeOnBVPriceIncrease() public {
        _giveBVShares(alice, 100e18);
        _wrapBV(alice, 100e18);

        // Advance past minimum update delay, then push BV price up 10 %
        skip(2);
        accountant.updateExchangeRate(1.1e18);
        wrapper.accrueFees();

        // gainBV = 100e18 × (1.1e18 − 1e18) / 1.1e18 ≈ 9.09e18
        // feeInBV = gainBV × 10 % ≈ 0.909e18
        // perfShares = feeInBV × supply / totalBV ≈ 0.909e18 × SHARE_SCALE (supply is wrapper-scaled)
        uint256 gainBV = uint256(100e18).mulDivDown(1.1e18 - 1e18, 1.1e18);
        uint256 feeInBV = gainBV.mulDivDown(PERF_FEE, 1e4);
        uint256 supply = 100e18 * SHARE_SCALE;
        uint256 expectedPerfShares = feeInBV.mulDivDown(supply, 100e18);

        // Tolerance scaled with share decimals: 2 s of mgmt fee dust on a SHARE_SCALE-larger supply.
        assertApproxEqAbs(wrapper.balanceOf(feeRecipient), expectedPerfShares, 1e18, "Performance fee shares");
        assertEq(wrapper.totalAssets(), 100e18, "BV assets unchanged after perf fee");
        assertEq(wrapper.performanceHighWaterMark(), 1.1e18, "HWM updated to new rate");
    }

    // =========================================================================
    //                   7. PERFORMANCE FEE — not charged below HWM
    // =========================================================================

    function testNoPerformanceFeeWhenBelowHWM() public {
        _giveBVShares(alice, 100e18);
        _wrapBV(alice, 100e18);

        // Raise rate to 1.1e18 → establish new HWM
        skip(2);
        accountant.updateExchangeRate(1.1e18);
        wrapper.accrueFees();
        uint256 recipientSharesAfterFirst = wrapper.balanceOf(feeRecipient);

        // Rate falls back below HWM — no new perf fees
        skip(2);
        accountant.updateExchangeRate(1.05e18); // 1.05 < 1.1 HWM
        wrapper.accrueFees();

        // Only tiny management fee for 2 seconds should have accrued.
        // Scale tolerance with SHARE_SCALE since supply is wrapper-scaled.
        uint256 newShares = wrapper.balanceOf(feeRecipient) - recipientSharesAfterFirst;
        assertLt(newShares, 1e15 * SHARE_SCALE, "No perf fee below HWM; only dust-level mgmt fee");
    }

    // =========================================================================
    //                   8. COMBINED FEES — both accrue together
    // =========================================================================

    function testCombinedManagementAndPerformanceFees() public {
        _giveBVShares(alice, 100e18);
        _wrapBV(alice, 100e18);

        // 182 days pass and BV price rises 10 %
        skip(182 days);
        accountant.updateExchangeRate(1.1e18);
        wrapper.accrueFees();

        // Standalone mgmt fee for 182 days on 100e18 supply
        uint256 mgmtOnly = uint256(100e18).mulDivDown(uint256(MGMT_FEE) * 182 days, uint256(1e4) * 365 days);

        uint256 totalFeeShares = wrapper.balanceOf(feeRecipient);

        // Total fees must exceed mgmt-only (because perf fee is also charged)
        assertGt(totalFeeShares, mgmtOnly, "Combined fees > management fee alone");
    }

    // =========================================================================
    //                   9. PREVIEW ACCURACY — previewDeposit matches execution
    // =========================================================================

    function testPreviewDepositMatchesExecution() public {
        // Seed the vault with 100e18 BV shares via address(this)
        _giveBVShares(address(this), 100e18);
        _wrapBV(address(this), 100e18);

        // Advance time so there are meaningful pending management fees
        skip(180 days);

        _giveBVShares(alice, 50e18);

        // Compute expected shares via preview BEFORE executing the deposit
        uint256 preview = wrapper.previewDeposit(50e18);

        // Execute
        vm.startPrank(alice);
        ERC20(address(boringVault)).approve(address(wrapper), 50e18);
        uint256 actual = wrapper.deposit(50e18, alice);
        vm.stopPrank();

        assertEq(preview, actual, "previewDeposit must match actual shares minted");
    }

    // =========================================================================
    //                   10. PREVIEW ACCURACY — previewRedeem matches execution
    // =========================================================================

    function testPreviewRedeemMatchesExecution() public {
        _giveBVShares(alice, 100e18);
        uint256 wShares = _wrapBV(alice, 100e18);

        skip(180 days);

        uint256 preview = wrapper.previewRedeem(wShares);

        vm.prank(alice);
        uint256 actual = wrapper.redeem(wShares, alice, alice);

        assertEq(preview, actual, "previewRedeem must match actual BV shares returned");
    }

    // =========================================================================
    //                   11. convertToShares reflects pending fees
    // =========================================================================

    function testConvertToSharesReflectsPendingFees() public {
        _giveBVShares(alice, 100e18);
        _wrapBV(alice, 100e18);

        // Immediately: 1 BV share → SHARE_SCALE wrapper shares (virtual-offset scaling)
        assertApproxEqAbs(
            wrapper.convertToShares(100e18), 100e18 * SHARE_SCALE, SHARE_SCALE, "No fees yet: virtual-offset ratio"
        );

        // After 1 year of pending mgmt fees, the simulated supply is larger, so each
        // new BV share converts to slightly MORE wrapper shares (rate adjusts for dilution).
        skip(365 days);

        uint256 supplyBefore = 100e18 * SHARE_SCALE;
        uint256 pendingFeeShares = supplyBefore.mulDivDown(uint256(MGMT_FEE) * 365 days, uint256(1e4) * 365 days);
        uint256 expectedPostFeeSupply = supplyBefore + pendingFeeShares;
        // OZ formula: shares = assets * (supply + 10^offset) / (totalAssets + 1)
        uint256 expected = uint256(100e18).mulDivDown(expectedPostFeeSupply + SHARE_SCALE, 100e18 + 1);

        assertApproxEqAbs(wrapper.convertToShares(100e18), expected, 1e15, "convertToShares includes pending fees");
        assertGt(wrapper.convertToShares(100e18), 100e18 * SHARE_SCALE, "More wrapper shares per BV after pending fees");
    }

    // =========================================================================
    //                   12. depositAsset — USDC → Teller → BV → wrapper
    // =========================================================================

    function testDepositAssetRoutesToTeller() public {
        uint256 depositAmount = 100e18;
        deal(address(baseAsset), alice, depositAmount);

        // bulkDeposit is used internally so no share lock is ever set on the wrapper.

        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), depositAmount);
        uint256 wShares = wrapper.depositAsset(baseAsset, depositAmount, 0, alice, ComplianceData(0, ""));
        vm.stopPrank();

        // Exchange rate = 1e18: 100 base → 100 BV → 100 * SHARE_SCALE wrapper shares (virtual-offset scaling).
        assertEq(wShares, depositAmount * SHARE_SCALE, "First depositAsset: wrapper shares = BV * SHARE_SCALE");
        assertEq(wrapper.balanceOf(alice), wShares, "Alice wrapper balance");
        assertEq(boringVault.balanceOf(address(wrapper)), depositAmount, "Wrapper holds BV shares");
        assertEq(baseAsset.balanceOf(alice), 0, "Alice spent all base asset");
        assertEq(baseAsset.balanceOf(address(wrapper)), 0, "No base asset stranded in wrapper");
    }

    // =========================================================================
    //                   13. depositAsset then redeem
    // =========================================================================

    function testDepositAssetThenRedeem() public {
        uint256 amount = 100e18;
        deal(address(baseAsset), alice, amount);

        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), amount);
        uint256 wShares = wrapper.depositAsset(baseAsset, amount, 0, alice, ComplianceData(0, ""));
        uint256 bvBack = wrapper.redeem(wShares, alice, alice);
        vm.stopPrank();

        // Alice gets BV shares out — she can then withdraw from the BV separately
        assertEq(bvBack, amount, "Redeem after depositAsset returns correct BV shares");
        assertEq(boringVault.balanceOf(alice), amount, "Alice holds BV shares");
        assertEq(wrapper.balanceOf(alice), 0, "Alice has no remaining wrapper shares");
    }

    // =========================================================================
    //                   14. setManagementFee — settles at old rate first
    // =========================================================================

    function testSetManagementFeeSettlesPendingFeesFirst() public {
        _giveBVShares(alice, 100e18);
        _wrapBV(alice, 100e18);

        skip(180 days);

        uint256 feeSharesBefore = wrapper.balanceOf(feeRecipient);

        // Changing the fee should accrue at the OLD 2 % rate first
        wrapper.setFeeConfig(feeRecipient, 100, PERF_FEE); // change management fee to 1 %

        uint256 feeSharesAccrued = wrapper.balanceOf(feeRecipient) - feeSharesBefore;

        // Expected mgmt fee shares scale with the wrapper-scaled supply.
        uint256 supply = 100e18 * SHARE_SCALE;
        uint256 expectedAt2Pct = supply.mulDivDown(uint256(MGMT_FEE) * 180 days, uint256(1e4) * 365 days);

        assertApproxEqAbs(feeSharesAccrued, expectedAt2Pct, 1e15, "180 days settled at old 2% rate");
        assertEq(wrapper.managementFee(), 100, "New fee correctly set");
        assertEq(wrapper.lastFeeAccrual(), uint64(block.timestamp), "Timestamp advanced");
    }

    // =========================================================================
    //                   15. setPerformanceFee — settles pending perf fee first
    // =========================================================================

    function testSetPerformanceFeeSettlesPendingFeesFirst() public {
        _giveBVShares(alice, 100e18);
        _wrapBV(alice, 100e18);

        skip(2);
        accountant.updateExchangeRate(1.1e18); // BV price up 10 %, perf fee pending

        uint256 feeSharesBefore = wrapper.balanceOf(feeRecipient);

        wrapper.setFeeConfig(feeRecipient, MGMT_FEE, 500); // change performance fee to 5 %

        uint256 feeSharesAccrued = wrapper.balanceOf(feeRecipient) - feeSharesBefore;

        // Perf fee was charged at old 10 % rate, so there should be non-trivial fee shares
        assertGt(feeSharesAccrued, 0, "Perf fee settled at old rate before change");
        assertEq(wrapper.performanceFee(), 500, "New performance fee set");
    }

    // =========================================================================
    //                   16. accrueFees — callable by anyone
    // =========================================================================

    function testPublicAccrueFeesCallableByAnyone() public {
        _giveBVShares(alice, 100e18);
        _wrapBV(alice, 100e18);

        skip(365 days);

        // Bob is a random stranger with no special role
        vm.prank(bob);
        wrapper.accrueFees();

        assertGt(wrapper.balanceOf(feeRecipient), 0, "Fees accrued by a third party caller");
    }

    // =========================================================================
    //                   17. Fee recipient can redeem their shares
    // =========================================================================

    function testFeeRecipientSharesAreRedeemable() public {
        _giveBVShares(alice, 100e18);
        _wrapBV(alice, 100e18);

        skip(365 days);
        wrapper.accrueFees();

        uint256 feeRecipientShares = wrapper.balanceOf(feeRecipient);
        assertGt(feeRecipientShares, 0, "Fee recipient has shares to redeem");

        // Fee recipient redeems
        vm.prank(feeRecipient);
        uint256 bvToFeeRecipient = wrapper.redeem(feeRecipientShares, feeRecipient, feeRecipient);

        assertGt(bvToFeeRecipient, 0, "Fee recipient receives BV shares");

        // Cache balance before the prank: vm.prank is consumed by the first external call
        // in the argument list, which would be balanceOf(), leaving redeem() with
        // msg.sender = address(this) and triggering an allowance underflow.
        uint256 aliceRemainingShares = wrapper.balanceOf(alice);
        vm.prank(alice);
        uint256 aliceBVBack = wrapper.redeem(aliceRemainingShares, alice, alice);

        // Together they received exactly 100 BV shares (within rounding)
        assertApproxEqAbs(aliceBVBack + bvToFeeRecipient, 100e18, 1e9, "All BV shares accounted for");
    }

    // =========================================================================
    //                   18. mint() and withdraw() ERC4626 entry points
    // =========================================================================

    function testMintAndWithdraw() public {
        _giveBVShares(alice, 100e18);

        // Use mint() to request 100e18 BV-equivalent wrapper shares = 100e18 * SHARE_SCALE wrapper shares.
        uint256 sharesToMint = 100e18 * SHARE_SCALE;
        uint256 bvCost = wrapper.previewMint(sharesToMint);
        // Ceil rounding inside _convertToAssets adds at most 1 wei.
        assertApproxEqAbs(bvCost, 100e18, 1, "First mint: BV cost matches mint quantity");

        vm.startPrank(alice);
        ERC20(address(boringVault)).approve(address(wrapper), bvCost);
        uint256 bvSpent = wrapper.mint(sharesToMint, alice);
        vm.stopPrank();

        assertEq(bvSpent, bvCost, "BV spent matches previewMint");
        assertEq(wrapper.balanceOf(alice), sharesToMint, "Alice has requested wrapper shares");

        // Use withdraw() to pull exactly 50e18 BV shares back out
        uint256 wSharesToBurn = wrapper.previewWithdraw(50e18);

        vm.prank(alice);
        uint256 wBurned = wrapper.withdraw(50e18, alice, alice);

        assertEq(wBurned, wSharesToBurn, "Shares burned matches previewWithdraw");
        assertApproxEqAbs(boringVault.balanceOf(alice), 50e18, 1, "Alice received requested BV amount");
    }

    // =========================================================================
    //                   19. totalAssets is always live
    // =========================================================================

    function testTotalAssetsIsLive() public {
        _giveBVShares(alice, 100e18);
        _wrapBV(alice, 100e18);

        assertEq(wrapper.totalAssets(), 100e18, "totalAssets after alice deposit");

        _giveBVShares(bob, 50e18);
        _wrapBV(bob, 50e18);

        assertEq(wrapper.totalAssets(), 150e18, "totalAssets after bob deposit");

        // Alice fully redeems (cache balance first — see note in testFeeRecipientSharesAreRedeemable)
        uint256 aliceShares = wrapper.balanceOf(alice);
        vm.prank(alice);
        wrapper.redeem(aliceShares, alice, alice);

        assertEq(wrapper.totalAssets(), 50e18, "totalAssets after alice full redeem");
    }

    // =========================================================================
    //                   20. No stale-price arb: fee minted before every action
    // =========================================================================

    function testFeeAlwaysSettledBeforeDeposit() public {
        _giveBVShares(alice, 100e18);
        _wrapBV(alice, 100e18);

        skip(365 days); // 1 year pending mgmt fees, not yet materialised

        // Bob deposits AFTER 1 year has elapsed but fees haven't been explicitly accrued.
        // The deposit() call must settle fees first so Bob gets the diluted rate.
        _giveBVShares(bob, 100e18);

        vm.startPrank(bob);
        ERC20(address(boringVault)).approve(address(wrapper), 100e18);
        uint256 bobShares = wrapper.deposit(100e18, bob);
        vm.stopPrank();

        // The fee recipient received shares automatically during Bob's deposit
        assertGt(wrapper.balanceOf(feeRecipient), 0, "Fees settled automatically during deposit");

        // After Bob's deposit the vault has 200 BV shares backing three parties
        // (alice + bob + feeRecipient).  Alice's per-share entitlement must be less
        // than 100 BV shares (she was diluted by the mgmt fee).
        assertLt(wrapper.convertToAssets(wrapper.balanceOf(alice)), 100e18, "Alice diluted by fee");

        // Bob deposited 100 BV shares and (because fees inflated supply before his
        // deposit) he gets slightly more wrapper shares than alice did initially.
        assertGt(bobShares, 100e18, "Bob gets > 1:1 because he deposited post-dilution");
    }

    // =========================================================================
    //                   21. depositAsset — first deposit 1:1 seeding
    // =========================================================================

    function testDepositAsset_FirstDeposit() public {
        uint256 amount = 100e18;
        deal(address(baseAsset), alice, amount);

        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), amount);
        uint256 wShares = wrapper.depositAsset(baseAsset, amount, 0, alice, ComplianceData(0, ""));
        vm.stopPrank();

        // Rate = 1e18: 100 base → 100 BV; first deposit seeds at SHARE_SCALE × BV.
        assertEq(wShares, amount * SHARE_SCALE, "First depositAsset: wrapper shares = BV * SHARE_SCALE");
        assertEq(wrapper.balanceOf(alice), wShares);
        assertEq(boringVault.balanceOf(address(wrapper)), amount, "Wrapper holds BV shares");
        assertEq(baseAsset.balanceOf(alice), 0, "Alice spent all base asset");
        assertEq(baseAsset.balanceOf(address(wrapper)), 0, "No base asset stranded in wrapper");
    }

    // =========================================================================
    //                   22. depositAsset — proportional after existing supply
    // =========================================================================

    function testDepositAsset_ProportionalAfterSeed() public {
        // Seed the vault via the BV-share path so there's an existing ratio.
        _giveBVShares(alice, 100e18);
        _wrapBV(alice, 100e18);
        // supply = 100e18, totalBV = 100e18, rate = 1e18

        // Bob deposits 50 base → 50 BV shares → 50 wrapper shares (same ratio).
        deal(address(baseAsset), bob, 50e18);
        vm.startPrank(bob);
        baseAsset.approve(address(wrapper), 50e18);
        uint256 wShares = wrapper.depositAsset(baseAsset, 50e18, 0, bob, ComplianceData(0, ""));
        vm.stopPrank();

        // Proportional: with existing supply = 100e18 * SHARE_SCALE and totalAssets = 100e18,
        // depositing 50 BV mints ≈ 50e18 * SHARE_SCALE wrapper shares (virtual-offset rounding error is ~1 wei).
        assertApproxEqAbs(wShares, 50e18 * SHARE_SCALE, 1, "Proportional wrapper shares at 1:1 rate");
        assertEq(wrapper.balanceOf(bob), wShares);
        assertEq(wrapper.totalAssets(), 150e18);
    }

    // =========================================================================
    //                   23. depositAsset → redeemAsset round-trip
    // =========================================================================

    function testDepositAsset_ThenRedeemAsset_RoundTrip() public {
        uint256 amount = 100e18;
        deal(address(baseAsset), alice, amount);

        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), amount);
        uint256 wShares = wrapper.depositAsset(baseAsset, amount, 0, alice, ComplianceData(0, ""));

        // Redeem all wrapper shares for base asset.
        uint256 baseOut = wrapper.redeemAsset(baseAsset, wShares, 0, alice, alice);
        vm.stopPrank();

        // At rate 1:1 and no fees the full amount comes back (minus rounding).
        assertApproxEqAbs(baseOut, amount, 1, "Round-trip: base asset recovered");
        assertEq(wrapper.balanceOf(alice), 0, "No wrapper shares remain");
        assertEq(boringVault.balanceOf(address(wrapper)), 0, "Wrapper holds no BV shares");
        assertApproxEqAbs(baseAsset.balanceOf(alice), amount, 1, "Alice recovers base asset");
    }

    // =========================================================================
    //                   24. redeemAsset — minAssetOut slippage guard (teller)
    // =========================================================================

    function testRedeemAsset_MinAssetOutReverts() public {
        uint256 amount = 100e18;
        deal(address(baseAsset), alice, amount);

        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), amount);
        uint256 wShares = wrapper.depositAsset(baseAsset, amount, 0, alice, ComplianceData(0, ""));

        // 100 wrapper shares → 100 BV shares → 100 base at rate 1:1.
        // Demanding 101 base must revert inside the Teller.
        vm.expectRevert(abi.encodeWithSignature("TellerWithMultiAssetSupport__MinimumAssetsNotMet()"));
        wrapper.redeemAsset(baseAsset, wShares, 101e18, alice, alice);
        vm.stopPrank();
    }

    // =========================================================================
    //                   25. redeemAsset — allowance (owner != msg.sender)
    // =========================================================================

    function testRedeemAsset_WithApproval() public {
        uint256 amount = 100e18;
        deal(address(baseAsset), alice, amount);

        // Alice deposits via asset path.
        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), amount);
        uint256 wShares = wrapper.depositAsset(baseAsset, amount, 0, alice, ComplianceData(0, ""));
        // Alice approves bob to redeem on her behalf.
        wrapper.approve(bob, wShares);
        vm.stopPrank();

        // Bob redeems: base asset goes to bob, wrapper shares burned from alice.
        vm.prank(bob);
        uint256 baseOut = wrapper.redeemAsset(baseAsset, wShares, 0, bob, alice);

        assertApproxEqAbs(baseOut, amount, 1, "Bob receives base asset");
        assertEq(wrapper.balanceOf(alice), 0, "Alice wrapper shares burned");
        assertEq(wrapper.allowance(alice, bob), 0, "Allowance fully consumed");
        assertApproxEqAbs(baseAsset.balanceOf(bob), amount, 1, "Base asset in bob's wallet");
    }

    // =========================================================================
    //                   26. Fees settled before depositAsset
    // =========================================================================

    function testDepositAsset_FeesSettledFirst() public {
        // Seed with alice via BV-share path.
        _giveBVShares(alice, 100e18);
        _wrapBV(alice, 100e18);

        skip(365 days); // 1 year pending mgmt fees, not yet materialised

        // Bob deposits via asset path — fees must be accrued first.
        deal(address(baseAsset), bob, 100e18);
        vm.startPrank(bob);
        baseAsset.approve(address(wrapper), 100e18);
        uint256 bobShares = wrapper.depositAsset(baseAsset, 100e18, 0, bob, ComplianceData(0, ""));
        vm.stopPrank();

        // Fees were minted to feeRecipient during Bob's depositAsset call.
        assertGt(wrapper.balanceOf(feeRecipient), 0, "Fees settled during depositAsset");
        // Bob gets more than 1:1 wrapper shares because he deposited after fee dilution.
        assertGt(bobShares, 100e18, "Bob gets > 1:1 wrapper shares after dilution");
        assertLt(wrapper.convertToAssets(wrapper.balanceOf(alice)), 100e18, "Alice diluted");
    }

    // =========================================================================
    //                   31. Share lock — transparent to wrapper users
    // =========================================================================

    /// @dev bulkDeposit skips _afterPublicDeposit so no lock is ever set on the
    ///      wrapper's BV-share balance, and bulkWithdraw skips beforeTransfer.
    ///      A non-zero Teller shareLockPeriod is therefore fully transparent to
    ///      wrapper vault users — both redeemAsset and standard ERC4626 redeem
    ///      work immediately after deposit.
    function testShareLock5Min_TransparentToWrapperUsers() public {
        // Wire up BeforeTransferHook (production-like) and set 5-minute lock.
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(boringVault), BoringVault.setBeforeTransferHook.selector, true
        );
        boringVault.setBeforeTransferHook(address(teller));
        teller.setShareLockPeriod(5 minutes);

        uint256 amount = 100e18;
        deal(address(baseAsset), alice, amount);

        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), amount);
        uint256 aliceWShares = wrapper.depositAsset(baseAsset, amount, 0, alice, ComplianceData(0, ""));
        vm.stopPrank();

        _giveBVShares(bob, 50e18);
        uint256 bobWShares = _wrapBV(bob, 50e18);

        // ── redeemAsset works immediately — bulkWithdraw skips beforeTransfer ─
        vm.prank(alice);
        uint256 baseOut = wrapper.redeemAsset(baseAsset, aliceWShares, 0, alice, alice);
        assertApproxEqAbs(baseOut, amount, 1, "redeemAsset succeeds immediately despite share lock");

        // ── ERC4626 redeem also works — no lock set (bulkDeposit) ────────────
        vm.prank(bob);
        uint256 bobBVBack = wrapper.redeem(bobWShares, bob, bob);
        assertApproxEqAbs(bobBVBack, 50e18, 1, "ERC4626 redeem succeeds immediately despite share lock");
    }

    // =========================================================================
    //                   27. Fees settled before redeemAsset
    // =========================================================================

    function testRedeemAsset_FeesSettledFirst() public {
        uint256 amount = 100e18;
        deal(address(baseAsset), alice, amount);

        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), amount);
        uint256 wShares = wrapper.depositAsset(baseAsset, amount, 0, alice, ComplianceData(0, ""));
        vm.stopPrank();

        skip(365 days); // 1 year of 2% management fees pending

        uint256 feeSharesBefore = wrapper.balanceOf(feeRecipient);

        vm.prank(alice);
        uint256 baseOut = wrapper.redeemAsset(baseAsset, wShares, 0, alice, alice);

        // Fees were materialised during the redeemAsset call.
        assertGt(wrapper.balanceOf(feeRecipient), feeSharesBefore, "Fees settled during redeemAsset");
        // Alice paid ~2% management fee, so she recovers slightly less than 100 base.
        assertLt(baseOut, amount, "Alice receives less base after fee dilution");
        // But she still gets the vast majority back (fee is only 2% annually).
        assertGt(baseOut, amount * 97 / 100, "Alice recovers at least 97% of base");
    }

    // =========================================================================
    //                   28. Constructor reverts — mismatched vault addresses
    // =========================================================================

    /// @dev Both BadTeller and BadAccountant are exercised in a single test to
    ///      avoid duplicating the decoy-vault deployment boilerplate.
    function testConstructorRevertsOnMismatchedVaultAddresses() public {
        // Deploy a decoy vault so we can build a teller and accountant that are
        // deliberately wired to the wrong BoringVault.
        BoringVault decoyVault = new BoringVault(address(this), "Decoy Vault", "DV", 18);

        TellerWithMultiAssetSupport decoyTeller = new TellerWithMultiAssetSupport(
            address(this), address(decoyVault), address(accountant), address(baseAsset)
        );

        AccountantWithRateProviders decoyAccountant = new AccountantWithRateProviders(
            address(this), address(decoyVault), payoutAddress, 1e18, address(baseAsset), 1.1e4, 0.9e4, 1, 0, 0
        );

        // decoyTeller.vault() == decoyVault != boringVault → BadTeller
        vm.expectRevert(BoringVaultWrapper.BoringVaultWrapper__BadTeller.selector);
        new BoringVaultWrapper(
            address(this), address(boringVault), address(accountant), address(decoyTeller), "Partner Vault", "PV"
        );

        // decoyAccountant.vault() == decoyVault != boringVault → BadAccountant
        vm.expectRevert(BoringVaultWrapper.BoringVaultWrapper__BadAccountant.selector);
        new BoringVaultWrapper(
            address(this), address(boringVault), address(decoyAccountant), address(teller), "Partner Vault", "PV"
        );
    }

    // =========================================================================
    //                   29. DUAL-LAYER FEES — BV and wrapper both charge fees
    // =========================================================================
    //
    //  The wrapper doc says fees are additive: users pay both the BV-level fees
    //  (platform + performance tracked in accountant.feesOwedInBase) and the
    //  wrapper-level fees (management + performance minted as share dilution).
    //
    //  The wrapper charges its performance fee on the GROSS BV rate appreciation
    //  — it has no visibility into BV-level pending fees — so the two layers
    //  compound on top of each other.
    //
    //  Setup:
    //    BV accountant  : 1 %/yr platform fee  +  5 % performance fee
    //    Wrapper        : 2 %/yr management fee + 10 % performance fee  (from setUp)
    //
    //  Timeline:
    //    T0   Alice deposits 100 BV shares into the wrapper.
    //    T0+1 Prime accountant.totalSharesLastUpdate (required: it is 0 from the
    //         constructor because the BV had no shares when the accountant was
    //         deployed; without this, shareSupplyToUse = min(0, 100e18) = 0 and
    //         all BV-level fees would silently compute as zero).
    //    T1   365 days later, BV earns 10 % gross yield.
    //         updateExchangeRate(1.1e18) → BV fees land in feesOwedInBase.
    //         wrapper.accrueFees()      → wrapper fees minted as share dilution.
    //
    // =========================================================================

    function testDualLayerFees_BothVaultsCharged() public {
        // ── Step 1: enable BV-level fees ────────────────────────────────────────
        // setUp() created the accountant with 0/0 BV fees; activate them now.
        accountant.updatePlatformFee(100); // 1 %/yr
        accountant.updatePerformanceFee(500); // 5 % on rate gains
        // Wrapper keeps its setUp() config: 2 %/yr management + 10 % performance.

        // ── Step 2: Alice deposits 100 BV shares ─────────────────────────────────
        _giveBVShares(alice, 100e18);
        _wrapBV(alice, 100e18);
        uint256 aliceWrapperShares = wrapper.balanceOf(alice);
        // State: wrapperSupply = 100e24, totalBV = 100e18, BV rate = 1.0e18

        // ── Step 3: prime accountant.totalSharesLastUpdate ──────────────────────
        // The accountant was constructed before any BV shares existed, so
        // totalSharesLastUpdate is 0. updateExchangeRate writes vault.totalSupply()
        // into that field; without this, _calculatePlatformFee uses
        // shareSupplyToUse = min(0, 100e18) = 0 and fees stay zero.
        skip(1); // satisfy minimumUpdateDelayInSeconds = 1
        accountant.updateExchangeRate(1e18); // no-op rate change; initialises field
        // After this call: totalSharesLastUpdate = 100e18, feesOwedInBase = 0
        // (platform fee elapsed = 1 s ≈ 0; performance fee: rate unchanged, no gain).

        // ── Step 4: 1 year passes, BV earns 10 % gross yield ────────────────────
        skip(365 days);

        // Push the new BV rate.  The accountant calculates BV-level fees:
        //   platform fee  ≈ 1 % × 365 d × min(100e18×1.0, 100e18×1.1)
        //                 = 1 % × 100e18 = 1e18 base units
        //   performance fee = 5 % × (1.1−1.0) × 100e18 = 5 % × 10e18 = 0.5e18
        //   total feesOwedInBase ≈ 1.5e18  (pending; not yet extracted from vault)
        accountant.updateExchangeRate(1.1e18);

        // Destructure the 12-field AccountantState to read feesOwedInBase (field 3).
        (
            , // payoutAddress
            , // highwaterMark
            uint128 bvFeesOwed,
            , // totalSharesLastUpdate
            , // exchangeRate
            , // allowedExchangeRateChangeUpper
            , // allowedExchangeRateChangeLower
            , // lastUpdateTimestamp
            , // isPaused
            , // minimumUpdateDelayInSeconds
            , // platformFee
              // performanceFee
        ) = accountant.accountantState();

        assertGt(bvFeesOwed, 0, "BV feesOwedInBase must be non-zero after rate update");
        // ~1 % platform + ~0.5 % performance of 100e18 AUM ≈ 1.5e18 base units.
        assertApproxEqRel(uint256(bvFeesOwed), 1.5e18, 0.02e18, "BV fees ~1.5% of AUM");

        // ── Step 5: accrue wrapper fees ──────────────────────────────────────────
        //   management fee  ≈ 2 % × 1 yr × 100e24 supply = 2e24 wrapper shares
        //   performance fee : gainBV = 100e18 × 0.1/1.1 ≈ 9.09e18
        //                     feeBV  = 9.09e18 × 10 %   ≈ 0.909e18
        //                     perfShares ≈ 0.909e18 × 102e24 / 100e18 ≈ 0.927e24
        //   total ≈ 2.927e24 wrapper shares
        uint256 feeSharesBefore = wrapper.balanceOf(feeRecipient);
        wrapper.accrueFees();
        uint256 wrapperFeeShares = wrapper.balanceOf(feeRecipient) - feeSharesBefore;

        assertGt(wrapperFeeShares, 0, "Wrapper fee shares must be minted");

        // ── Step 6: wrapper performance fee fired on the GROSS BV rate ───────────
        // The wrapper's HWM advances to 1.1e18, proving it charged perf fee on
        // the full 1.0 → 1.1 move without any deduction for pending BV-level fees.
        assertEq(
            uint256(wrapper.performanceHighWaterMark()), 1.1e18, "Wrapper HWM advances to gross BV rate"
        );

        // ── Step 7: wrapper fees include both management and performance ──────────
        uint256 supplyBeforeFees = 100e18 * SHARE_SCALE;
        uint256 mgmtFeeSharesOnly =
            supplyBeforeFees.mulDivDown(uint256(MGMT_FEE) * 365 days, uint256(1e4) * 365 days);
        assertGt(wrapperFeeShares, mgmtFeeSharesOnly, "Wrapper charged both mgmt and perf fee");

        // ── Step 8: Alice's BV entitlement is reduced by wrapper dilution ─────────
        uint256 aliceBVEntitlement = wrapper.convertToAssets(aliceWrapperShares);
        assertLt(aliceBVEntitlement, 100e18, "Alice's BV entitlement reduced by wrapper fee dilution");
        // Rough check: Alice should recover at least 95 BV shares (fees < 5 %).
        assertGt(aliceBVEntitlement, 95e18, "Alice's loss bounded by fee rates");

        // ── Step 9: two distinct, simultaneously non-zero fee sinks ──────────────
        // BV-level fees sit in accountant.feesOwedInBase and will flow to
        // payoutAddress when boringVault.claimFees() is called.  Wrapper fees
        // already live in feeRecipient's share balance.  Both are non-zero at
        // the same time and flow to different addresses.
        assertTrue(payoutAddress != feeRecipient, "BV payout and wrapper feeRecipient are separate");
        assertGt(uint256(bvFeesOwed), 0, "BV fee sink is funded");
        assertGt(wrapperFeeShares, 0, "Wrapper fee sink is funded");

        // ── Step 10: combined economic burden exceeds either layer alone ──────────
        // Convert wrapper fee shares → BV-asset units for an apples-to-apples sum.
        uint256 wrapperFeeSharesInBV =
            wrapperFeeShares.mulDivDown(wrapper.totalAssets(), wrapper.totalSupply());
        // Convert BV feesOwedInBase (base units) → BV shares at the current rate.
        uint256 bvFeesInBV = uint256(bvFeesOwed).mulDivDown(1e18, 1.1e18);
        uint256 combinedFeesBV = wrapperFeeSharesInBV + bvFeesInBV;

        assertLt(wrapperFeeSharesInBV, combinedFeesBV, "Wrapper layer alone < combined");
        assertLt(bvFeesInBV, combinedFeesBV, "BV layer alone < combined");

        // Sanity: combined fees ≈ 4.4 % of 100e18, so between 3 and 8 BV shares.
        assertGt(combinedFeesBV, 3e18, "Combined fees are material");
        assertLt(combinedFeesBV, 8e18, "Combined fees are within expected bounds");
    }
}
