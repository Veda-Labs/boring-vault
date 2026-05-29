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

contract RedTeam_BoringVaultWrapper_Test is Test {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    uint8 constant ADMIN_ROLE = 1;
    uint8 constant MINTER_ROLE = 7;
    uint8 constant BURNER_ROLE = 8;
    uint8 constant WRAPPER_ROLE = 55; // SOLVER_ROLE proxy granted to wrapper
    uint8 constant SETTER_ROLE = 2;
    uint8 constant DENIER_ROLE = 9;
    uint8 constant COMPLIANCE_ROLE = 10;
    uint8 constant TRANSFER_ALLOWED_ROLE = 11;

    MockERC20 baseAsset;
    BoringVault boringVault;
    AccountantWithRateProviders accountant;
    TellerWithMultiAssetSupport teller;
    BoringVaultWrapper wrapper;
    RolesAuthority rolesAuthority;

    address feeRecipient = makeAddr("feeRecipient");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address mallory = makeAddr("mallory");
    address payoutAddress = makeAddr("payoutAddress");

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
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.updateAssetData.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.setDenyFlags.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.setTransferRestrictions.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.setComplianceConfig.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.bulkDeposit.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector, true
        );

        rolesAuthority.setRoleCapability(
            WRAPPER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkDeposit.selector, true
        );
        rolesAuthority.setRoleCapability(
            WRAPPER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector, true
        );

        // Public teller.deposit() requires_auth — gate it like the real config (open to all)
        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.deposit.selector, true);

        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);
        rolesAuthority.setUserRole(address(wrapper), WRAPPER_ROLE, true);

        teller.updateAssetData(baseAsset, true, true, 0);
        accountant.setRateProviderData(baseAsset, true, address(0));
    }

    function test_DenylistedUserBypassesComplianceViaWrapper() public {
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.setDenyFlags.selector, true
        );
        teller.setDenyFlags(mallory, true, true, true);

        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(boringVault), BoringVault.setBeforeTransferHook.selector, true
        );
        boringVault.setBeforeTransferHook(address(teller));

        // Deposit by sanctioned user now reverts with the wrapper's denylist error.
        deal(address(baseAsset), mallory, 100e18);
        vm.startPrank(mallory);
        baseAsset.approve(address(wrapper), 100e18);
        vm.expectRevert(
            abi.encodeWithSelector(
                BoringVaultWrapper.BoringVaultWrapper__TransferDenied.selector, mallory, mallory, mallory
            )
        );
        wrapper.depositAsset(baseAsset, 100e18, 0, mallory, ComplianceData(0, ""));
        vm.stopPrank();

        // Even if Mallory had wrapper shares somehow, redeemAsset blocks the exit.
        // Seed her with wrapper shares via deal() to isolate the redeemAsset check.
        deal(address(wrapper), mallory, 100e18, true);
        vm.prank(mallory);
        vm.expectRevert(
            abi.encodeWithSelector(
                BoringVaultWrapper.BoringVaultWrapper__TransferDenied.selector, mallory, mallory, mallory
            )
        );
        wrapper.redeemAsset(baseAsset, 100e18, 0, mallory, mallory);
    }

    function test_WrapperSharesTransfersHaveNoHook() public {
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.setDenyFlags.selector, true
        );
        teller.setDenyFlags(mallory, false, true, false); // denyTo only

        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(boringVault), BoringVault.setBeforeTransferHook.selector, true
        );
        boringVault.setBeforeTransferHook(address(teller));

        // Alice acquires wrapper shares legitimately.
        deal(address(baseAsset), alice, 100e18);
        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), 100e18);
        uint256 aliceShares = wrapper.depositAsset(baseAsset, 100e18, 0, alice, ComplianceData(0, ""));

        // Transfer to denylisted Mallory now reverts.
        vm.expectRevert(
            abi.encodeWithSelector(
                BoringVaultWrapper.BoringVaultWrapper__TransferDenied.selector, alice, mallory, alice
            )
        );
        wrapper.transfer(mallory, aliceShares);
        vm.stopPrank();

        assertEq(wrapper.balanceOf(mallory), 0, "Sanctioned user blocked from receiving wrapper shares");
    }

    function test_ComplianceSignatureBypassed() public {
        teller.setComplianceConfig(COMPLIANCE_ROLE, 0);

        deal(address(baseAsset), alice, 100e18);
        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), 100e18);
        // No signer is registered for COMPLIANCE_ROLE → any sig fails.
        vm.expectRevert();
        wrapper.depositAsset(baseAsset, 100e18, 0, alice, ComplianceData(block.timestamp + 1 hours, hex"00"));
        vm.stopPrank();
    }

    // We deliberately do NOT grant the role to the
    // wrapper in the allowlist check — the wrapper is the operator AND the
    // check requires operator OR from OR to to have the role.
    //
    function test_TransferAllowlistBypassed() public {
        teller.setTransferRestrictions(TRANSFER_ALLOWED_ROLE, type(uint8).max);
        // Note: NOT granting TRANSFER_ALLOWED_ROLE to the wrapper here — the fix
        // enforces this on the real user, so the wrapper holding the role would
        // re-open the bypass. Real deployments must not grant it to the wrapper.

        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(boringVault), BoringVault.setBeforeTransferHook.selector, true
        );
        boringVault.setBeforeTransferHook(address(teller));

        deal(address(baseAsset), mallory, 100e18);
        vm.startPrank(mallory);
        baseAsset.approve(address(wrapper), 100e18);
        vm.expectRevert(BoringVaultWrapper.BoringVaultWrapper__TransferNotAllowed.selector);
        wrapper.depositAsset(baseAsset, 100e18, 0, mallory, ComplianceData(0, ""));
        vm.stopPrank();
    }

    //
    // OZ ERC4626 with _decimalsOffset() = 6.
    // Conversion is now `assets * (supply + 10^6) / (totalAssets + 1)`, which makes
    // the donation always strictly more expensive than what the attacker can recover.
    // This test runs the same playbook and proves the attacker LOSES money.
    //
    function test_InflationAttackOnFirstDepositor() public {
        // Attacker seeds with 1 wei base. Virtual offset gives them 10^6 wrapper shares,
        // not 1 — they pay nothing to acquire the offset.
        deal(address(baseAsset), mallory, 1);
        vm.startPrank(mallory);
        baseAsset.approve(address(wrapper), 1);
        uint256 attackerWShares = wrapper.depositAsset(baseAsset, 1, 0, mallory, ComplianceData(0, ""));
        vm.stopPrank();

        // Attacker donates 400 BV shares directly.
        uint256 donation = 400e18;
        deal(address(boringVault), mallory, donation, true);
        vm.prank(mallory);
        boringVault.transfer(address(wrapper), donation);

        // Victim Alice deposits 500 BV shares.
        deal(address(boringVault), alice, 500e18, true);
        vm.startPrank(alice);
        boringVault.approve(address(wrapper), 500e18);
        uint256 aliceWShares = wrapper.deposit(500e18, alice);
        vm.stopPrank();

        // Attacker redeems their wrapper shares.
        vm.prank(mallory);
        uint256 attackerOut = wrapper.redeem(attackerWShares, mallory, mallory);

        // Attack must be unprofitable: recovered < (1 wei base ≈ 1 wei BV) + donation.
        // Equivalently: attackerOut < 400e18 + 1.
        assertLt(attackerOut, donation + 1, "Inflation attack is unprofitable: attacker loses BV");

        // And Alice should recover (approximately) her full 500 BV deposit. Any tiny
        // rounding loss (sub-ppb) flows into the virtual-offset "well", not the attacker.
        vm.prank(alice);
        uint256 aliceOut = wrapper.redeem(aliceWShares, alice, alice);
        // Empirically Alice's rounding loss is ~9e13 wei (≈ 1.8e-7 of 500 BV).
        assertApproxEqAbs(aliceOut, 500e18, 1e15, "Alice recovers ~full deposit (sub-ppm rounding only)");
    }

    // perf-fee accrual is now skipped when accountant is paused.
    // Wrapper still functions (mgmt fee continues, deposits/redeems work) so users
    // are not locked in during a pause.
    function test_PerformanceFeeAccruesEvenWhenAccountantPaused() public {
        wrapper.setFeeConfig(feeRecipient, 200, 1000);

        deal(address(baseAsset), alice, 100e18);
        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), 100e18);
        wrapper.depositAsset(baseAsset, 100e18, 0, alice, ComplianceData(0, ""));
        vm.stopPrank();

        // Push rate up so a perf fee would normally be charged, then pause.
        skip(2);
        accountant.updateExchangeRate(1.05e18);
        accountant.pause();

        // getRateSafe reverts while paused; getRate still returns the cached value.
        vm.expectRevert();
        accountant.getRateSafe();

        // Snapshot HWM and feeRecipient shares before the pause-time accrual.
        uint96 hwmBefore = wrapper.performanceHighWaterMark();
        uint256 feeSharesBefore = wrapper.balanceOf(feeRecipient);

        skip(180 days); // long enough that mgmt fee is clearly non-trivial
        wrapper.accrueFees();

        // HWM must NOT advance while the accountant is paused.
        assertEq(wrapper.performanceHighWaterMark(), hwmBefore, "HWM frozen during pause");

        // Some shares accrued, but only mgmt — bounded by mgmt formula on supply for 180 days.
        // For supply ~ 100e18 * SHARE_SCALE and 2% over 180 days, expected ~9.86e23. Anything
        // significantly above that would imply perf fee leaked through.
        uint256 mgmtExpected = (100e18 * 1e6 * uint256(200) * 180 days) / (uint256(1e4) * 365 days);
        uint256 accrued = wrapper.balanceOf(feeRecipient) - feeSharesBefore;
        assertApproxEqRel(accrued, mgmtExpected, 0.01e18, "Only mgmt fee accrues during pause");
    }

    function test_DepositCapShared_AcrossPaths() public {
        // Set a tight deposit cap
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.setDepositCap.selector, true
        );
        teller.setDepositCap(50e18); // 50 shares cap

        // First wrapper-routed deposit succeeds (40 shares)
        deal(address(baseAsset), alice, 40e18);
        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), 40e18);
        wrapper.depositAsset(baseAsset, 40e18, 0, alice, ComplianceData(0, ""));
        vm.stopPrank();

        // Second wrapper-routed deposit exceeding the cap reverts
        deal(address(baseAsset), bob, 20e18);
        vm.startPrank(bob);
        baseAsset.approve(address(wrapper), 20e18);
        vm.expectRevert();
        wrapper.depositAsset(baseAsset, 20e18, 0, bob, ComplianceData(0, ""));
        vm.stopPrank();
    }
}
