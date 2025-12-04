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

    event Paused();

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
    address internal WEETH_RATE_PROVIDER;


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
    address public referrer = vm.addr(1337);

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

        WEETH_RATE_PROVIDER = getAddress(sourceChain, "WEETH_RATE_PROVIDER");

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
        rolesAuthority.setRoleCapability(MINTER_ROLE, address(accountant), AccountantWithYieldStreaming.setFirstDepositTimestamp.selector, true);
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
            STRATEGIST_ROLE, address(accountant), AccountantWithYieldStreaming.postLoss.selector, true
        );
        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE, address(accountant), bytes4(keccak256("updateExchangeRate(bool)")), true
        );
        rolesAuthority.setRoleCapability(
            MINTER_ROLE, address(accountant), bytes4(keccak256("updateCumulative()")), true
        );
        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.deposit.selector, true);
        rolesAuthority.setPublicCapability(
            address(teller), TellerWithMultiAssetSupport.depositWithPermit.selector, true
        );
        rolesAuthority.setPublicCapability(address(teller), TellerWithYieldStreaming.withdraw.selector, true);

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
        accountant.setRateProviderData(WEETH, false, address(WEETH_RATE_PROVIDER));
       
        teller.updateAssetData(WETH, true, true, 0);
        teller.updateAssetData(EETH, true, true, 0);
        teller.updateAssetData(WEETH, true, true, 0);

        accountant.updateMaximumDeviationYield(50000); //500% allowable (for testing)
    }

    //test
    function testDepositsWithNoYield_() external {
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0, referrer);
        assertEq(WETHAmount, shares0); 
        
        uint256 totalAssetsBefore = accountant.totalAssets();         

        //==== BEGIN DEPOSIT 2 ====

        //deposit 2
        uint256 shares1 = teller.deposit(WETH, WETHAmount, 0, referrer);
        assertEq(shares1, WETHAmount); 

        uint256 totalAssetsAfter = accountant.totalAssets();         
        assertGt(totalAssetsAfter, totalAssetsBefore); 
    }

    function testDepositsWithYield() external {
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0, referrer);
        assertEq(WETHAmount, shares0); 

        //vest some yield
        deal(address(WETH), address(boringVault), WETHAmount);
        accountant.vestYield(WETHAmount, 24 hours); 
        skip(12 hours); 

        //==== BEGIN DEPOSIT 2 ====
        uint256 shares1 = teller.deposit(WETH, WETHAmount, 0, referrer);
        vm.assertApproxEqAbs(shares1, 6666666666666666666, 10);  

        //total of 2 deposits to 10 weth each + 5 vested yield 
        
        uint256 totalAssets = accountant.totalAssets(); 
        vm.assertApproxEqAbs(totalAssets, 25e18, 1); 
    }

    //test
    function testDepositsWithNoYieldNonBaseAsset() external {
        uint256 WEETHAmount = 10e18;
        deal(address(WEETH), address(this), 1_000e18);
        WEETH.approve(address(boringVault), 1_000e18);

        uint256 rateInWEETH = accountant.getRateInQuote(WEETH);

        // shares = depositAmount * 1e18 / rateInWEETH
        uint256 expectedShares = WEETHAmount.mulDivDown(1e18, rateInWEETH);

        deal(address(WEETH), address(this), 1_000e18);
        WEETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WEETH, WEETHAmount, 0, referrer);
        assertEq(expectedShares, shares0); 

        //after deposit, last share price is updated
        (uint128 lastSharePrice, , , , ) = accountant.vestingState(); 
        
        uint256 totalAssetsInBase = accountant.totalAssets();
        assertEq(totalAssetsInBase, shares0.mulDivDown(lastSharePrice, 1e18)); //total supply * last share price 
    }

    //test
    function testDepositsWithYieldNonBaseAsset() external {
        uint256 WEETHAmount = 10e18;
        deal(address(WEETH), address(this), 1_000e18);
        WEETH.approve(address(boringVault), 1_000e18);

        uint256 rateInWEETH = accountant.getRateInQuote(WEETH);

        // shares = depositAmount * 1e18 / rateInWEETH
        uint256 expectedShares = WEETHAmount.mulDivDown(1e18, rateInWEETH);

        deal(address(WEETH), address(this), 1_000e18);
        WEETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WEETH, WEETHAmount, 0, referrer);
        assertEq(expectedShares, shares0); 

        //before deposit, last share price is updated
        (uint128 lastSharePrice, , , , ) = accountant.vestingState(); 
        
        uint256 totalAssetsInBaseLast = accountant.totalAssets();
        assertEq(totalAssetsInBaseLast, shares0.mulDivDown(lastSharePrice, 1e18)); //total supply * last share price 

        //vest some yield
        deal(address(WETH), address(boringVault), 10e18); //stream 10 WETH yield over 24 hours
        accountant.vestYield(10e18, 24 hours); 
        skip(12 hours); 
      
        //get pending yield
        uint256 vestedYield = accountant.getPendingVestingGains();  

        uint256 totalAssetsInBaseMid = accountant.totalAssets();
        assertApproxEqAbs(totalAssetsInBaseMid, totalAssetsInBaseLast + vestedYield, 1e4); 

        //deposit again
        uint256 shares1 = teller.deposit(WEETH, WEETHAmount, 0, referrer);

        (lastSharePrice, , , , ) = accountant.vestingState(); 

        uint256 totalAssetsInBase = accountant.totalAssets();
        assertApproxEqAbs(totalAssetsInBase, totalAssetsInBaseMid + shares1.mulDivDown(lastSharePrice, 1e18), 1e6); 
    }

    function testDepositsUpdateFirstDepositTimestamp() external {
        uint256 WEETHAmount = 10e18;
        deal(address(WEETH), address(this), 1_000e18);
        WEETH.approve(address(boringVault), 1_000e18);

        //before deposit, last share price is updated
        (, , , uint64 startVestingTimeLast, ) = accountant.vestingState(); 
        assertEq(startVestingTimeLast, block.timestamp);  
            
        skip(1 days); 

        deal(address(WEETH), address(this), 1_000e18);
        WEETH.approve(address(boringVault), 1_000e18);
        teller.deposit(WEETH, WEETHAmount, 0, referrer);
       
        (, , , uint64 startVestingTimeNow, ) = accountant.vestingState(); 
        assertEq(startVestingTimeLast + 1 days, startVestingTimeNow);  
    }


    function testWithdrawNoYieldStream() external {
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0, referrer);
        assertEq(WETHAmount, shares0); 

        //deposit 2
        teller.deposit(WETH, WETHAmount, 0, referrer);

        uint256 assetsOut0 = teller.withdraw(WETH, shares0, 0, address(boringVault));   
        assertEq(assetsOut0, WETHAmount); 
    }

    function testWithdrawWithYieldStream() external {
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0, referrer);
        assertEq(WETHAmount, shares0); 

        //==== Add Vesting Yield Stream ====
        deal(address(WETH), address(boringVault), WETHAmount);
        accountant.vestYield(WETHAmount, 24 hours); 
        skip(12 hours); 
        
        //==== BEGIN DEPOSIT 2 ====
        deal(address(WETH), alice, 1_000e18);
        vm.startPrank(alice); 
        WETH.approve(address(boringVault), type(uint256).max); 
        uint256 shares1 = teller.deposit(WETH, WETHAmount, 0, referrer);
        vm.stopPrank(); 
        
        //==== BEGIN WITHDRAW USER 1 ====
        uint256 assetsOut = teller.withdraw(WETH, shares0, 0, address(boringVault));   
        assertEq(assetsOut, 15e18); 

        //==== BEGIN WITHDRAW USER 2 ====
        vm.prank(alice); 
        assetsOut = teller.withdraw(WETH, shares1, 0, address(alice));   
        vm.assertApproxEqAbs(assetsOut, 10e18, 1); 
    }

    function testWithdrawWithYieldStreamUser2WaitsForYield() external {
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0, referrer);
        assertEq(WETHAmount, shares0); 

        //==== Add Vesting Yield Stream ====
        deal(address(WETH), address(boringVault), WETHAmount);
        accountant.vestYield(WETHAmount, 24 hours); 
        skip(12 hours); 
        
        //==== BEGIN DEPOSIT 2 ====
        deal(address(WETH), alice, 1_000e18);
        vm.startPrank(alice); 
        WETH.approve(address(boringVault), type(uint256).max); 
        uint256 shares1 = teller.deposit(WETH, WETHAmount, 0, referrer);
        vm.stopPrank(); 
        
        //==== BEGIN WITHDRAW USER 1 ====
        uint256 assetsOut = teller.withdraw(WETH, shares0, 0, address(boringVault));   
        assertEq(assetsOut, 15e18); 

        skip(12 hours); 

        //==== BEGIN WITHDRAW USER 2 ====
        vm.prank(alice); 
        assetsOut = teller.withdraw(WETH, shares1, 0, address(alice));   
        //vm.assertApproxEqAbs(assetsOut, 15e18, 10); 
        vm.assertLe(assetsOut, 15e18); 
    }

    function testVestLossAbsorbBuffer() external {
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0, referrer);
        assertEq(WETHAmount, shares0); 

        //==== Add Vesting Yield Stream ===="); 
        deal(address(WETH), address(boringVault), WETHAmount * 2);
        accountant.vestYield(WETHAmount, 24 hours); 
        skip(12 hours); 
        
        uint256 totalAssetsBeforeLoss = accountant.totalAssets(); 

        uint256 unvested = accountant.getPendingVestingGains(); //5e18

        //==== Vault Posts A Loss ====
        accountant.postLoss(2.5e18); //smaller loss than buffer (5 weth at this point)

        uint256 totalAssetsAfterLoss = accountant.totalAssets(); 
        
        //assert the vestingGains is removed from  
        (, uint128 vestingGains, , , ) = accountant.vestingState(); 
        assertEq(unvested - 2.5e18, vestingGains); 

        //total assets should remain the same as the buffer absorbed the entire loss
        assertEq(totalAssetsBeforeLoss, totalAssetsAfterLoss); 

        skip(12 hours); 
        
        uint256 assetsOut = teller.withdraw(WETH, shares0, 0, address(boringVault)); 
        assertEq(assetsOut, 17.5e18); //10 WETH deposit -> 5 weth is vested -> 2.5 loss -> remaining 2.5 vests over the next 12 hours = total of 17.5 earned
    }


    function testVestLossAffectsSharePrice() external {
        accountant.updateMaximumDeviationLoss(10_000); 

        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0, referrer);
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
        accountant.postLoss(15e18); //this moves vested yield -> share price (to protect share price)
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
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0, referrer);
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
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0, referrer);
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
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0, referrer);
        assertEq(WETHAmount, shares0); 

        deal(address(WETH), address(boringVault), WETHAmount);
        accountant.vestYield(WETHAmount, 24 hours); 

        // Skip 1 year
        skip(365 days);
        
        //update the rate
        accountant.updateExchangeRate(false);  
        
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
        teller.deposit(WETH, WETHAmount, 0, referrer);
    
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
        accountant.updateExchangeRate(false);
    
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
        accountant.updateMaximumDeviationYield(500); // 5%
    
        uint256 WETHAmount = 100e18;
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0, referrer);
        assertEq(WETHAmount, shares0);
    
        accountant.vestYield(1e18, 1 days); // 1% of vault
    
        // T=12 hours: Deposit more to change supply
        skip(12 hours);
    
        // Get supply before deposit
        uint256 supplyBefore = boringVault.totalSupply();
        assertEq(supplyBefore, 100e18, "Supply should still be 100e18");
    
        //will get fewer shares due to yield
        teller.deposit(WETH, 100e18, 0, referrer);
    
        // Get actual supply after deposit (not exactly 200e18 due to share price)
        uint256 supplyAfter = boringVault.totalSupply();
        assertApproxEqRel(supplyAfter, 199.5e18, 0.01e18, "Supply should be ~199.5e18");
    
        (uint256 cumulative,,) = accountant.supplyObservation();
        uint256 expectedCumulative = 100e18 * 12 hours; // 4.32e24
        assertEq(cumulative, expectedCumulative, "Cumulative should be 100e18 * 12 hours");
    
        skip(12 hours);
        accountant.vestYield(2e18, 1 days);
    
        // After second vestYield, cumulative should account for actual supply
        // (100e18 * 12 hours) + (supplyAfter * 12 hours)
        (cumulative,,) = accountant.supplyObservation();
        expectedCumulative = (100e18 * 12 hours) + (supplyAfter * 12 hours);
        assertApproxEqAbs(cumulative, expectedCumulative, 1e6, "Cumulative should match actual supply changes");
    
        // Verify checkpoint
        (, uint256 cumulativeSupplyLast,) = accountant.supplyObservation();
        assertEq(cumulativeSupplyLast, cumulative, "Checkpoint should equal cumulative at vest time");
    
        // Verify the TWAS was calculated correctly for the yield check
        // TWAS = cumulative / 24 hours ≈ 149.75e18 (as shown in logs)
        uint256 calculatedTWAS = cumulative / (24 hours);
        assertApproxEqRel(calculatedTWAS, 149.75e18, 0.01e18, "TWAS should be ~149.75e18");
    }

    function testTWASWorksAsExpectedWhenPostingLoss() external {
        accountant.updateMaximumDeviationYield(500); // 5%
        accountant.updateDelay(0); 
    
        uint256 WETHAmount = 100e18;
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0, referrer);
        assertEq(WETHAmount, shares0);
    
        accountant.vestYield(1e18, 1 days); // 1% of vault
    
        // T=12 hours: Deposit more to change supply
        skip(12 hours);
    
        // Get supply before deposit
        uint256 supplyBefore = boringVault.totalSupply();
        assertEq(supplyBefore, 100e18, "Supply should still be 100e18");
    
        //will get fewer shares due to yield
        teller.deposit(WETH, 100e18, 0, referrer);
    
        // Get actual supply after deposit (not exactly 200e18 due to share price)
        uint256 supplyAfter = boringVault.totalSupply();
        assertApproxEqRel(supplyAfter, 199.5e18, 0.01e18, "Supply should be ~199.5e18");
    
        (uint256 cumulativeBefore, uint256 cumulativeLastBefore,) = accountant.supplyObservation();
        uint256 expectedCumulative = 100e18 * 12 hours; // 4.32e24
        assertEq(cumulativeBefore, expectedCumulative, "Cumulative should be 100e18 * 12 hours");
        

        //now we post a loss
        //this passing means it works
        skip(12 hours);
        accountant.postLoss(2e18);

        //verify the cumulative is updated
        (uint256 cumulativeAfter, uint256 cumulativeLastAfter, uint256 timestamp) = accountant.supplyObservation();
        assertGt(cumulativeAfter, cumulativeBefore); 
        assertEq(timestamp, block.timestamp); 
        assertEq(cumulativeLastBefore, cumulativeLastAfter); 

        //now post a very large loss
        //vm.expectEmit(false, false, false, true, address(accountant));
        vm.expectEmit(address(accountant));
        emit Paused();

        accountant.postLoss(10e18);
    }

    // ========================= EDGE CASES ===============================
    
    function testDonationsShouldNotBeConsideredInCalculations() external {
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0, referrer);
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

        uint256 assetsOut = teller.withdraw(WETH, shares0, 0, address(boringVault));   
        assertEq(assetsOut, 15e18); 
    }

    function testDoubleDepositInSameBlock() external {
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0, referrer);
        assertEq(WETHAmount, shares0); 

        uint256 shares1 = teller.deposit(WETH, WETHAmount, 0, referrer);
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
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0, referrer);
        assertEq(WETHAmount, shares0); 

        //vest some yield
        deal(address(WETH), address(boringVault), WETHAmount * 2);
        accountant.vestYield(WETHAmount, 24 hours); 
        skip(12 hours); 
        
        //double deposit -> alice, bill both deposit in the same block 
        deal(address(WETH), alice, WETHAmount);
        vm.startPrank(alice);
        WETH.approve(address(boringVault), WETHAmount);
        uint256 sharesAlice = teller.deposit(WETH, WETHAmount, 0, referrer);
        vm.stopPrank();

        deal(address(WETH), bill, WETHAmount);
        vm.startPrank(bill);
        WETH.approve(address(boringVault), WETHAmount);
        uint256 sharesBill = teller.deposit(WETH, WETHAmount, 0, referrer);
        vm.stopPrank();

        //skip time
        skip(12 hours); 
        
        //alice withdraws
        vm.prank(alice); 
        uint256 assetsOutAlice = teller.withdraw(WETH, sharesAlice, 0, address(boringVault));   

        //bob withdraws
        vm.prank(bill); 
        uint256 assetsOutBill = teller.withdraw(WETH, sharesBill, 0, address(boringVault));   

        assertEq(assetsOutAlice, assetsOutBill); 
    }

    function testLoopDepositWithdrawDuringVest() external {
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0, referrer);
        assertEq(WETHAmount, shares0); 

        //vest some yield
        deal(address(WETH), address(boringVault), WETHAmount * 2);
        accountant.vestYield(WETHAmount, 24 hours); 
        skip(12 hours); 
        
        //double deposit -> alice, bill both deposit in the same block 
        deal(address(WETH), alice, WETHAmount);
        vm.startPrank(alice);
        WETH.approve(address(boringVault), WETHAmount);
        uint256 sharesAlice = teller.deposit(WETH, WETHAmount, 0, referrer);
        vm.stopPrank();

        //skip time
        //skip(12 hours); 
        
        //alice withdraws
        vm.prank(alice); 
        uint256 assetsOutAlice = teller.withdraw(WETH, sharesAlice, 0, address(boringVault));   

        deal(address(WETH), bill, WETHAmount);
        vm.startPrank(bill);
        WETH.approve(address(boringVault), WETHAmount);
        teller.deposit(WETH, WETHAmount, 0, referrer);
        vm.stopPrank();

        assertApproxEqAbs(assetsOutAlice, WETHAmount, 10); 
    }

    function testLoopDepositWithdrawDepositDuringVest() external {
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0, referrer);
        assertEq(WETHAmount, shares0); 

        //vest some yield
        deal(address(WETH), address(boringVault), WETHAmount * 2);
        accountant.vestYield(WETHAmount, 24 hours); 
        skip(12 hours); 
        
        deal(address(WETH), alice, WETHAmount);
        vm.startPrank(alice);
        WETH.approve(address(boringVault), WETHAmount);
        uint256 sharesAlice = teller.deposit(WETH, WETHAmount, 0, referrer);
        vm.stopPrank();

        //skip time
        //skip(12 hours); 
        
        //alice withdraws
        vm.prank(alice); 
        uint256 assetsOutAlice = teller.withdraw(WETH, sharesAlice, 0, address(boringVault));   

        deal(address(WETH), bill, WETHAmount);
        vm.startPrank(bill);
        WETH.approve(address(boringVault), WETHAmount);
        uint256 sharesBill = teller.deposit(WETH, WETHAmount, 0, referrer);
        vm.stopPrank();

        assertLt(assetsOutAlice, WETHAmount); 

        vm.prank(bill); 
        uint256 assetsOutBill = teller.withdraw(WETH, sharesBill, 0, address(boringVault));   
        assertApproxEqAbs(WETHAmount, assetsOutBill, 1);
    }

    function testDepositDuringSameBlockAsYieldIsDeposited() external {
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0, referrer);
        assertEq(WETHAmount, shares0); 

        //vest some yield
        deal(address(WETH), address(boringVault), WETHAmount * 2);
        accountant.vestYield(WETHAmount, 24 hours); 
        
        deal(address(WETH), alice, WETHAmount);
        vm.startPrank(alice);
        WETH.approve(address(boringVault), WETHAmount);
        uint256 sharesAlice = teller.deposit(WETH, WETHAmount, 0, referrer);
        vm.stopPrank();

        //alice withdraws
        vm.prank(alice); 
        uint256 assetsOutAlice = teller.withdraw(WETH, sharesAlice, 0, address(boringVault));   

        assertEq(assetsOutAlice, WETHAmount); //assert no dilution, no extra yield
    }

    function testRoundingIssuesAfterYieldStreamEnds() external {
        uint256 WETHAmount = 1e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0, referrer);
        assertEq(WETHAmount, shares0); 

        //vest some yield
        deal(address(WETH), address(boringVault), WETHAmount * 2);
        accountant.vestYield(70, 24 hours); 

        skip(24 hours);

        //now the state of the contract should be 
        //totalSupply > 1
        //exchange rate > 1 
        uint256 supplyBefore = boringVault.totalSupply();
        uint256 rateBefore = accountant.getRate();
        console.log("supply before:", supplyBefore);
        console.log("rate before:", rateBefore);

        uint256 depositAmount = 389998;
        uint256 shares1 = teller.deposit(WETH, depositAmount, 0, referrer);

        // Check rate AFTER deposit
        uint256 supplyAfter = boringVault.totalSupply();
        uint256 rateAfter = accountant.getRate();
        console.log("supply after:", supplyAfter);
        console.log("rate after:", rateAfter);
        //console.log("rate increased by:", rateAfter - rateBefore);

        boringVault.approve(address(teller), shares1);
        uint256 assetsOut = teller.withdraw(WETH, shares1, 0, address(this));

        console.log("deposited:", depositAmount);
        console.log("shares received:", shares1);
        console.log("assets out:", assetsOut);
        console.log("any profit:", int256(assetsOut) - int256(depositAmount));

        assertLt(assetsOut, depositAmount, "should not profit");
    }

    // ========================= REVERT TESTS / FAILURE CASES ===============================
    
    function testVestYieldCannotExceedMaximumDuration() external {
        //by default, maximum duration is 7 days
        uint256 WETHAmount = 10e18; 
        deal(address(WETH), address(this), 1_000e18);
        WETH.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0, referrer);
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
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0, referrer);
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
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0, referrer);
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
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0, referrer);
        assertEq(shares0, WETHAmount); 

        //==== BEGIN DEPOSIT 2 ====

        deal(address(WETH), address(this), WETHAmount2);
        uint256 shares1 = teller.deposit(WETH, WETHAmount2, 0, referrer);
        assertEq(shares1, WETHAmount2); 

        uint256 totalAssetsAfter = accountant.totalAssets();         
        assertEq(totalAssetsAfter, uint256(WETHAmount) + uint256(WETHAmount2)); 
    }

    function testFuzzDepositsWithYield(uint96 WETHAmount, uint96 WETHAmount2, uint96 yieldVestAmount) external {
        accountant.updateMaximumDeviationYield(5000000);
        
        vm.assume(WETHAmount >= 1e18 && WETHAmount <= 1_000_000e18);
        vm.assume(WETHAmount2 >= 1e18 && WETHAmount2 <= 1_000_000e18);
        vm.assume(yieldVestAmount >= 1e16 && yieldVestAmount <= uint256(WETHAmount) * 100);
        
        // === FIRST DEPOSIT ===
        deal(address(WETH), address(this), WETHAmount);
        WETH.approve(address(boringVault), type(uint256).max);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0, referrer);
        
        // First deposit should be 1:1 at initial rate
        assertEq(shares0, WETHAmount, "First deposit should be 1:1");
        
        // === ADD YIELD ===
        deal(address(WETH), address(boringVault), WETHAmount + yieldVestAmount);
        accountant.vestYield(yieldVestAmount, 24 hours);
        skip(12 hours); // Half vesting period
        
        // === SECOND DEPOSIT - INDEPENDENT CALCULATION ===
        
        // Calculate expected shares from first principles:
        uint256 expectedVestedYield = yieldVestAmount / 2; // Linear vesting, 12/24 hours
        assertEq(expectedVestedYield, accountant.getPendingVestingGains()); 

        uint256 totalValueInVault = WETHAmount + expectedVestedYield;
        assertEq(accountant.totalAssets(), totalValueInVault); 

        uint256 totalSharesBefore = shares0;
        assertEq(totalSharesBefore, boringVault.totalSupply()); 

        uint256 sharePrice = totalValueInVault.mulDivDown(1e18, totalSharesBefore);
        assertEq(sharePrice, accountant.getRate());  
        
        uint256 expectedShares1 = uint256(WETHAmount2).mulDivDown(1e18, sharePrice);

        //when calling deposit, the rate is updated before getting the rate 
        //rate before deposit should be totalassets * 1e18 / shares0  where totalassets == (last share price * shares0) / 1e18
        
        // === EXECUTE SECOND DEPOSIT ===
        deal(address(WETH), address(this), WETHAmount2);
        uint256 shares1 = teller.deposit(WETH, WETHAmount2, 0, referrer);
        
        //check total assets after
        uint256 totalAssetsAfter = accountant.totalAssets();
        uint256 expectedTotalAssets = WETHAmount + WETHAmount2 + expectedVestedYield;
        assertApproxEqAbs(totalAssetsAfter, expectedTotalAssets, 1e6, "Total assets mismatch");
        
        // === VERIFY ===
        assertApproxEqAbs(shares1, expectedShares1, 1e6, "Second deposit shares mismatch");
    }

    function testFuzzWithdrawWithYield(uint96 WETHAmount, uint96 WETHAmount2, uint96 yieldVestAmount) external {
        accountant.updateMaximumDeviationYield(5000000);
        
        vm.assume(WETHAmount >= 1e18 && WETHAmount <= 1_000_000e18);
        vm.assume(WETHAmount2 >= 1e18 && WETHAmount2 <= 1_000_000e18);
        vm.assume(yieldVestAmount >= 1e16 && yieldVestAmount <= uint256(WETHAmount) * 100);
        
        // === FIRST DEPOSIT ===
        deal(address(WETH), address(this), WETHAmount);
        WETH.approve(address(boringVault), type(uint256).max);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0, referrer);
        assertEq(shares0, WETHAmount, "First deposit should be 1:1");
        
        // === ADD YIELD ===
        deal(address(WETH), address(boringVault), WETHAmount + yieldVestAmount);
        accountant.vestYield(yieldVestAmount, 24 hours);
        skip(12 hours); // Half vesting period
        
        // === SECOND DEPOSIT ===
        uint256 expectedVestedYield = yieldVestAmount / 2;
        deal(address(WETH), address(this), WETHAmount2);
        uint256 shares1 = teller.deposit(WETH, WETHAmount2, 0, referrer);
        
        // === CHECK WITHDRAW AMOUNTS ===
        
        // Get current rate after deposits and vesting
        uint256 currentRate = accountant.getRate();
        
        // Test 1: First depositor withdraws half their shares
        uint256 sharesToWithdraw0 = shares0 / 2;
        uint256 expectedWithdrawAmount0 = sharesToWithdraw0.mulDivDown(currentRate, 1e18);
        
        // Approve shares for withdrawal
        boringVault.approve(address(teller), sharesToWithdraw0);
        uint256 actualWithdrawn0 = teller.withdraw(WETH, sharesToWithdraw0, 0, address(this));
        
        assertApproxEqAbs(
            actualWithdrawn0, 
            expectedWithdrawAmount0, 
            1e6, 
            "First depositor withdraw amount mismatch"
        );
        
        // Verify first depositor got their principal + share of yield
        uint256 firstDepositorExpectedValue = (WETHAmount + expectedVestedYield) / 2; // They withdraw half
        assertApproxEqAbs(
            actualWithdrawn0,
            firstDepositorExpectedValue,
            1e6,
            "First depositor should get principal + yield share"
        );
        
        // Test 2: Second depositor withdraws all their shares
        vm.startPrank(address(this)); // Ensure we're the owner of shares1
        boringVault.approve(address(teller), shares1);
        uint256 expectedWithdrawAmount1 = shares1.mulDivDown(currentRate, 1e18);
        uint256 actualWithdrawn1 = teller.withdraw(WETH, shares1, 0, address(this));
        vm.stopPrank();
        
        assertApproxEqAbs(
            actualWithdrawn1,
            expectedWithdrawAmount1,
            1e6,
            "Second depositor withdraw amount mismatch"
        );
        
        // Second depositor should get back approximately what they deposited (no yield share)
        assertApproxEqAbs(
            actualWithdrawn1,
            WETHAmount2,
            1e6,
            "Second depositor should get back their deposit"
        );
        
       // // === VERIFY INVARIANTS ===
       // 
       // // Total withdrawn should not exceed total assets
       // uint256 totalWithdrawn = actualWithdrawn0 + actualWithdrawn1;
       // uint256 totalDeposited = WETHAmount + WETHAmount2;
       // 
       // assert(totalWithdrawn <= totalDeposited + expectedVestedYield);
       // 
       // // Check remaining shares and assets are consistent
       // uint256 remainingShares = boringVault.totalSupply();
       // uint256 expectedRemainingShares = shares0 - sharesToWithdraw0; // shares1 fully withdrawn
       // assertEq(remainingShares, expectedRemainingShares, "Remaining shares mismatch");
       // 
       // // Remaining assets should match remaining shares at current rate
       // uint256 remainingAssets = accountant.totalAssets();
       // uint256 expectedRemainingAssets = remainingShares.mulDivDown(currentRate, 1e18);
       // assertApproxEqAbs(
       //     remainingAssets,
       //     expectedRemainingAssets,
       //     1e6,
       //     "Remaining assets should match remaining shares value"
       // );
       // 
       // // === TEST EDGE CASE: Try to withdraw more than balance ===
       // vm.expectRevert(); // Should revert due to insufficient shares
       // teller.withdraw(WETH, shares0, 0, address(this)); // Try to withdraw all of shares0 (but we only have half left)
    }

    function testRoundingAfterYieldStreamEndsFuzz(uint96 WETHAmount, uint96 secondDepositAmount) external {
        WETHAmount = uint96(bound(WETHAmount, 1, 1e6));
        secondDepositAmount = uint96(bound(secondDepositAmount, 1e1, 1e11)); 
        //vm.assume(secondDepositAmount > 1e1 && secondDepositAmount <= 1e11); 
        deal(address(WETH), address(this), WETHAmount);
        WETH.approve(address(boringVault), type(uint256).max);
        uint256 shares0 = teller.deposit(WETH, WETHAmount, 0, referrer);
        //assertEq(WETHAmount, shares0); 

        // Use a yield that's safely under the limit (e.g., 5%)
        uint256 yieldAmount = uint256(WETHAmount) * 500 / 10_000;

        // Ensure yield is at least 1 to be meaningful
        vm.assume(yieldAmount > 0);

        //vest some yield
        deal(address(WETH), address(boringVault), secondDepositAmount * 2);
        accountant.vestYield(yieldAmount, 24 hours); 

        skip(24 hours);

        accountant.updateExchangeRate(false);

        //now the state of the contract should be 
        //totalSupply > 1
        //exchange rate > 1 

        // Second Depositor deposits
        deal(address(WETH), address(this), secondDepositAmount);
        uint256 secondDepositorShares = teller.deposit(WETH, secondDepositAmount, 0, referrer);

        // Check rate AFTER deposit

        // Second Depositor immediately withdraws
        boringVault.approve(address(teller), secondDepositorShares);
        uint256 assetsOut = teller.withdraw(WETH, secondDepositorShares, 0, address(this));

        // this is the bug - user gets more out than they put in
        assertLe(assetsOut, secondDepositAmount, "Second depositor should not profit");
    }


    // ========================================= HELPER FUNCTIONS =========================================
    
    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
