// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test, console} from "@forge-std/Test.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MessageHashUtils} from "@openzeppelin-contracts-5.3.0/utils/cryptography/MessageHashUtils.sol";

import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {TellerWithMultiAssetSupport, ComplianceData} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {TellerWithMultiAssetSupportLib} from "src/base/Roles/TellerWithMultiAssetSupportLib.sol";
import {BoringVaultWrapper} from "src/base/Roles/BoringVaultWrapper.sol";
import {MockERC20} from "src/helper/MockERC20.sol";

// ============================================================================
//  Legacy Teller Mock
//
//  Simulates a pre-compliance teller (matches the "Base V0.2" era contract).
//  Intentionally absent:
//    • complianceSignerRole()   — did not exist; wrapper must not revert
//    • transferAllowedRole()    — did not exist; wrapper must not revert
//
//  Present (minimum surface the wrapper actually calls):
//    • vault()              — checked in BoringVaultWrapper constructor/setTeller
//    • authority()          — used by _enforceTransferPolicy (RolesAuthority lookup)
//    • beforeTransferData() — used by _enforceTransferPolicy / _isFeeRecipientBlocked
//    • bulkDeposit()        — called by depositAsset
//    • bulkWithdraw()       — called by redeemAsset
// ============================================================================
contract LegacyTellerMock {
    using FixedPointMathLib for uint256;

    BoringVault public immutable vault;
    AccountantWithRateProviders public immutable accountant;
    address internal _authority;
    uint256 internal immutable ONE_SHARE;

    // Minimal denylist storage mirroring the legacy BeforeTransferData struct.
    // The legacy struct had an extra `permissionedOperator` bool and a uint256
    // shareUnlockTime, but the wrapper only ever reads the first three bools, so
    // a plain 3-bool mapping is sufficient here.
    mapping(address => bool) public denyFromMap;
    mapping(address => bool) public denyToMap;
    mapping(address => bool) public denyOperatorMap;

    constructor(address _vault, address _accountant, address auth_) {
        vault = BoringVault(payable(_vault));
        accountant = AccountantWithRateProviders(_accountant);
        _authority = auth_;
        ONE_SHARE = 10 ** BoringVault(payable(_vault)).decimals();
    }

    // ── Functions called by BoringVaultWrapper ────────────────────────────

    function authority() external view returns (Authority) {
        return Authority(_authority);
    }

    /// @dev Returns (denyFrom, denyTo, denyOperator, shareUnlockTime).
    ///      The wrapper only ever reads fields 0, 1, and 2; field 3 is unused.
    function beforeTransferData(address user)
        external
        view
        returns (bool denyFrom, bool denyTo, bool denyOperator, uint64 shareUnlockTime)
    {
        return (denyFromMap[user], denyToMap[user], denyOperatorMap[user], 0);
    }

    function bulkDeposit(ERC20 depositAsset, uint256 depositAmount, uint256 minimumMint, address to)
        external
        returns (uint256 shares)
    {
        shares = depositAmount.mulDivDown(ONE_SHARE, accountant.getRateInQuoteSafe(depositAsset));
        require(shares >= minimumMint, "LegacyTellerMock: min not met");
        // vault.enter pulls tokens from msg.sender; the wrapper pre-approved the vault.
        vault.enter(msg.sender, depositAsset, depositAmount, to, shares);
    }

    function bulkWithdraw(ERC20 withdrawAsset, uint256 shareAmount, uint256 minimumAssets, address to)
        external
        returns (uint256 assetsOut)
    {
        assetsOut = shareAmount.mulDivDown(accountant.getRateInQuoteSafe(withdrawAsset), ONE_SHARE);
        require(assetsOut >= minimumAssets, "LegacyTellerMock: min assets not met");
        vault.exit(to, withdrawAsset, assetsOut, msg.sender, shareAmount);
    }

    // ── Test helpers ──────────────────────────────────────────────────────

    function setDenyFrom(address user, bool deny) external {
        denyFromMap[user] = deny;
    }

    function setDenyTo(address user, bool deny) external {
        denyToMap[user] = deny;
    }

    // ── Intentionally absent ─────────────────────────────────────────────
    //
    //  complianceSignerRole()   — NOT present (pre-dates compliance feature)
    //  transferAllowedRole()    — NOT present (pre-dates role-based transfer allowlist)
    //
    //  Calling either selector on this contract produces an EVM revert (no
    //  matching function, no fallback).  The try/catch blocks in
    //  BoringVaultWrapper._verifyComplianceSignature and
    //  BoringVaultWrapper._enforceTransferPolicy must handle this gracefully.
}

