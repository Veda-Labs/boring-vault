// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test, console} from "@forge-std/Test.sol";
import {StdInvariant} from "@forge-std/StdInvariant.sol";

import {YSOnlyInvariants} from "./invariants/YSOnlyInvariants.sol";
import {AccountantHandler} from "./handlers/AccountantHandler.sol";
import {TellerHandler} from "./handlers/TellerHandler.sol";

import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {AccountantWithYieldStreaming} from "src/base/Roles/AccountantWithYieldStreaming.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {TellerWithYieldStreaming} from "src/base/Roles/TellerWithYieldStreaming.sol";

/**
 * @title InvariantTestYS
 * @notice Invariant test suite for the YIELD STREAMING system
 * @dev Inherits from YSOnlyInvariants (which inherits from BaseInvariants)
 * 
 * SYSTEM: AccountantWithYieldStreaming + TellerWithYieldStreaming + vaultYS
 * 
 * INVARIANTS TESTED:
 * - Group 1: Accountant Common (1-7) - via BaseInvariants
 * - Group 2: YS-Specific (8-19, 32, 34, 35) - via YSOnlyInvariants
 * - Group 3: Teller & Vault Integrity (20-31) - via BaseInvariants
 * - Group 4: Math & Solvency (33, 36-48) - via BaseInvariants
 * 
 * TOTAL: All shared invariants + YS-specific invariants
 * Each fuzz run operates exclusively on the YS vault and contracts.
 */
contract InvariantTestYS is YSOnlyInvariants {
    // ============================================
    // HANDLER INSTANCES
    // ============================================
    AccountantHandler public accountantHandler;
    TellerHandler public tellerHandler;

    // ============================================
    // SETUP
    // ============================================
    function setUp() public override {
        // Deploy base infrastructure (from BaseSetup)
        _setupActors();
        _deployMocks();
        _deployRPSystem();
        _deployYSSystem();
        _setupRoles();
        _configureAssets();
        _fundActors();
        
        // Prepare alternative assets arrays for handler constructors
        // Note: YS only uses base asset, but handlers need alt assets for RP compatibility
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
        
        // Fund handlers with base asset (YS only uses base asset)
        deal(address(baseAsset), address(accountantHandler), 10_000_000e18);
        deal(address(baseAsset), address(tellerHandler), 10_000_000e18);
        
        // Fund handlers with all alternative assets (for handler compatibility)
        for (uint256 i = 0; i < NUM_ALT_ASSETS; i++) {
            deal(address(alternativeAssets[i]), address(accountantHandler), 10_000_000e18);
            deal(address(alternativeAssets[i]), address(tellerHandler), 10_000_000e18);
        }
        
        // ============================================
        // TARGET ONLY YS SYSTEM FUNCTIONS
        // ============================================
        
        // Accountant YS functions
        bytes4[] memory accountantYSSelectors = new bytes4[](9);
        accountantYSSelectors[0] = AccountantHandler.vestYield.selector;
        accountantYSSelectors[1] = AccountantHandler.postLoss.selector;
        accountantYSSelectors[2] = AccountantHandler.updateExchangeRateYS.selector;
        accountantYSSelectors[3] = AccountantHandler.claimFeesYS.selector;
        accountantYSSelectors[4] = AccountantHandler.pauseYS.selector;
        accountantYSSelectors[5] = AccountantHandler.unpauseYS.selector;
        accountantYSSelectors[6] = AccountantHandler.resetHighwaterMarkYS.selector;
        accountantYSSelectors[7] = AccountantHandler.warpTime.selector;
        accountantYSSelectors[8] = AccountantHandler.updateVestingParams.selector;
        
        // Teller YS functions (warpTime handled by AccountantHandler)
        bytes4[] memory tellerYSSelectors = new bytes4[](6);
        tellerYSSelectors[0] = TellerHandler.depositYS.selector;
        tellerYSSelectors[1] = TellerHandler.withdrawYS.selector;
        tellerYSSelectors[2] = TellerHandler.bulkDepositYS.selector;
        tellerYSSelectors[3] = TellerHandler.bulkWithdrawYS.selector;
        tellerYSSelectors[4] = TellerHandler.pauseYS.selector;
        tellerYSSelectors[5] = TellerHandler.unpauseYS.selector;
        
        // ============================================
        // TARGETING: ONLY HANDLERS
        // ============================================
        // Use targetContract to ONLY target handlers - this prevents the fuzzer
        // from calling functions directly on MockRateProvider, BoringVault, etc.
        targetContract(address(accountantHandler));
        targetContract(address(tellerHandler));
        
        // Target specific selectors on handlers
        targetSelector(FuzzSelector({addr: address(accountantHandler), selectors: accountantYSSelectors}));
        targetSelector(FuzzSelector({addr: address(tellerHandler), selectors: tellerYSSelectors}));
        
        // Exclude senders that shouldn't be used by fuzzer
        excludeSender(owner);
        excludeSender(strategist);
        excludeSender(payoutAddress);
        excludeSender(address(vaultYS));
        excludeSender(address(accountantYS));
        excludeSender(address(tellerYS));
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
    // ABSTRACT GETTER IMPLEMENTATIONS (BaseInvariants)
    // ============================================
    
    function _accountant() internal view override returns (AccountantWithRateProviders) {
        // YS accountant inherits from RP accountant
        return AccountantWithRateProviders(address(accountantYS));
    }
    
    function _teller() internal view override returns (TellerWithMultiAssetSupport) {
        // YS teller inherits from MAS teller
        return TellerWithMultiAssetSupport(address(tellerYS));
    }
    
    function _vault() internal view override returns (BoringVault) {
        return vaultYS;
    }
    
    function _accountantHandler() internal view override returns (AccountantHandler) {
        return accountantHandler;
    }
    
    function _tellerHandler() internal view override returns (TellerHandler) {
        return tellerHandler;
    }
    
    /// @notice For YS, we use the YSAccountant state (same struct as RPState, but for YS accountant)
    function _getPreState() internal view override returns (AccountantHandler.RPState memory) {
        return accountantHandler.getPreYSAccountant();
    }
    
    /// @notice For YS, we use the YSAccountant state (same struct as RPState, but for YS accountant)
    function _getPostState() internal view override returns (AccountantHandler.RPState memory) {
        return accountantHandler.getPostYSAccountant();
    }
    
    function _getTellerPreState() internal view override returns (TellerHandler.TellerState memory) {
        return tellerHandler.getPreYS();
    }
    
    function _getTellerPostState() internal view override returns (TellerHandler.TellerState memory) {
        return tellerHandler.getPostYS();
    }

    // ============================================
    // ABSTRACT GETTER IMPLEMENTATIONS (YSOnlyInvariants)
    // ============================================
    
    function _accountantYS() internal view override returns (AccountantWithYieldStreaming) {
        return accountantYS;
    }
    
    function _getPreYS() internal view override returns (AccountantHandler.YSState memory) {
        return accountantHandler.getPreYS();
    }
    
    function _getPostYS() internal view override returns (AccountantHandler.YSState memory) {
        return accountantHandler.getPostYS();
    }
}
