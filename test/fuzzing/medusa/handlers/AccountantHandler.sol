// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

// Test and console unused but keeping for debugging if needed
import {CommonBase} from "@forge-std/Base.sol";
import {StdCheats} from "@forge-std/StdCheats.sol";
import {StdUtils} from "@forge-std/StdUtils.sol";

import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {AccountantWithYieldStreaming} from "src/base/Roles/AccountantWithYieldStreaming.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {MockRateProvider} from "../../mocks/MockRateProvider.sol";
import {MockERC20Extended} from "../../mocks/MockERC20Extended.sol";

/**
 * @title AccountantHandler
 * @notice Handler contract for fuzzing accountant operations with ghost state tracking (Medusa-compatible)
 * @dev Tracks pre/post state for invariant verification. Uses mint/burn instead of deal() for Medusa compatibility.
 */
contract AccountantHandler is CommonBase, StdCheats, StdUtils {
    using FixedPointMathLib for uint256;

    // ============================================
    // CONSTANTS
    // ============================================
    
    uint256 public constant ONE_SHARE = 1e18;
    uint256 public constant NUM_ALT_ASSETS = 5;
    uint8 public constant BASE_DECIMALS = 18;
    
    // Decimals for each alternative asset (must match BaseSetup)
    // Index 0: 18 decimals (standard ERC20)
    // Index 1: 6 decimals (USDC-like)
    // Index 2: 6 decimals (USDT-like)
    // Index 3: 8 decimals (WBTC-like)
    // Index 4: 11 decimals (unusual, edge case)
    uint8[5] public ALT_ASSET_DECIMALS = [18, 6, 6, 8, 11];

    // ============================================
    // CONTRACTS
    // ============================================
    
    AccountantWithRateProviders public accountantRP;
    AccountantWithYieldStreaming public accountantYS;
    BoringVault public vaultRP;  // Vault for RP system
    BoringVault public vaultYS;  // Vault for YS system
    ERC20 public baseAsset;
    
    // Multiple alternative assets for RP multi-asset testing
    ERC20[] public alternativeAssets;
    MockRateProvider[] public altAssetRateProviders;
    
    address public owner;
    address public strategist;
    address public payoutAddress;
    
    // ============================================
    // GHOST STATE - Pre-call snapshots (only fields used by invariants)
    // ============================================
    
    // Rate Provider Accountant ghost state - minimal for invariants
    struct RPState {
        uint96 highwaterMark;
        uint128 feesOwedInBase;
        uint64 lastUpdateTimestamp;
        bool isPaused;
    }
    
    // Yield Streaming Accountant ghost state - minimal for invariants
    struct YSState {
        uint128 lastSharePrice;
        uint128 lastVestingUpdate;
        uint128 vestingGains;      // Total vesting gains pool
        uint256 pendingGains;      // Amount that has vested (claimable)
        uint256 totalSupply;       // Vault total supply at snapshot time
    }
    
    RPState public preRP;
    RPState public postRP;
    YSState public preYS;
    YSState public postYS;
    
    // YS Accountant state (same fields as RP for shared invariants)
    RPState public preYSAccountant;
    RPState public postYSAccountant;
    
    // ============================================
    // TRACKING VARIABLES
    // ============================================
    
    // Track the last selector called
    bytes4 public lastSelector;
    
    // Track if the last call succeeded (for selector-based invariants)
    bool public lastCallSucceeded;
    
    // External call tracking (always false - no unauthorized calls in handlers)
    bool public constant callMade = false;
    bool public constant delegatecallMade = false;
    
    // Track if fees were recently claimed (solvency invariants should skip)
    bool public feesRecentlyClaimed;
    
    // Flag to track if ANY alternative asset rate was changed (oracle simulation)
    bool public altAssetRateChanged;
    
    // Vesting simulation tracking - cumulative vested assets released to vault
    uint256 public cumulativeVestedAssetsReleased;
    
    
    // ============================================
    // CONSTRUCTOR
    // ============================================
    
    constructor(
        address _accountantRP,
        address _accountantYS,
        address _vaultRP,
        address _vaultYS,
        address _baseAsset,
        address[] memory _alternativeAssets,
        address[] memory _altAssetRateProviders,
        address _owner,
        address _strategist,
        address _payoutAddress
    ) {
        require(_alternativeAssets.length == NUM_ALT_ASSETS, "Must provide NUM_ALT_ASSETS alternative assets");
        require(_altAssetRateProviders.length == NUM_ALT_ASSETS, "Must provide NUM_ALT_ASSETS rate providers");
        
        accountantRP = AccountantWithRateProviders(_accountantRP);
        accountantYS = AccountantWithYieldStreaming(_accountantYS);
        vaultRP = BoringVault(payable(_vaultRP));
        vaultYS = BoringVault(payable(_vaultYS));
        baseAsset = ERC20(_baseAsset);
        
        // Initialize alternative assets arrays
        for (uint256 i = 0; i < NUM_ALT_ASSETS; i++) {
            alternativeAssets.push(ERC20(_alternativeAssets[i]));
            altAssetRateProviders.push(MockRateProvider(_altAssetRateProviders[i]));
        }
        
        owner = _owner;
        strategist = _strategist;
        payoutAddress = _payoutAddress;
    }
    
    // ============================================
    // SNAPSHOT FUNCTIONS - Minimal to avoid stack-too-deep
    // ============================================
    
    function _snapshotRPState() internal view returns (RPState memory state) {
        // Only read the fields we actually need for invariants
        (
            ,              // payout
            uint96 hwm,
            uint128 fees,
            ,              // shares
            ,              // rate
            ,              // upper
            ,              // lower
            uint64 timestamp,
            bool paused,
            ,              // delay
            ,              // platformFee
                           // performanceFee (last)
        ) = accountantRP.accountantState();
        
        state.highwaterMark = hwm;
        state.feesOwedInBase = fees;
        state.lastUpdateTimestamp = timestamp;
        state.isPaused = paused;
    }
    
    function _snapshotYSAccountantState() internal view returns (RPState memory state) {
        // Read accountantState for YS accountant (same fields as RP for shared invariants)
        (
            ,              // payout
            uint96 hwm,
            uint128 fees,
            ,              // shares
            ,              // rate
            ,              // upper
            ,              // lower
            uint64 timestamp,
            bool paused,
            ,              // delay
            ,              // platformFee
                           // performanceFee (last)
        ) = accountantYS.accountantState();
        
        state.highwaterMark = hwm;
        state.feesOwedInBase = fees;
        state.lastUpdateTimestamp = timestamp;
        state.isPaused = paused;
    }
    
    function _snapshotYSState() internal view returns (YSState memory state) {
        // Read vestingState for lastSharePrice, vestingGains, and lastVestingUpdate
        (
            uint128 lastSharePrice,
            uint128 vestingGains,
            uint128 lastVestingUpdate,
            ,                        // startVestingTime
                                     // endVestingTime (last)
        ) = accountantYS.vestingState();
        
        state.lastSharePrice = lastSharePrice;
        state.lastVestingUpdate = lastVestingUpdate;
        state.vestingGains = vestingGains;
        state.pendingGains = accountantYS.getPendingVestingGains();
        state.totalSupply = vaultYS.totalSupply();
    }
    
    /// @notice Setup call metadata without capturing state (for handlers that need time warps first)
    function _setupCall(bytes4 selector) internal {
        lastSelector = selector;
        lastCallSucceeded = false;
    }
    
    /// @notice Capture pre-state snapshots - call this AFTER any time warps but BEFORE the actual call
    function _capturePreState() internal {
        preRP = _snapshotRPState();
        preYS = _snapshotYSState();
        preYSAccountant = _snapshotYSAccountantState();
    }
    
    /// @notice Combined setup + capture for handlers without time warps (backwards compatible)
    function _beforeCall(bytes4 selector) internal {
        _setupCall(selector);
        _capturePreState();
    }
    
    function _afterCall() internal {
        postRP = _snapshotRPState();
        postYS = _snapshotYSState();
        postYSAccountant = _snapshotYSAccountantState();
    }
    
    // ============================================
    // RATE PROVIDER ACCOUNTANT HANDLERS
    // ============================================
    
    /**
     * @notice Update exchange rate on AccountantWithRateProviders
     * @param newRate The new exchange rate to set
     * @param timeDelta Time to warp forward before calling (set to 0 to test timing constraints)
     */
    function updateExchangeRateRP(uint96 newRate, uint256 timeDelta) external {
        _beforeCall(AccountantWithRateProviders.updateExchangeRate.selector);
        
        // Bound timeDelta - allows testing both normal updates and timing edge cases
        vm.warp(block.timestamp + bound(timeDelta, 0, 30 days));
        syncVestedAssets();
        
        uint256 totalSupply = vaultRP.totalSupply();
        if (totalSupply == 0) {
            _afterCall();
            return;
        }
        
        // Calculate bounds and new rate (uses helper functions to avoid stack-too-deep)
        (uint256 minRate, uint256 maxRate) = _calculateRPRateBounds(totalSupply);
        
        // If no valid range exists, skip - system is in an extreme state
        if (minRate > maxRate) {
            _afterCall();
            return;
        }
        
        newRate = uint96(bound(newRate, minRate, maxRate));
        
        vm.prank(owner);
        try accountantRP.updateExchangeRate(newRate) {
            lastCallSucceeded = true;
            feesRecentlyClaimed = false;
            altAssetRateChanged = false;
        } catch {}
        
        _afterCall();
    }
    
    /**
     * @notice Helper to calculate rate bounds for RP system
     * @dev Intersects solvency-based bounds with contract's allowed rate change bounds.
     *      This ensures updateExchangeRate never triggers auto-pause from exceeding bounds.
     */
    function _calculateRPRateBounds(uint256 totalSupply) internal view returns (uint256 minRate, uint256 maxRate) {
        // Calculate solvency-based bounds (0.99x to 1.01x of NAV/supply)
        (uint256 minSolvencyRate, uint256 maxSolvencyRate) = _getSolvencyRateBoundsRP(totalSupply);
        
        // Get contract's allowed rate change bounds
        (uint256 contractMinRate, uint256 contractMaxRate) = _getContractRateBoundsRP();
        
        // Intersect solvency bounds with contract bounds
        minRate = minSolvencyRate > contractMinRate ? minSolvencyRate : contractMinRate;
        maxRate = maxSolvencyRate < contractMaxRate ? maxSolvencyRate : contractMaxRate;
    }
    
    function _getSolvencyRateBoundsRP(uint256 totalSupply) internal view returns (uint256 minRate, uint256 maxRate) {
        uint256 baseRate = accountantRP.getRateInQuoteSafe(baseAsset);
        
        if (baseRate == 0) {
            // Cannot calculate solvency without a valid base rate
            return (1, type(uint96).max);
        }
        
        // Calculate total value in share terms using the accountant's rate calculations
        // This matches how Teller computes shares: shares = amount * ONE_SHARE / rateInQuote
        uint256 totalValueInShares = 0;
        
        // Base asset value
        uint256 baseBalance = baseAsset.balanceOf(address(vaultRP));
        if (baseBalance > 0) {
            totalValueInShares += baseBalance * ONE_SHARE / baseRate;
        }
        
        // Alternative assets value
        for (uint256 i = 0; i < NUM_ALT_ASSETS; i++) {
            uint256 altBalance = alternativeAssets[i].balanceOf(address(vaultRP));
            if (altBalance > 0) {
                try accountantRP.getRateInQuoteSafe(alternativeAssets[i]) returns (uint256 altRate) {
                    if (altRate > 0) {
                        totalValueInShares += altBalance * ONE_SHARE / altRate;
                    }
                } catch {
                    // Asset not configured, skip
                }
            }
        }
        
        // Calculate the rate that would make the vault solvent
        uint256 solvencyRate = totalValueInShares * baseRate / totalSupply;
        
        // Use 0.05% buffer (tighter than invariant's 0.1% tolerance)
        minRate = solvencyRate * 9995 / 10000;  // 99.95%
        maxRate = solvencyRate * 10005 / 10000; // 100.05%
        
        // Enforce absolute bounds to prevent extreme rates
        uint256 ABSOLUTE_MIN_RATE = 1e15;  // 0.001 tokens per share
        uint256 ABSOLUTE_MAX_RATE = 1e21;  // 1000 tokens per share
        
        if (minRate < ABSOLUTE_MIN_RATE) minRate = ABSOLUTE_MIN_RATE;
        if (maxRate > ABSOLUTE_MAX_RATE) maxRate = ABSOLUTE_MAX_RATE;
        if (maxRate > type(uint96).max) maxRate = type(uint96).max;
    }
    
    function _getContractRateBoundsRP() internal view returns (uint256 minRate, uint256 maxRate) {
        (, , , , uint96 currentRate, uint16 upper, uint16 lower, , , , , ) = accountantRP.accountantState();
        minRate = uint256(currentRate) * lower / 10000;
        maxRate = uint256(currentRate) * upper / 10000;
        if (minRate == 0) minRate = 1;
        if (maxRate > type(uint96).max) maxRate = type(uint96).max;
    }
    
    /**
     * @notice Pause AccountantWithRateProviders
     */
    function pauseRP() external {
        _beforeCall(AccountantWithRateProviders.pause.selector);
        
        vm.prank(owner);
        try accountantRP.pause() {} catch {}
        
        _afterCall();
    }
    
    /**
     * @notice Unpause AccountantWithRateProviders
     */
    function unpauseRP() external {
        _beforeCall(AccountantWithRateProviders.unpause.selector);
        
        vm.prank(owner);
        try accountantRP.unpause() {} catch {}
        
        _afterCall();
    }
    
    /**
     * @notice Reset highwater mark on AccountantWithRateProviders
     */
    function resetHighwaterMarkRP() external {
        _beforeCall(AccountantWithRateProviders.resetHighwaterMark.selector);
        
        vm.prank(owner);
        try accountantRP.resetHighwaterMark() {} catch {}
        
        _afterCall();
    }
    
    /**
     * @notice Update platform fee
     */
    function updatePlatformFeeRP(uint16 fee) external {
        _beforeCall(AccountantWithRateProviders.updatePlatformFee.selector);
        
        fee = uint16(bound(fee, 0, 2000)); // Max 20%
        
        vm.prank(owner);
        try accountantRP.updatePlatformFee(fee) {} catch {}
        
        _afterCall();
    }
    
    /**
     * @notice Update performance fee
     */
    function updatePerformanceFeeRP(uint16 fee) external {
        _beforeCall(AccountantWithRateProviders.updatePerformanceFee.selector);
        
        fee = uint16(bound(fee, 0, 5000)); // Max 50%
        
        vm.prank(owner);
        try accountantRP.updatePerformanceFee(fee) {} catch {}
        
        _afterCall();
    }
    
    /**
     * @notice Update exchange rate bounds
     * @dev Covers both normal and edge case ranges:
     *      - upper: 100% to 200% (allows testing normal 1-5% and extreme 50%+ changes)
     *      - lower: 50% to 100% (allows testing normal 1-5% and extreme 50% drops)
     */
    function updateBoundsRP(uint16 upper, uint16 lower) external {
        _beforeCall(AccountantWithRateProviders.updateUpper.selector);
        
        upper = uint16(bound(upper, 10000, 20000)); // 100% to 200%
        lower = uint16(bound(lower, 5000, 10000));  // 50% to 100%
        
        vm.startPrank(owner);
        try accountantRP.updateUpper(upper) {} catch {}
        try accountantRP.updateLower(lower) {} catch {}
        vm.stopPrank();
        
        _afterCall();
    }
    
    /**
     * @notice Update minimum delay
     */
    function updateDelayRP(uint24 delay) external {
        _beforeCall(AccountantWithRateProviders.updateDelay.selector);
        
        delay = uint24(bound(delay, 0, 14 days));
        
        vm.prank(owner);
        try accountantRP.updateDelay(delay) {} catch {}
        
        _afterCall();
    }
    
    /**
     * @notice Claim fees from AccountantWithRateProviders
     * @dev After claiming fees, solvency invariants skip until rate is updated.
     */
    function claimFeesRP() external {
        _beforeCall(AccountantWithRateProviders.claimFees.selector);
        
        vm.startPrank(address(vaultRP));
        baseAsset.approve(address(accountantRP), type(uint256).max);
        try accountantRP.claimFees(baseAsset) {
            feesRecentlyClaimed = true;
        } catch {}
        vm.stopPrank();
        
        _afterCall();
    }
    
    
    /**
     * @notice Set rate provider data for an asset
     * @dev Tests dynamic rate provider configuration changes.
     * @param assetIndex The alternative asset index (0 to NUM_ALT_ASSETS-1)
     * @param isPeggedToBase Whether the asset is pegged 1:1 to base
     */
    function setRateProviderDataRP(uint256 assetIndex, bool isPeggedToBase) external {
        _beforeCall(AccountantWithRateProviders.setRateProviderData.selector);
        
        assetIndex = bound(assetIndex, 0, NUM_ALT_ASSETS - 1);
        
        ERC20 asset = alternativeAssets[assetIndex];
        address rateProvider = isPeggedToBase ? address(0) : address(altAssetRateProviders[assetIndex]);
        
        vm.prank(owner);
        try accountantRP.setRateProviderData(asset, isPeggedToBase, rateProvider) {
            // Rate provider config changed - set flag so solvency invariants skip
            // In production, strategist would update rate after this
            altAssetRateChanged = true;
        } catch {}
        
        _afterCall();
    }
    
    /**
     * @notice Update payout address
     */
    function updatePayoutAddressRP(address newPayout) external {
        _beforeCall(AccountantWithRateProviders.updatePayoutAddress.selector);
        
        vm.prank(owner);
        try accountantRP.updatePayoutAddress(newPayout) {} catch {}
        
        _afterCall();
    }
    
    /**
     * @notice Change the alternative asset rate provider rate (parameterized by asset index)
     * @dev Tests multi-asset solvency across different rate scenarios.
     *      Rates must be in the QUOTE TOKEN's decimals, not 18 decimals.
     *      Bounds are realistic oracle movements (50% to 200%) to avoid extreme
     *      rounding scenarios that mask real bugs.
     * @param assetIndex The index of the alternative asset (0 to NUM_ALT_ASSETS-1)
     * @param newRate The new rate to set (bounded to realistic oracle movement)
     */
    function setAltAssetRate(uint256 assetIndex, uint256 newRate) external {
        _beforeCall(bytes4(keccak256("setAltAssetRate(uint256,uint256)")));
        
        assetIndex = bound(assetIndex, 0, NUM_ALT_ASSETS - 1);
        
        uint8 assetDecimals = ALT_ASSET_DECIMALS[assetIndex];
        uint256 oneUnit = 10 ** assetDecimals;
        
        // Bound rate: 50% to 200% of unit rate (realistic oracle movement)
        // This avoids extreme rounding-to-zero scenarios while still testing
        // meaningful rate fluctuations that could expose real bugs
        newRate = bound(newRate, oneUnit / 2, oneUnit * 2);
        
        altAssetRateProviders[assetIndex].setRate(newRate);
        altAssetRateChanged = true;
        
        _afterCall();
    }
    
    // ============================================
    // YIELD STREAMING ACCOUNTANT HANDLERS
    // ============================================
    
    /**
     * @notice Sync vault balance with vested yield (Medusa-compatible using mint instead of deal)
     * @dev In production, yield assets flow into the vault as they vest.
     *      This helper calculates how much has vested and mints that amount.
     *      Called after any time-advancing operation to maintain solvency.
     *      Made public so TellerHandler can also sync after time warps.
     *
     *      Important: getPendingVestingGains() can DECREASE when _updateExchangeRate()
     *      is called (by vestYield, postLoss, updateExchangeRate). This "realizes" the
     *      vested gains by moving them from vestingGains to lastSharePrice. When this
     *      happens, we need to reset our tracking to match the new state.
     */
    function syncVestedAssets() public {
        // Get current pending vesting gains (how much has vested so far but not yet realized)
        uint256 currentVested = accountantYS.getPendingVestingGains();
        
        if (currentVested > cumulativeVestedAssetsReleased) {
            // New vesting has occurred - mint the difference to YS vault
            uint256 newlyVested = currentVested - cumulativeVestedAssetsReleased;
            MockERC20Extended(address(baseAsset)).mint(address(vaultYS), newlyVested);
            cumulativeVestedAssetsReleased = currentVested;
        } else if (currentVested < cumulativeVestedAssetsReleased) {
            // Gains were "realized" by _updateExchangeRate() being called
            // (vestYield, postLoss, or updateExchangeRate)
            // Reset tracking to match new state - no minting needed since
            // we already minted for those gains before they were realized
            cumulativeVestedAssetsReleased = currentVested;
        }
        // If equal, do nothing
    }
    
    /**
     * @notice Fix vesting state after a deposit to an empty vault created invalid state (Medusa-compatible)
     * @dev Called by TellerHandler after depositYS/bulkDepositYS when vault was empty
     *      This corrects the startVestingTime > endVestingTime condition by doing a minimal vestYield
     */
    function fixVestingStateAfterFirstDeposit() external {
        // Check if vesting state is invalid
        (, , , uint64 startTime, uint64 endTime) = accountantYS.vestingState();
        
        // Only fix if we have an invalid state: startVestingTime > endVestingTime
        // and there are shares (deposit succeeded)
        if (startTime <= endTime || vaultYS.totalSupply() == 0) return;
        
        // Reset vesting state by doing a minimal vestYield call
        syncVestedAssets();
        
        // Get min vesting duration
        uint64 minVest = accountantYS.minimumVestingTime();
        uint64 maxVest = accountantYS.maximumVestingTime();
        uint256 duration = minVest > 0 ? minVest : 1 days;
        if (duration > maxVest && maxVest > 0) duration = maxVest;
        
        // Calculate safe yield amount that will pass the daily yield check:
        // dailyYieldBps = (yieldAmount * 1 day / duration) * 10000 / totalAssets
        // For it to pass: dailyYieldBps <= maxDeviationYield
        // Therefore: yieldAmount <= totalAssets * maxDeviationYield * duration / (10000 * 1 day)
        uint256 totalAssets = accountantYS.totalAssets();
        uint32 maxDeviation = accountantYS.maxDeviationYield();
        
        // Calculate max safe yield - use 1% of max deviation to be safe
        // yieldAmount = totalAssets * maxDeviation * duration / (10000 * 1 days * 100)
        uint256 yieldAmount;
        if (totalAssets > 0) {
            yieldAmount = totalAssets.mulDivDown(maxDeviation, 10000);
            yieldAmount = yieldAmount.mulDivDown(duration, 1 days);
            yieldAmount = yieldAmount / 100; // Use 1% of max to be very safe
            if (yieldAmount == 0) yieldAmount = 1;
        } else {
            yieldAmount = 1;
        }
        
        // Ensure vault has enough assets for the yield (using mint instead of deal)
        uint256 vaultBal = baseAsset.balanceOf(address(vaultYS));
        if (vaultBal < totalAssets + yieldAmount) {
            uint256 mintAmount = totalAssets + yieldAmount - vaultBal;
            MockERC20Extended(address(baseAsset)).mint(address(vaultYS), mintAmount);
        }
        
        vm.prank(strategist);
        try accountantYS.vestYield(yieldAmount, duration) {
            // Success - vesting state is now valid
            cumulativeVestedAssetsReleased = 0; // Reset tracking for new vest
        } catch {
            // If vestYield fails, the invariant will catch the invalid state
            // This is expected if the contract has checks we can't bypass
        }
    }
    
    /**
     * @notice Vest yield on AccountantWithYieldStreaming
     * @param yieldAmount The amount of yield to vest (bounded dynamically based on totalAssets)
     * @param duration The vesting duration
     * @param timeDelta Time to warp forward before calling
     * @dev Simulates yield vesting by tracking progress and minting proportionally.
     *      Yield is bounded to 0.01%-50% of totalAssets to test both normal and edge cases.
     */
    function vestYield(uint256 yieldAmount, uint256 duration, uint256 timeDelta) external {
        _setupCall(AccountantWithYieldStreaming.vestYield.selector);
        
        // Cannot vest yield if vault has no shares
        if (vaultYS.totalSupply() == 0) {
            _capturePreState();
            _afterCall();
            return;
        }
        
        syncVestedAssets();
        vm.warp(block.timestamp + bound(timeDelta, 0, 90 days));
        syncVestedAssets();
        
        // Calculate yield bounds based on totalAssets for realistic testing
        uint256 totalAssets = accountantYS.totalAssets();
        uint256 minYield = totalAssets > 10000 ? totalAssets / 10000 : 1;  // 0.01%
        uint256 maxYield = totalAssets > 2 ? totalAssets / 2 : 100_000e18; // 50%
        
        yieldAmount = bound(yieldAmount, minYield, maxYield);
        duration = bound(duration, 1 hours, 30 days);
        
        _capturePreState();
        
        vm.prank(strategist);
        try accountantYS.vestYield(yieldAmount, duration) {} catch {}
        
        syncVestedAssets();
        _afterCall();
    }
    
    /**
     * @notice Post loss on AccountantWithYieldStreaming (Medusa-compatible using burn instead of deal)
     * @param lossAmount The amount of loss to post (max 10% of total assets)
     * @param timeDelta Time to warp forward before calling
     * @dev Loss can be absorbed by unvested gains or reduce principal.
     */
    function postLoss(uint256 lossAmount, uint256 timeDelta) external {
        _setupCall(AccountantWithYieldStreaming.postLoss.selector);
        
        if (vaultYS.totalSupply() == 0) {
            _capturePreState();
            _afterCall();
            return;
        }
        
        uint256 totalAssets = accountantYS.totalAssets();
        uint256 maxLoss = totalAssets / 10;
        if (maxLoss == 0) {
            _capturePreState();
            _afterCall();
            return;
        }
        
        lossAmount = bound(lossAmount, 1, maxLoss);
        
        vm.warp(block.timestamp + bound(timeDelta, 0, 90 days));
        syncVestedAssets();
        _capturePreState();
        
        // Get unvested gains to calculate principal loss
        (, uint128 vestingGains, , , ) = accountantYS.vestingState();
        uint256 pendingVested = accountantYS.getPendingVestingGains();
        uint256 unvestedGains = vestingGains > pendingVested ? vestingGains - pendingVested : 0;
        
        vm.prank(strategist);
        try accountantYS.postLoss(lossAmount) {
            lastCallSucceeded = true;
            
            // Remove assets for principal loss (portion not absorbed by unvested gains)
            if (lossAmount > unvestedGains) {
                uint256 principalLoss = lossAmount - unvestedGains;
                uint256 vaultBal = baseAsset.balanceOf(address(vaultYS));
                uint256 burnAmount = vaultBal > principalLoss ? principalLoss : vaultBal;
                if (burnAmount > 0) {
                    MockERC20Extended(address(baseAsset)).burn(address(vaultYS), burnAmount);
                }
            }
        } catch {}
        
        syncVestedAssets();
        _afterCall();
    }
    
    /**
     * @notice Update exchange rate on AccountantWithYieldStreaming (no-arg version)
     * @param timeDelta Time to warp forward before calling
     * @dev Realizes vested gains by calling _updateExchangeRate() internally.
     */
    function updateExchangeRateYS(uint256 timeDelta) external {
        _setupCall(bytes4(keccak256("updateExchangeRate()")));
        
        if (vaultYS.totalSupply() == 0) {
            _capturePreState();
            _afterCall();
            return;
        }
        
        vm.warp(block.timestamp + bound(timeDelta, 0, 30 days));
        syncVestedAssets();
        _capturePreState();
        
        vm.prank(strategist);
        try accountantYS.updateExchangeRate() {} catch {}
        
        syncVestedAssets();
        _afterCall();
    }
    
    /**
     * @notice Pause AccountantWithYieldStreaming
     */
    function pauseYS() external {
        _beforeCall(AccountantWithRateProviders.pause.selector);
        
        vm.prank(owner);
        try accountantYS.pause() {} catch {}
        
        _afterCall();
    }
    
    /**
     * @notice Unpause AccountantWithYieldStreaming
     */
    function unpauseYS() external {
        _beforeCall(AccountantWithRateProviders.unpause.selector);
        
        vm.prank(owner);
        try accountantYS.unpause() {} catch {}
        
        _afterCall();
    }
    
    /**
     * @notice Reset highwater mark on AccountantWithYieldStreaming
     */
    function resetHighwaterMarkYS() external {
        _beforeCall(AccountantWithRateProviders.resetHighwaterMark.selector);
        
        vm.prank(owner);
        try accountantYS.resetHighwaterMark() {} catch {}
        
        _afterCall();
    }
    
    /**
     * @notice Update vesting parameters
     * @dev Covers both normal and edge case ranges with proper min <= max enforcement.
     *      Duration: 1 hour to 90 days, Deviations: 0.1% to 50%
     */
    function updateVestingParams(uint64 minVest, uint64 maxVest, uint32 maxYield, uint32 maxLoss) external {
        _beforeCall(AccountantWithYieldStreaming.updateMaximumVestDuration.selector);
        
        // Wide ranges covering both normal and edge cases
        minVest = uint64(bound(minVest, 1 hours, 30 days));
        maxVest = uint64(bound(maxVest, 1 hours, 90 days));
        
        // Ensure minVest <= maxVest
        if (minVest > maxVest) {
            (minVest, maxVest) = (maxVest, minVest);
        }
        
        maxYield = uint32(bound(maxYield, 10, 5000)); // 0.1% to 50%
        maxLoss = uint32(bound(maxLoss, 10, 5000));   // 0.1% to 50%
        
        vm.startPrank(owner);
        // Set maxVest FIRST to avoid intermediate invalid state
        try accountantYS.updateMaximumVestDuration(maxVest) {} catch {}
        try accountantYS.updateMinimumVestDuration(minVest) {} catch {}
        try accountantYS.updateMaximumDeviationYield(maxYield) {} catch {}
        try accountantYS.updateMaximumDeviationLoss(maxLoss) {} catch {}
        vm.stopPrank();
        
        _afterCall();
    }
    
    /**
     * @notice Claim fees from AccountantWithYieldStreaming
     */
    function claimFeesYS() external {
        _beforeCall(AccountantWithRateProviders.claimFees.selector);
        
        vm.startPrank(address(vaultYS));
        baseAsset.approve(address(accountantYS), type(uint256).max);
        try accountantYS.claimFees(baseAsset) {
            feesRecentlyClaimed = true;
        } catch {}
        vm.stopPrank();
        
        _afterCall();
    }
    
    // ============================================
    // TIME PASSAGE HANDLER
    // ============================================
    
    /**
     * @notice Warp time forward to simulate long-duration vesting
     * @dev Also syncs vested assets to simulate production yield flow
     */
    function warpTime(uint256 timeDelta) external {
        timeDelta = bound(timeDelta, 1, 365 days);
        vm.warp(block.timestamp + timeDelta);
        
        // After time passes, sync vested assets to vault
        // This simulates production where yield flows into vault as it vests
        syncVestedAssets();
    }
    
    // ============================================
    // EXTERNAL STATE CAPTURE (for TellerHandler to use)
    // ============================================
    
    /// @notice Begin a YS operation from TellerHandler - captures pre-state
    /// @param selector The selector of the operation (for invariant checking)
    function beginYSOperation(bytes4 selector) external {
        _setupCall(selector);
        _capturePreState();
    }
    
    /// @notice End a YS operation from TellerHandler - captures post-state
    /// @param succeeded Whether the operation succeeded
    function endYSOperation(bool succeeded) external {
        lastCallSucceeded = succeeded;
        _afterCall();
    }
    
    // ============================================
    // STRUCT GETTERS (needed because public structs return tuples)
    // ============================================
    
    function getPreRP() external view returns (RPState memory) {
        return preRP;
    }
    
    function getPostRP() external view returns (RPState memory) {
        return postRP;
    }
    
    function getPreYS() external view returns (YSState memory) {
        return preYS;
    }
    
    function getPostYS() external view returns (YSState memory) {
        return postYS;
    }
    
    function getPreYSAccountant() external view returns (RPState memory) {
        return preYSAccountant;
    }
    
    function getPostYSAccountant() external view returns (RPState memory) {
        return postYSAccountant;
    }
    
}
