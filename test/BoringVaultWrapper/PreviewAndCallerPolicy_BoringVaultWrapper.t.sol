// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";

import {TellerWithMultiAssetSupport, ComplianceData} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {BoringVaultWrapper} from "src/base/Roles/BoringVaultWrapper.sol";
import {BVWTestBase} from "./BVWTestBase.sol";

// =============================================================================
//  Fix 1 — previewDeposit / previewMint must return 0
//
//  deposit() and mint() always revert; maxDeposit() / maxMint() return 0.
//  Before the fix, the inherited OZ previewDeposit / previewMint still called
//  _convertToShares/_convertToAssets and returned real non-zero values, giving
//  integrators a believable quote for an entry path that can never execute.
// =============================================================================

contract PreviewDisabled_BoringVaultWrapper_Test is BVWTestBase {
    function setUp() public override {
        super.setUp();
    }

    // ── previewDeposit always 0 ───────────────────────────────────────────────

    function testPreviewDeposit_ZeroInput_ReturnsZero() public view {
        assertEq(wrapper.previewDeposit(0), 0, "previewDeposit(0) == 0");
    }

    function testPreviewDeposit_NonZeroInput_ReturnsZero() public view {
        assertEq(wrapper.previewDeposit(100e18), 0, "previewDeposit(100e18) == 0");
    }

    function testPreviewDeposit_LargeInput_ReturnsZero() public view {
        assertEq(wrapper.previewDeposit(type(uint256).max / 2), 0, "previewDeposit(max/2) == 0");
    }

    // ── previewMint always 0 ─────────────────────────────────────────────────

    function testPreviewMint_ZeroInput_ReturnsZero() public view {
        assertEq(wrapper.previewMint(0), 0, "previewMint(0) == 0");
    }

    function testPreviewMint_NonZeroInput_ReturnsZero() public view {
        assertEq(wrapper.previewMint(100e18), 0, "previewMint(100e18) == 0");
    }

    function testPreviewMint_LargeInput_ReturnsZero() public view {
        assertEq(wrapper.previewMint(type(uint256).max / 2), 0, "previewMint(max/2) == 0");
    }

    // ── Consistency: all four disabled-entry caps are zero together ───────────

    function testAllEntryCapsFour_ZeroBeforeAnyDeposit() public view {
        assertEq(wrapper.maxDeposit(alice), 0, "maxDeposit pre-deposit");
        assertEq(wrapper.maxMint(alice), 0, "maxMint pre-deposit");
        assertEq(wrapper.previewDeposit(1e18), 0, "previewDeposit pre-deposit");
        assertEq(wrapper.previewMint(1e18), 0, "previewMint pre-deposit");
    }

    function testAllEntryCapsFour_ZeroAfterDeposit() public {
        _wrapBV(alice, 100e18);
        // Even with non-zero supply the disabled-entry caps must remain zero.
        assertEq(wrapper.maxDeposit(alice), 0, "maxDeposit post-deposit");
        assertEq(wrapper.maxMint(alice), 0, "maxMint post-deposit");
        assertEq(wrapper.previewDeposit(50e18), 0, "previewDeposit post-deposit");
        assertEq(wrapper.previewMint(50e18 * SHARE_SCALE), 0, "previewMint post-deposit");
    }

    // ── previewWithdraw / previewRedeem are not affected by the fix ───────────

    function testPreviewWithdraw_StillNonZeroAfterDeposit() public {
        _wrapBV(alice, 100e18);
        assertGt(wrapper.previewWithdraw(50e18), 0, "previewWithdraw still works");
    }

    function testPreviewRedeem_StillNonZeroAfterDeposit() public {
        uint256 wShares = _wrapBV(alice, 100e18);
        assertGt(wrapper.previewRedeem(wShares), 0, "previewRedeem still works");
    }

    // ── ERC4626 spec: max == 0  ⟹  preview and actual must not be relied upon ─
    //    Verify the "do not call me" contract: deposit and mint still revert.

    function testDeposit_StillReverts() public {
        vm.expectRevert(BoringVaultWrapper.BoringVaultWrapper__DirectDepositDisabled.selector);
        wrapper.deposit(100e18, alice);
    }

    function testMint_StillReverts() public {
        vm.expectRevert(BoringVaultWrapper.BoringVaultWrapper__DirectDepositDisabled.selector);
        wrapper.mint(100e18 * SHARE_SCALE, alice);
    }
}

