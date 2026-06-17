// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test} from "@forge-std/Test.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";

import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {BoringVaultWrapper} from "src/base/Roles/BoringVaultWrapper.sol";
import {MockERC20} from "src/helper/MockERC20.sol";

/// @dev Shared base for all BoringVaultWrapper test suites.
///
///      Declares canonical production role IDs, deploys the standard
///      five-contract stack (baseAsset → boringVault → accountant → teller
///      → wrapper), wires roles, and exposes common BV-share helpers.
///
///      Individual test contracts should:
///        • inherit `BVWTestBase`
///        • call `super.setUp()` first in their own `setUp` override
///        • declare only the state / role constants unique to their suite
abstract contract BVWTestBase is Test {
    // ── Production Role IDs ─────────────────────────────────────────────────
    // Source-of-truth values used in the deployed role authority. Copied from bureaucracy/roles.rs
    uint8 constant MANAGER = 1;
    uint8 constant MINTER = 2;
    uint8 constant BURNER = 3;
    uint8 constant MANAGER_INTERNAL = 4;
    uint8 constant PAUSER = 5;
    uint8 constant STRATEGIST = 7;
    uint8 constant OWNER_ROLE = 8; // "OWNER" — role ID 8 in the shared RolesAuthority
    uint8 constant MULTISIG = 9;
    uint8 constant STRATEGIST_MULTISIG = 10;
    uint8 constant UPDATE_EXCHANGE_RATE = 11;
    uint8 constant SOLVER = 12;
    uint8 constant GENERIC_PAUSER = 14;
    uint8 constant GENERIC_UNPAUSER = 15;
    uint8 constant PAUSE_ALL = 16;
    uint8 constant UNPAUSE_ALL = 17;
    uint8 constant SENDER_PAUSER = 18;
    uint8 constant SENDER_UNPAUSER = 19;
    uint8 constant CAN_SOLVE = 31;
    uint8 constant ONLY_QUEUE = 32;
    uint8 constant SOLVER_ORIGIN = 33;
    uint8 constant CANONICAL_ACCOUNTANT = 35;
    uint8 constant SPLIT_DISPERSER = 49;
    uint8 constant BLACKLISTER = 50;
    uint8 constant UNBLACKLISTER = 51;
    uint8 constant BULKUSER = 100;

    // ── Shared scaling constant ─────────────────────────────────────────────
    /// @dev Wrapper shares are 10**DECIMALS_OFFSET (= 1e6) larger than BV shares
    ///      due to the OZ ERC4626 virtual-offset (inflation-attack protection).
    uint256 constant SHARE_SCALE = 1e6;

    // ── Contracts ────────────────────────────────────────────────────────────
    MockERC20 baseAsset;
    BoringVault boringVault;
    AccountantWithRateProviders accountant;
    TellerWithMultiAssetSupport teller;
    BoringVaultWrapper wrapper;
    RolesAuthority rolesAuthority;

    // ── Actors ───────────────────────────────────────────────────────────────
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address feeRecipient = makeAddr("feeRecipient");
    address payoutAddress = makeAddr("payoutAddress");

    // =========================================================================
    //                              SET UP
    // =========================================================================

    function setUp() public virtual {
        baseAsset = new MockERC20("Wrapped Ether", "WETH", 18);
        boringVault = new BoringVault(address(this), "Test Boring Vault", "TBV", 18);
        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), payoutAddress, 1e18, address(baseAsset), 1.1e4, 0.9e4, 1, 0, 0
        );
        teller = new TellerWithMultiAssetSupport(
            address(this), address(boringVault), address(accountant), address(baseAsset)
        );
        wrapper =
            new BoringVaultWrapper(address(this), address(boringVault), address(accountant), "Partner Vault", "PV");
        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));

        boringVault.setAuthority(rolesAuthority);
        accountant.setAuthority(rolesAuthority);
        teller.setAuthority(rolesAuthority);

        // BV enter / exit gated by MINTER / BURNER.
        rolesAuthority.setRoleCapability(MINTER, address(boringVault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER, address(boringVault), BoringVault.exit.selector, true);

        // The wrapper calls teller.bulkDeposit / bulkWithdraw under the BULKUSER role.
        rolesAuthority.setRoleCapability(
            BULKUSER, address(teller), TellerWithMultiAssetSupport.bulkDeposit.selector, true
        );
        rolesAuthority.setRoleCapability(
            BULKUSER, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector, true
        );

        rolesAuthority.setUserRole(address(teller), MINTER, true);
        rolesAuthority.setUserRole(address(teller), BURNER, true);
        rolesAuthority.setUserRole(address(wrapper), BULKUSER, true);

        // Asset + rate-provider configuration.
        // address(this) == owner of all contracts, so auth is bypassed automatically.
        teller.updateAssetData(baseAsset, true, true, 0);
        accountant.setRateProviderData(baseAsset, true, address(0));
        boringVault.setBeforeTransferHook(address(teller));
    }

    // =========================================================================
    //                             HELPERS
    // =========================================================================

    /// @dev Mint BV shares directly to `user` via Foundry deal (bypasses the teller).
    function _giveBVShares(address user, uint256 amount) internal {
        deal(address(boringVault), user, amount, true);
    }

    /// @dev Approve + deposit BV shares into the wrapper.
    function _wrapBV(address user, uint256 bvAmount) internal returns (uint256 wrapperShares) {
        vm.startPrank(user);
        ERC20(address(boringVault)).approve(address(wrapper), bvAmount);
        wrapperShares = wrapper.deposit(bvAmount, user);
        vm.stopPrank();
    }

    /// @dev Deal BV shares to `user` and immediately wrap them.
    ///      Shorthand for the common `_giveBVShares(u, n); _wrapBV(u, n)` pattern.
    function _giveBVAndWrap(address user, uint256 bvAmount) internal {
        _giveBVShares(user, bvAmount);
        _wrapBV(user, bvAmount);
    }
}
