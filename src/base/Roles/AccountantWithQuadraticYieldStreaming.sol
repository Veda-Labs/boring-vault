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

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract AccountantWithQuadraticYieldStreaming is AccountantWithRateProviders, Test {
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
    event LossRecorded(uint256 lossAmount); 

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

    function getRateInQuoteForWithdraw(ERC20 quote, uint256 withdrawnShares) public view returns (uint256 rateInQuote) {
        uint256 currentShares = vault.totalSupply();
        withdrawnShares; //not needed, cancels out anyways  
        // Total value including vested gains
        uint256 totalValue = totalAssetsInBase + _getPendingVestingGains();
    
        // Simple NAV calculation - this is the fair rate
        uint256 rateInBase = totalValue.mulDivDown(10 ** decimals, currentShares);
    
        // Convert to quote if needed
        if (address(quote) == address(base)) {
            return rateInBase;
        } else {
            return convertToQuote(rateInBase, quote);
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
            // TODO double check this, I think getRate should always report the same decimals as the baseAsset
            uint256 quoteRate = data.rateProvider.getRate();
    
            // Convert: amountInBase = amountInQuote * quoteRate / 10^quoteDecimals
            // This gives us the base asset amount
            amountInBase = amountInQuote.mulDivDown(quoteRate, 10 ** quoteDecimals);
    
            // Adjust decimals if needed
            amountInBase = _changeDecimals(amountInBase, quoteDecimals, baseDecimals);
        }
    }

    /**
     * @notice Converts a rate from base asset terms to quote asset terms
     * @param rateInBase The rate in base asset terms (e.g., WBTC per share)
     * @param quote The quote asset to convert to (e.g., LBTC)
     * @return rateInQuote The rate in quote asset terms (e.g., LBTC per share)
     */
    function convertToQuote(uint256 rateInBase, ERC20 quote)
        public view returns (uint256 rateInQuote)
    {
        // If quote is base, no conversion needed
        if (address(quote) == address(base)) {
            return rateInBase;
        }
    
        RateProviderData memory data = rateProviderData[quote];
        uint8 quoteDecimals = quote.decimals();
        uint8 baseDecimals = base.decimals();
    
        // First adjust decimals if needed
        uint256 rateInQuoteDecimals = _changeDecimals(rateInBase, baseDecimals, quoteDecimals);
    
        if (data.isPeggedToBase) {
            // For pegged assets, rate conversion is just decimal adjustment
            rateInQuote = rateInQuoteDecimals;
        } else {
            // For non-pegged assets, we need to convert using the quote/base exchange rate
            // If rateInBase = X base per share
            // And quoteRate = Y base per quote (from rate provider)
            // Then rateInQuote = X / Y quote per share
    
            uint256 quoteRate = data.rateProvider.getRate(); // How many base units per quote unit
    
            // rateInQuote = rateInBase / quoteRate
            // But we need to handle decimals properly
            rateInQuote = rateInQuoteDecimals.mulDivDown(10 ** quoteDecimals, quoteRate);
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
     * @notice callable by the Teller //TODO rolesAuth
     */
    function recordWithdraw(ERC20 withdrawAsset, uint256 withdrawAmount) external {
        _updateVestedYield(); //updates the lastVestingUpdated 
        //set the new duration
        //end = end - 
        //endVestingTime -=

        uint256 withdrawInBase = convertToBase(withdrawAsset, withdrawAmount);
        totalAssetsInBase -= withdrawInBase; //subtract the withdraw
        
        emit WithdrawRecorded(withdrawInBase, totalAssetsInBase);
    }

    /**
     * @notice Record new yield to be vested over a duration
     * @param yieldAmount The amount of yield earned
     * @param duration The period over which to vest this yield
     * @dev `yieldAmount` should be denominated in the BASE ASSET
     */
    function recordYield(uint256 yieldAmount, uint256 duration) external {
        require(duration > 0, "Duration must be positive"); //maybe remove this check, we might want to have the ability to post instant yield
        
        // first, update any previously vested gains
        _updateVestedYield();
        
        //removed -- strategists should now account for unvested yield if they want, gives more flexibility in posting pnl updates 
        vestingGains = yieldAmount;
        
        endVestingTime = block.timestamp + duration;
        emit YieldRecorded(yieldAmount, endVestingTime);
    }

    function _updateVestedYield() internal {
        // Calculate how much has vested since lastVestingUpdate
        uint256 newlyVested = _calculateVestingGains();

        console.log("amount should be added totalAssets: ", newlyVested); 
        
        if (newlyVested > 0) {
            // Move vested amount from pending to realized
            vestingGains -= newlyVested;        // remove from pending
            totalAssetsInBase += newlyVested;   // add to realized assets
            lastVestingUpdate = block.timestamp;  // update timestamp 
        }
    }


    /**
     * @notice callable by the Teller
     */
    function recordLoss(uint256 lossAmount) external requiresAuth {
        emit LossRecorded(lossAmount);
    }

}