// =============================================================================
//  Fix 2 — _enforceCallerPolicy: single beforeTransferData call in depositAsset
//
//  Because depositAsset enforces receiver == msg.sender, all three policy slots
//  (from / to / operator) resolve to the same address. The old code issued three
//  separate teller.beforeTransferData() calls and three doesUserHaveRole checks
//  for the same key. The new _enforceCallerPolicy helper collapses that to one
//  call each. Behaviour must be strictly identical.
// =============================================================================

contract CallerPolicy_BoringVaultWrapper_Test is BVWTestBase {
    uint8 constant TRANSFER_ALLOWED_ROLE = 70;

    function setUp() public override {
        super.setUp();
    }

    // ── denyFrom on caller blocks depositAsset ────────────────────────────────

    function testDepositAsset_DenyFrom_Reverts() public {
        teller.setDenyFlags(alice, true, false, false); // denyFrom

        deal(address(baseAsset), alice, 100e18);
        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), 100e18);
        vm.expectRevert(
            abi.encodeWithSelector(BoringVaultWrapper.BoringVaultWrapper__TransferDenied.selector, alice, alice, alice)
        );
        wrapper.depositAsset(baseAsset, 100e18, 0, alice, ComplianceData(0, ""));
        vm.stopPrank();
    }

    // ── denyTo on caller blocks depositAsset ─────────────────────────────────
    //    (pre-existing test in Compliance_BoringVaultWrapper.t.sol covers this;
    //     included here for completeness of the single-party check surface)

    function testDepositAsset_DenyTo_Reverts() public {
        teller.setDenyFlags(alice, false, true, false); // denyTo

        deal(address(baseAsset), alice, 100e18);
        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), 100e18);
        vm.expectRevert(
            abi.encodeWithSelector(BoringVaultWrapper.BoringVaultWrapper__TransferDenied.selector, alice, alice, alice)
        );
        wrapper.depositAsset(baseAsset, 100e18, 0, alice, ComplianceData(0, ""));
        vm.stopPrank();
    }

    // ── denyOperator on caller blocks depositAsset ────────────────────────────

    function testDepositAsset_DenyOperator_Reverts() public {
        teller.setDenyFlags(alice, false, false, true); // denyOperator

        deal(address(baseAsset), alice, 100e18);
        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), 100e18);
        vm.expectRevert(
            abi.encodeWithSelector(BoringVaultWrapper.BoringVaultWrapper__TransferDenied.selector, alice, alice, alice)
        );
        wrapper.depositAsset(baseAsset, 100e18, 0, alice, ComplianceData(0, ""));
        vm.stopPrank();
    }

    // ── clearing the deny flag unblocks the deposit ───────────────────────────

    function testDepositAsset_ClearDenyFrom_Succeeds() public {
        teller.setDenyFlags(alice, true, false, false);
        teller.setDenyFlags(alice, false, false, false); // cleared

        deal(address(baseAsset), alice, 100e18);
        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), 100e18);
        uint256 wShares = wrapper.depositAsset(baseAsset, 100e18, 0, alice, ComplianceData(0, ""));
        vm.stopPrank();
        assertGt(wShares, 0, "deposit unblocked after clearing denyFrom");
    }

    // ── transferAllowedRole blocks depositAsset when caller lacks the role ────

    function testDepositAsset_TransferAllowedRole_CallerLacksRole_Reverts() public {
        teller.setTransferRestrictions(TRANSFER_ALLOWED_ROLE, type(uint8).max);

        deal(address(baseAsset), alice, 100e18);
        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), 100e18);
        vm.expectRevert(BoringVaultWrapper.BoringVaultWrapper__TransferNotAllowed.selector);
        wrapper.depositAsset(baseAsset, 100e18, 0, alice, ComplianceData(0, ""));
        vm.stopPrank();
    }

    // ── transferAllowedRole: granting the role to caller unblocks deposit ─────

    function testDepositAsset_TransferAllowedRole_CallerHoldsRole_Succeeds() public {
        teller.setTransferRestrictions(TRANSFER_ALLOWED_ROLE, type(uint8).max);
        rolesAuthority.setUserRole(alice, TRANSFER_ALLOWED_ROLE, true);

        deal(address(baseAsset), alice, 100e18);
        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), 100e18);
        uint256 wShares = wrapper.depositAsset(baseAsset, 100e18, 0, alice, ComplianceData(0, ""));
        vm.stopPrank();
        assertGt(wShares, 0, "deposit succeeds with transferAllowedRole");
    }

    // ── transferAllowedRole disabled (type(uint8).max) allows any caller ──────

    function testDepositAsset_TransferAllowedRoleMax_AnyCallerSucceeds() public {
        // Default state in BVWTestBase: transferAllowedRole = 255 (disabled).
        // Verify depositAsset succeeds for an address that holds no roles at all.
        deal(address(baseAsset), alice, 100e18);
        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), 100e18);
        uint256 wShares = wrapper.depositAsset(baseAsset, 100e18, 0, alice, ComplianceData(0, ""));
        vm.stopPrank();
        assertGt(wShares, 0, "no transfer role restriction: deposit succeeds");
    }

    // ── Fund-locking demonstration ────────────────────────────────────────────
    //
    //  This is the canonical reason the transferAllowedRole check must also fire
    //  inside depositAsset, not just on secondary transfers.
    //
    //  When transferAllowedRole is set, every exit path (redeem, withdraw,
    //  redeemAsset) calls _enforceTransferPolicy(shareOwner, receiver, caller).
    //  With all three being the same non-role address, the OR collapses to
    //  doesUserHaveRole(alice) → false → revert on every exit.  A user who
    //  deposits without the role ends up with shares they can NEVER move.
    //
    //  The depositAsset check refuses entry up-front rather than allowing the
    //  deposit and locking the funds silently.
    //
    //  We simulate fund-locking by having Bob (whitelisted) transfer shares to
    //  Alice (non-whitelisted) via a path the OR logic permits (Bob as `from`
    //  satisfies the role check), then show Alice cannot exit by any path.

    function testFundLocking_NonRoleHolder_CannotExitByAnyPath() public {
        teller.setTransferRestrictions(TRANSFER_ALLOWED_ROLE, type(uint8).max);
        rolesAuthority.setUserRole(bob, TRANSFER_ALLOWED_ROLE, true);

        // Bob (whitelisted) deposits and transfers shares to Alice.
        // Transfer is allowed because Bob (from) holds the role — OR semantics.
        uint256 bobShares = _wrapBV(bob, 100e18);
        vm.prank(bob);
        wrapper.transfer(alice, bobShares);
        assertEq(wrapper.balanceOf(alice), bobShares, "alice received shares via whitelisted sender");

        // Alice now holds shares but has no role. Every exit path reverts.

        // redeem to self
        vm.prank(alice);
        vm.expectRevert(BoringVaultWrapper.BoringVaultWrapper__TransferNotAllowed.selector);
        wrapper.redeem(bobShares, alice, alice);

        // withdraw to self
        vm.prank(alice);
        vm.expectRevert(BoringVaultWrapper.BoringVaultWrapper__TransferNotAllowed.selector);
        wrapper.withdraw(50e18, alice, alice);

        // redeemAsset to self
        vm.prank(alice);
        vm.expectRevert(BoringVaultWrapper.BoringVaultWrapper__TransferNotAllowed.selector);
        wrapper.redeemAsset(baseAsset, bobShares, 0, alice, alice);

        // transfer to self (or anyone without the role)
        vm.prank(alice);
        vm.expectRevert(BoringVaultWrapper.BoringVaultWrapper__TransferNotAllowed.selector);
        wrapper.transfer(alice, bobShares);

        // Funds are permanently locked for Alice. The depositAsset check prevents
        // a user from walking into this dead-end via the self-deposit path.
    }

    // ── Behaviour parity: single-party check matches multi-party for same addr ─
    //    Place two depositors, deny only one of them, confirm the other is unaffected.

    function testDepositAsset_DenyOneCallerDoesNotAffectAnother() public {
        teller.setDenyFlags(alice, true, false, false); // alice denied

        // Alice reverts.
        deal(address(baseAsset), alice, 100e18);
        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), 100e18);
        vm.expectRevert(
            abi.encodeWithSelector(BoringVaultWrapper.BoringVaultWrapper__TransferDenied.selector, alice, alice, alice)
        );
        wrapper.depositAsset(baseAsset, 100e18, 0, alice, ComplianceData(0, ""));
        vm.stopPrank();

        // Bob (undeniably different address) succeeds.
        deal(address(baseAsset), bob, 50e18);
        vm.startPrank(bob);
        baseAsset.approve(address(wrapper), 50e18);
        uint256 bobShares = wrapper.depositAsset(baseAsset, 50e18, 0, bob, ComplianceData(0, ""));
        vm.stopPrank();
        assertGt(bobShares, 0, "bob unaffected by alice's deny flag");
    }
}
