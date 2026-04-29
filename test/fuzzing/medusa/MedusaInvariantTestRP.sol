// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test, console} from "@forge-std/Test.sol";
import {StdInvariant} from "@forge-std/StdInvariant.sol";

import {BaseInvariants} from "./invariants/BaseInvariants.sol";
import {AccountantHandler} from "./handlers/AccountantHandler.sol";
import {TellerHandler} from "../handlers/TellerHandler.sol";

import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";

/**
 * @title MedusaInvariantTestRP
 * @notice Invariant test suite for the RATE PROVIDER system (Medusa-compatible)
 * @dev Inherits from BaseInvariants and implements abstract getters for RP system
 *      Named differently from Foundry version to avoid compilation conflicts.
 *
 * SYSTEM: AccountantWithRateProviders + TellerWithMultiAssetSupport + vaultRP
 *
 * INVARIANTS TESTED (via BaseInvariants inheritance):
 * - Group 1: Accountant Common (1-7)
 * - Group 3: Teller & Vault Integrity (20-31)
 * - Group 4: Math & Solvency (33, 36-48)
 *
 * TOTAL: All shared invariants, focused on RP system only
 * Each fuzz run operates exclusively on the RP vault and contracts.
 */
contract MedusaInvariantTestRP is BaseInvariants {
    // ============================================
    // HANDLER INSTANCES
    // ============================================
    AccountantHandler public accountantHandler;
    TellerHandler public tellerHandler;

    // ============================================
    // CONSTRUCTOR - Medusa requires setup in constructor
    // ============================================
    constructor() {
        _medusaSetUp();
    }

    // ============================================
    // SETUP - Called from constructor for Medusa compatibility
    // ============================================
    function setUp() public override {
        // No-op for Foundry compatibility - actual setup in constructor
    }

    function _medusaSetUp() internal {
        // Deploy base infrastructure (from BaseSetup)
        _setupActors();
        _deployMocks();
        _deployRPSystem();
        _deployYSSystem();
        _setupRoles();
        _configureAssets();
        _fundActors();

        // Prepare alternative assets arrays for handler constructors
        address[] memory altAssetAddresses = new address[](NUM_ALT_ASSETS);
        address[] memory altRateProviderAddresses = new address[](NUM_ALT_ASSETS);
        for (uint256 i = 0; i < NUM_ALT_ASSETS; i++) {
            altAssetAddresses[i] = address(alternativeAssets[i]);
            altRateProviderAddresses[i] = address(altAssetRateProviders[i]);
        }

        // Deploy handlers with N-asset support
        accountantHandler = new AccountantHandler(
            address(accountantRP),
            address(accountantYS),
            address(vaultRP),
            address(vaultYS),
            address(baseAsset),
            altAssetAddresses,
            altRateProviderAddresses,
            owner,
            strategist,
            payoutAddress
        );

        tellerHandler = new TellerHandler(
            address(tellerMAS),
            address(tellerYS),
            address(vaultRP),
            address(vaultYS),
            address(baseAsset),
            altAssetAddresses,
            owner,
            solver,
            deniedUser,
            actors
        );

        // Wire up handlers
        tellerHandler.setAccountantHandler(address(accountantHandler));

        // Fund handlers with base asset (using mint instead of deal for Medusa compatibility)
        baseAsset.mint(address(accountantHandler), 10_000_000e18);
        baseAsset.mint(address(tellerHandler), 10_000_000e18);

        // Fund handlers with ALL alternative assets (for handler compatibility)
        for (uint256 i = 0; i < NUM_ALT_ASSETS; i++) {
            alternativeAssets[i].mint(address(accountantHandler), 10_000_000e18);
            alternativeAssets[i].mint(address(tellerHandler), 10_000_000e18);
        }

        // ============================================
        // TARGET ONLY RP SYSTEM FUNCTIONS
        // ============================================

        // Accountant RP functions (N-asset support)
        bytes4[] memory accountantRPSelectors = new bytes4[](13);
        accountantRPSelectors[0] = AccountantHandler.updateExchangeRateRP.selector;
        accountantRPSelectors[1] = AccountantHandler.claimFeesRP.selector;
        accountantRPSelectors[2] = AccountantHandler.pauseRP.selector;
        accountantRPSelectors[3] = AccountantHandler.unpauseRP.selector;
        accountantRPSelectors[4] = AccountantHandler.resetHighwaterMarkRP.selector;
        accountantRPSelectors[5] = bytes4(keccak256("setAltAssetRate(uint256,uint256)"));
        accountantRPSelectors[6] = AccountantHandler.updatePlatformFeeRP.selector;
        accountantRPSelectors[7] = AccountantHandler.updatePerformanceFeeRP.selector;
        accountantRPSelectors[8] = AccountantHandler.updateBoundsRP.selector;
        accountantRPSelectors[9] = AccountantHandler.updateDelayRP.selector;
        accountantRPSelectors[10] = AccountantHandler.setRateProviderDataRP.selector;
        accountantRPSelectors[11] = AccountantHandler.updatePayoutAddressRP.selector;
        accountantRPSelectors[12] = AccountantHandler.warpTime.selector;

        // Teller MAS functions (N-asset support)
        // Note: depositAltMAS and withdrawAltMAS are now parameterized by asset index
        // Note: warpTime is handled by AccountantHandler only
        bytes4[] memory tellerMASSelectors = new bytes4[](27);
        tellerMASSelectors[0] = TellerHandler.depositMAS.selector;
        tellerMASSelectors[1] = TellerHandler.withdrawMAS.selector;
        tellerMASSelectors[2] = TellerHandler.bulkDepositMAS.selector;
        tellerMASSelectors[3] = TellerHandler.bulkWithdrawMAS.selector;
        tellerMASSelectors[4] = bytes4(keccak256("depositAltMAS(uint256,uint256,uint256,uint256)")); // Parameterized by asset index
        tellerMASSelectors[5] = bytes4(keccak256("withdrawAltMAS(uint256,uint256,uint256,uint256,uint256)")); // Parameterized by asset index
        tellerMASSelectors[6] = TellerHandler.pauseMAS.selector;
        tellerMASSelectors[7] = TellerHandler.unpauseMAS.selector;
        tellerMASSelectors[8] = TellerHandler.denyUserMAS.selector;
        tellerMASSelectors[9] = TellerHandler.allowUserMAS.selector;
        tellerMASSelectors[10] = TellerHandler.setShareLockPeriodMAS.selector;
        tellerMASSelectors[11] = TellerHandler.setDepositCapMAS.selector;
        // Granular deny/allow controls
        tellerMASSelectors[12] = TellerHandler.denyFromMAS.selector;
        tellerMASSelectors[13] = TellerHandler.denyToMAS.selector;
        tellerMASSelectors[14] = TellerHandler.allowFromMAS.selector;
        tellerMASSelectors[15] = TellerHandler.allowToMAS.selector;
        tellerMASSelectors[16] = TellerHandler.denyOperatorMAS.selector;
        tellerMASSelectors[17] = TellerHandler.allowOperatorMAS.selector;
        // Deposit cap boundary testing
        tellerMASSelectors[18] = TellerHandler.depositNearCapMAS.selector;
        tellerMASSelectors[19] = TellerHandler.setDepositCapNearSupplyMAS.selector;
        // Edge case testing
        tellerMASSelectors[20] = TellerHandler.updateAssetDataMAS.selector;
        tellerMASSelectors[21] = TellerHandler.depositTinyMAS.selector;
        tellerMASSelectors[22] = TellerHandler.withdrawLockedMAS.selector;
        tellerMASSelectors[23] = TellerHandler.withdrawZeroMinMAS.selector;
        // Refund and denied user testing (critical for invariant coverage)
        tellerMASSelectors[24] = TellerHandler.refundDepositMAS.selector;
        tellerMASSelectors[25] = TellerHandler.depositAsDeniedUser.selector;
        tellerMASSelectors[26] = TellerHandler.transferFromDeniedUser.selector;

        // ============================================
        // TARGETING: ONLY HANDLERS
        // ============================================
        // Use targetContract to ONLY target handlers - this prevents the fuzzer
        // from calling functions directly on MockRateProvider, BoringVault, etc.
        targetContract(address(accountantHandler));
        targetContract(address(tellerHandler));

        // Target specific selectors on handlers
        targetSelector(FuzzSelector({addr: address(accountantHandler), selectors: accountantRPSelectors}));
        targetSelector(FuzzSelector({addr: address(tellerHandler), selectors: tellerMASSelectors}));

        // Exclude senders that shouldn't be used by fuzzer
        excludeSender(owner);
        excludeSender(strategist);
        excludeSender(payoutAddress);
        excludeSender(address(vaultRP));
        excludeSender(address(accountantRP));
        excludeSender(address(tellerMAS));
        excludeSender(address(accountantHandler));
        excludeSender(address(tellerHandler));

        // Exclude mock contracts from being targeted directly
        excludeContract(address(baseAsset));
        excludeContract(address(vaultRP));
        excludeContract(address(vaultYS));
        excludeContract(address(accountantRP));
        excludeContract(address(accountantYS));
        excludeContract(address(tellerMAS));
        excludeContract(address(tellerYS));
        excludeContract(address(rolesAuthorityRP));
        excludeContract(address(rolesAuthorityYS));

        // Exclude ALL alternative assets and rate providers (N-asset support)
        for (uint256 i = 0; i < NUM_ALT_ASSETS; i++) {
            excludeContract(address(alternativeAssets[i]));
            excludeContract(address(altAssetRateProviders[i]));
        }
    }

    // ============================================
    // ABSTRACT GETTER IMPLEMENTATIONS
    // ============================================

    function _accountant() internal view override returns (AccountantWithRateProviders) {
        return accountantRP;
    }

    function _teller() internal view override returns (TellerWithMultiAssetSupport) {
        return tellerMAS;
    }

    function _vault() internal view override returns (BoringVault) {
        return vaultRP;
    }

    function _accountantHandler() internal view override returns (AccountantHandler) {
        return accountantHandler;
    }

    function _tellerHandler() internal view override returns (TellerHandler) {
        return tellerHandler;
    }

    function _getPreState() internal view override returns (AccountantHandler.RPState memory) {
        return accountantHandler.getPreRP();
    }

    function _getPostState() internal view override returns (AccountantHandler.RPState memory) {
        return accountantHandler.getPostRP();
    }

    function _getTellerPreState() internal view override returns (TellerHandler.TellerState memory) {
        return tellerHandler.getPreMAS();
    }

    function _getTellerPostState() internal view override returns (TellerHandler.TellerState memory) {
        return tellerHandler.getPostMAS();
    }
}
