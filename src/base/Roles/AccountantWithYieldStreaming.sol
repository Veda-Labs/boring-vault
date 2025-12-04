// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {Auth} from "@solmate/auth/Auth.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";


contract AccountantWithYieldStreaming is AccountantWithRateProviders {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    // ========================================= STRUCTS =========================================
    /**
     * @notice Stores the state variables related to yield vesting and share price tracking
     * @dev lastSharePrice The most recent share price
     * @dev unvestedGains The remaining amount of yield still vesting (reduced as gains vest)
     * @dev totalVestingGains The original total amount of yield to vest for this period
     * @dev startVestingTime The start time for the yield streaming period
     * @dev endVestingTime The end time for the yield streaming period
     */
    struct VestingState {
        uint128 lastSharePrice;
        uint128 unvestedGains;
        uint128 totalVestingGains;
        uint64 startVestingTime;
        uint64 endVestingTime;
    }

    struct SupplyObservation {
        uint256 cumulativeSupply;
        uint256 cumulativeSupplyLast;
    }

    // ========================================= STATE =========================================

    /**
     * @notice Store the vesting state in 2 packed slots.
     */
    VestingState public vestingState;

    /**
     * @notice Store the supply observation state in 2 slots.
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
        vestingState.unvestedGains = 0;
        vestingState.totalVestingGains = 0;
        vestingState.startVestingTime = uint64(block.timestamp);
        vestingState.endVestingTime = uint64(block.timestamp);

        //initialize supply observations
        supplyObservation.cumulativeSupply = 0;
        supplyObservation.cumulativeSupplyLast = 0;

        //initialize strategist update time to deploy time so first posts are valid
        lastStrategistUpdateTimestamp = uint64(block.timestamp);
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
        if (vestingState.unvestedGains > 0) {
            if (block.timestamp < lastStrategistUpdateTimestamp + accountantState.minimumUpdateDelayInSeconds) {
                revert AccountantWithYieldStreaming__NotEnoughTimePassed();
            }
        }

        //update the exchange rate, then validate if everything checks out
        // Round down to be conservative when recording yield
        _updateExchangeRate({roundCeil: false});

        //use TWAS to validate the yield amount:
        uint256 averageSupply = _getTWAS();
        uint256 _totalAssets = averageSupply.mulDivDown(vestingState.lastSharePrice, ONE_SHARE);
        uint256 dailyYieldAmount = yieldAmount.mulDivDown(1 days, duration);
        uint256 dailyYieldBps = dailyYieldAmount.mulDivDown(10_000, _totalAssets);

        if (dailyYieldBps > maxDeviationYield) {
            // maxDeviationYield is in bps
            revert AccountantWithYieldStreaming__MaxDeviationYieldExceeded();
        }

        //update the cumulative supply checkpoint
        supplyObservation.cumulativeSupplyLast = supplyObservation.cumulativeSupply;

        //strategists should account for any unvested yield they want, gives more flexibility in posting pnl updates
        vestingState.unvestedGains = uint128(yieldAmount);
        vestingState.totalVestingGains = uint128(yieldAmount);

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
        // Round down to be conservative when recording losses
        _updateExchangeRate({roundCeil: false}); //vested gains are moved to totalAssets, only unvested remains in `vestingState.unvestedGains`

        // Calculate how much has already vested (for loss accounting)
        uint256 alreadyVested = vestingState.totalVestingGains - vestingState.unvestedGains;

        if (vestingState.unvestedGains >= lossAmount) {
            //remaining unvested gains absorb the loss
            vestingState.unvestedGains -= uint128(lossAmount);
            // Reset the vesting timeline to start now with the remaining amount
            // This prevents the underflow issue where reducing totalVestingGains while keeping
            // the old start time causes the calculated vested amount to drop below what was already vested
            vestingState.totalVestingGains = vestingState.unvestedGains;
            vestingState.startVestingTime = uint64(block.timestamp);
        } else {
            uint256 principalLoss = lossAmount - vestingState.unvestedGains;

            //wipe out remaining vesting
            vestingState.unvestedGains = 0;
            //original is now just what has already vested (no more will vest)
            vestingState.totalVestingGains = uint128(alreadyVested);
            // Reset vesting period since all remaining is wiped
            vestingState.startVestingTime = uint64(block.timestamp);
            vestingState.endVestingTime = uint64(block.timestamp);

            //reduce share price to reflect principal loss
            uint256 currentShares = vault.totalSupply();
            if (currentShares > 0) {
                uint128 cachedSharePrice = vestingState.lastSharePrice;
                vestingState.lastSharePrice =
                    uint128((totalAssets() - principalLoss).mulDivDown(ONE_SHARE, currentShares));

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
     * @param roundCeil true to round up (protect existing shareholders), false to round down (conservative)
     */
    function updateExchangeRate(bool roundCeil) external requiresAuth {
        _updateExchangeRate({roundCeil: roundCeil});
    }

    /**
     * @dev calling this moves any vested gains to be calculated into the current share price
     * @dev Defaults to rounding down (conservative) for backward compatibility
     */
    function updateExchangeRate() external requiresAuth {
        _updateExchangeRate({roundCeil: false});
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
        uint256 pendingGains = _getUnrealizedVested(); 
        if (pendingGains == 0) {
            // Everything is vested, return the current share price
            return vestingState.lastSharePrice;
        } 
        
        // Otherwise, return the current share price plus the unrealized vested gains
        rate = uint256(vestingState.lastSharePrice) + pendingGains.mulDivDown(ONE_SHARE, currentShares);
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
     * @notice Get this BoringVault's current rate in the provided quote.
     * @dev `quote` must have its RateProviderData set, else this will revert.
     * @dev Rounds up the rate.
     */
    function getRateInQuoteCeil(ERC20 quote) public view override returns (uint256 rateInQuote) {
        uint256 rate;
        if (vault.totalSupply() == 0) {
            rate = vestingState.lastSharePrice;
        } else {
            // Avoid round-trip precision loss by using lastSharePrice directly
            // rate = lastSharePrice + (pendingGains / totalSupply)
            // We round up the pending gains contribution to ensure we favor the vault
            rate = uint256(vestingState.lastSharePrice) + _getUnrealizedVested().mulDivUp(ONE_SHARE, vault.totalSupply());
        }

        if (address(quote) == address(base)) {
            return rate;
        }
        
        RateProviderData memory data = rateProviderData[quote];
        uint8 quoteDecimals = ERC20(quote).decimals();
        uint256 exchangeRateInQuoteDecimals = _changeDecimals(rate, decimals, quoteDecimals);
        if (data.isPeggedToBase) {
            rateInQuote = exchangeRateInQuoteDecimals;
        } else {
            uint256 quoteRate = data.rateProvider.getRate();
            uint256 oneQuote = 10 ** quoteDecimals;
            rateInQuote = oneQuote.mulDivUp(exchangeRateInQuoteDecimals, quoteRate);
        }
    }

    /**
     * @notice Get this BoringVault's current rate in the provided quote.
     * @dev `quote` must have its RateProviderData set, else this will revert.
     * @dev Revert if paused.
     * @dev Rounds up the rate.
     */
    function getRateInQuoteSafeCeil(ERC20 quote) external view override returns (uint256 rateInQuote) {
        if (accountantState.isPaused) revert AccountantWithRateProviders__Paused();
        rateInQuote = getRateInQuoteCeil(quote);
    }

    /**
     * @notice Returns the amount of yield that has already vested based on the current block
     * @dev Calculates total vested from startVestingTime, then returns the difference from original amount
     */
    function getPendingVestingGains() public view returns (uint256 amountVested) {
        //if we're past the end of vesting, all original gains have vested
        if (block.timestamp >= vestingState.endVestingTime) {
            return vestingState.totalVestingGains;
        }

        //if no gains to vest
        if (vestingState.totalVestingGains == 0) {
            return 0;
        }

        //time that has passed since vesting started
        uint256 timeElapsed = block.timestamp - vestingState.startVestingTime;

        //total vesting period
        uint256 totalVestingPeriod = vestingState.endVestingTime - vestingState.startVestingTime;

        //if no time has elapsed, nothing has vested
        if (timeElapsed == 0 || totalVestingPeriod == 0) {
            return 0;
        }

        //calculate total amount that should have vested by now (linear vesting)
        uint256 totalVested = uint256(vestingState.totalVestingGains).mulDivDown(timeElapsed, totalVestingPeriod);
        
        //return the amount that has vested (original - remaining)
        return totalVested;
    }

    /**
     * @notice Returns the amount of yield that has yet to vest based on the current block and `unvestedGains`
     */
    function getPendingUnvestedGains() external view returns (uint256) {
        return vestingState.totalVestingGains - getPendingVestingGains();
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
        return uint256(vestingState.lastSharePrice).mulDivDown(currentShares, ONE_SHARE) + _getUnrealizedVested();
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
     * @notice Returns the amount of yield that has vested since the last exchange rate update
     * @dev Used to avoid double counting vested gains already in share price
     */
    function _getUnrealizedVested() internal view returns (uint256) {
        uint256 totalVested = getPendingVestingGains();
        // unvestedGains tracks the remaining unvested amount from the last update
        // so original - unvestedGains is the amount that was already realized into the share price
        uint256 alreadyRealized = vestingState.totalVestingGains - vestingState.unvestedGains;
        
        if (totalVested <= alreadyRealized) {
            return 0;
        }
        return totalVested - alreadyRealized;
    }

    /**
     * @dev calling this moves any vested gains to be calculated into the current share price
     */
    function _updateExchangeRate(bool roundCeil) internal {
        AccountantState storage state = accountantState;
        if (state.isPaused) revert AccountantWithRateProviders__Paused();
        _updateCumulative();

        //calculate how much has vested in total from startVestingTime
        uint256 totalVested = getPendingVestingGains();
        
        //calculate how much has newly vested since last update (difference between total and remaining)
        uint256 newlyVested = totalVested - (vestingState.totalVestingGains - vestingState.unvestedGains);

        uint256 currentShares = vault.totalSupply();
        if (newlyVested > 0) {
            // update the share price w/o reincluding the pending gains (done in `newlyVested`)
            // we add the newly vested yield to the share price directly to avoid precision loss
            // roundCeil = true: round up to protect existing shareholders (for deposits)
            // roundCeil = false: round down to be conservative (for withdrawals, vestYield, postLoss)
            vestingState.lastSharePrice += uint128(
                roundCeil 
                    ? newlyVested.mulDivUp(ONE_SHARE, currentShares)
                    : newlyVested.mulDivDown(ONE_SHARE, currentShares)
            );

            //move vested amount from pending to realized
            vestingState.unvestedGains = uint128(vestingState.totalVestingGains - totalVested); // update remaining
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
        uint256 timeElapsed = currentTime - accountantState.lastUpdateTimestamp;

        if (timeElapsed > 0) {
            //add (current supply * time elapsed) to accumulator
            supplyObservation.cumulativeSupply += vault.totalSupply() * timeElapsed;
            // lastUpdateTimestamp is updated in _collectFees or by parent logic
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
}
