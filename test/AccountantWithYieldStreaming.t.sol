// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs // Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
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
    uint8 public constant STRATEGIST_ROLE = 7;
    uint8 public constant BURNER_ROLE = 8;
    uint8 public constant SOLVER_ROLE = 9;
    uint8 public constant QUEUE_ROLE = 10;
    uint8 public constant CAN_SOLVE_ROLE = 11;
    
    address public alice = address(69); 
    address public bill = address(6969); 

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
        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE, address(accountant), AccountantWithYieldStreaming.vestYield.selector, true
        );
        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE, address(accountant), AccountantWithYieldStreaming.vestLoss.selector, true
        );
        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE, address(accountant), bytes4(keccak256("updateExchangeRate()")), true
        );
        rolesAuthority.setRoleCapability(
            MINTER_ROLE, address(accountant), bytes4(keccak256("updateCumulative()")), true
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
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(teller), STRATEGIST_ROLE, true);
        //deal(address(WETH), address(this), 1_000e18);
        //WETH.safeApprove(address(boringVault), 1_000e18);
        //boringVault.enter(address(this), WETH, 1_000e18, address(address(this)), 1_000e18);

        //accountant.setRateProviderData(EETH, true, address(0));
        //accountant.setRateProviderData(WEETH, false, address(WEETH_RATE_PROVIDER));
       
        teller.updateAssetData(WETH, true, true, 0);
        teller.updateAssetData(EETH, true, true, 0);
        teller.updateAssetData(WEETH, true, true, 0);

        accountant.updateMaximumDeviationYield(50000); //500% allowable (for testing)
    }

    //test
    function testDepositsWithNoYield() external {
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);
        assertEq(WETHAmount, shares0); 
        
        uint256 totalAssetsBefore = accountant.totalAssets();         

        //==== BEGIN DEPOSIT 2 ====

        //deposit 2
        uint256 shares1 = teller.deposit(WETH, WETHAmount, 0);
        assertEq(shares1, WETHAmount); 

        uint256 totalAssetsAfter = accountant.totalAssets();         
        assertGt(totalAssetsAfter, totalAssetsBefore); 
    }

    function testDepositsWithYield() external {
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);
        assertEq(WETHAmount, shares0); 

        //vest some yield
        deal(address(WETH), address(boringVault), WETHAmount);
        accountant.vestYield(WETHAmount, 24 hours); 
        skip(12 hours); 

        //==== BEGIN DEPOSIT 2 ====
        uint256 shares1 = teller.deposit(WETH, WETHAmount, 0);
        vm.assertApproxEqAbs(shares1, 6666666666666666666, 10);  

        //total of 2 deposits to 10 weth each + 5 vested yield 
        
        uint256 totalAssets = accountant.totalAssets(); 
        vm.assertApproxEqAbs(totalAssets, 25e18, 1); 
    }

    function testWithdrawNoYieldStream() external {
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);
        assertEq(WETHAmount, shares0); 

        //deposit 2
        teller.deposit(WETH, WETHAmount, 0);

        uint256 assetsOut0 = teller.bulkWithdraw(WETH, shares0, 0, address(boringVault));   
        assertEq(assetsOut0, WETHAmount); 
    }

    function testWithdrawWithYieldStream() external {
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);
        assertEq(WETHAmount, shares0); 

        //==== Add Vesting Yield Stream ====
        deal(address(WETH), address(boringVault), WETHAmount);
        accountant.vestYield(WETHAmount, 24 hours); 
        skip(12 hours); 
        
        //==== BEGIN DEPOSIT 2 ====
        deal(address(WETH), alice, 1_000e18);
        vm.startPrank(alice); 
        WETH.approve(address(boringVault), type(uint256).max); 
        uint256 shares1 = teller.deposit(WETH, WETHAmount, 0);
        vm.stopPrank(); 
        
        //==== BEGIN WITHDRAW USER 1 ====
        uint256 assetsOut = teller.bulkWithdraw(WETH, shares0, 0, address(boringVault));   
        assertEq(assetsOut, 15e18); 

        //==== BEGIN WITHDRAW USER 2 ====
        vm.prank(alice); 
        assetsOut = teller.bulkWithdraw(WETH, shares1, 0, address(alice));   
        vm.assertApproxEqAbs(assetsOut, 10e18, 1); 
    }

    function testWithdrawWithYieldStreamUser2WaitsForYield() external {
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);
        assertEq(WETHAmount, shares0); 

        //==== Add Vesting Yield Stream ====
        deal(address(WETH), address(boringVault), WETHAmount);
        accountant.vestYield(WETHAmount, 24 hours); 
        skip(12 hours); 
        
        //==== BEGIN DEPOSIT 2 ====
        deal(address(WETH), alice, 1_000e18);
        vm.startPrank(alice); 
        WETH.approve(address(boringVault), type(uint256).max); 
        uint256 shares1 = teller.deposit(WETH, WETHAmount, 0);
        vm.stopPrank(); 
        
        //==== BEGIN WITHDRAW USER 1 ====
        uint256 assetsOut = teller.bulkWithdraw(WETH, shares0, 0, address(boringVault));   
        assertEq(assetsOut, 15e18); 

        skip(12 hours); 

        //==== BEGIN WITHDRAW USER 2 ====
        vm.prank(alice); 
        assetsOut = teller.bulkWithdraw(WETH, shares1, 0, address(alice));   
        vm.assertApproxEqAbs(assetsOut, 15e18, 10); 
    }

    function testVestLossAbsorbBuffer() external {
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);
        assertEq(WETHAmount, shares0); 

        //==== Add Vesting Yield Stream ===="); 
        deal(address(WETH), address(boringVault), WETHAmount * 2);
        accountant.vestYield(WETHAmount, 24 hours); 
        skip(12 hours); 
        
        uint256 totalAssetsBeforeLoss = accountant.totalAssets(); 

        uint256 unvested = accountant.getPendingVestingGains(); //5e18

        //==== Vault Posts A Loss ====
        accountant.vestLoss(2.5e18); //smaller loss than buffer (5 weth at this point)

        uint256 totalAssetsAfterLoss = accountant.totalAssets(); 
        
        //assert the vestingGains is removed from  
        (, uint128 vestingGains, , , ) = accountant.vestingState(); 
        assertEq(unvested - 2.5e18, vestingGains); 

        //total assets should remain the same as the buffer absorbed the entire loss
        assertEq(totalAssetsBeforeLoss, totalAssetsAfterLoss); 

        skip(12 hours); 
        
        uint256 assetsOut = teller.bulkWithdraw(WETH, shares0, 0, address(boringVault)); 
        assertEq(assetsOut, 17.5e18); //10 WETH deposit -> 5 weth is vested -> 2.5 loss -> remaining 2.5 vests over the next 12 hours = total of 17.5 earned
    }


    function testVestLossAffectsSharePrice() external {
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);
        assertEq(WETHAmount, shares0); 

        //vault total = 10

        //==== Add Vesting Yield Stream ====
        deal(address(WETH), address(boringVault), WETHAmount);
        accountant.vestYield(WETHAmount, 24 hours); 
        skip(12 hours); 

        //total assets = 15

        uint256 totalAssetsInBaseBefore = accountant.totalAssets();  
        assertEq(totalAssetsInBaseBefore, 15e18); 
        
        (uint128 lastSharePrice, , , , ) = accountant.vestingState(); 
        uint256 sharePriceInitial = lastSharePrice; 

        //15 total assets as this point
        
        //==== Vault Posts A Loss ====
        accountant.vestLoss(15e18); //this moves vested yield -> share price (to protect share price)
        //note: the buffer absorbs the loss, so we're left with 5 remaining (the vested yield)
        
        //15 - 15 with (5 unvested remaining) = 5 left

        uint256 totalAssetsInBaseAfter = accountant.totalAssets();  
        
        //vesting gains should be 0
        (, uint128 vestingGains, , , ) = accountant.vestingState(); 
        assertEq(0, vestingGains); 

        //total assets should be 5e18 -> 10 initial, 5 yield, 5 unvested -> 15 weth loss (5 from buffer) -> 15 - 10 = 5 totalAssets remaining
        assertEq(totalAssetsInBaseAfter, 5e18); 

        skip(12 hours); 
        
        //TA should be same as remaining yield has been wiped
        uint256 totalAssetsInBaseAfterVest = accountant.totalAssets();  
        assertEq(totalAssetsInBaseAfter, totalAssetsInBaseAfterVest); //should be the same, as the remaining yield was wiped

        //check that the share price was affected
        
        (uint128 sharePriceAfter, , , , ) = accountant.vestingState(); 
        assertLt(sharePriceAfter, sharePriceInitial, "share price should be less after loss exceeds buffer"); 

        //console.log("difference: ", sharePriceInitial - sharePriceAfter); //diff = 50% 
        assertEq(sharePriceInitial / 2, sharePriceAfter); 
    }

    function testGetPendingVestingGains() external {
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);
        assertEq(WETHAmount, shares0); 

        //vault total = 10

        deal(address(WETH), address(boringVault), WETHAmount);
        accountant.vestYield(WETHAmount, 24 hours); 
        skip(6 hours); 
       
        //total should be 10 + (10 / 4) = 2.5

        uint256 totalAssets = accountant.totalAssets();  
        assertEq(totalAssets, 12.5e18); 
    }

    function testYieldStreamUpdateDuringExistingStream() external {
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);
        assertEq(shares0, WETHAmount); 

        deal(address(WETH), address(boringVault), WETHAmount);
        accountant.vestYield(WETHAmount, 24 hours); 
        skip(12 hours); 


        accountant.updateMinimumVestDuration(6 hours); 
        accountant.updateMaximumDeviationYield(50000); //500% allowable

        //total assets = 15

        uint256 unvested = accountant.getPendingVestingGains(); 

        //unvested = 5
        
        //strategist posts another yield update, halfway through the remaining update 
        //recall that the strategist MUST account for unvested yield in the update if they wish to include it in the next update
        deal(address(WETH), address(boringVault), WETHAmount * 3); //total should now be 30
        accountant.vestYield(WETHAmount + unvested, 24 hours); //total of 15 to post
        skip(12 hours); 

        //15 + 7.5 = 22.5

        uint256 totalAssets = accountant.totalAssets();  
        assertEq(totalAssets, 22.5e18); 
        
        (, uint128 gains, uint128 lastVestingUpdate, uint64 startVestingTime, uint64 endVestingTime) = accountant.vestingState(); 
        assertEq(gains, 15e18); 
        
        uint256 lastUpdate = lastVestingUpdate; 
        assertEq(lastUpdate, block.timestamp - 12 hours); 
        
        uint256 startTime = startVestingTime; 
        assertEq(startTime, block.timestamp - 12 hours); 

        uint256 endTime = endVestingTime; 
        assertEq((block.timestamp - 12 hours) + 24 hours, endTime); 
    }


    function testPlatformFees() external {
        uint256 platformFeeRate = 0.1e4; // 10%

        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);
        assertEq(WETHAmount, shares0); 

        deal(address(WETH), address(boringVault), WETHAmount);
        accountant.vestYield(WETHAmount, 24 hours); 

        // Skip 1 year
        skip(365 days);
        
        //update the rate
        accountant.updateExchangeRate();  
        
        //check the fees owned 
        (,, uint128 feesOwedInBase,,,,,,,,,) = accountant.accountantState();
        uint256 expectedFees = (WETHAmount * 2) * platformFeeRate / 1e4; // 20 WETH (10 over day 1, 20 over 364 days for total of 2)
        assertEq(feesOwedInBase, expectedFees);

        //claim fees
        vm.startPrank(address(boringVault));
        WETH.approve(address(accountant), feesOwedInBase);
        accountant.claimFees(WETH);
        vm.stopPrank();
        
        //verify we got paid
        assertEq(WETH.balanceOf(payoutAddress), expectedFees);
    }
    
    function testPerformanceFeesAfterYield() external {
        uint256 performanceFeeRate = 0.1e4; // 10%
    
        uint256 WETHAmount = 10e18;
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        teller.deposit(WETH, WETHAmount, 0);
    
        // Record initial state
        (, uint96 initialHighwaterMark, ,,,,,,,,,) = accountant.accountantState();
        (uint128 initialSharePrice,,,,) = accountant.vestingState(); 
        //uint256 initialSharePrice = uint256(lastSharePrice); 
        uint256 totalShares = boringVault.totalSupply();
    
        deal(address(WETH), address(boringVault), WETHAmount);
        accountant.vestYield(WETHAmount, 24 hours);
    
        //let it fully vest
        skip(1 days);
    
        //update exchange rate to trigger fee calculation
        accountant.updateExchangeRate();
    
        (, uint96 nextHighwaterMark, uint128 feesOwedInBase,,,,,,,,,) = accountant.accountantState();
        (uint128 finalSharePrice,,,,) = accountant.vestingState(); 
        //uint256 finalSharePrice = accountant.lastSharePrice();
    
        // Calculate expected performance fees based on SHARE PRICE APPRECIATION
        uint256 sharePriceIncrease = uint256(finalSharePrice - initialSharePrice); 
    
        // The appreciation in value = price increase * total shares / 10^18
        uint256 valueAppreciation = (sharePriceIncrease * totalShares) / 1e18;
    
        // Expected fees = 10% of appreciation
        uint256 expectedPerformanceFees = (valueAppreciation * performanceFeeRate) / 1e4;
        uint256 actualFees = feesOwedInBase;

        uint128 platformFee = 2739726027397260; //1 day of platform fees (10 WETH / 365)
    
        // Allow for small rounding difference
        assertApproxEqAbs(actualFees - platformFee, expectedPerformanceFees, 1e15, "Performance fees should match share price appreciation");
    
        // Verify high water mark updated
        assertGt(nextHighwaterMark, initialHighwaterMark, "HWM should increase");
        assertEq(uint256(nextHighwaterMark), finalSharePrice, "HWM should equal new share price");
    }

    function testTWASWorksAsExpectedWhenUpdatingYield() external {
        accountant.updateMaximumDeviationYield(500); //5%

        uint256 WETHAmount = 100e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);
        assertEq(WETHAmount, shares0); 

        accountant.vestYield(1e18, 1 days); // 1 WETH yield over 1 day //1% of vault 

        // T=12 hours: Deposit more to change supply
        skip(12 hours); 
        teller.deposit(WETH, 100e18, 0);

        skip(12 hours); 
        accountant.vestYield(2e18, 1 days); //another 1%, should pass //should be ~150ETH as totalAssets

        skip(24 hours); //total should now be ~152ETH
        accountant.vestYield(10e18, 1 days); //almost 5%, should pass //should be ~152ETH as totalAssets

        teller.deposit(WETH, 100e18, 0);

        skip(24 hours); //total should now be ~200ETH
        vm.expectRevert(AccountantWithYieldStreaming.AccountantWithYieldStreaming__MaxDeviationYieldExceeded.selector); 
        accountant.vestYield(100e18, 1 days); //should fail 
    }
    
        
    // ========================= EDGE CASES ===============================
    
    function testDonationsShouldNotBeConsideredInCalculations() external {
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);
        assertEq(WETHAmount, shares0); 

        //vest some yield
        deal(address(WETH), address(boringVault), WETHAmount * 2);
        accountant.vestYield(WETHAmount, 24 hours); 
        skip(12 hours); 
        
        deal(address(WETH), alice, 10e18); 
        vm.prank(alice);
        WETH.transfer(address(boringVault), 10e18); 

        //deposit 2 uint256 shares1 = teller.deposit(WETH, WETHAmount, 0);
        uint256 totalAssets = accountant.totalAssets(); 
        vm.assertApproxEqAbs(totalAssets, 15e18, 1); 

        uint256 assetsOut = teller.bulkWithdraw(WETH, shares0, 0, address(boringVault));   
        assertEq(assetsOut, 15e18); 
    }

    function testDoubleDepositInSameBlock() external {
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);
        assertEq(WETHAmount, shares0); 

        uint256 shares1 = teller.deposit(WETH, WETHAmount, 0);
        assertEq(WETHAmount, shares1); 
        
        uint256 currentShares = boringVault.totalSupply(); 
        (uint128 lsp, , , ,) = accountant.vestingState(); 
        uint256 lastSharePrice = uint256(lsp); 
        uint256 totalAssetsInBase = ((currentShares * lastSharePrice) / 1e18) + accountant.getPendingVestingGains(); 
        assertEq(totalAssetsInBase, 20e18); 
    }

    function testDoubleDepositInSameBlockAfterYieldEvent() external {
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);
        assertEq(WETHAmount, shares0); 

        //vest some yield
        deal(address(WETH), address(boringVault), WETHAmount * 2);
        accountant.vestYield(WETHAmount, 24 hours); 
        skip(12 hours); 
        
        //double deposit -> alice, bill both deposit in the same block 
        deal(address(WETH), alice, WETHAmount);
        vm.startPrank(alice);
        WETH.approve(address(boringVault), WETHAmount);
        uint256 sharesAlice = teller.deposit(WETH, WETHAmount, 0);
        vm.stopPrank();

        deal(address(WETH), bill, WETHAmount);
        vm.startPrank(bill);
        WETH.approve(address(boringVault), WETHAmount);
        uint256 sharesBill = teller.deposit(WETH, WETHAmount, 0);
        vm.stopPrank();

        //skip time
        skip(12 hours); 
        
        //alice withdraws
        vm.prank(alice); 
        uint256 assetsOutAlice = teller.bulkWithdraw(WETH, sharesAlice, 0, address(boringVault));   

        //bob withdraws
        vm.prank(bill); 
        uint256 assetsOutBill = teller.bulkWithdraw(WETH, sharesBill, 0, address(boringVault));   

        assertEq(assetsOutAlice, assetsOutBill); 
    }

    function testLoopDepositWithdrawDuringVest() external {
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);
        assertEq(WETHAmount, shares0); 

        //vest some yield
        deal(address(WETH), address(boringVault), WETHAmount * 2);
        accountant.vestYield(WETHAmount, 24 hours); 
        skip(12 hours); 
        
        //double deposit -> alice, bill both deposit in the same block 
        deal(address(WETH), alice, WETHAmount);
        vm.startPrank(alice);
        WETH.approve(address(boringVault), WETHAmount);
        uint256 sharesAlice = teller.deposit(WETH, WETHAmount, 0);
        vm.stopPrank();

        //skip time
        //skip(12 hours); 
        
        //alice withdraws
        vm.prank(alice); 
        uint256 assetsOutAlice = teller.bulkWithdraw(WETH, sharesAlice, 0, address(boringVault));   

        deal(address(WETH), bill, WETHAmount);
        vm.startPrank(bill);
        WETH.approve(address(boringVault), WETHAmount);
        teller.deposit(WETH, WETHAmount, 0);
        vm.stopPrank();

        assertApproxEqAbs(assetsOutAlice, WETHAmount, 10); 
    }

    function testLoopDepositWithdrawDepositDuringVest() external {
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);
        assertEq(WETHAmount, shares0); 

        //vest some yield
        deal(address(WETH), address(boringVault), WETHAmount * 2);
        accountant.vestYield(WETHAmount, 24 hours); 
        skip(12 hours); 
        
        deal(address(WETH), alice, WETHAmount);
        vm.startPrank(alice);
        WETH.approve(address(boringVault), WETHAmount);
        uint256 sharesAlice = teller.deposit(WETH, WETHAmount, 0);
        vm.stopPrank();

        //skip time
        //skip(12 hours); 
        
        //alice withdraws
        vm.prank(alice); 
        uint256 assetsOutAlice = teller.bulkWithdraw(WETH, sharesAlice, 0, address(boringVault));   

        deal(address(WETH), bill, WETHAmount);
        vm.startPrank(bill);
        WETH.approve(address(boringVault), WETHAmount);
        uint256 sharesBill = teller.deposit(WETH, WETHAmount, 0);
        vm.stopPrank();

        assertLt(assetsOutAlice, WETHAmount); 

        vm.prank(bill); 
        uint256 assetsOutBill = teller.bulkWithdraw(WETH, sharesBill, 0, address(boringVault));   
        assertApproxEqAbs(WETHAmount, assetsOutBill, 1);
    }

    function testDepositDuringSameBlockAsYieldIsDeposited() external {
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);
        assertEq(WETHAmount, shares0); 

        //vest some yield
        deal(address(WETH), address(boringVault), WETHAmount * 2);
        accountant.vestYield(WETHAmount, 24 hours); 
        
        deal(address(WETH), alice, WETHAmount);
        vm.startPrank(alice);
        WETH.approve(address(boringVault), WETHAmount);
        uint256 sharesAlice = teller.deposit(WETH, WETHAmount, 0);
        vm.stopPrank();

        //alice withdraws
        vm.prank(alice); 
        uint256 assetsOutAlice = teller.bulkWithdraw(WETH, sharesAlice, 0, address(boringVault));   

        assertEq(assetsOutAlice, WETHAmount); //assert no dilution, no extra yield
    }

    // ========================= REVERT TESTS / FAILURE CASES ===============================
    
    function testVestYieldCannotExceedMaximumDuration() external {
        //by default, maximum duration is 7 days
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);
        assertEq(WETHAmount, shares0); 

        //vest some yield
        deal(address(WETH), address(boringVault), WETHAmount * 2);
        vm.expectRevert(AccountantWithYieldStreaming.AccountantWithYieldStreaming__DurationExceedsMaximum.selector); 
        accountant.vestYield(WETHAmount, 7 days + 1 hours); 
    }

    function testVestYieldUnderMinimumDuration() external {
        //by default, maximum duration is 7 days
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);
        assertEq(WETHAmount, shares0); 

        //vest some yield
        deal(address(WETH), address(boringVault), WETHAmount * 2);
        vm.expectRevert(AccountantWithYieldStreaming.AccountantWithYieldStreaming__DurationUnderMinimum.selector); 
        accountant.vestYield(WETHAmount, 23 hours); 
    }

    function testVestYieldZeroAmount() external {
        //by default, maximum duration is 7 days
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);
        assertEq(WETHAmount, shares0); 

        //vest some yield
        deal(address(WETH), address(boringVault), WETHAmount * 2);
        vm.expectRevert(AccountantWithYieldStreaming.AccountantWithYieldStreaming__ZeroYieldUpdate.selector); 
        accountant.vestYield(0, 24 hours); 
    }

    // ========================= FUZZ TESTS ===============================
    
    function testFuzzDepositsWithNoYield(uint96 WETHAmount, uint96 WETHAmount2) external {
        accountant.updateMaximumDeviationYield(5000000); 
        vm.assume(uint256(WETHAmount) + uint256(WETHAmount2) < type(uint128).max); 
        vm.assume(WETHAmount > 0); 
        vm.assume(WETHAmount2 > 0); 

        deal(address(WETH), address(this), WETHAmount);
        WETH.approve(address(boringVault), type(uint256).max);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);
        assertEq(shares0, WETHAmount); 

        //==== BEGIN DEPOSIT 2 ====

        deal(address(WETH), address(this), WETHAmount2);
        uint256 shares1 = teller.deposit(WETH, WETHAmount2, 0);
        assertEq(shares1, WETHAmount2); 

        uint256 totalAssetsAfter = accountant.totalAssets();         
        assertEq(totalAssetsAfter, uint256(WETHAmount) + uint256(WETHAmount2)); 
    }

    function testFuzzDepositsWithYield(uint96 WETHAmount, uint96 WETHAmount2, uint96 yieldVestAmount) external {
    accountant.updateMaximumDeviationYield(5000000); 
    //function testFuzzDepositsWithYield() external {
        //vm.assume(WETHAmount > 1 && WETHAmount <= 1_000_000e18); 
        //vm.assume(WETHAmount2 > 1 && WETHAmount2 <= 1_000_000e18); 
        //vm.assume(uint256(WETHAmount) + uint256(WETHAmount2) + uint256(yieldVestAmount) < type(uint128).max); 

        vm.assume(WETHAmount >= 1e18 && WETHAmount <= 1_000_000e18);
        vm.assume(WETHAmount2 >= 1e18 && WETHAmount2 <= 1_000_000e18);
        // Yield should be reasonable relative to deposits - max 100x the first deposit
        vm.assume(yieldVestAmount >= 1e16 && yieldVestAmount <= uint256(WETHAmount) * 100);
        deal(address(WETH), address(this), WETHAmount);
        WETH.approve(address(boringVault), type(uint256).max);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);
        assertEq(shares0, WETHAmount);
       
         
        uint256 totalAssetsBefore = accountant.totalAssets();
        assertEq(totalAssetsBefore, WETHAmount); 
        
        deal(address(WETH), address(boringVault), WETHAmount);
        accountant.vestYield(yieldVestAmount, 24 hours); 
        skip(12 hours); 

        //==== BEGIN DEPOSIT 2 ====
        
        // New share price = totalAssets / totalShares
        // Expected shares = depositAmount * totalShares / totalAssets

        uint256 actualVestedAmount = accountant.getPendingVestingGains();
        //console.log("actualVestedAmount", actualVestedAmount);
        

        deal(address(WETH), address(this), WETHAmount2);
        uint256 shares1 = teller.deposit(WETH, WETHAmount2, 0);

        // Calculate shares: amount / rate
        // Since rate is scaled by 1e18, we need to adjust:
        uint256 currentRate = accountant.getRate();
        uint256 expectedShares1 = uint256(WETHAmount2).mulDivDown(1e18, currentRate);

        assertEq(shares1, expectedShares1); 

        //uint256 currentShares = boringVault.totalSupply(); 
        uint256 totalAssetsAfter = accountant.totalAssets();         
        uint256 expectedTotal = uint256(WETHAmount) + uint256(WETHAmount2) + actualVestedAmount;
        assertApproxEqAbs(totalAssetsAfter, expectedTotal, 1e6);  
    }

    function testFuzzWithdrawWithYield(uint96 WETHAmount, uint96 WETHAmount2, uint96 yieldVestAmount) external {
        accountant.updateMaximumDeviationYield(5000000); 
        vm.assume(WETHAmount >= 1e18 && WETHAmount <= 1_000_000e18);
        vm.assume(WETHAmount2 >= 1e18 && WETHAmount2 <= 1_000_000e18);
        // Yield should be reasonable relative to deposits - max 100x the first deposit
        vm.assume(yieldVestAmount >= 1e16 && yieldVestAmount <= uint256(WETHAmount) * 100);
        deal(address(WETH), address(this), WETHAmount);
        WETH.approve(address(boringVault), type(uint256).max);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0);
        assertEq(shares0, WETHAmount);
       
         
        uint256 totalAssetsBefore = accountant.totalAssets();
        assertEq(totalAssetsBefore, WETHAmount); 
        
        deal(address(WETH), address(boringVault), WETHAmount);
        accountant.vestYield(yieldVestAmount, 24 hours); 
        skip(12 hours); 

        //==== BEGIN DEPOSIT 2 ====
        
        // New share price = totalAssets / totalShares
        // Expected shares = depositAmount * totalShares / totalAssets

        uint256 actualVestedAmount = accountant.getPendingVestingGains();
        //console.log("actualVestedAmount", actualVestedAmount);
        

        deal(address(WETH), address(this), WETHAmount2);
        uint256 shares1 = teller.deposit(WETH, WETHAmount2, 0);

        // Calculate shares: amount / rate
        // Since rate is scaled by 1e18, we need to adjust:
        uint256 currentRate = accountant.getRate();
        uint256 expectedShares1 = uint256(WETHAmount2).mulDivDown(1e18, currentRate);

        assertEq(shares1, expectedShares1); 

        //uint256 currentShares = boringVault.totalSupply(); 
        uint256 totalAssetsAfter = accountant.totalAssets();         
        uint256 expectedTotal = uint256(WETHAmount) + uint256(WETHAmount2) + actualVestedAmount;
        assertApproxEqAbs(totalAssetsAfter, expectedTotal, 1e6);  
        
        deal(address(WETH), address(boringVault), type(uint256).max); 
        //withdraw 
        currentRate = accountant.getRate();
        uint256 assetsOut = teller.bulkWithdraw(WETH, shares0, 0, address(boringVault));   

        uint256 expectedAssetsOut = uint256(shares0).mulDivDown(currentRate, 1e18);
        assertApproxEqAbs(assetsOut, expectedAssetsOut, 1e5); 
    }

    // ========================================= HELPER FUNCTIONS =========================================
    
    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
