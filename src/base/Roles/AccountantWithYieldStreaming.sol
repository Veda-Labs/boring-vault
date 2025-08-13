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
    /**
     * @notice Stores the state variables related to yield vesting and share price tracking
     * @dev lastSharePrice The most recent share price 
     * @dev vestingGainst The total amount of yield being streamed for this period
     * @dev lastVestingUpdate The last time a yield update was posted
     * @dev endVestingTime The end time for the yield streaming period
     */
    struct VestingState {
        uint128 lastSharePrice; 
        uint128 vestingGains;      
        uint128 lastVestingUpdate;
        uint128 endVestingTime;   
    }
    
    // ========================================= STATE =========================================
    
    /**
     * @notice Store the vesting state in 2 packed slots.
     */
    VestingState public vestingState; 

    //============================== ERRORS ===============================
    
    error AccountantWithYieldStreaming__UpdateExchangeRateNotSupported(); 

    //============================== EVENTS ===============================
    
    event YieldRecorded(uint256 amountAdded, uint256 newtotalAssetsInBase); 
    event LossRecorded(uint256 lossAmount); 
    event ExchangeRateUpdated(uint256 newExchangeRate); 

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
        
        vestingState.lastSharePrice = startingExchangeRate;  
        vestingState.vestingGains = 0;  
        vestingState.lastVestingUpdate = uint128(block.timestamp); 
        vestingState.endVestingTime = uint128(block.timestamp); 
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
        // first, update any previously vested gains
        updateExchangeRate();
        
        //strategists should account for any unvested yield they want, gives more flexibility in posting pnl updates 
        vestingState.vestingGains = uint128(yieldAmount); 
        
        vestingState.endVestingTime = uint128(block.timestamp + duration); 
        emit YieldRecorded(yieldAmount, vestingState.endVestingTime);
    }

    /**
     * @param lossAmount The amount lost by the vault during n period 
     * @notice callable by the STRATEGIST role
     * @dev `lossAmount` should be denominated in the BASE ASSET 
     */
    function vestLoss(uint256 lossAmount) external requiresAuth {
        updateExchangeRate(); //vested gains are moved to totalAssets, only unvested remains in `vestingState.vestingGains` 

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
                vestingState.lastSharePrice = uint128((totalAssets() - principalLoss).mulDivDown(1e18, currentShares)); 
            }
        }

        emit LossRecorded(lossAmount);
    }

    /**
     * @dev calling this moves any vested gains to be calculated into the current share price
     */
    function updateExchangeRate() public requiresAuth {

        // Calculate how much has vested since vestingState.lastVestingUpdate
        uint256 newlyVested = getPendingVestingGains(); 

        uint256 currentShares = vault.totalSupply();
        if (newlyVested > 0) {

            // update the share price w/o reincluding the pending gains (done in `newlyVested`)
            //uint256 lastSharePrice = 
            uint256 _totalAssets = uint256(vestingState.lastSharePrice).mulDivDown(currentShares, 1e18); 
            vestingState.lastSharePrice = uint128((_totalAssets + newlyVested).mulDivDown(1e18, currentShares)); 

            _collectFees();

            // Move vested amount from pending to realized
            vestingState.vestingGains -= uint128(newlyVested);        // remove from pending
            vestingState.lastVestingUpdate = uint128(block.timestamp);  // update timestamp 

            if (block.timestamp < vestingState.endVestingTime) {
                uint256 timeRemaining = vestingState.endVestingTime - block.timestamp;
                vestingState.endVestingTime = uint128(block.timestamp + timeRemaining); 
            }
        }
        
        AccountantState storage state = accountantState;
        state.totalSharesLastUpdate = uint128(currentShares); 

        emit ExchangeRateUpdated(vestingState.lastSharePrice); 
    }

    /**
     * @notice Override updateExchangeRate to revert if called accidentally
     */
    function updateExchangeRate(uint96 /*newExchangeRate*/) external view override requiresAuth {
        revert AccountantWithYieldStreaming__UpdateExchangeRateNotSupported(); 
    }

    // ========================================= VIEW FUNCTIONS =========================================
    
    /**
     * @notice Returns the rate for one share at current block based on amount of gains that are vested and have vested
     * @dev linear interpolation between current timestamp and `endVestingTime` 
     */
    function getRate() public override view returns (uint256 rate) {
        uint256 currentShares = vault.totalSupply();
        if (currentShares == 0) {
            return rate = vestingState.lastSharePrice; //staringExchangeRate
        }
        rate = totalAssets().mulDivDown(10 ** decimals, currentShares);
    }

    /**
     * @notice Returns the safe rate for one share 
     * @dev Rerverts if the the accountant is paused
     */
    function getRateSafe() external override view returns (uint256 rate) {
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
        
        //if we haven't updated yet or no gains to vest
        if (vestingState.lastVestingUpdate >= vestingState.endVestingTime || vestingState.vestingGains == 0) {
            return 0;
        }
        
        //time that has passed since last update
        uint256 timeSinceLastUpdate = currentTime - vestingState.lastVestingUpdate;
        
        //total remaining vesting period when we last updated
        uint256 totalRemainingTime = vestingState.endVestingTime - vestingState.lastVestingUpdate;
        
        //vest it linearly over the remaining time
        return amountVested = (vestingState.vestingGains * timeSinceLastUpdate) / totalRemainingTime;
    }
    
    /**
     * @notice Returns the total assets in the vault at current timestamp
     * @dev Includes any gains that have already vested for this period
     */
    function totalAssets() public view returns (uint256) {
        uint256 currentShares = vault.totalSupply();
        return uint256(vestingState.lastSharePrice).mulDivDown(currentShares, 1e18) + getPendingVestingGains();
    }

    /**
     * @notice Returns the total assets in the vault at current timestamp
     */
    function version() external pure returns (string memory) {
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
        
        //calculate fees using function inherited from `AccountantWithRateProviders`
        _calculateFeesOwed(
            state,
            uint96(vestingState.lastSharePrice),
            state.exchangeRate,
            currentTotalShares,
            currentTime
        );
        
        state.exchangeRate = uint96(vestingState.lastSharePrice);
        state.totalSharesLastUpdate = uint128(currentTotalShares);
        state.lastUpdateTimestamp = currentTime;
    }
}
