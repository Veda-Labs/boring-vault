// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithYieldStreaming} from "src/base/Roles/AccountantWithYieldStreaming.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol"; 
import {TellerWithYieldStreaming} from "src/base/Roles/TellerWithYieldStreaming.sol"; 
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {GenericRateProvider} from "src/helper/GenericRateProvider.sol";
import {GenericRateProviderWithDecimalScaling} from "src/helper/GenericRateProviderWithDecimalScaling.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";


contract AccountantWithYieldStreamingTest is Test, MerkleTreeHelper {
    using FixedPointMathLib for uint256;


    BoringVault public boringVault;
    AccountantWithYieldStreaming public accountant; 
    TellerWithYieldStreaming public teller;
    RolesAuthority public rolesAuthority;

    address public payoutAddress = vm.addr(7777777);
    ERC20 internal WETH;
    ERC20 internal EETH;
    ERC20 internal WEETH;
    ERC20 internal ETHX;

    //GenericRateProvider public mETHRateProvider;
    //GenericRateProvider public ptRateProvider;


    uint8 public constant MINTER_ROLE = 1;
    uint8 public constant ADMIN_ROLE = 1;
    uint8 public constant BORING_VAULT_ROLE = 4;
    uint8 public constant UPDATE_EXCHANGE_RATE_ROLE = 3;
    //uint8 public constant MINTER_ROLE = 7;
    uint8 public constant BURNER_ROLE = 8;
    uint8 public constant SOLVER_ROLE = 9;
    uint8 public constant QUEUE_ROLE = 10;
    uint8 public constant CAN_SOLVE_ROLE = 11;
    
    address public alice = address(69); 

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 23039901;
        _startFork(rpcKey, blockNumber);

        WETH = getERC20(sourceChain, "WETH");
        EETH = getERC20(sourceChain, "EETH");
        WEETH = getERC20(sourceChain, "WEETH");
        ETHX = getERC20(sourceChain, "ETHX");

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);
        accountant = new AccountantWithYieldStreaming(
            address(this), address(boringVault), payoutAddress, 1e18, address(WETH), 1.001e4, 0.999e4, 1, 0.1e4, 0.1e4
        );
        teller =
            new TellerWithYieldStreaming(address(this), address(boringVault), address(accountant), address(WETH));

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        accountant.setAuthority(rolesAuthority);
        teller.setAuthority(rolesAuthority);
        boringVault.setAuthority(rolesAuthority);

        // Setup roles authority.
        rolesAuthority.setRoleCapability(MINTER_ROLE, address(boringVault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(boringVault), BoringVault.exit.selector, true);
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(accountant), AccountantWithRateProviders.pause.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(accountant), AccountantWithRateProviders.unpause.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(accountant), AccountantWithRateProviders.updateDelay.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(accountant), AccountantWithRateProviders.updateUpper.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(accountant), AccountantWithRateProviders.updateLower.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(accountant), AccountantWithRateProviders.updatePlatformFee.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(accountant), AccountantWithRateProviders.updatePayoutAddress.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(accountant), AccountantWithRateProviders.setRateProviderData.selector, true
        );
        rolesAuthority.setRoleCapability(
            UPDATE_EXCHANGE_RATE_ROLE,
            address(accountant),
            AccountantWithRateProviders.updateExchangeRate.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            BORING_VAULT_ROLE, address(accountant), AccountantWithRateProviders.claimFees.selector, true
        );
        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.deposit.selector, true);
        rolesAuthority.setPublicCapability(
            address(teller), TellerWithMultiAssetSupport.depositWithPermit.selector, true
        );
        rolesAuthority.setPublicCapability(address(teller), TellerWithYieldStreaming.bulkWithdraw.selector, true);

        // Allow the boring vault to receive ETH.
        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);

        rolesAuthority.setUserRole(address(this), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(this), UPDATE_EXCHANGE_RATE_ROLE, true);
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);
        //deal(address(WETH), address(this), 1_000e18);
        //WETH.safeApprove(address(boringVault), 1_000e18);
        //boringVault.enter(address(this), WETH, 1_000e18, address(address(this)), 1_000e18);

        //accountant.setRateProviderData(EETH, true, address(0));
        //accountant.setRateProviderData(WEETH, false, address(WEETH_RATE_PROVIDER));
       
        teller.updateAssetData(WETH, true, true, 0);
        teller.updateAssetData(EETH, true, true, 0);
        teller.updateAssetData(WEETH, true, true, 0);
        
    }

    //test
    function testDepositsWithNoYield() external {
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);

        console.log("shares0 minted: ", shares0); 
        assertEq(WETHAmount, shares0); 
        
        uint256 currentShares = boringVault.totalSupply(); 
        console.log("curent shares: ", currentShares); 
        uint256 totalAssetsInBase = ((currentShares * accountant.lastSharePrice()) / 1e18) + accountant.getPendingVestingGains(); 
        console.log("totalAssetsInBase: ", totalAssetsInBase); 

        console.log("==== BEGIN DEPOSIT 2 ===="); 

        //deposit 2
        uint256 shares1 = teller.deposit(WETH, WETHAmount, 0);
        console.log("shares1 with no yield: ", shares1); 

        //totalAssetsInBase = accountant.totalAssetsInBase(); 
        currentShares = boringVault.totalSupply(); 
        console.log("curent shares: ", currentShares); 
        totalAssetsInBase = ((currentShares * accountant.lastSharePrice()) / 1e18) + accountant.getPendingVestingGains(); 
        console.log("totalAssetsInBase: ", totalAssetsInBase); 
    }

    function testDepositsWithYield() external {
        console.log("==== Test Deposit With Yield Stream at 50% ===="); 
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);

        console.log("shares0 minted: ", shares0); 
        assertEq(WETHAmount, shares0); 
        
        uint256 currentShares = boringVault.totalSupply(); 
        console.log("curent shares: ", currentShares); 
        uint256 totalAssetsInBase = ((currentShares * accountant.lastSharePrice()) / 1e18) + accountant.getPendingVestingGains(); 
        console.log("totalAssetsInBase: ", totalAssetsInBase); 

        //vest some yield
        WETH.approve(address(accountant), type(uint256).max);
        accountant.vestYield(WETHAmount, 24 hours); 
        skip(12 hours); 

        console.log("==== BEGIN DEPOSIT 2 ===="); 

        //deposit 2
        uint256 shares1 = teller.deposit(WETH, WETHAmount, 0);
        console.log("shares1 with yield: ", shares1); 

        //totalAssetsInBase = accountant.totalAssetsInBase(); 
        currentShares = boringVault.totalSupply(); 
        console.log("curent shares: ", currentShares); 
        totalAssetsInBase = currentShares.mulDivDown(accountant.lastSharePrice(), 1e18); 
        //should be 25 -> 2 deposits of 10 WETH, and 50% of a yield stream vested = 5 WETH
        console.log("totalAssetsInBase: ", totalAssetsInBase); 
        vm.assertApproxEqAbs(totalAssetsInBase, 25e18, 1); 
    }

    function testWithdrawNoYieldStream() external {
        console.log("==== Test Withdraw No Yield Stream ===="); 
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);

        console.log("==== BEGIN DEPOSIT 2 ===="); 

        //deposit 2
        uint256 shares1 = teller.deposit(WETH, WETHAmount, 0);
        
        console.log("==== BEGIN WITHDRAW ===="); 
        teller.bulkWithdraw(WETH, shares0, 0, address(boringVault));   

        uint256 currentShares = boringVault.totalSupply(); 
        console.log("curent shares: ", currentShares); 
        uint256 totalAssetsInBase = currentShares.mulDivDown(accountant.lastSharePrice(), 1e18); 
        console.log("totalAssetsInBase: ", totalAssetsInBase); 
    }

    function testWithdrawWithYieldStream() external {
        console.log("==== Test Withdraw With Yield Stream ===="); 
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);

        console.log("==== Add Vesting Yield Stream ===="); 
        WETH.approve(address(accountant), type(uint256).max);
        accountant.vestYield(WETHAmount, 24 hours); 
        skip(12 hours); 
        
        console.log("==== BEGIN DEPOSIT 2 ===="); 
        //deposit 2
        deal(address(WETH), alice, 1_000e18);
        vm.startPrank(alice); 
        WETH.approve(address(boringVault), type(uint256).max); 
        uint256 shares1 = teller.deposit(WETH, WETHAmount, 0);
        vm.stopPrank(); 
        
        console.log("==== BEGIN WITHDRAW USER 1 ===="); 
        uint256 assetsOut = teller.bulkWithdraw(WETH, shares0, 0, address(boringVault));   

        uint256 currentShares = boringVault.totalSupply(); 
        console.log("curent shares: ", currentShares); 
        uint256 totalAssetsInBase = currentShares.mulDivDown(accountant.lastSharePrice(), 1e18); 
        console.log("totalAssetsInBase: ", totalAssetsInBase); 

        console.log("user 1 received: ", assetsOut); 
        assertEq(assetsOut, 15e18); 

        console.log("==== BEGIN WITHDRAW USER 2 ===="); 
        vm.prank(alice); 
        assetsOut = teller.bulkWithdraw(WETH, shares1, 0, address(alice));   

        console.log("user 2 received: ", assetsOut); 
        vm.assertApproxEqAbs(assetsOut, 10e18, 1); 
    }

    function testWithdrawWithYieldStreamUser2WaitsForYield() external {
        console.log("==== Test Withdraw With Yield Stream User 2 Waits for Yield ===="); 
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);

        console.log("==== Add Vesting Yield Stream ===="); 
        WETH.approve(address(accountant), type(uint256).max);
        accountant.vestYield(WETHAmount, 24 hours); 
        skip(12 hours); 
        
        console.log("==== BEGIN DEPOSIT 2 ===="); 
        //deposit 2
        deal(address(WETH), alice, 1_000e18);
        vm.startPrank(alice); 
        WETH.approve(address(boringVault), type(uint256).max); 
        uint256 shares1 = teller.deposit(WETH, WETHAmount, 0);
        vm.stopPrank(); 
        
        console.log("==== BEGIN WITHDRAW USER 1 ===="); 
        uint256 assetsOut = teller.bulkWithdraw(WETH, shares0, 0, address(boringVault));   

        uint256 currentShares = boringVault.totalSupply(); 
        console.log("curent shares: ", currentShares); 
        uint256 totalAssetsInBase = currentShares.mulDivDown(accountant.lastSharePrice(), 1e18); 
        console.log("totalAssetsInBase: ", totalAssetsInBase); 

        console.log("user 1 received: ", assetsOut); 
        assertEq(assetsOut, 15e18); 

        skip(12 hours); 

        console.log("==== BEGIN WITHDRAW USER 2 ===="); 
        vm.prank(alice); 
        assetsOut = teller.bulkWithdraw(WETH, shares1, 0, address(alice));   

        console.log("user 2 received: ", assetsOut); 
        vm.assertApproxEqAbs(assetsOut, 15e18, 2); 
    }

    function testVestLossAbsorbBuffer() external {
        console.log("==== Test Vesting a Loss (fully absorbed by buffer) ==="); 
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);

        console.log("==== Add Vesting Yield Stream ===="); 
        WETH.approve(address(accountant), type(uint256).max);
        accountant.vestYield(WETHAmount, 24 hours); 
        skip(12 hours); 
        console.log("==== End Vesting Yield Stream ===="); 

        uint256 currentShares = boringVault.totalSupply(); 
        console.log("curent shares before loss: ", currentShares); 
        uint256 totalAssetsInBaseBefore = accountant.totalAssets();  
        console.log("totalAssetsInBase before loss: ", totalAssetsInBaseBefore); 

        console.log("==== Vault Posts A Loss ===="); 
        accountant.vestLoss(2.5e18, 0); //smaller loss than buffer (5 weth at this point)

        currentShares = boringVault.totalSupply(); 
        console.log("curent shares: ", currentShares); 
        uint256 totalAssetsInBaseAfter = accountant.totalAssets();  
        console.log("totalAssetsInBase after loss: ", totalAssetsInBaseAfter); 

        console.log("vesting gains should decrease by 2.5e18: ", accountant.vestingGains()); 

        //total assets should remain the same as the buffer absorbed the entire loss
        assertEq(totalAssetsInBaseBefore, totalAssetsInBaseAfter); 


        skip(12 hours); 

        uint256 assetsOut = teller.bulkWithdraw(WETH, shares0, 0, address(boringVault)); 
        //assertEq(should be 15 total instead of 20); 
    }


    function testVestLossAffectsSharePrice() external {
        console.log("==== Test Vesting a Loss (affects share price) ==="); 
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);

        //vault total = 10

        console.log("==== Add Vesting Yield Stream ===="); 
        WETH.approve(address(accountant), type(uint256).max);
        accountant.vestYield(WETHAmount, 24 hours); 
        skip(12 hours); 
        console.log("==== End Vesting Yield Stream ===="); 

        //total assets = 15

        uint256 currentShares = boringVault.totalSupply(); 
        uint256 totalAssetsInBaseBefore = accountant.totalAssets();  
        assertEq(totalAssetsInBaseBefore, 15e18); 

        uint256 sharePriceInitial = accountant.lastSharePrice(); 

        //15 total assets as this point
        
        console.log("==== Vault Posts A Loss ===="); 
        accountant.vestLoss(15e18, 0); //this moves vested yield -> share price (to protect share price)
        //note: the buffer absorbs the loss, so we're left with 5 remaining (the vested yield)
        
        //15 - 15 with (5 unvested remaining) = 5 left

        currentShares = boringVault.totalSupply(); 
        uint256 totalAssetsInBaseAfter = accountant.totalAssets();  
        console.log("totalAssetsInBase after loss: ", totalAssetsInBaseAfter); 
        
        //vesting gains should be 0
        assertEq(0, accountant.vestingGains()); 

        //total assets should be 5e18 -> 10 initial, 5 yield, 5 unvested -> 15 weth loss (5 from buffer) -> 15 - 10 = 5 totalAssets remaining
        assertEq(totalAssetsInBaseAfter, 5e18); 

        skip(12 hours); 
        
        //TA should be same as remaining yield has been wiped
        uint256 totalAssetsInBaseAfterVest = accountant.totalAssets();  
        assertEq(totalAssetsInBaseAfter, totalAssetsInBaseAfterVest); //should be the same, as the remaining yield was wiped

        //check that the share price was affected
        uint256 sharePriceAfter = accountant.lastSharePrice(); 
        assertLt(sharePriceAfter, sharePriceInitial, "share price should be less after loss exceeds buffer"); 

        console.log("share price before loss: ", sharePriceInitial); 
        console.log("share price after loss: ", sharePriceAfter); 
        console.log("difference: ", sharePriceInitial - sharePriceAfter); //diff = 50% 
    }

    function testGetPendingVestingGains() external {
        console.log("==== Test Vesting Yield returns the Vested Yield only as a part of total assets ==="); 
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);

        //vault total = 10

        WETH.approve(address(accountant), type(uint256).max);
        accountant.vestYield(WETHAmount, 24 hours); 
        skip(6 hours); 
       
        //total should be 10 + (10 / 4) = 2.5

        uint256 currentShares = boringVault.totalSupply(); 
        uint256 totalAssets = accountant.totalAssets();  
        console.log("total assets: ", totalAssets); 
        assertEq(totalAssets, 12.5e18); 
    }

    function testPlatformFees() external {
        console.log("==== Test Platform Fees still work as expected ==="); 
        uint256 platformFeeRate = 0.1e4; // 10%

        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);

        WETH.approve(address(accountant), type(uint256).max);
        accountant.vestYield(WETHAmount, 24 hours); 

        // Skip 1 year
        skip(365 days);
        
        //update the rate
        accountant.updateExchangeRate();  
        
        //check the fees owned 
        (,, uint128 feesOwedInBase,,,,,,,,,) = accountant.accountantState();
        uint256 expectedFees = WETHAmount * platformFeeRate / 1e4; // 10 WETH
        assertEq(feesOwedInBase, expectedFees);

        //claim fees
        vm.startPrank(address(boringVault));
        WETH.approve(address(accountant), feesOwedInBase);
        accountant.claimFees(WETH);
        vm.stopPrank();
        
        //verify we got paid
        uint256 fees = WETH.balanceOf(payoutAddress); 
        console.log("Fees earned: ", fees); 
        assertEq(WETH.balanceOf(payoutAddress), expectedFees);
    }
    
    function testPerformanceFeesAfterYield() external {
        console.log("==== Test Performance Fees After Yield ====");
    
        uint256 performanceFeeRate = 0.1e4; // 10%
    
        uint256 WETHAmount = 10e18;
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        teller.deposit(WETH, WETHAmount, 0);
    
        // Record initial state
        (, uint96 initialHighwaterMark, ,,,,,,,,,) = accountant.accountantState();
        uint256 initialSharePrice = accountant.lastSharePrice();
        uint256 totalShares = boringVault.totalSupply();
    
        console.log("Initial high water mark:", initialHighwaterMark);
        console.log("Initial share price:", initialSharePrice);
        console.log("Total shares:", totalShares);
    
        WETH.approve(address(accountant), type(uint256).max);
        accountant.vestYield(WETHAmount, 24 hours);
    
        // Let it fully vest
        skip(1 days);
    
        // Update exchange rate to trigger fee calculation
        accountant.updateExchangeRate();
    
        (, uint96 nextHighwaterMark, uint128 feesOwedInBase,,,,,,,,,) = accountant.accountantState();
        uint256 finalSharePrice = accountant.lastSharePrice();
    
        console.log("Share price after yield:", finalSharePrice);
        console.log("New high water mark:", nextHighwaterMark);
    
        // Calculate expected performance fees based on SHARE PRICE APPRECIATION
        uint256 sharePriceIncrease = finalSharePrice - initialSharePrice;
        console.log("Share price increase:", sharePriceIncrease);
    
        // The appreciation in value = price increase * total shares / 10^18
        uint256 valueAppreciation = (sharePriceIncrease * totalShares) / 1e18;
        console.log("Value appreciation:", valueAppreciation);
    
        // Expected fees = 10% of appreciation
        uint256 expectedPerformanceFees = (valueAppreciation * performanceFeeRate) / 1e4;
        uint256 actualFees = feesOwedInBase;
    
        console.log("Expected performance fees (10% of appreciation):", expectedPerformanceFees);
        console.log("Actual fees owed:", actualFees);
    
        // Allow for small rounding difference
        assertApproxEqAbs(actualFees, expectedPerformanceFees, 1e15, "Performance fees should match share price appreciation");
    
        // Verify high water mark updated
        assertGt(nextHighwaterMark, initialHighwaterMark, "HWM should increase");
        assertEq(uint256(nextHighwaterMark), finalSharePrice, "HWM should equal new share price");
    }
    
    // ========================================= HELPER FUNCTIONS =========================================
    
    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
