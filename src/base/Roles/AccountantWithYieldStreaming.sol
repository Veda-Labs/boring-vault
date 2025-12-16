// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";


contract AccountantWithYieldStreaming is AccountantWithRateProviders {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    // ========================================= STRUCTS =========================================
    /**
     * @notice Stores the state variables related to yield vesting and share price tracking
     * @dev lastSharePrice The most recent share price
     * @dev vestingGainst The total amount of yield being streamed for this period
     * @dev lastVestingUpdate The last time a yield update was posted
     * @dev startVestingTime The start time for the yield streaming period
     * @dev endVestingTime The end time for the yield streaming period
     */
    struct VestingState {
        uint128 lastSharePrice;
        uint128 vestingGains;
        uint128 lastVestingUpdate;
        uint64 startVestingTime;
        uint64 endVestingTime;
    }

    struct SupplyObservation {
        uint256 cumulativeSupply;
        uint256 cumulativeSupplyLast;
        uint256 lastUpdateTimestamp;
    }

    // ========================================= STATE =========================================

    /**
     * @notice Store the vesting state in 2 packed slots.
     */
    VestingState public vestingState;

    /**
     * @notice Store the supply observation state in 3 slots.
     */
    SupplyObservation public supplyObservation;

    /**
     * @notice The minimum amount of time a yield update is required to vest to be posted to the vault
     * @dev set to sane default but configurable by ADMIN_ROLE
     */
    uint64 public minimumVestingTime = 1 days;

    /**
     * @notice The maximum amount of time a yield update can vest to be posted to the vault
     * @dev set to sane default but configurable by ADMIN_ROLE
     */
    uint64 public maximumVestingTime = 7 days;

    /**
     * @notice The maximum amount a yield vest can be > old supply
     * @dev recorded in bps (maxDeviationYield / 10_000)
     */
    uint32 public maxDeviationYield = 500;

    /**
     * @notice The maximum amount a loss can be before the contract is paused
     * @dev recorded in bps (maxDeviationLoss / 10_000)
     */
    uint32 public maxDeviationLoss = 100;

    /**
     * @notice The last time any vesting function was called
     * @dev applies to vestYield and postLoss
     */
    uint64 public lastStrategistUpdateTimestamp;

    /**
     * @notice The virtual share price is the share price expressed in ray
     * @dev useful for calculating the impact of vested gains when the sharePrice (in asset decimals) is not precise enough
     */

    uint256 public lastVirtualSharePrice;

    uint256 internal constant RAY = 1e27;

    //============================== ERRORS ===============================

    error AccountantWithYieldStreaming__UpdateExchangeRateNotSupported();
    error AccountantWithYieldStreaming__DurationExceedsMaximum();
    error AccountantWithYieldStreaming__DurationUnderMinimum();
    error AccountantWithYieldStreaming__NotEnoughTimePassed();
    error AccountantWithYieldStreaming__ZeroYieldUpdate();
    error AccountantWithYieldStreaming__MaxDeviationYieldExceeded();

    //============================== EVENTS ===============================

    event YieldRecorded(uint256 amountAdded, uint64 endVestingTime);
    event LossRecorded(uint256 lossAmount);
    event ExchangeRateUpdated(uint256 newExchangeRate);
    event MaximumVestDurationUpdated(uint64 newMaximum);
    event MinimumVestDurationUpdated(uint64 newMinimum);
    event MaximumDeviationYieldUpdated(uint64 newMaximum);
    event MaximumDeviationLossUpdated(uint64 newMaximum);

    constructor(
        address _owner,
        address _vault,
        address payoutAddress,
        uint96 startingExchangeRate,
        address _base,
        uint16 allowedExchangeRateChangeUpper,
        uint16 allowedExchangeRateChangeLower,
        uint24 minimumUpdateDelayInSeconds,
        uint16 platformFee,
        uint16 performanceFee
    )
        AccountantWithRateProviders(
            _owner,
            _vault,
            payoutAddress,
            startingExchangeRate,
            _base,
            allowedExchangeRateChangeUpper,
            allowedExchangeRateChangeLower,
            minimumUpdateDelayInSeconds,
            platformFee,
            performanceFee
        )
    {
        //initialize vesting state
        vestingState.lastSharePrice = startingExchangeRate;
        vestingState.vestingGains = 0;
        vestingState.lastVestingUpdate = uint128(block.timestamp);
        vestingState.startVestingTime = uint64(block.timestamp);
        vestingState.endVestingTime = uint64(block.timestamp);

        //initialize supply observations
        supplyObservation.cumulativeSupply = 0;
        supplyObservation.cumulativeSupplyLast = 0;
        supplyObservation.lastUpdateTimestamp = uint128(block.timestamp);

        //initialize strategist update time to deploy time so first posts are valid
        lastStrategistUpdateTimestamp = uint64(block.timestamp);

        //initialize virtual share price
        lastVirtualSharePrice = (uint256(startingExchangeRate)).mulDivDown(RAY, ONE_SHARE);
    }

    // ========================================= UPDATE EXCHANGE RATE/FEES FUNCTIONS =========================================

    /**
     * @notice Record new yield to be vested over a duration
     * @param yieldAmount The amount of yield earned
     * @param duration The period over which to vest this yield
     * @notice callable by the STRATEGIST role
     * @dev `yieldAmount` should be denominated in the BASE ASSET
     */
    function vestYield(uint256 yieldAmount, uint256 duration) external requiresAuth {
        if (accountantState.isPaused) revert AccountantWithRateProviders__Paused();

        if (duration > uint256(maximumVestingTime)) revert AccountantWithYieldStreaming__DurationExceedsMaximum();
        if (duration < uint256(minimumVestingTime)) revert AccountantWithYieldStreaming__DurationUnderMinimum();
        if (yieldAmount == 0) revert AccountantWithYieldStreaming__ZeroYieldUpdate();
        //only check if there's an active vest
        if (vestingState.vestingGains > 0) {
            if (block.timestamp < lastStrategistUpdateTimestamp + accountantState.minimumUpdateDelayInSeconds) {
                revert AccountantWithYieldStreaming__NotEnoughTimePassed();
            }
        }

        //update the exchange rate, then validate if everything checks out
        _updateExchangeRate();

        //use TWAS to validate the yield amount:
        uint256 averageSupply = _getTWAS();
        uint256 _totalAssets = averageSupply.mulDivDown(lastVirtualSharePrice, RAY);
        uint256 dailyYieldAmount = yieldAmount.mulDivDown(1 days, duration);
        uint256 dailyYieldBps = dailyYieldAmount.mulDivDown(10_000, _totalAssets);

        if (dailyYieldBps > maxDeviationYield) {
            // maxDeviationYield is in bps
            revert AccountantWithYieldStreaming__MaxDeviationYieldExceeded();
        }

        //update the cumulative supply checkpoint
        supplyObservation.cumulativeSupplyLast = supplyObservation.cumulativeSupply;

        //strategists should account for any unvested yield they want, gives more flexibility in posting pnl updates
        vestingState.vestingGains = uint128(yieldAmount);

        //update vesting timestamps
        vestingState.startVestingTime = uint64(block.timestamp);
        vestingState.endVestingTime = uint64(block.timestamp + duration);

        //update state timestamp
        lastStrategistUpdateTimestamp = uint64(block.timestamp);

        emit YieldRecorded(yieldAmount, vestingState.endVestingTime);
    }

    /**
     * @param lossAmount The amount lost by the vault during n period
     * @notice callable by the STRATEGIST role
     * @dev `lossAmount` should be denominated in the BASE ASSET
     */
    function postLoss(uint256 lossAmount) external requiresAuth {
        if (accountantState.isPaused) revert AccountantWithRateProviders__Paused();

        if (block.timestamp < lastStrategistUpdateTimestamp + accountantState.minimumUpdateDelayInSeconds) {
            revert AccountantWithYieldStreaming__NotEnoughTimePassed();
        }

        //ensure most up to date data
        _updateExchangeRate(); //vested gains are moved to totalAssets, only unvested remains in `vestingState.vestingGains`

        if (vestingState.vestingGains >= lossAmount) {
            //remaining unvested gains absorb the loss
            vestingState.vestingGains -= uint128(lossAmount);
        } else {
            uint256 principalLoss = lossAmount - vestingState.vestingGains;

            //wipe out remaining vesting
            vestingState.vestingGains = 0;

            //reduce share price to reflect principal loss
            uint256 currentShares = vault.totalSupply();
            if (currentShares > 0) {
                uint128 cachedSharePrice = vestingState.lastSharePrice;
                
                lastVirtualSharePrice = (totalAssets() - principalLoss) * (RAY / currentShares);

                vestingState.lastSharePrice = _calculateSharePriceFromVirtual();

                uint256 lossBps =
                    uint256(cachedSharePrice - vestingState.lastSharePrice).mulDivDown(10_000, cachedSharePrice);



                //verify the loss isn't too large
                if (lossBps > maxDeviationLoss) {
                    accountantState.isPaused = true;
                    emit Paused();
                }
            }
        }
        

        AccountantState storage state = accountantState;
        state.exchangeRate = uint96(vestingState.lastSharePrice);

        //update state timestamp
        lastStrategistUpdateTimestamp = uint64(block.timestamp);

        emit LossRecorded(lossAmount);
    }

    /**
     * @dev calling this moves any vested gains to be calculated into the current share price
     */
    function updateExchangeRate() external requiresAuth {
        _updateExchangeRate();
    }

    /**
     * @notice Override updateExchangeRate to revert if called accidentally
     */
    function updateExchangeRate(uint96 /*newExchangeRate*/ ) external view override requiresAuth {
        revert AccountantWithYieldStreaming__UpdateExchangeRateNotSupported();
    }

    /**
     * @notice Updates startVestingTime timestamp
     * @dev Callable by TELLER
     */
    function setFirstDepositTimestamp() external requiresAuth {
        vestingState.startVestingTime = uint64(block.timestamp);
    }

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @notice Update the maximum vesting time to a new value.
     * @dev Callable by OWNER_ROLE.
     */
    function updateMaximumVestDuration(uint64 newMaximum) external requiresAuth {
        maximumVestingTime = newMaximum;
        emit MaximumVestDurationUpdated(newMaximum);
    }

    /**
     * @notice Update the minimum vesting time to a new value.
     * @dev Callable by OWNER_ROLE.
     */
    function updateMinimumVestDuration(uint64 newMinimum) external requiresAuth {
        minimumVestingTime = newMinimum;
        emit MinimumVestDurationUpdated(newMinimum);
    }

    /**
     * @notice Update the maximum deviation yield
     * @dev Callable by OWNER_ROLE.
     */
    function updateMaximumDeviationYield(uint32 newMaximum) external requiresAuth {
        maxDeviationYield = newMaximum;
        emit MaximumDeviationYieldUpdated(newMaximum);
    }

    /**
     * @notice Update the maximum deviation loss
     * @dev Callable by OWNER_ROLE.
     */
    function updateMaximumDeviationLoss(uint32 newMaximum) external requiresAuth {
        maxDeviationLoss = newMaximum;
        emit MaximumDeviationLossUpdated(newMaximum);
    }

    // ========================================= VIEW FUNCTIONS =========================================

    function getRateInQuote(ERC20 quote) public view override returns (uint256 rateInQuote) {
        if (address(quote) == address(base)) {
            rateInQuote = getRate();
        } else {
            RateProviderData memory data = rateProviderData[quote];
            uint8 quoteDecimals = ERC20(quote).decimals();
            uint256 exchangeRateInQuoteDecimals = _changeDecimals(getRate(), decimals, quoteDecimals);
            if (data.isPeggedToBase) {
                rateInQuote = exchangeRateInQuoteDecimals;
            } else {
                uint256 quoteRate = data.rateProvider.getRate();
                uint256 oneQuote = 10 ** quoteDecimals;
                rateInQuote = oneQuote.mulDivDown(exchangeRateInQuoteDecimals, quoteRate);
            }
        }
    }

    /**
     * @notice Get this BoringVault's current rate in the provided quote.
     * @dev `quote` must have its RateProviderData set, else this will revert.
     * @dev Revert if paused.
     */
    function getRateInQuoteSafe(ERC20 quote) external view override returns (uint256 rateInQuote) {
        if (accountantState.isPaused) revert AccountantWithRateProviders__Paused();
        rateInQuote = getRateInQuote(quote);
    }

    /**
     * @notice Returns the rate for one share at current block based on amount of gains that are vested and have vested
     * @dev linear interpolation between current timestamp and `endVestingTime`
     */
    function getRate() public view override returns (uint256 rate) {
        uint256 currentShares = vault.totalSupply();
        if (currentShares == 0) {
            return rate = vestingState.lastSharePrice; //startingExchangeRate
        }
        //to avoid any weird edge cases, we separate the two conditions so we don't get currentShares == 0 and pendingGains > 0; 
        uint256 pendingGains = getPendingVestingGains(); 
        if (pendingGains == 0) {
            return rate = vestingState.lastSharePrice;
        } 
        rate = totalAssets().mulDivDown(ONE_SHARE, currentShares);
    }

    /**
     * @notice Returns the safe rate for one share
     * @dev Rerverts if the the accountant is paused
     */
    function getRateSafe() external view override returns (uint256 rate) {
        if (accountantState.isPaused) revert AccountantWithRateProviders__Paused();
        return rate = getRate();
    }

    /**
     * @notice Returns the amount of yield that has already vested based on the current block and `vestingGains`
     */
    function getPendingVestingGains() public view returns (uint256 amountVested) {
        uint256 currentTime = block.timestamp;

        //if we're past the end of vesting, all remaining gains have vested
        if (currentTime >= vestingState.endVestingTime) {
            return vestingState.vestingGains; // Return ALL remaining unvested gains
        }

        //if no gains to vest
        if (vestingState.vestingGains == 0) {
            return 0;
        }

        //time that has passed since last update
        uint256 timeSinceLastUpdate = currentTime - vestingState.lastVestingUpdate;

        //total remaining vesting period when we last updated
        uint256 totalRemainingTime = vestingState.endVestingTime - vestingState.lastVestingUpdate;

        //vest it linearly over the remaining time
        //return amountVested = (vestingState.vestingGains * timeSinceLastUpdate) / totalRemainingTime;
        return amountVested = uint256(vestingState.vestingGains).mulDivDown(timeSinceLastUpdate, totalRemainingTime);
    }

    /**
     * @notice Returns the amount of yield that has yet to vest based on the current block and `vestingGains`
     */
    function getPendingUnvestedGains() external view returns (uint256) {
        return vestingState.vestingGains - getPendingVestingGains();
    }

    /**
     * @notice Calculate TWAS since last vest
     */
    function _getTWAS() internal view returns (uint256) {
        //handle first yield event
        if (supplyObservation.cumulativeSupply == 0) {
            return vault.totalSupply();
        }

        uint64 timeSinceLastVest = uint64(block.timestamp) - vestingState.startVestingTime;

        if (timeSinceLastVest == 0) {
            return vault.totalSupply(); // If no time passed, return current supply
        }

        // TWAS = (current cumulative - last vest cumulative) / time elapsed
        uint256 cumulativeDelta = supplyObservation.cumulativeSupply - supplyObservation.cumulativeSupplyLast;
        return cumulativeDelta / timeSinceLastVest;
    }

    /**
     * @notice Returns the total assets in the vault at current timestamp
     * @dev Includes any gains that have already vested for this period
     */
    function totalAssets() public view returns (uint256) {
        uint256 currentShares = vault.totalSupply();
        return uint256(vestingState.lastSharePrice).mulDivDown(currentShares, ONE_SHARE) + getPendingVestingGains();
    }

    /**
     * @notice Returns the current version of the accountant
     */
    function version() external pure returns (string memory) {
        return "V0.1";
    }

    /**
     * @notice Override previewUpdateExchangeRate to revert if called accidentally
     */
    function previewUpdateExchangeRate(uint96 /*newExchangeRate*/ )
        external
        view
        override
        requiresAuth
        returns (bool, /*updateWillPause*/ uint256, /*newFeesOwedInBase*/ uint256 /*totalFeesOwedInBase*/ )
    {
        revert AccountantWithYieldStreaming__UpdateExchangeRateNotSupported();
    }

    // ========================================= INTERNAL HELPER FUNCTIONS =========================================

    /**
     * @dev calling this moves any vested gains to be calculated into the current share price
     */
    function _updateExchangeRate() internal {
        AccountantState storage state = accountantState;
        if (state.isPaused) revert AccountantWithRateProviders__Paused();
        _updateCumulative();

        //calculate how much has vested since `lastVestingUpdate`
        uint256 newlyVested = getPendingVestingGains();

        uint256 currentShares = vault.totalSupply();
        if (newlyVested > 0 && currentShares > 0) {
            // update the share price w/o reincluding the pending gains (done in `newlyVested`)
            uint256 _totalAssetsPrecise = lastVirtualSharePrice.mulDivDown(currentShares, RAY);
            lastVirtualSharePrice = (_totalAssetsPrecise + newlyVested).mulDivDown(RAY, currentShares);

            //move vested amount from pending to realized
            vestingState.vestingGains -= uint128(newlyVested); // remove from pending
            vestingState.lastVestingUpdate = uint128(block.timestamp); //update timestamp
            vestingState.lastSharePrice = _calculateSharePriceFromVirtual();
        }

        //sync fee variables 
        _collectFees();

        state.totalSharesLastUpdate = uint128(currentShares);

        emit ExchangeRateUpdated(vestingState.lastSharePrice);
    }

    /**
     * @notice Updates the cumulative supply tracking
     * @dev Called before any supply changes and before TWAS calculations
     */
    function _updateCumulative() internal {
        uint256 currentTime = block.timestamp;
        uint256 timeElapsed = currentTime - supplyObservation.lastUpdateTimestamp;

        if (timeElapsed > 0) {
            //add (current supply * time elapsed) to accumulator
            supplyObservation.cumulativeSupply += vault.totalSupply() * timeElapsed;
            supplyObservation.lastUpdateTimestamp = currentTime;
        }
    }

    /**
     * @notice Call this before share price increases to collect fees
     */
    function _collectFees() internal {
        AccountantState storage state = accountantState;
        uint256 currentTotalShares = vault.totalSupply();
        uint64 currentTime = uint64(block.timestamp);

        //calculate fees using function inherited from `AccountantWithRateProviders`
        _calculateFeesOwed(
            state, uint96(vestingState.lastSharePrice), state.exchangeRate, currentTotalShares, currentTime
        );

        state.exchangeRate = uint96(vestingState.lastSharePrice);
        state.lastUpdateTimestamp = currentTime;
    }

    function _calculateSharePriceFromVirtual() internal view returns (uint128) {
        return uint128(lastVirtualSharePrice.mulDivDown(ONE_SHARE, RAY));
    }
}