// ============================================================================
//  Test contract
// ============================================================================
contract LegacyTeller_BoringVaultWrapper_Test is Test {
    using FixedPointMathLib for uint256;

    // ── Role IDs ──────────────────────────────────────────────────────────
    uint8 constant ADMIN_ROLE = 1;
    uint8 constant MINTER_ROLE = 7;
    uint8 constant BURNER_ROLE = 8;
    uint8 constant MODERN_WRAPPER_ROLE = 55;
    uint8 constant COMPLIANCE_ROLE = 60;
    uint8 constant TRANSFER_ALLOWED_ROLE = 70;

    // ── Contracts ─────────────────────────────────────────────────────────
    MockERC20 baseAsset;
    BoringVault boringVault;
    AccountantWithRateProviders accountant;
    LegacyTellerMock legacyTeller;
    BoringVaultWrapper wrapper;          // backed by legacyTeller
    RolesAuthority rolesAuthority;

    // ── Modern-teller setup (regression tests) ────────────────────────────
    TellerWithMultiAssetSupport modernTeller;
    BoringVaultWrapper modernWrapper;

    address payoutAddress = makeAddr("payoutAddress");
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    uint256 constant SIGNER_KEY = uint256(keccak256("compliance-signer-key"));
    address signer;

    uint256 constant SHARE_SCALE = 1e6; // BoringVaultWrapper.DECIMALS_OFFSET

    // =========================================================================
    //                               SET UP
    // =========================================================================

    function setUp() public {
        signer = vm.addr(SIGNER_KEY);

        baseAsset = new MockERC20("Wrapped Ether", "WETH", 18);
        boringVault = new BoringVault(address(this), "Test Boring Vault", "TBV", 18);

        accountant = new AccountantWithRateProviders(
            address(this),
            address(boringVault),
            payoutAddress,
            1e18, // startingExchangeRate — 1 BV share == 1 baseAsset
            address(baseAsset),
            1.1e4,
            0.9e4,
            1,
            0,
            0
        );

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));

        // ── Deploy legacy teller mock ─────────────────────────────────────
        legacyTeller = new LegacyTellerMock(address(boringVault), address(accountant), address(rolesAuthority));

        // ── Deploy wrapper backed by the legacy teller ────────────────────
        wrapper = new BoringVaultWrapper(
            address(this),
            address(boringVault),
            address(accountant),
            address(legacyTeller),
            "Legacy Partner Vault",
            "LPV"
        );

        // ── Deploy modern teller + its wrapper (regression tests) ─────────
        modernTeller = new TellerWithMultiAssetSupport(
            address(this), address(boringVault), address(accountant), address(baseAsset)
        );
        modernWrapper = new BoringVaultWrapper(
            address(this),
            address(boringVault),
            address(accountant),
            address(modernTeller),
            "Modern Partner Vault",
            "MPV"
        );

        // ── Wire authorities ──────────────────────────────────────────────
        boringVault.setAuthority(rolesAuthority);
        accountant.setAuthority(rolesAuthority);
        modernTeller.setAuthority(rolesAuthority);
        wrapper.setAuthority(rolesAuthority);
        modernWrapper.setAuthority(rolesAuthority);

        // ── BoringVault capabilities ──────────────────────────────────────
        rolesAuthority.setRoleCapability(MINTER_ROLE, address(boringVault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(boringVault), BoringVault.exit.selector, true);

        // Legacy mock needs these to call vault.enter / vault.exit.
        rolesAuthority.setUserRole(address(legacyTeller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(legacyTeller), BURNER_ROLE, true);

        // Modern teller likewise.
        rolesAuthority.setUserRole(address(modernTeller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(modernTeller), BURNER_ROLE, true);

        // ── Modern teller capabilities ────────────────────────────────────
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(modernTeller), TellerWithMultiAssetSupport.updateAssetData.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(modernTeller), TellerWithMultiAssetSupport.setComplianceConfig.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(modernTeller), TellerWithMultiAssetSupport.setTransferRestrictions.selector, true
        );
        rolesAuthority.setRoleCapability(
            MODERN_WRAPPER_ROLE, address(modernTeller), TellerWithMultiAssetSupport.bulkDeposit.selector, true
        );
        rolesAuthority.setRoleCapability(
            MODERN_WRAPPER_ROLE, address(modernTeller), TellerWithMultiAssetSupport.bulkWithdraw.selector, true
        );

        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(modernWrapper), MODERN_WRAPPER_ROLE, true);

        // ── Asset + rate-provider config ──────────────────────────────────
        modernTeller.updateAssetData(baseAsset, true, true, 0);
        accountant.setRateProviderData(baseAsset, true, address(0));
    }

    // =========================================================================
    //  HELPER
    // =========================================================================

    function _wrapperHash(
        address wrapperAddr,
        address user,
        address receiver,
        address asset,
        uint256 amount,
        uint256 deadline
    ) internal view returns (bytes32) {
        return keccak256(abi.encode(wrapperAddr, block.chainid, user, receiver, asset, amount, deadline));
    }

    // =========================================================================
    //  TEST 1 — Legacy teller: depositAsset with empty compliance data succeeds
    //
    //  Exercises: _verifyComplianceSignature (missing complianceSignerRole)
    //             _enforceTransferPolicy     (missing transferAllowedRole)
    // =========================================================================
    function test_LegacyTeller_DepositAsset_SkipsComplianceAndAllowlistChecks() public {
        uint256 amount = 100e18;
        deal(address(baseAsset), alice, amount);

        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), amount);
        uint256 wShares = wrapper.depositAsset(baseAsset, amount, 0, alice, ComplianceData(0, ""));
        vm.stopPrank();

        assertEq(wShares, amount * SHARE_SCALE, "first deposit: shares at SHARE_SCALE ratio");
        assertEq(wrapper.balanceOf(alice), wShares, "alice wrapper balance");
        assertEq(boringVault.balanceOf(address(wrapper)), amount, "BV shares landed in wrapper");
    }

    // =========================================================================
    //  TEST 2 — Legacy teller: garbage compliance signature is silently ignored
    // =========================================================================
    function test_LegacyTeller_DepositAsset_GarbageSignatureIgnored() public {
        uint256 amount = 50e18;
        deal(address(baseAsset), alice, amount);

        vm.startPrank(alice);
        baseAsset.approve(address(wrapper), amount);
        uint256 wShares =
            wrapper.depositAsset(baseAsset, amount, 0, alice, ComplianceData(block.timestamp + 1 hours, hex"deadbeef"));
        vm.stopPrank();

        assertGt(wShares, 0, "should have received wrapper shares");
    }

    // =========================================================================
    //  TEST 3 — Legacy teller: standard ERC4626 deposit + redeem succeed
    //
    //  The ERC4626 deposit/redeem paths call _enforceTransferPolicy, which
    //  calls transferAllowedRole().  With the legacy teller that function is
    //  absent; the try/catch must allow both operations to complete.
    // =========================================================================
    function test_LegacyTeller_StandardDepositAndRedeem_Succeed() public {
        uint256 bvAmount = 80e18;
        // Credit alice with BV shares directly (bypasses the teller entirely).
        deal(address(boringVault), alice, bvAmount, true);

        // deposit() → _enforceTransferPolicy → transferAllowedRole() absent → try/catch → ok
        vm.startPrank(alice);
        IERC20(address(boringVault)).approve(address(wrapper), bvAmount);
        uint256 wShares = wrapper.deposit(bvAmount, alice);
        vm.stopPrank();

        assertEq(wShares, bvAmount * SHARE_SCALE, "deposit: shares at SHARE_SCALE ratio");

        // redeem() → _enforceTransferPolicy → same path
        vm.startPrank(alice);
        uint256 bvBack = wrapper.redeem(wShares, alice, alice);
        vm.stopPrank();

        assertEq(bvBack, bvAmount, "redeem: all BV shares returned");
        assertEq(wrapper.balanceOf(alice), 0, "alice wrapper balance zero after redeem");
    }

    // =========================================================================
    //  TEST 4 — Legacy teller: wrapper-share transfer succeeds
    //
    //  transfer() calls _enforceTransferPolicy → transferAllowedRole() absent.
    // =========================================================================
    function test_LegacyTeller_WrapperShareTransfer_Succeeds() public {
        deal(address(boringVault), alice, 100e18, true);
        vm.startPrank(alice);
        IERC20(address(boringVault)).approve(address(wrapper), 100e18);
        wrapper.deposit(100e18, alice);
        // transfer() must not revert even though transferAllowedRole() is absent
        wrapper.transfer(bob, 30e18);
        vm.stopPrank();

        assertEq(wrapper.balanceOf(bob), 30e18, "bob received wrapper shares");
    }

    // =========================================================================
    //  TEST 5 — Legacy teller: denylist is still enforced
    //
    //  Even without transferAllowedRole, the denylist (beforeTransferData)
    //  must still be respected.
    // =========================================================================
    function test_LegacyTeller_DenylistStillEnforced() public {
        deal(address(boringVault), alice, 100e18, true);
        vm.startPrank(alice);
        IERC20(address(boringVault)).approve(address(wrapper), 100e18);
        wrapper.deposit(100e18, alice);
        vm.stopPrank();

        // Sanction bob: he must not receive shares.
        legacyTeller.setDenyTo(bob, true);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(BoringVaultWrapper.BoringVaultWrapper__TransferDenied.selector, alice, bob, alice)
        );
        wrapper.transfer(bob, 10e18);
    }

    // =========================================================================
    //  TEST 6 — Regression: modern teller still enforces compliance when enabled
    // =========================================================================
    function test_ModernTeller_ComplianceStillEnforced_WithLegacyFix() public {
        rolesAuthority.setUserRole(signer, COMPLIANCE_ROLE, true);
        modernTeller.setComplianceConfig(COMPLIANCE_ROLE, 0);

        uint256 amount = 100e18;
        uint256 deadline = block.timestamp + 1 hours;

        // Wrong-domain signature (uses teller address, not wrapper).
        bytes32 wrongHash =
            keccak256(abi.encode(address(modernTeller), block.chainid, alice, alice, address(baseAsset), amount, deadline));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_KEY, MessageHashUtils.toEthSignedMessageHash(wrongHash));

        deal(address(baseAsset), alice, amount);
        vm.startPrank(alice);
        baseAsset.approve(address(modernWrapper), amount);
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupportLib.TellerWithMultiAssetSupport__ComplianceCheckFailed.selector
            )
        );
        modernWrapper.depositAsset(
            baseAsset, amount, 0, alice, ComplianceData(deadline, abi.encodePacked(r, s, v))
        );
        vm.stopPrank();
    }

    // =========================================================================
    //  TEST 7 — Regression: modern teller transfer allowlist still enforced
    // =========================================================================
    function test_ModernTeller_TransferAllowlistStillEnforced_WithLegacyFix() public {
        // Enable transfer allowlist on the modern teller.
        modernTeller.setTransferRestrictions(TRANSFER_ALLOWED_ROLE, type(uint8).max);

        // Role management must happen as the test contract (rolesAuthority owner),
        // not inside a prank.
        deal(address(boringVault), alice, 100e18, true);
        rolesAuthority.setUserRole(alice, TRANSFER_ALLOWED_ROLE, true); // alice may deposit

        vm.startPrank(alice);
        IERC20(address(boringVault)).approve(address(modernWrapper), 100e18);
        modernWrapper.deposit(100e18, alice);
        vm.stopPrank();

        // Revoke the role — now neither alice nor bob holds it.
        rolesAuthority.setUserRole(alice, TRANSFER_ALLOWED_ROLE, false);

        vm.prank(alice);
        vm.expectRevert(BoringVaultWrapper.BoringVaultWrapper__TransferNotAllowed.selector);
        modernWrapper.transfer(bob, 10e18);
    }

    // =========================================================================
    //  TEST 8 — Regression: modern teller accepts a valid compliance signature
    // =========================================================================
    function test_ModernTeller_ValidSignature_StillSucceeds() public {
        rolesAuthority.setUserRole(signer, COMPLIANCE_ROLE, true);
        modernTeller.setComplianceConfig(COMPLIANCE_ROLE, 0);

        uint256 amount = 100e18;
        uint256 deadline = block.timestamp + 1 hours;

        bytes32 hash = _wrapperHash(address(modernWrapper), alice, alice, address(baseAsset), amount, deadline);
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(SIGNER_KEY, MessageHashUtils.toEthSignedMessageHash(hash));

        deal(address(baseAsset), alice, amount);
        vm.startPrank(alice);
        baseAsset.approve(address(modernWrapper), amount);
        uint256 wShares = modernWrapper.depositAsset(
            baseAsset, amount, 0, alice, ComplianceData(deadline, abi.encodePacked(r, s, v))
        );
        vm.stopPrank();

        assertEq(wShares, amount * SHARE_SCALE, "valid sig: shares at SHARE_SCALE ratio");
    }
}
