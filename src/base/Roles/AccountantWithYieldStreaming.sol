// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol"; 
import {IPausable} from "src/interfaces/IPausable.sol";

contract AccountantWithYieldStreaming is AccountantWithRateProviders {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;
    
    // New state variables TEMPORARY -> to be replaced with packed struct or somethin better
    uint256 public totalAssetsInBase; //total assets denominated in `base()` asset
    uint256 public vestingGains; //the amount to vest over the period
    uint256 public lastVestingUpdate; //the last time the vesting gains were updated
    uint256 public endVestingTime; //the ending time for the gains to vest over

    event DepositRecorded(uint256 amountAdded, uint256 newtotalAssetsInBase); 
    event WithdrawRecorded(uint256 amountRemoved, uint256 newtotalAssetsInBase); 
    event YieldRecorded(uint256 amountAdded, uint256 newtotalAssetsInBase); 
    event LossRecorded(uint256 amountRemoved, uint256 newtotalAssetsInBase); 

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
    ) AccountantWithRateProviders(
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
    ) {
        
        //already 0 but for my sanity pls
        totalAssetsInBase = 0;  
        vestingGains = 0;  
        lastVestingUpdate = block.timestamp;  
        endVestingTime = block.timestamp;  
    }

    // New function specifically for deposits that accounts for the deposit amount
    // This is the ONLY new function that Teller needs to know about
    function getRateInQuoteForDeposit(ERC20 quote, uint256 depositAmount) public view returns (uint256 rateInQuote) {
        uint256 currentShares = vault.totalSupply();
        
        // Handle initial deposit
        if (currentShares == 0) {
            return 10 ** decimals;
        }

        // Convert deposit amount to base asset if needed
        uint256 depositAmountInBase = depositAmount;
        if (address(quote) != address(base)) {
            // Convert to base using existing rate provider logic
            depositAmountInBase = convertToBase(quote, depositAmount); 
        }
        
        // Get base values in asset terms
        uint256 currentTotalAssets = totalAssetsInBase;
        uint256 totalVestingGains = _getPendingVestingGains();
        
        // Quadratic formula components
        uint256 a = depositAmountInBase;
        uint256 b = currentShares;
        uint256 c = currentTotalAssets + totalVestingGains + depositAmountInBase;
        
        // Solve quadratic: r = (-b + sqrt(b² + 4ac)) / 2a
        uint256 discriminant = b * b + 4 * a * c;
        uint256 sqrtDiscriminant = FixedPointMathLib.sqrt(discriminant); 
        
        // Rate in base terms
        uint256 rateInBase = (sqrtDiscriminant - b) * 10 ** decimals / (2 * a);
        
        // Convert to quote if needed
        if (address(quote) == address(base)) {
            rateInQuote = rateInBase;
        } else {
            // Apply same conversion logic as getRateInQuote
            RateProviderData memory data = rateProviderData[quote];
            uint8 quoteDecimals = ERC20(quote).decimals();
            uint256 rateInQuoteDecimals = _changeDecimals(rateInBase, decimals, quoteDecimals);
            
            if (data.isPeggedToBase) {
                rateInQuote = rateInQuoteDecimals;
            } else {
                uint256 quoteRate = data.rateProvider.getRate();
                uint256 oneQuote = 10 ** quoteDecimals;
                rateInQuote = oneQuote.mulDivDown(rateInQuoteDecimals, quoteRate);
            }
        }
    }
    
    // Helper functions
    function _getPendingVestingGains() internal view returns (uint256) {
        return _calculateVestingGains();
    }

    function _calculateVestingGains() internal view returns (uint256) {
        uint256 currentTime = block.timestamp;
        
        // If we're past the end of vesting, all remaining gains have vested
        if (currentTime >= endVestingTime) {
            return vestingGains; // Return ALL remaining unvested gains
        }
        
        // If we haven't updated yet or no gains to vest
        if (lastVestingUpdate >= endVestingTime || vestingGains == 0) {
            return 0;
        }
        
        // Calculate time that has passed since last update
        uint256 timeSinceLastUpdate = currentTime - lastVestingUpdate;
        
        // Calculate total remaining vesting period when we last updated
        uint256 totalRemainingTime = endVestingTime - lastVestingUpdate;
        
        // Calculate proportion of remaining gains that have vested
        // vestingGains = total unvested amount as of lastVestingUpdate
        // We vest it linearly over the remaining time
        return (vestingGains * timeSinceLastUpdate) / totalRemainingTime;
    }

    /**
     * @notice Converts an amount in quote asset to base asset value
     * @param quote The asset to convert from (e.g., LBTC)
     * @param amountInQuote The amount in quote asset terms
     * @return amountInBase The equivalent amount in base asset terms (e.g., WBTC)
     */
    function convertToBase(ERC20 quote, uint256 amountInQuote) public view returns (uint256 amountInBase) {
        // If already in base, no conversion needed
        if (address(quote) == address(base)) {
            return amountInQuote;
        }
    
        // Get rate provider data for the quote asset
        RateProviderData memory data = rateProviderData[quote];
    
        // Get decimals for both assets
        uint8 quoteDecimals = quote.decimals();
        uint8 baseDecimals = base.decimals();
    
        if (data.isPeggedToBase) {
            // For pegged assets (1:1 with base), just adjust decimals
            amountInBase = _changeDecimals(amountInQuote, quoteDecimals, baseDecimals);
        } else {
            // For non-pegged assets, use rate provider
            // quoteRate is: "How many quote units equal 1 base unit"
            // For example, if LBTC/WBTC rate is 0.98, then quoteRate = 0.98e18
            uint256 quoteRate = data.rateProvider.getRate();
    
            // Convert: amountInBase = amountInQuote * quoteRate / 10^quoteDecimals
            // This gives us the base asset amount
            amountInBase = amountInQuote.mulDivDown(quoteRate, 10 ** quoteDecimals);
    
            // Adjust decimals if needed
            amountInBase = _changeDecimals(amountInBase, quoteDecimals, baseDecimals);
        }
    }

    /**
     * @notice callable by the Teller //TODO rolesAuth
     */
    function recordDeposit(ERC20 depositAsset, uint256 depositAmount) external {
        uint256 depositInBase = convertToBase(depositAsset, depositAmount);
        totalAssetsInBase += depositInBase;
        
        emit DepositRecorded(depositInBase, totalAssetsInBase);
    }

    /**
     * @notice callable by the Teller
     */
    function recordWithdraw(ERC20 withdrawAsset, uint256 withdrawAmount) external requiresAuth {
        uint256 withdrawInBase = convertToBase(withdrawAsset, withdrawAmount);
        totalAssetsInBase -= withdrawInBase;
        
        emit WithdrawRecorded(withdrawInBase, totalAssetsInBase);
    }

    /**
     * @notice Record new yield to be vested over a duration
     * @param yieldAsset The asset the yield is denominated in
     * @param yieldAmount The amount of yield earned
     * @param duration The period over which to vest this yield
     */
    function recordYield(ERC20 yieldAsset, uint256 yieldAmount, uint256 duration) external {
        require(duration > 0, "Duration must be positive");
        
        // First, update any previously vested gains
        _updateVestedYield();
        
        // Convert yield to base asset
        uint256 yieldInBase = convertToBase(yieldAsset, yieldAmount);
        
        // Add to unvested gains (not total assets yet!)
        vestingGains += yieldInBase;  // Fixed: use yieldInBase, not yieldAmount
        
        // Calculate new vesting end time
        uint256 currentTime = block.timestamp;
        
        if (endVestingTime <= currentTime) {
            // Previous vesting completed, start fresh
            endVestingTime = currentTime + duration;
            lastVestingUpdate = currentTime;
        } else {
            // Blend with existing vesting schedule
            uint256 remainingTime = endVestingTime - currentTime;
            uint256 existingUnvested = vestingGains - yieldInBase;
            
            // Weighted average for smooth vesting
            if (vestingGains > 0) {
                uint256 newEndTime = currentTime + 
                    ((remainingTime * existingUnvested + duration * yieldInBase) / vestingGains);
                endVestingTime = newEndTime;
            }
        }
        
        emit YieldRecorded(yieldInBase, endVestingTime);
    }

    function _updateVestedYield() internal {
        // Calculate how much has vested since lastVestingUpdate
        uint256 newlyVested = _calculateVestingGains();
        
        if (newlyVested > 0) {
            // Move vested amount from pending to realized
            vestingGains -= newlyVested;        // Remove from pending
            totalAssetsInBase += newlyVested;   // Add to realized assets
            lastVestingUpdate = block.timestamp; // Update checkpoint
        }
    }


    /**
     * @notice callable by the Teller
     */
    function recordLoss(ERC20 lossAsset, uint256 lossAmount) external requiresAuth {
        uint256 lossInBase = convertToBase(lossAsset, lossAmount);
        //totalAssetsInBase -= depositInBase;
        
        emit WithdrawRecorded(lossInBase, totalAssetsInBase);
    }

}
