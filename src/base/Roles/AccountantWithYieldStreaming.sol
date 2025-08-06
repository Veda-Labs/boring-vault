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

contract AccountantWithYieldStreaming is AccountantWithRateProviders, Test {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;
    
    // New state variables TEMPORARY -> to be replaced with packed struct or somethin better
    uint256 public lastSharePrice; //the last share price (can maybe extend from previous accountant)
    uint256 public vestingGains; //the amount to vest over the period
    uint256 public lastVestingUpdate; //the last time the vesting gains were updated
    uint256 public endVestingTime; //the ending time for the gains to vest over

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
        
        lastSharePrice = startingExchangeRate;  
        vestingGains = 0;  
        lastVestingUpdate = block.timestamp;  
        endVestingTime = block.timestamp;  
    }

    // the rate for 1 share (used for deposits, withdraws, and current rate)
    // TODO unsure if we want to override `getRate()` here this function, so giving it a different name for now
    function getRateInBase() public view returns (uint256 rate) {
        uint256 currentShares = vault.totalSupply();
        
        if (currentShares == 0) {
            return rate = lastSharePrice; //staringExchangeRate
        }

        uint256 totalAssets = ((lastSharePrice * currentShares) / 1e18) + getPendingVestingGains(); //use muldiv //TODO swap out 1e18 for 10 ** decimals after bug fixing
        
        //rate = totalAssets / currentShares; 
        rate = totalAssets.mulDivDown(10 ** decimals, currentShares);
    }
    
    function getPendingVestingGains() public view returns (uint256) {
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
     * @notice Record new yield to be vested over a duration
     * @param yieldAmount The amount of yield earned
     * @param duration The period over which to vest this yield
     * @dev `yieldAmount` should be denominated in the BASE ASSET
     */
    function vestYield(uint256 yieldAmount, uint256 duration) external {
        //require(duration > 0, "Duration must be positive"); //maybe remove this check, we might want to have the ability to post instant yield
        // first, update any previously vested gains
        updateVestedYield();
        
        //removed -- strategists should now account for unvested yield if they want, gives more flexibility in posting pnl updates 
        vestingGains = yieldAmount;
        
        endVestingTime = block.timestamp + duration;
        emit YieldRecorded(yieldAmount, endVestingTime);
    }

    function updateVestedYield() public {
        // Calculate how much has vested since lastVestingUpdate
        uint256 newlyVested = getPendingVestingGains(); 

        console.log("amount should be added totalAssets: ", newlyVested); 
        
        if (newlyVested > 0) {
            // update the share price
            uint256 currentShares = vault.totalSupply();
            uint256 totalAssets = lastSharePrice * currentShares / 1e18; //use a muldiv here maybe (cleaner) //TODO
            lastSharePrice = (totalAssets + newlyVested) * 1e18 / currentShares;

            uint256 timeRemaining = endVestingTime - block.timestamp; 
           
            // Move vested amount from pending to realized
            vestingGains -= newlyVested;        // remove from pending
            lastVestingUpdate = block.timestamp;  // update timestamp 

            if (block.timestamp < endVestingTime) {
                uint256 timeRemaining = endVestingTime - block.timestamp;
                endVestingTime = block.timestamp + timeRemaining;
            }
        }
    }

    /**
     * @notice callable by the Teller
     */
    function vestLoss(uint256 lossAmount) external requiresAuth {
        emit LossRecorded(lossAmount);
    }

}
