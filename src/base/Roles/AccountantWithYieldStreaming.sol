// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
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

    // ========================================= STRUCTS =========================================
    
    // ========================================= STATE =========================================
    
    // New state variables TEMPORARY -> to be replaced with packed struct or somethin better
    uint256 public lastSharePrice; //the last share price (can maybe extend from previous accountant)
    uint256 public vestingGains; //the amount to vest over the period
    uint256 public lastVestingUpdate; //the last time the vesting gains were updated
    uint256 public endVestingTime; //the ending time for the gains to vest over

    //============================== ERRORS ===============================
    
    error AccountantWithYieldStreaming__UpdateExchangeRateNotSupported(); 

    //============================== EVENTS ===============================
    
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

    // ========================================= UPDATE EXCHANGE RATE/FEES FUNCTIONS =========================================

    /**
     * @notice Record new yield to be vested over a duration
     * @param yieldAmount The amount of yield earned
     * @param duration The period over which to vest this yield
     * @notice callable by the STRATEGIST role
     * @dev `yieldAmount` should be denominated in the BASE ASSET
     */
    function vestYield(uint256 yieldAmount, uint256 duration) external {
        // first, update any previously vested gains
        updateExchangeRate();
        
        //strategists should account for any unvested yield they want, gives more flexibility in posting pnl updates 
        vestingGains = yieldAmount;
        
        endVestingTime = block.timestamp + duration;
        emit YieldRecorded(yieldAmount, endVestingTime);
    }

    /**
     * @notice callable by the STRATEGIST role
     * //TODO add auth
     */
    function vestLoss(uint256 lossAmount, uint256 duration) external {
        updateExchangeRate(); //vested gains are moved to totalAssets, only unvested remains in `vestingGains` 

        if (vestingGains >= lossAmount) {
            //remaining unvested gains absorb the loss
            vestingGains -= lossAmount;
        } else {
            uint256 principalLoss = lossAmount - vestingGains;

            //wipe out remaining vesting
            vestingGains = 0;

            // Reduce share price to reflect principal loss
            uint256 currentShares = vault.totalSupply();
            if (currentShares > 0) {
                uint256 totalAssets = lastSharePrice.mulDivDown(currentShares, 1e18);
                lastSharePrice = (totalAssets - principalLoss).mulDivDown(1e18, currentShares);
            }
        }

        emit LossRecorded(lossAmount);
    }

    //TODO auth
    function updateExchangeRate() public {

        // Calculate how much has vested since lastVestingUpdate
        uint256 newlyVested = getPendingVestingGains(); 

        uint256 currentShares = vault.totalSupply();
        if (newlyVested > 0) {

            // update the share price
            uint256 totalAssets = lastSharePrice.mulDivDown(currentShares, 1e18); 
            lastSharePrice = (totalAssets + newlyVested).mulDivDown(1e18, currentShares);

            _collectFees();

            // Move vested amount from pending to realized
            vestingGains -= newlyVested;        // remove from pending
            lastVestingUpdate = block.timestamp;  // update timestamp 

            if (block.timestamp < endVestingTime) {
                uint256 timeRemaining = endVestingTime - block.timestamp;
                endVestingTime = block.timestamp + timeRemaining;
            }
        }
        
        AccountantState storage state = accountantState;
        state.totalSharesLastUpdate = uint128(currentShares); 
    }

    /**
     * @notice Override updateExchangeRate to revert if called accidentally
     */
    function updateExchangeRate(uint96 /*newExchangeRate*/) external override requiresAuth {
        revert AccountantWithYieldStreaming__UpdateExchangeRateNotSupported(); 
    }

    // ========================================= VIEW FUNCTIONS =========================================
    
    // the rate for 1 share (used for deposits, withdraws, and current rate)
    function getRate() public override view returns (uint256 rate) {
        uint256 currentShares = vault.totalSupply();
        if (currentShares == 0) {
            return rate = lastSharePrice; //staringExchangeRate
        }
        rate = totalAssets().mulDivDown(10 ** decimals, currentShares);
    }

    function getRateSafe() external override view returns (uint256 rate) {
        if (accountantState.isPaused) revert AccountantWithRateProviders__Paused();
        uint256 currentShares = vault.totalSupply();
        if (currentShares == 0) {
            return rate = lastSharePrice; //staringExchangeRate
        }
        rate = totalAssets().mulDivDown(10 ** decimals, currentShares);
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
    
    function totalAssets() public view returns (uint256) {
        uint256 currentShares = vault.totalSupply();
        return lastSharePrice.mulDivDown(currentShares, 1e18) + getPendingVestingGains();
    }

    function version() external view returns (string memory) {
        return "V0.1";
    }

    // ========================================= INTERNAL HELPER FUNCTIONS =========================================
    
    /**
     * @notice Call this before share price increases to collect fees
     */
    function _collectFees() internal {
        AccountantState storage state = accountantState;
        uint256 currentTotalShares = vault.totalSupply();
        uint64 currentTime = uint64(block.timestamp);
        
        // Calculate fees using `AccountantWithRateProviders`
        // this should update the highwater mark, but isnt...
        _calculateFeesOwed(
            state,
            uint96(lastSharePrice),
            state.exchangeRate,
            currentTotalShares,
            currentTime
        );
        
        state.exchangeRate = uint96(lastSharePrice);
        state.totalSharesLastUpdate = uint128(currentTotalShares);
        state.lastUpdateTimestamp = currentTime;
    }

}
