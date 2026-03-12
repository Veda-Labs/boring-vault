// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test, console} from "@forge-std/Test.sol";

// Core contracts
import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {AccountantWithYieldStreaming} from "src/base/Roles/AccountantWithYieldStreaming.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {TellerWithYieldStreaming} from "src/base/Roles/TellerWithYieldStreaming.sol";

// Auth
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";

// Tokens
import {ERC20} from "@solmate/tokens/ERC20.sol";

// Mocks
import {MockWETH} from "./mocks/MockWETH.sol";
import {MockERC20Extended} from "./mocks/MockERC20Extended.sol";
import {MockRateProvider} from "./mocks/MockRateProvider.sol";

/**
 * @title BaseSetup
 * @notice Base setup contract for invariant fuzzing tests
 * @dev Deploys BoringVault with dual Accountant/Teller configurations:
 *      - AccountantWithRateProviders + TellerWithMultiAssetSupport
 *      - AccountantWithYieldStreaming + TellerWithYieldStreaming
 */
contract BaseSetup is Test {
    // ============================================
    // CONSTANTS
    // ============================================
    
    uint8 public constant MINTER_ROLE = 1;
    uint8 public constant BURNER_ROLE = 2;
    uint8 public constant MANAGER_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant UPDATE_EXCHANGE_RATE_ROLE = 5;
    uint8 public constant SOLVER_ROLE = 6;
    uint8 public constant OWNER_ROLE = 7;
    uint8 public constant STRATEGIST_ROLE = 8;
    uint8 public constant DENIER_ROLE = 9;
    
    uint256 public constant ONE_SHARE = 1e18;
    uint256 public constant INITIAL_EXCHANGE_RATE = 1e18;
    uint256 public constant INITIAL_MINT = 1_000_000e18;
    
    // ============================================
    // CORE CONTRACTS - TWO SEPARATE SYSTEMS
    // ============================================
    // Each vault uses ONE accounting system to avoid cross-contamination
    // This matches production deployments where a vault is either RP or YS
    
    // RP System: Multi-asset support with rate providers
    BoringVault public vaultRP;
    RolesAuthority public rolesAuthorityRP;
    AccountantWithRateProviders public accountantRP;
    TellerWithMultiAssetSupport public tellerMAS;
    
    // YS System: Yield streaming with vesting
    BoringVault public vaultYS;
    RolesAuthority public rolesAuthorityYS;
    AccountantWithYieldStreaming public accountantYS;
    TellerWithYieldStreaming public tellerYS;
    
    // ============================================
    // MOCK TOKENS
    // ============================================
    
    // Number of alternative assets for multi-asset testing (RP system)
    uint256 public constant NUM_ALT_ASSETS = 5;
    
    // Decimals for each alternative asset (mimics real-world assets)
    // Index 0: 18 decimals (standard ERC20)
    // Index 1: 6 decimals (USDC-like)
    // Index 2: 6 decimals (USDT-like)
    // Index 3: 8 decimals (WBTC-like)
    // Index 4: 11 decimals (unusual, edge case)
    uint8[5] public ALT_ASSET_DECIMALS = [18, 6, 6, 8, 11];
    
    MockWETH public weth;
    MockERC20Extended public baseAsset;
    
    // Alternative assets array for RP multi-asset support
    MockERC20Extended[] public alternativeAssets;
    MockRateProvider[] public altAssetRateProviders;
    
    // Legacy single asset reference (for backward compatibility / convenience)
    // Points to alternativeAssets[0]
    MockERC20Extended public alternativeAsset;
    MockRateProvider public altAssetRateProvider;
    
    // ============================================
    // ACTORS
    // ============================================
    
    address public owner;
    address public payoutAddress;
    address public strategist;
    address public solver;
    address public user1;
    address public user2;
    address public user3;
    address public deniedUser;
    
    address[] public actors;
    
    // ============================================
    // CONFIGURATION
    // ============================================
    
    // Accountant configuration
    uint16 public constant ALLOWED_EXCHANGE_RATE_CHANGE_UPPER = 10100; // 101%
    uint16 public constant ALLOWED_EXCHANGE_RATE_CHANGE_LOWER = 9900;  // 99%
    uint24 public constant MINIMUM_UPDATE_DELAY = 1 hours;
    uint16 public constant PLATFORM_FEE = 100;     // 1%
    uint16 public constant PERFORMANCE_FEE = 1000; // 10%
    
    // Teller configuration
    uint64 public constant SHARE_LOCK_PERIOD = 1 days;
    
    // ============================================
    // SETUP
    // ============================================
    
    function setUp() public virtual {
        // Setup actors
        _setupActors();
        
        // Deploy mocks (shared between both systems)
        _deployMocks();
        
        // Deploy RP System (vault + accountant + teller)
        _deployRPSystem();
        
        // Deploy YS System (vault + accountant + teller)
        _deployYSSystem();
        
        // Setup roles and permissions for both systems
        _setupRoles();
        
        // Configure assets for both systems
        _configureAssets();
        
        // Initial funding for both vaults
        _fundActors();
    }
    
    // ============================================
    // INTERNAL SETUP FUNCTIONS
    // ============================================
    
    function _setupActors() internal {
        owner = address(this);
        payoutAddress = makeAddr("payoutAddress");
        strategist = makeAddr("strategist");
        solver = makeAddr("solver");
        user1 = makeAddr("user1");
        user2 = makeAddr("user2");
        user3 = makeAddr("user3");
        deniedUser = makeAddr("deniedUser");
        
        actors.push(user1);
        actors.push(user2);
        actors.push(user3);
    }
    
    function _deployMocks() internal {
        // Deploy WETH mock
        weth = new MockWETH();
        
        // Deploy base asset (18 decimals)
        baseAsset = new MockERC20Extended("Base Asset", "BASE", 18);
        
        // Deploy multiple alternative assets with rate providers for RP multi-asset testing
        // Each asset has different decimals to test decimal diversity
        for (uint256 i = 0; i < NUM_ALT_ASSETS; i++) {
            string memory name = string(abi.encodePacked("Alternative Asset ", vm.toString(i)));
            string memory symbol = string(abi.encodePacked("ALT", vm.toString(i)));
            
            // Use the decimal configuration for this asset index
            uint8 assetDecimals = ALT_ASSET_DECIMALS[i];
            MockERC20Extended altAsset = new MockERC20Extended(name, symbol, assetDecimals);
            
            // Each alt asset starts with a slightly different rate for diversity
            // IMPORTANT: Rates must be in QUOTE TOKEN's decimals, not 18 decimals!
            // This is required by getRateInQuote formula: rateInQuote = oneQuote * exchangeRate / quoteRate
            // ALT0 (18 dec): 1.0, ALT1 (6 dec): 0.9, ALT2 (6 dec): 1.1, ALT3 (8 dec): 0.8, ALT4 (11 dec): 1.2
            uint256 oneUnit = 10 ** assetDecimals;
            uint256 initialRate;
            if (i == 0) initialRate = oneUnit;              // 1.0 * 10^18 = 1e18
            else if (i == 1) initialRate = oneUnit * 9 / 10; // 0.9 * 10^6 = 9e5
            else if (i == 2) initialRate = oneUnit * 11 / 10; // 1.1 * 10^6 = 1.1e6
            else if (i == 3) initialRate = oneUnit * 8 / 10;  // 0.8 * 10^8 = 8e7
            else initialRate = oneUnit * 12 / 10;            // 1.2 * 10^11 = 1.2e11
            
            MockRateProvider rateProvider = new MockRateProvider(initialRate, assetDecimals);
            
            alternativeAssets.push(altAsset);
            altAssetRateProviders.push(rateProvider);
        }
        
        // Set legacy references for backward compatibility
        alternativeAsset = alternativeAssets[0];
        altAssetRateProvider = altAssetRateProviders[0];
    }
    
    function _deployRPSystem() internal {
        // Deploy RP vault
        vaultRP = new BoringVault(
            owner,
            "Boring Vault RP",
            "BVRP",
            18
        );
        
        // Deploy RP roles authority
        rolesAuthorityRP = new RolesAuthority(owner, Authority(address(0)));
        vaultRP.setAuthority(rolesAuthorityRP);
        
        // Deploy accountant with rate providers
        accountantRP = new AccountantWithRateProviders(
            owner,
            address(vaultRP),
            payoutAddress,
            uint96(INITIAL_EXCHANGE_RATE),
            address(baseAsset),
            ALLOWED_EXCHANGE_RATE_CHANGE_UPPER,
            ALLOWED_EXCHANGE_RATE_CHANGE_LOWER,
            MINIMUM_UPDATE_DELAY,
            PLATFORM_FEE,
            PERFORMANCE_FEE
        );
        accountantRP.setAuthority(rolesAuthorityRP);
        
        // Deploy teller with multi-asset support
        tellerMAS = new TellerWithMultiAssetSupport(
            owner,
            address(vaultRP),
            address(accountantRP),
            address(weth)
        );
        tellerMAS.setAuthority(rolesAuthorityRP);
    }
    
    function _deployYSSystem() internal {
        // Deploy YS vault
        vaultYS = new BoringVault(
            owner,
            "Boring Vault YS",
            "BVYS",
            18
        );
        
        // Deploy YS roles authority
        rolesAuthorityYS = new RolesAuthority(owner, Authority(address(0)));
        vaultYS.setAuthority(rolesAuthorityYS);
        
        // Deploy accountant with yield streaming
        accountantYS = new AccountantWithYieldStreaming(
            owner,
            address(vaultYS),
            payoutAddress,
            uint96(INITIAL_EXCHANGE_RATE),
            address(baseAsset),
            ALLOWED_EXCHANGE_RATE_CHANGE_UPPER,
            ALLOWED_EXCHANGE_RATE_CHANGE_LOWER,
            MINIMUM_UPDATE_DELAY,
            PLATFORM_FEE,
            PERFORMANCE_FEE
        );
        accountantYS.setAuthority(rolesAuthorityYS);
        
        // Deploy teller with yield streaming
        tellerYS = new TellerWithYieldStreaming(
            owner,
            address(vaultYS),
            address(accountantYS),
            address(weth)
        );
        tellerYS.setAuthority(rolesAuthorityYS);
    }
    
    function _setupRoles() internal {
        // ============================================
        // RP SYSTEM ROLES
        // ============================================
        _setupRPRoles();
        
        // ============================================
        // YS SYSTEM ROLES
        // ============================================
        _setupYSRoles();
    }
    
    function _setupRPRoles() internal {
        // VaultRP capabilities
        rolesAuthorityRP.setRoleCapability(MINTER_ROLE, address(vaultRP), BoringVault.enter.selector, true);
        rolesAuthorityRP.setRoleCapability(BURNER_ROLE, address(vaultRP), BoringVault.exit.selector, true);
        rolesAuthorityRP.setRoleCapability(MANAGER_ROLE, address(vaultRP), bytes4(keccak256("manage(address,bytes,uint256)")), true);
        rolesAuthorityRP.setRoleCapability(MANAGER_ROLE, address(vaultRP), bytes4(keccak256("manage(address[],bytes[],uint256[])")), true);
        rolesAuthorityRP.setRoleCapability(OWNER_ROLE, address(vaultRP), BoringVault.setBeforeTransferHook.selector, true);
        
        // AccountantRP capabilities
        rolesAuthorityRP.setRoleCapability(ADMIN_ROLE, address(accountantRP), AccountantWithRateProviders.pause.selector, true);
        rolesAuthorityRP.setRoleCapability(ADMIN_ROLE, address(accountantRP), AccountantWithRateProviders.unpause.selector, true);
        rolesAuthorityRP.setRoleCapability(ADMIN_ROLE, address(accountantRP), AccountantWithRateProviders.updateDelay.selector, true);
        rolesAuthorityRP.setRoleCapability(ADMIN_ROLE, address(accountantRP), AccountantWithRateProviders.updateUpper.selector, true);
        rolesAuthorityRP.setRoleCapability(ADMIN_ROLE, address(accountantRP), AccountantWithRateProviders.updateLower.selector, true);
        rolesAuthorityRP.setRoleCapability(ADMIN_ROLE, address(accountantRP), AccountantWithRateProviders.updatePlatformFee.selector, true);
        rolesAuthorityRP.setRoleCapability(ADMIN_ROLE, address(accountantRP), AccountantWithRateProviders.updatePerformanceFee.selector, true);
        rolesAuthorityRP.setRoleCapability(ADMIN_ROLE, address(accountantRP), AccountantWithRateProviders.updatePayoutAddress.selector, true);
        rolesAuthorityRP.setRoleCapability(ADMIN_ROLE, address(accountantRP), AccountantWithRateProviders.setRateProviderData.selector, true);
        rolesAuthorityRP.setRoleCapability(ADMIN_ROLE, address(accountantRP), AccountantWithRateProviders.resetHighwaterMark.selector, true);
        rolesAuthorityRP.setRoleCapability(UPDATE_EXCHANGE_RATE_ROLE, address(accountantRP), AccountantWithRateProviders.updateExchangeRate.selector, true);
        rolesAuthorityRP.setRoleCapability(MINTER_ROLE, address(accountantRP), AccountantWithRateProviders.claimFees.selector, true);
        
        // TellerMAS capabilities
        rolesAuthorityRP.setRoleCapability(ADMIN_ROLE, address(tellerMAS), TellerWithMultiAssetSupport.pause.selector, true);
        rolesAuthorityRP.setRoleCapability(ADMIN_ROLE, address(tellerMAS), TellerWithMultiAssetSupport.unpause.selector, true);
        rolesAuthorityRP.setRoleCapability(ADMIN_ROLE, address(tellerMAS), TellerWithMultiAssetSupport.updateAssetData.selector, true);
        rolesAuthorityRP.setRoleCapability(ADMIN_ROLE, address(tellerMAS), TellerWithMultiAssetSupport.setShareLockPeriod.selector, true);
        rolesAuthorityRP.setRoleCapability(ADMIN_ROLE, address(tellerMAS), TellerWithMultiAssetSupport.setDepositCap.selector, true);
        rolesAuthorityRP.setRoleCapability(DENIER_ROLE, address(tellerMAS), TellerWithMultiAssetSupport.denyAll.selector, true);
        rolesAuthorityRP.setRoleCapability(DENIER_ROLE, address(tellerMAS), TellerWithMultiAssetSupport.allowAll.selector, true);
        rolesAuthorityRP.setRoleCapability(DENIER_ROLE, address(tellerMAS), TellerWithMultiAssetSupport.denyFrom.selector, true);
        rolesAuthorityRP.setRoleCapability(DENIER_ROLE, address(tellerMAS), TellerWithMultiAssetSupport.allowFrom.selector, true);
        rolesAuthorityRP.setRoleCapability(DENIER_ROLE, address(tellerMAS), TellerWithMultiAssetSupport.denyTo.selector, true);
        rolesAuthorityRP.setRoleCapability(DENIER_ROLE, address(tellerMAS), TellerWithMultiAssetSupport.allowTo.selector, true);
        rolesAuthorityRP.setRoleCapability(DENIER_ROLE, address(tellerMAS), TellerWithMultiAssetSupport.denyOperator.selector, true);
        rolesAuthorityRP.setRoleCapability(DENIER_ROLE, address(tellerMAS), TellerWithMultiAssetSupport.allowOperator.selector, true);
        rolesAuthorityRP.setRoleCapability(ADMIN_ROLE, address(tellerMAS), TellerWithMultiAssetSupport.refundDeposit.selector, true);
        rolesAuthorityRP.setRoleCapability(SOLVER_ROLE, address(tellerMAS), TellerWithMultiAssetSupport.bulkDeposit.selector, true);
        rolesAuthorityRP.setRoleCapability(SOLVER_ROLE, address(tellerMAS), TellerWithMultiAssetSupport.bulkWithdraw.selector, true);
        rolesAuthorityRP.setPublicCapability(address(tellerMAS), TellerWithMultiAssetSupport.deposit.selector, true);
        rolesAuthorityRP.setPublicCapability(address(tellerMAS), TellerWithMultiAssetSupport.depositWithPermit.selector, true);
        rolesAuthorityRP.setPublicCapability(address(tellerMAS), TellerWithMultiAssetSupport.withdraw.selector, true);
        
        // Assign roles for RP system
        rolesAuthorityRP.setUserRole(owner, OWNER_ROLE, true);
        rolesAuthorityRP.setUserRole(owner, ADMIN_ROLE, true);
        rolesAuthorityRP.setUserRole(owner, UPDATE_EXCHANGE_RATE_ROLE, true);
        rolesAuthorityRP.setUserRole(owner, DENIER_ROLE, true);
        rolesAuthorityRP.setUserRole(address(tellerMAS), MINTER_ROLE, true);
        rolesAuthorityRP.setUserRole(address(tellerMAS), BURNER_ROLE, true);
        rolesAuthorityRP.setUserRole(strategist, STRATEGIST_ROLE, true);
        rolesAuthorityRP.setUserRole(solver, SOLVER_ROLE, true);
        rolesAuthorityRP.setUserRole(address(vaultRP), MINTER_ROLE, true); // For fee claiming
    }
    
    function _setupYSRoles() internal {
        // VaultYS capabilities
        rolesAuthorityYS.setRoleCapability(MINTER_ROLE, address(vaultYS), BoringVault.enter.selector, true);
        rolesAuthorityYS.setRoleCapability(BURNER_ROLE, address(vaultYS), BoringVault.exit.selector, true);
        rolesAuthorityYS.setRoleCapability(MANAGER_ROLE, address(vaultYS), bytes4(keccak256("manage(address,bytes,uint256)")), true);
        rolesAuthorityYS.setRoleCapability(MANAGER_ROLE, address(vaultYS), bytes4(keccak256("manage(address[],bytes[],uint256[])")), true);
        rolesAuthorityYS.setRoleCapability(OWNER_ROLE, address(vaultYS), BoringVault.setBeforeTransferHook.selector, true);
        
        // AccountantYS capabilities
        rolesAuthorityYS.setRoleCapability(ADMIN_ROLE, address(accountantYS), AccountantWithRateProviders.pause.selector, true);
        rolesAuthorityYS.setRoleCapability(ADMIN_ROLE, address(accountantYS), AccountantWithRateProviders.unpause.selector, true);
        rolesAuthorityYS.setRoleCapability(ADMIN_ROLE, address(accountantYS), AccountantWithRateProviders.updateDelay.selector, true);
        rolesAuthorityYS.setRoleCapability(ADMIN_ROLE, address(accountantYS), AccountantWithRateProviders.updateUpper.selector, true);
        rolesAuthorityYS.setRoleCapability(ADMIN_ROLE, address(accountantYS), AccountantWithRateProviders.updateLower.selector, true);
        rolesAuthorityYS.setRoleCapability(ADMIN_ROLE, address(accountantYS), AccountantWithRateProviders.updatePlatformFee.selector, true);
        rolesAuthorityYS.setRoleCapability(ADMIN_ROLE, address(accountantYS), AccountantWithRateProviders.updatePerformanceFee.selector, true);
        rolesAuthorityYS.setRoleCapability(ADMIN_ROLE, address(accountantYS), AccountantWithRateProviders.updatePayoutAddress.selector, true);
        rolesAuthorityYS.setRoleCapability(ADMIN_ROLE, address(accountantYS), AccountantWithRateProviders.setRateProviderData.selector, true);
        rolesAuthorityYS.setRoleCapability(ADMIN_ROLE, address(accountantYS), AccountantWithRateProviders.resetHighwaterMark.selector, true);
        rolesAuthorityYS.setRoleCapability(STRATEGIST_ROLE, address(accountantYS), AccountantWithYieldStreaming.vestYield.selector, true);
        rolesAuthorityYS.setRoleCapability(STRATEGIST_ROLE, address(accountantYS), AccountantWithYieldStreaming.postLoss.selector, true);
        rolesAuthorityYS.setRoleCapability(STRATEGIST_ROLE, address(accountantYS), bytes4(keccak256("updateExchangeRate()")), true);
        rolesAuthorityYS.setRoleCapability(MINTER_ROLE, address(accountantYS), AccountantWithYieldStreaming.setFirstDepositTimestamp.selector, true);
        rolesAuthorityYS.setRoleCapability(MINTER_ROLE, address(accountantYS), AccountantWithRateProviders.claimFees.selector, true);
        
        // TellerYS capabilities
        rolesAuthorityYS.setRoleCapability(ADMIN_ROLE, address(tellerYS), TellerWithMultiAssetSupport.pause.selector, true);
        rolesAuthorityYS.setRoleCapability(ADMIN_ROLE, address(tellerYS), TellerWithMultiAssetSupport.unpause.selector, true);
        rolesAuthorityYS.setRoleCapability(ADMIN_ROLE, address(tellerYS), TellerWithMultiAssetSupport.updateAssetData.selector, true);
        rolesAuthorityYS.setRoleCapability(ADMIN_ROLE, address(tellerYS), TellerWithMultiAssetSupport.setShareLockPeriod.selector, true);
        rolesAuthorityYS.setRoleCapability(ADMIN_ROLE, address(tellerYS), TellerWithMultiAssetSupport.setDepositCap.selector, true);
        rolesAuthorityYS.setRoleCapability(DENIER_ROLE, address(tellerYS), TellerWithMultiAssetSupport.denyAll.selector, true);
        rolesAuthorityYS.setRoleCapability(DENIER_ROLE, address(tellerYS), TellerWithMultiAssetSupport.allowAll.selector, true);
        rolesAuthorityYS.setRoleCapability(DENIER_ROLE, address(tellerYS), TellerWithMultiAssetSupport.denyFrom.selector, true);
        rolesAuthorityYS.setRoleCapability(DENIER_ROLE, address(tellerYS), TellerWithMultiAssetSupport.allowFrom.selector, true);
        rolesAuthorityYS.setRoleCapability(DENIER_ROLE, address(tellerYS), TellerWithMultiAssetSupport.denyTo.selector, true);
        rolesAuthorityYS.setRoleCapability(DENIER_ROLE, address(tellerYS), TellerWithMultiAssetSupport.allowTo.selector, true);
        rolesAuthorityYS.setRoleCapability(DENIER_ROLE, address(tellerYS), TellerWithMultiAssetSupport.denyOperator.selector, true);
        rolesAuthorityYS.setRoleCapability(DENIER_ROLE, address(tellerYS), TellerWithMultiAssetSupport.allowOperator.selector, true);
        rolesAuthorityYS.setRoleCapability(ADMIN_ROLE, address(tellerYS), TellerWithMultiAssetSupport.refundDeposit.selector, true);
        rolesAuthorityYS.setRoleCapability(SOLVER_ROLE, address(tellerYS), TellerWithMultiAssetSupport.bulkDeposit.selector, true);
        rolesAuthorityYS.setRoleCapability(SOLVER_ROLE, address(tellerYS), TellerWithMultiAssetSupport.bulkWithdraw.selector, true);
        rolesAuthorityYS.setPublicCapability(address(tellerYS), TellerWithMultiAssetSupport.deposit.selector, true);
        rolesAuthorityYS.setPublicCapability(address(tellerYS), TellerWithMultiAssetSupport.depositWithPermit.selector, true);
        rolesAuthorityYS.setPublicCapability(address(tellerYS), TellerWithMultiAssetSupport.withdraw.selector, true);
        
        // Assign roles for YS system
        rolesAuthorityYS.setUserRole(owner, OWNER_ROLE, true);
        rolesAuthorityYS.setUserRole(owner, ADMIN_ROLE, true);
        rolesAuthorityYS.setUserRole(owner, DENIER_ROLE, true);
        rolesAuthorityYS.setUserRole(address(tellerYS), MINTER_ROLE, true);
        rolesAuthorityYS.setUserRole(address(tellerYS), BURNER_ROLE, true);
        rolesAuthorityYS.setUserRole(address(tellerYS), STRATEGIST_ROLE, true); // For updateExchangeRate() calls in deposit/withdraw
        rolesAuthorityYS.setUserRole(strategist, STRATEGIST_ROLE, true);
        rolesAuthorityYS.setUserRole(solver, SOLVER_ROLE, true);
        rolesAuthorityYS.setUserRole(address(vaultYS), MINTER_ROLE, true); // For fee claiming
    }
    
    function _configureAssets() internal {
        // ============================================
        // RP System Asset Configuration
        // ============================================
        // Configure base asset for RP accountant
        accountantRP.setRateProviderData(baseAsset, true, address(0));
        
        // Configure ALL alternative assets with their rate providers (multi-asset support)
        for (uint256 i = 0; i < NUM_ALT_ASSETS; i++) {
            accountantRP.setRateProviderData(
                alternativeAssets[i], 
                false, 
                address(altAssetRateProviders[i])
            );
            // Allow deposits/withdraws for each alternative asset
            tellerMAS.updateAssetData(alternativeAssets[i], true, true, 0);
        }
        
        // Allow deposits/withdraws for base asset
        tellerMAS.updateAssetData(baseAsset, true, true, 0);
        tellerMAS.setShareLockPeriod(SHARE_LOCK_PERIOD);
        vaultRP.setBeforeTransferHook(address(tellerMAS));
        
        // ============================================
        // YS System Asset Configuration
        // ============================================
        // Configure base asset for YS accountant (YS only uses base asset)
        accountantYS.setRateProviderData(baseAsset, true, address(0));
        
        // Allow deposits/withdraws for base asset only
        tellerYS.updateAssetData(baseAsset, true, true, 0);
        tellerYS.setShareLockPeriod(SHARE_LOCK_PERIOD);
        vaultYS.setBeforeTransferHook(address(tellerYS));
    }
    
    function _fundActors() internal {
        uint256 fundAmount = INITIAL_MINT;
        
        // Fund actors with base asset (enough for both systems)
        baseAsset.mint(user1, fundAmount * 2);
        baseAsset.mint(user2, fundAmount * 2);
        baseAsset.mint(user3, fundAmount * 2);
        baseAsset.mint(solver, fundAmount * 2);
        baseAsset.mint(deniedUser, fundAmount);
        
        // Fund actors with ALL alternative assets (for RP system multi-asset)
        // Amount is scaled by decimals: 1_000_000 tokens in each asset's native decimals
        for (uint256 i = 0; i < NUM_ALT_ASSETS; i++) {
            uint256 altFundAmount = 1_000_000 * (10 ** ALT_ASSET_DECIMALS[i]);
            alternativeAssets[i].mint(user1, altFundAmount);
            alternativeAssets[i].mint(user2, altFundAmount);
            alternativeAssets[i].mint(user3, altFundAmount);
            alternativeAssets[i].mint(solver, altFundAmount);
        }
        
        // Fund RP vault with initial assets for withdrawals (all alternative assets)
        baseAsset.mint(address(vaultRP), fundAmount);
        for (uint256 i = 0; i < NUM_ALT_ASSETS; i++) {
            uint256 altFundAmount = 1_000_000 * (10 ** ALT_ASSET_DECIMALS[i]);
            alternativeAssets[i].mint(address(vaultRP), altFundAmount);
        }
        
        // Fund YS vault with base asset only
        baseAsset.mint(address(vaultYS), fundAmount);
        
        // Give ETH to actors
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
        vm.deal(solver, 100 ether);
    }
    
}

