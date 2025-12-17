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
    ERC20 internal USDC;
    ERC20 internal USDE;

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
    address public referrer = vm.addr(1337);

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 23039901;
        _startFork(rpcKey, blockNumber);

        USDC = getERC20(sourceChain, "USDC");
        USDE = getERC20(sourceChain, "USDE");

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 6);
        accountant = new AccountantWithYieldStreaming(
            address(this), address(boringVault), payoutAddress, 1e6, address(USDC), 1.001e4, 0.999e4, 1, 0.1e4, 0.1e4
        );
        teller =
            new TellerWithYieldStreaming(address(this), address(boringVault), address(accountant), getAddress(sourceChain, "USDC"));

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
            STRATEGIST_ROLE, address(accountant), bytes4(keccak256("updateExchangeRate()")), true
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
        //deal(address(USDC), address(this), 1_000e6);
        //USDC.safeApprove(address(boringVault), 1_000e6);
        //boringVault.enter(address(this), USDC, 1_000e6, address(address(this)), 1_000e6);

        accountant.setRateProviderData(USDE, true, address(0));
        //accountant.setRateProviderData(WEETH, false, address(WEETH_RATE_PROVIDER));
       
        teller.updateAssetData(USDC, true, true, 0);
        teller.updateAssetData(USDE, true, true, 0);

        accountant.updateMaximumDeviationYield(50000); //500% allowable (for testing)
    }

    //test
    function testDepositsWithNoYield() external {
        uint256 USDCAmount = 10e6; 
        deal(address(USDC), address(this), 1_000e6);
        USDC.approve(address(boringVault), 1_000e6);
        uint256 shares0 = teller.deposit(USDC, USDCAmount, 0, referrer);
        assertGt(USDCAmount, shares0); 
        
        uint256 totalAssetsBefore = accountant.totalAssets();         

        //==== BEGIN DEPOSIT 2 ====

        //deposit 2
        uint256 shares1 = teller.deposit(USDC, USDCAmount, 0, referrer);
        assertEq(shares1, USDCAmount - 10); 

        uint256 totalAssetsAfter = accountant.totalAssets();         
        assertGt(totalAssetsAfter, totalAssetsBefore); 
    }

    function testDepositsWithYield() external {
        uint256 USDCAmount = 10e6; 
        deal(address(USDC), address(this), 1_000e6);
        USDC.approve(address(boringVault), 1_000e6);
        uint256 shares0 = teller.deposit(USDC, USDCAmount, 0, referrer);
        assertGt(USDCAmount, shares0); 

        //vest some yield
        deal(address(USDC), address(boringVault), USDCAmount);
        accountant.vestYield(USDCAmount, 24 hours); 
        skip(12 hours); 

        //==== BEGIN DEPOSIT 2 ====
        uint256 shares1 = teller.deposit(USDC, USDCAmount, 0, referrer);
        vm.assertApproxEqAbs(shares1, 6666666, 10); //
        assertLe(shares1, 6666666);

        //total of 2 deposits to 10 weth each + 5 vested yield 
        
        uint256 totalAssets = accountant.totalAssets(); 
        vm.assertApproxEqAbs(totalAssets, 25e6, 1e3); 
        assertLe(totalAssets, 25e6); 
    }

    function testDepositsWithYieldGreaterDecimals() external {
        uint256 USDEAmount = 10e18; 
        deal(address(USDE), address(this), 1_000e18);
        USDE.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(USDE, USDEAmount, 0, referrer);
        assertApproxEqAbs(10e6, shares0, 1e1); 
        assertLe(shares0, 10e6); 

        //vest some yield
        deal(address(USDE), address(boringVault), USDEAmount);
        accountant.vestYield(USDEAmount * 1e6 / 1e18, 24 hours); 
        skip(12 hours); 

        //==== BEGIN DEPOSIT 2 ====
        uint256 shares1 = teller.deposit(USDE, USDEAmount, 0, referrer);
        vm.assertApproxEqAbs(shares1, 6666666, 10); //
        assertLe(shares1, 6666666); 

        //total of 2 deposits to 10 weth each + 5 vested yield 
        
        uint256 totalAssets = accountant.totalAssets(); 
        vm.assertApproxEqAbs(totalAssets, 25e6, 5); 
        assertLe(totalAssets, 25e6); 
    }

    function testWithdrawNoYieldStream() external {
        uint256 USDCAmount = 10e6; 
        deal(address(USDC), address(this), 1_000e6);
        USDC.approve(address(boringVault), 1_000e6);
        uint256 shares0 = teller.deposit(USDC, USDCAmount, 0, referrer);
        assertGt(USDCAmount, shares0); 

        //deposit 2
        teller.deposit(USDC, USDCAmount, 0, referrer);

        uint256 assetsOut0 = teller.withdraw(USDC, shares0, 0, address(boringVault));   
        assertApproxEqAbs(assetsOut0, USDCAmount, 1e3); 
        assertLe(assetsOut0, USDCAmount); 
    }

    function testWithdrawWithYieldStream() external {
        uint256 USDCAmount = 10e6; 
        deal(address(USDC), address(this), 1_000e6);
        USDC.approve(address(boringVault), 1_000e6);
        uint256 shares0 = teller.deposit(USDC, USDCAmount, 0, referrer);
        assertGt(USDCAmount, shares0); 

        //==== Add Vesting Yield Stream ====
        deal(address(USDC), address(boringVault), USDCAmount);
        accountant.vestYield(USDCAmount, 24 hours); 
        skip(12 hours); 
        
        //==== BEGIN DEPOSIT 2 ====
        deal(address(USDC), alice, 1_000e6);
        vm.startPrank(alice); 
        USDC.approve(address(boringVault), type(uint256).max); 
        uint256 shares1 = teller.deposit(USDC, USDCAmount, 0, referrer);
        vm.stopPrank(); 
        
        //==== BEGIN WITHDRAW USER 1 ====
        uint256 assetsOut = teller.withdraw(USDC, shares0, 0, address(boringVault));   
        assertApproxEqAbs(assetsOut, 15e6, 1e2); 
        assertLe(assetsOut, 15e6); 

        //==== BEGIN WITHDRAW USER 2 ====
        vm.prank(alice); 
        assetsOut = teller.withdraw(USDC, shares1, 0, address(alice));   
        vm.assertApproxEqAbs(assetsOut, 10e6, 1e2); 
        assertLe(assetsOut, 10e6); 
    }

    function testWithdrawWithYieldStreamGreaterDecimals() external {
        uint256 USDEAmount = 10e18; 
        deal(address(USDE), address(this), 1_000e18);
        USDE.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(USDE, USDEAmount, 0, referrer);
        assertGt(10e6, shares0); 

        //==== Add Vesting Yield Stream ====
        deal(address(USDE), address(boringVault), USDEAmount);
        accountant.vestYield(10e6, 24 hours); 
        skip(12 hours); 
        
        //==== BEGIN DEPOSIT 2 ====
        deal(address(USDE), alice, 1_000e18);
        vm.startPrank(alice); 
        USDE.approve(address(boringVault), type(uint256).max); 
        uint256 shares1 = teller.deposit(USDE, USDEAmount, 0, referrer);
        vm.stopPrank(); 
        
        //==== BEGIN WITHDRAW USER 1 ====
        uint256 assetsOut = teller.withdraw(USDE, shares0, 0, address(boringVault));   
        assertApproxEqAbs(assetsOut, 15e18, 1e13); //account for higher decimals
        assertLe(assetsOut, 15e18); 

        //==== BEGIN WITHDRAW USER 2 ====
        vm.prank(alice); 
        assetsOut = teller.withdraw(USDE, shares1, 0, address(alice));   
        vm.assertApproxEqAbs(assetsOut, 10e18, 1e13); 
        assertLe(assetsOut, 10e18); 
    }

    function testWithdrawWithYieldStreamUser2WaitsForYield() external {
        uint256 USDCAmount = 10e6; 
        deal(address(USDC), address(this), 1_000e6);
        USDC.approve(address(boringVault), 1_000e6);
        uint256 shares0 = teller.deposit(USDC, USDCAmount, 0, referrer);
        assertGt(USDCAmount, shares0); 

        //==== Add Vesting Yield Stream ====
        deal(address(USDC), address(boringVault), USDCAmount);
        accountant.vestYield(USDCAmount, 24 hours); 
        skip(12 hours); 
        
        //==== BEGIN DEPOSIT 2 ====
        deal(address(USDC), alice, 1_000e6);
        vm.startPrank(alice); 
        USDC.approve(address(boringVault), type(uint256).max); 
        uint256 shares1 = teller.deposit(USDC, USDCAmount, 0, referrer);
        vm.stopPrank(); 
        
        //==== BEGIN WITHDRAW USER 1 ====
        uint256 assetsOut = teller.withdraw(USDC, shares0, 0, address(boringVault));   
        assertApproxEqAbs(assetsOut, 15e6, 1e2); 
        assertLe(assetsOut, 15e6); 

        skip(12 hours); 

        //==== BEGIN WITHDRAW USER 2 ====
        vm.prank(alice); 
        assetsOut = teller.withdraw(USDC, shares1, 0, address(alice));   
        vm.assertApproxEqAbs(assetsOut, 15e6, 1e3); 
        assertLe(assetsOut, 15e6); 
    }

    function testVestLossAbsorbBuffer() external {
        accountant.updateMaximumDeviationLoss(10_000); 
        uint256 USDCAmount = 10e6; 
        deal(address(USDC), address(this), 1_000e6);
        USDC.approve(address(boringVault), 1_000e6);
        uint256 shares0 = teller.deposit(USDC, USDCAmount, 0, referrer);
        assertGt(USDCAmount, shares0); 

        //==== Add Vesting Yield Stream ===="); 
        deal(address(USDC), address(boringVault), USDCAmount * 2);
        accountant.vestYield(USDCAmount, 24 hours); 
        skip(12 hours); 
        
        uint256 totalAssetsBeforeLoss = accountant.totalAssets(); 

        uint256 unvested = accountant.getPendingVestingGains(); //5e6

        //==== Vault Posts A Loss ====
        accountant.postLoss(2.5e6); //smaller loss than buffer (5 weth at this point)

        uint256 totalAssetsAfterLoss = accountant.totalAssets(); 
        
        //assert the vestingGains is removed from  
        (, uint128 vestingGains, , , ) = accountant.vestingState(); 
        assertEq(unvested - 2.5e6, vestingGains); 

        //total assets should remain the same as the buffer absorbed the entire loss
        assertApproxEqAbs(totalAssetsBeforeLoss, totalAssetsAfterLoss, 1e2); //should be a minor difference between the due due to rounding
        assertGt(totalAssetsBeforeLoss, totalAssetsAfterLoss); //make sure the rounding is the correct direction 

        skip(12 hours); 
        
        uint256 assetsOut = teller.withdraw(USDC, shares0, 0, address(boringVault)); 
        assertApproxEqAbs(assetsOut, 17.5e6, 1e2); //10 USDC deposit -> 5 usdc is vested -> 2.5 loss -> remaining 2.5 vests over the next 12 hours = total of 17.5 earned
        assertLe(assetsOut, 17.5e6); 
    }


    function testVestLossAffectsSharePrice() external {
        accountant.updateMaximumDeviationLoss(10_000); 
        uint256 USDCAmount = 10e6; 
        deal(address(USDC), address(this), 1_000e6);
        USDC.approve(address(boringVault), 1_000e6);
        uint256 shares0 = teller.deposit(USDC, USDCAmount, 0, referrer);
        assertGt(USDCAmount, shares0); 

        //vault total = 10

        //==== Add Vesting Yield Stream ====
        deal(address(USDC), address(boringVault), USDCAmount);
        accountant.vestYield(USDCAmount, 24 hours); 
        skip(12 hours); 

        //total assets = 15

        uint256 totalAssetsInBaseBefore = accountant.totalAssets();  
        assertApproxEqAbs(totalAssetsInBaseBefore, 15e6, 1e2); 
        assertLe(totalAssetsInBaseBefore, 15e6); 
        
        (uint128 lastSharePrice, , , , ) = accountant.vestingState(); 
        uint256 sharePriceInitial = lastSharePrice; 

        //15 total assets as this point
        
        //==== Vault Posts A Loss ====
        accountant.postLoss(15e6); //this moves vested yield -> share price (to protect share price)
        //note: the buffer absorbs the loss, so we're left with 5 remaining (the vested yield)
        
        //15 - 15 with (5 unvested remaining) = 5 left

        uint256 totalAssetsInBaseAfter = accountant.totalAssets();  
        
        //vesting gains should be 0
        (, uint128 vestingGains, , , ) = accountant.vestingState(); 
        assertEq(0, vestingGains); 

        //total assets should be 5e6 -> 10 initial, 5 yield, 5 unvested -> 15 weth loss (5 from buffer) -> 15 - 10 = 5 totalAssets remaining
        assertApproxEqAbs(totalAssetsInBaseAfter, 5e6, 1e2); 
        assertLe(totalAssetsInBaseAfter, 5e6); //maybe slightly higher due to rounding?

        skip(12 hours); 
        
        //TA should be same as remaining yield has been wiped
        uint256 totalAssetsInBaseAfterVest = accountant.totalAssets();  
        assertEq(totalAssetsInBaseAfter, totalAssetsInBaseAfterVest); //should be the same, as the remaining yield was wiped

        //check that the share price was affected
        
        (uint128 sharePriceAfter, , , , ) = accountant.vestingState(); 
        assertLt(sharePriceAfter, sharePriceInitial, "share price should be less after loss exceeds buffer"); 

        //console.log("difference: ", sharePriceInitial - sharePriceAfter); //diff = 50% 
        assertApproxEqAbs(sharePriceInitial / 2, sharePriceAfter, 1e1); 
        assertLe(sharePriceAfter, sharePriceInitial / 2); //should be slightly less due to rounding
    }

    function testGetPendingVestingGains() external {
        uint256 USDCAmount = 10e6; 
        deal(address(USDC), address(this), 1_000e6);
        USDC.approve(address(boringVault), 1_000e6);
        uint256 shares0 = teller.deposit(USDC, USDCAmount, 0, referrer);
        assertGt(USDCAmount, shares0); 

        //vault total = 10

        deal(address(USDC), address(boringVault), USDCAmount);
        accountant.vestYield(USDCAmount, 24 hours); 
        skip(6 hours); 
       
        //total should be 10 + (10 / 4) = 2.5

        uint256 totalAssets = accountant.totalAssets();  
        assertApproxEqAbs(totalAssets, 12.5e6, 1e2); 
        assertLe(totalAssets, 12.5e6); 
    }

    function testYieldStreamUpdateDuringExistingStream() external {
        uint256 USDCAmount = 10e6; 
        deal(address(USDC), address(this), 1_000e6);
        USDC.approve(address(boringVault), 1_000e6);
        uint256 shares0 = teller.deposit(USDC, USDCAmount, 0, referrer);
        assertLe(shares0, USDCAmount); 

        deal(address(USDC), address(boringVault), USDCAmount);
        accountant.vestYield(USDCAmount, 24 hours); 
        skip(12 hours); 


        accountant.updateMinimumVestDuration(6 hours); 

        //total assets = 15

        uint256 unvested = accountant.getPendingVestingGains(); 

        //unvested = 5
        
        //strategist posts another yield update, halfway through the remaining update 
        //recall that the strategist MUST account for unvested yield in the update if they wish to include it in the next update
        deal(address(USDC), address(boringVault), USDCAmount * 3); //total should now be 30
        accountant.vestYield(USDCAmount + unvested, 24 hours); //total of 15 to post
        skip(12 hours); 

        //15 + 7.5 = 22.5
        uint256 totalAssets = accountant.totalAssets();  
        assertApproxEqAbs(totalAssets, 22.5e6, 1e3); 
        assertLe(totalAssets, 22.5e6); 
        
        (, uint128 gains, uint128 lastVestingUpdate, uint64 startVestingTime, uint64 endVestingTime) = accountant.vestingState(); 
        assertEq(gains, 15e6); 
        
        uint256 lastUpdate = lastVestingUpdate; 
        assertEq(lastUpdate, block.timestamp - 12 hours); 
        
        uint256 startTime = startVestingTime; 
        assertEq(startTime, block.timestamp - 12 hours); 

        uint256 endTime = endVestingTime; 
        assertEq((block.timestamp - 12 hours) + 24 hours, endTime); 
    }


    function testPlatformFees() external {
        uint256 platformFeeRate = 0.1e4; // 10%

        uint256 USDCAmount = 10e6; 
        deal(address(USDC), address(this), 1_000e6);
        USDC.approve(address(boringVault), 1_000e6);
        uint256 shares0 = teller.deposit(USDC, USDCAmount, 0, referrer);
        assertGt(USDCAmount, shares0); 

        deal(address(USDC), address(boringVault), USDCAmount);
        accountant.vestYield(USDCAmount, 24 hours); 

        // Skip 1 year
        skip(365 days);
        
        //update the rate
        accountant.updateExchangeRate();  
        
        //check the fees owned 
        (,, uint128 feesOwedInBase,,,,,,,,,) = accountant.accountantState();
        uint256 expectedFees = (USDCAmount * 2) * platformFeeRate / 1e4; // 20 USDC (10 over day 1, 20 over 364 days for total of 2)
        assertApproxEqAbs(feesOwedInBase, expectedFees, 1e3);

        //claim fees
        vm.startPrank(address(boringVault));
        USDC.approve(address(accountant), feesOwedInBase);
        accountant.claimFees(USDC);
        vm.stopPrank();
        
        //verify we got paid
        assertApproxEqAbs(USDC.balanceOf(payoutAddress), expectedFees, 1e3);
        assertLe(USDC.balanceOf(payoutAddress), expectedFees);
    }
    
    function testPerformanceFeesAfterYield() external {
        uint256 performanceFeeRate = 0.1e4; // 10%
    
        uint256 USDCAmount = 10e6;
        deal(address(USDC), address(this), 1_000e6);
        USDC.approve(address(boringVault), 1_000e6);
        teller.deposit(USDC, USDCAmount, 0, referrer);
    
        // Record initial state
        (, uint96 initialHighwaterMark, ,,,,,,,,,) = accountant.accountantState();
        (uint128 initialSharePrice,,,,) = accountant.vestingState(); 
        //uint256 initialSharePrice = uint256(lastSharePrice); 
        uint256 totalShares = boringVault.totalSupply();
    
        deal(address(USDC), address(boringVault), USDCAmount);
        accountant.vestYield(USDCAmount, 24 hours);
    
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
        uint256 valueAppreciation = (sharePriceIncrease * totalShares) / 1e6;
    
        // Expected fees = 10% of appreciation
        uint256 expectedPerformanceFees = (valueAppreciation * performanceFeeRate) / 1e4;
        uint256 actualFees = feesOwedInBase;

        uint128 platformFee = 2739; //1 day of platform fees (10 USDC / 365)
    
        // Allow for small rounding difference
        assertEq(actualFees - platformFee, expectedPerformanceFees, "Performance fees should match share price appreciation");
    
        // Verify high water mark updated
        assertGt(nextHighwaterMark, initialHighwaterMark, "HWM should increase");
        assertEq(uint256(nextHighwaterMark), finalSharePrice, "HWM should equal new share price");
    }

    function testDepositsWithNoYieldGreaterDecimals() external {
        uint256 USDEAmount = 10e18; 
        deal(address(USDE), address(this), 1_000e18);
        USDE.approve(address(boringVault), 1_000e18);
        uint256 shares0 = teller.deposit(USDE, USDEAmount, 0, referrer);
        //we expect this to be converted to proper decimals
        assertApproxEqAbs(10e6, shares0, 1e2); 
        assertLe(shares0, 10e6); 
        
        uint256 totalAssetsBefore = accountant.totalAssets();         

        //==== BEGIN DEPOSIT 2 ====

        //deposit 2
        uint256 shares1 = teller.deposit(USDE, USDEAmount, 0, referrer);
        assertApproxEqAbs(shares1, 10e6, 1e2); 
        assertLe(shares1, 10e6); 
        
        //ensure the total assets increases
        uint256 totalAssetsAfter = accountant.totalAssets();         
        assertGt(totalAssetsAfter, totalAssetsBefore); 
    }
        
    // ========================= EDGE CASES ===============================
    
    function testDonationsShouldNotBeConsideredInCalculations() external {
        uint256 USDCAmount = 10e6; 
        deal(address(USDC), address(this), 1_000e6);
        USDC.approve(address(boringVault), 1_000e6);
        uint256 shares0 = teller.deposit(USDC, USDCAmount, 0, referrer);
        assertGt(USDCAmount, shares0); 

        //vest some yield
        deal(address(USDC), address(boringVault), USDCAmount * 2);
        accountant.vestYield(USDCAmount, 24 hours); 
        skip(12 hours); 
        
        deal(address(USDC), alice, 10e6); 
        vm.prank(alice);
        USDC.transfer(address(boringVault), 10e6); 

        //deposit 2 uint256 shares1 = teller.deposit(USDC, USDCAmount, 0);
        uint256 totalAssets = accountant.totalAssets(); 
        vm.assertApproxEqAbs(totalAssets, 15e6, 1e2); 
        assertLe(totalAssets, 15e6); 

        uint256 assetsOut = teller.withdraw(USDC, shares0, 0, address(boringVault));   
        assertApproxEqAbs(assetsOut, 15e6, 1e2); 
        assertLe(totalAssets, 15e6); 
    }

    function testDoubleDepositInSameBlock() external {
        uint256 USDCAmount = 10e6; 
        deal(address(USDC), address(this), 1_000e6);
        USDC.approve(address(boringVault), 1_000e6);
        uint256 shares0 = teller.deposit(USDC, USDCAmount, 0, referrer);
        assertGt(USDCAmount, shares0); 

        uint256 shares1 = teller.deposit(USDC, USDCAmount, 0, referrer);
        assertApproxEqAbs(USDCAmount, shares1, 1e2); 
        assertLe(shares1, USDCAmount); 
        
        uint256 currentShares = boringVault.totalSupply(); 
        (uint128 lsp, , , ,) = accountant.vestingState(); 
        uint256 lastSharePrice = uint256(lsp); 
        uint256 totalAssetsInBase = ((currentShares * lastSharePrice) / 1e6) + accountant.getPendingVestingGains(); 
        assertApproxEqAbs(totalAssetsInBase, 20e6, 1e2); 
        assertLe(totalAssetsInBase, 20e6); 
    }

    function testDoubleDepositInSameBlockAfterYieldEvent() external {
        uint256 USDCAmount = 10e6; 
        deal(address(USDC), address(this), 1_000e6);
        USDC.approve(address(boringVault), 1_000e6);
        uint256 shares0 = teller.deposit(USDC, USDCAmount, 0, referrer);
        assertGt(USDCAmount, shares0); 

        //vest some yield
        deal(address(USDC), address(boringVault), USDCAmount * 2);
        accountant.vestYield(USDCAmount, 24 hours); 
        skip(12 hours); 
        
        //double deposit -> alice, bill both deposit in the same block 
        deal(address(USDC), alice, USDCAmount);
        vm.startPrank(alice);
        USDC.approve(address(boringVault), USDCAmount);
        uint256 sharesAlice = teller.deposit(USDC, USDCAmount, 0, referrer);
        vm.stopPrank();

        deal(address(USDC), bill, USDCAmount);
        vm.startPrank(bill);
        USDC.approve(address(boringVault), USDCAmount);
        uint256 sharesBill = teller.deposit(USDC, USDCAmount, 0, referrer);
        vm.stopPrank();

        //skip time
        skip(12 hours); 
        
        //alice withdraws
        vm.prank(alice); 
        uint256 assetsOutAlice = teller.withdraw(USDC, sharesAlice, 0, address(boringVault));   

        //bob withdraws
        vm.prank(bill); 
        uint256 assetsOutBill = teller.withdraw(USDC, sharesBill, 0, address(boringVault));   

        assertEq(assetsOutAlice, assetsOutBill); 
    }

    function testLoopDepositWithdrawDuringVest() external {
        uint256 USDCAmount = 10e6; 
        deal(address(USDC), address(this), 1_000e6);
        USDC.approve(address(boringVault), 1_000e6);
        uint256 shares0 = teller.deposit(USDC, USDCAmount, 0, referrer);
        assertGt(USDCAmount, shares0); 

        //vest some yield
        deal(address(USDC), address(boringVault), USDCAmount * 2);
        accountant.vestYield(USDCAmount, 24 hours); 
        skip(12 hours); 
        
        //double deposit -> alice, bill both deposit in the same block 
        deal(address(USDC), alice, USDCAmount);
        vm.startPrank(alice);
        USDC.approve(address(boringVault), USDCAmount);
        uint256 sharesAlice = teller.deposit(USDC, USDCAmount, 0, referrer);
        vm.stopPrank();

        //skip time
        //skip(12 hours); 
        
        //alice withdraws
        vm.prank(alice); 
        uint256 assetsOutAlice = teller.withdraw(USDC, sharesAlice, 0, address(boringVault));   

        deal(address(USDC), bill, USDCAmount);
        vm.startPrank(bill);
        USDC.approve(address(boringVault), USDCAmount);
        teller.deposit(USDC, USDCAmount, 0, referrer);
        vm.stopPrank();

        assertApproxEqAbs(assetsOutAlice, USDCAmount, 10); 
        assertLe(assetsOutAlice, USDCAmount); 
    }

    function testLoopDepositWithdrawDepositDuringVest() external {
        uint256 USDCAmount = 10e6; 
        deal(address(USDC), address(this), 1_000e6);
        USDC.approve(address(boringVault), 1_000e6);
        uint256 shares0 = teller.deposit(USDC, USDCAmount, 0, referrer);
        assertGt(USDCAmount, shares0); 

        //vest some yield
        deal(address(USDC), address(boringVault), USDCAmount * 2);
        accountant.vestYield(USDCAmount, 24 hours); 
        skip(12 hours); 
        
        deal(address(USDC), alice, USDCAmount);
        vm.startPrank(alice);
        USDC.approve(address(boringVault), USDCAmount);
        uint256 sharesAlice = teller.deposit(USDC, USDCAmount, 0, referrer);
        vm.stopPrank();

        //skip time
        //skip(12 hours); 
        
        //alice withdraws
        vm.prank(alice); 
        uint256 assetsOutAlice = teller.withdraw(USDC, sharesAlice, 0, address(boringVault));   

        deal(address(USDC), bill, USDCAmount);
        vm.startPrank(bill);
        USDC.approve(address(boringVault), USDCAmount);
        uint256 sharesBill = teller.deposit(USDC, USDCAmount, 0, referrer);
        vm.stopPrank();

        assertLt(assetsOutAlice, USDCAmount); 

        vm.prank(bill); 
        uint256 assetsOutBill = teller.withdraw(USDC, sharesBill, 0, address(boringVault));   
        assertApproxEqAbs(USDCAmount, assetsOutBill, 1e2);
        assertLe(assetsOutBill, USDCAmount);
    }

    function testDepositDuringSameBlockAsYieldIsDeposited() external {
        uint256 USDCAmount = 10e6; 
        deal(address(USDC), address(this), 1_000e6);
        USDC.approve(address(boringVault), 1_000e6);
        uint256 shares0 = teller.deposit(USDC, USDCAmount, 0, referrer);
        assertGt(USDCAmount, shares0); 

        //vest some yield
        deal(address(USDC), address(boringVault), USDCAmount * 2);
        accountant.vestYield(USDCAmount, 24 hours); 
        
        deal(address(USDC), alice, USDCAmount);
        vm.startPrank(alice);
        USDC.approve(address(boringVault), USDCAmount);
        uint256 sharesAlice = teller.deposit(USDC, USDCAmount, 0, referrer);
        vm.stopPrank();

        //alice withdraws
        vm.prank(alice); 
        uint256 assetsOutAlice = teller.withdraw(USDC, sharesAlice, 0, address(boringVault));   

        assertLe(assetsOutAlice, USDCAmount); //assert slight dilution, no extra yield
    }

    function testRoundingIssuesAfterYieldStreamEndsNoFuzz() external {
        uint256 USDCAmount = 1e6; 
        deal(address(USDC), address(this), 1_000e6);
        USDC.approve(address(boringVault), 1_000e6);
        uint256 shares0 = teller.deposit(USDC, USDCAmount, 0, referrer);
        assertGt(USDCAmount, shares0); 

        //vest some yield
        deal(address(USDC), address(boringVault), USDCAmount * 2);
        accountant.vestYield(1, 24 hours); 

        skip(24 hours);

        accountant.updateExchangeRate();

        //now the state of the contract should be 
        //totalSupply > 1
        //exchange rate > 1 
        uint256 supplyBefore = boringVault.totalSupply();
        uint256 rateBefore = accountant.getRate();

        uint256 depositAmount = 389998;
        uint256 shares1 = teller.deposit(USDC, depositAmount, 0, referrer);

        // Check rate AFTER deposit
        uint256 supplyAfter = boringVault.totalSupply();
        uint256 rateAfter = accountant.getRate();
        console.logInt(int256(rateAfter) - int256(rateBefore));

        uint256 assetsOut = teller.withdraw(USDC, shares1, 0, address(this));

        assertLt(assetsOut, depositAmount, "should not profit");
    }

    // ========================= REVERT TESTS / FAILURE CASES ===============================
    
    function testVestYieldCannotExceedMaximumDuration() external {
        //by default, maximum duration is 7 days
        uint256 USDCAmount = 10e6; 
        deal(address(USDC), address(this), 1_000e6);
        USDC.approve(address(boringVault), 1_000e6);
        uint256 shares0 = teller.deposit(USDC, USDCAmount, 0, referrer);
        assertGt(USDCAmount, shares0); 

        //vest some yield
        deal(address(USDC), address(boringVault), USDCAmount * 2);
        vm.expectRevert(AccountantWithYieldStreaming.AccountantWithYieldStreaming__DurationExceedsMaximum.selector); 
        accountant.vestYield(USDCAmount, 7 days + 1 hours); 
    }

    function testVestYieldUnderMinimumDuration() external {
        //by default, maximum duration is 7 days
        uint256 USDCAmount = 10e6; 
        deal(address(USDC), address(this), 1_000e6);
        USDC.approve(address(boringVault), 1_000e6);
        uint256 shares0 = teller.deposit(USDC, USDCAmount, 0, referrer);
        assertGt(USDCAmount, shares0); 

        //vest some yield
        deal(address(USDC), address(boringVault), USDCAmount * 2);
        vm.expectRevert(AccountantWithYieldStreaming.AccountantWithYieldStreaming__DurationUnderMinimum.selector); 
        accountant.vestYield(USDCAmount, 23 hours); 
    }

    function testVestYieldZeroAmount() external {
        //by default, maximum duration is 7 days
        uint256 USDCAmount = 10e6; 
        deal(address(USDC), address(this), 1_000e6);
        USDC.approve(address(boringVault), 1_000e6);
        uint256 shares0 = teller.deposit(USDC, USDCAmount, 0, referrer);
        assertGt(USDCAmount, shares0); 

        //vest some yield
        deal(address(USDC), address(boringVault), USDCAmount * 2);
        vm.expectRevert(AccountantWithYieldStreaming.AccountantWithYieldStreaming__ZeroYieldUpdate.selector); 
        accountant.vestYield(0, 24 hours); 
    }

    // ========================= FUZZ TESTS ===============================
    
    function testFuzzDepositsWithNoYield(uint96 USDCAmount, uint96 USDCAmount2) external {
        USDCAmount = uint96(bound(USDCAmount, 1e1, 1e14)); 
        USDCAmount2 = uint96(bound(USDCAmount2, 1e1, 1e14)); 

        deal(address(USDC), address(this), USDCAmount);
        USDC.approve(address(boringVault), type(uint256).max);
        uint256 shares0 = teller.deposit(USDC, USDCAmount, 0, referrer);
        assertApproxEqAbs(shares0, USDCAmount, 1e9, "should be almost equal"); 
        assertLe(shares0, USDCAmount); 

        //==== BEGIN DEPOSIT 2 ====

        deal(address(USDC), address(this), USDCAmount2);
        uint256 shares1 = teller.deposit(USDC, USDCAmount2, 0, referrer);
        assertApproxEqAbs(shares1, USDCAmount2, 1e9, "should be almost equal"); 
        assertLe(shares1, USDCAmount2); 

        uint256 totalAssetsAfter = accountant.totalAssets();         
        assertApproxEqAbs(totalAssetsAfter, uint256(USDCAmount) + uint256(USDCAmount2), 1e9); 
        assertLe(totalAssetsAfter, uint256(USDCAmount) + uint256(USDCAmount2)); 
    }

    function testFuzzDepositsWithYield(uint96 USDCAmount, uint96 USDCAmount2, uint96 yieldVestAmount) external {
        accountant.updateMaximumDeviationYield(5000000);
        
        USDCAmount = uint96(bound(USDCAmount, 1e6, 10_000_000e6)); 
        USDCAmount2 = uint96(bound(USDCAmount2, 1e6, 10_000_000e6)); 
        yieldVestAmount = uint96(bound(yieldVestAmount, 1e6, USDCAmount * 100)); 
        
        // === FIRST DEPOSIT ===
        deal(address(USDC), address(this), USDCAmount);
        USDC.approve(address(boringVault), type(uint256).max);
        uint256 shares0 = teller.deposit(USDC, USDCAmount, 0, referrer);
        
        // First deposit should be 1:1 at initial rate
        assertApproxEqRel(shares0, USDCAmount, 1e13, "First deposit should be close to 1:1");
        assertLe(shares0, USDCAmount, "Less than deposit by slight amount");
        
        // === ADD YIELD ===
        deal(address(USDC), address(boringVault), USDCAmount + yieldVestAmount);
        accountant.vestYield(yieldVestAmount, 24 hours);
        skip(12 hours); // Half vesting period
        
        // === SECOND DEPOSIT - INDEPENDENT CALCULATION ===

        // Calculate expected shares from first principles:
        uint256 expectedVestedYield = uint256(yieldVestAmount).mulDivDown(12 hours, 24 hours);
        assertEq(expectedVestedYield, accountant.getPendingVestingGains()); 

        uint256 totalValueInVault = shares0 + expectedVestedYield; //this is higher than totalAssets(); 
        assertEq(accountant.totalAssets(), totalValueInVault); 
        
        uint256 totalSharesBefore = shares0;
        assertEq(totalSharesBefore, boringVault.totalSupply()); 

        uint256 sharePrice = totalValueInVault.mulDivDown(1e6, totalSharesBefore);
        assertEq(sharePrice, accountant.getRate());  
        
        uint256 expectedShares1 = uint256(USDCAmount2).mulDivDown(1e6, sharePrice + 1); //account for rounding

        //when calling deposit, the rate is updated before getting the rate 
        //rate before deposit should be totalassets * 1e6 / shares0  where totalassets == (last share price * shares0) / 1e6
        
        // === EXECUTE SECOND DEPOSIT ===
        deal(address(USDC), address(this), USDCAmount2);
        uint256 shares1 = teller.deposit(USDC, USDCAmount2, 0, referrer);
        
        //check total assets after
        uint256 totalAssetsAfter = accountant.totalAssets();
        uint256 expectedTotalAssets = (shares0 + expectedShares1).mulDivDown(sharePrice, 1e6) + accountant.getPendingVestingGains(); //verify the total assets == amount of shares
        assertApproxEqAbs(totalAssetsAfter, expectedTotalAssets, 1, "Total assets mismatch");
        assertLe(totalAssetsAfter, expectedTotalAssets);  
        
        // === VERIFY ===
        assertApproxEqRel(shares1, expectedShares1, 1e12, "Second deposit shares mismatch"); //1e5 diff is expected
        assertLe(shares1, expectedShares1, "shares mismatch");  
    }

    function testFuzzWithdrawWithYield(uint96 USDCAmount, uint96 USDCAmount2, uint96 yieldVestAmount) external {
        accountant.updateMaximumDeviationYield(5000000);
        
        USDCAmount = uint96(bound(USDCAmount, 1e6, 1e22)); 
        USDCAmount2 = uint96(bound(USDCAmount2, 1e6, 1e22)); 
        yieldVestAmount = uint96(bound(yieldVestAmount, 1e1, USDCAmount * 500 / 10_000)); 
        
        // === FIRST DEPOSIT ===
        deal(address(USDC), address(this), USDCAmount);
        USDC.approve(address(boringVault), type(uint256).max);
        uint256 shares0 = teller.deposit(USDC, USDCAmount, 0, referrer);
        assertLe(shares0, USDCAmount); 
        
        // === ADD YIELD ===
        deal(address(USDC), address(boringVault), USDCAmount + yieldVestAmount);
        accountant.vestYield(yieldVestAmount, 24 hours);
        skip(12 hours); // half vesting period
        
        // === SECOND DEPOSIT ===
        uint256 expectedVestedYield = yieldVestAmount / 2;
        deal(address(USDC), address(this), USDCAmount2);
        uint256 shares1 = teller.deposit(USDC, USDCAmount2, 0, referrer);

        // === CHECK WITHDRAW AMOUNTS ===
        
        // get current rate after deposits and vesting
        uint256 currentRate = accountant.getRate();
        
        //first depositor withdraws half their shares
        uint256 sharesToWithdraw0 = shares0 / 2;
        uint256 expectedWithdrawAmount0 = sharesToWithdraw0.mulDivDown(currentRate, 1e6);
        
        //approve shares for withdrawal
        uint256 actualWithdrawn0 = teller.withdraw(USDC, sharesToWithdraw0, 0, address(this)); 
        assertApproxEqRel(
            actualWithdrawn0, 
            expectedWithdrawAmount0, 
            1e12, //0.01% 
            "First depositor withdraw amount mismatch"
        );
        assertLe(actualWithdrawn0, expectedWithdrawAmount0, "first deposit actual withdraw > expected withdraw"); 
        
        //verify first depositor got their principal + share of yield
        //we need a large net to account for the large dis
        uint256 firstDepositorExpectedValue = (USDCAmount + expectedVestedYield) / 2; // They withdraw half
        assertApproxEqRel(
            actualWithdrawn0,
            firstDepositorExpectedValue,
            1e13,
            "First depositor should get principal + yield share"
        );
        assertLe(actualWithdrawn0, firstDepositorExpectedValue, "first deposit actual withdrawn > first depositor expected value"); 
        
        //second depositor withdraws all their shares
        uint256 rateBeforeWithdraw1 = accountant.getRate(); //rate changes due to the withdraw
        uint256 expectedWithdrawAmount1 = shares1.mulDivDown(rateBeforeWithdraw1, 1e6);
        uint256 actualWithdrawn1 = teller.withdraw(USDC, shares1, 0, address(this));
        vm.stopPrank();
        
        assertApproxEqRel(
            actualWithdrawn1,
            expectedWithdrawAmount1,
            1e12, //0.00001%
            "Second depositor withdraw amount mismatch"
        );
        assertLe(actualWithdrawn1, expectedWithdrawAmount1, "second deposit actual withdraw > expected withdraw"); 
        
        // Second depositor should get back approximately what they deposited (no yield share)
        assertApproxEqRel(
            actualWithdrawn1,
            USDCAmount2,
            1e13, //0.0001%
            "Second depositor should get back their deposit"
        );
        assertLe(actualWithdrawn1, USDCAmount2, "second deposit > weth amount"); 
    }

    function testRoundingIssuesAfterYieldStreamEndsFuzz(uint96 USDCAmount, uint96 secondDepositAmount) external {
        USDCAmount = uint96(bound(USDCAmount, 1, 1e6));
        secondDepositAmount = uint96(bound(secondDepositAmount, 1e1, 1e11)); 
        deal(address(USDC), address(this), USDCAmount);
        USDC.approve(address(boringVault), type(uint256).max);
        uint256 shares0 = teller.deposit(USDC, USDCAmount, 0, referrer);
        assertGt(USDCAmount, shares0); 

        // Use a yield that's safely under the limit (e.g., 5%)
        uint256 yieldAmount = uint256(USDCAmount) * 500 / 10_000;

        // Ensure yield is at least 1 to be meaningful
        vm.assume(yieldAmount > 0);

        //vest some yield
        deal(address(USDC), address(boringVault), secondDepositAmount * 2);
        accountant.vestYield(yieldAmount, 24 hours); 

        skip(23 hours);

        accountant.updateExchangeRate();

        //now the state of the contract should be 
        //totalSupply > 1
        //exchange rate > 1 

        deal(address(USDC), address(this), secondDepositAmount);
        uint256 shares1 = teller.deposit(USDC, secondDepositAmount, 0, referrer);

        // Check rate AFTER deposit
        boringVault.approve(address(teller), shares1);
        uint256 assetsOut = teller.withdraw(USDC, shares1, 0, address(this));

        assertLe(assetsOut, secondDepositAmount, "should not profit");
    }

    function testRoundingIssuesAfterYieldStreamAlmostEndsMinorWeiVestFuzz(uint96 USDCAmount, uint96 secondDepositAmount, uint256 yieldAmount) external {
        USDCAmount = uint96(bound(USDCAmount, 1, 1e6));
        secondDepositAmount = uint96(bound(secondDepositAmount, 1e1, 1e11)); 
        yieldAmount = uint256(bound(yieldAmount, 1e1, 1e5)); 
        deal(address(USDC), address(this), USDCAmount);
        USDC.approve(address(boringVault), type(uint256).max);
        uint256 shares0 = teller.deposit(USDC, USDCAmount, 0, referrer);
        assertGt(USDCAmount, shares0); 

        // Use a yield that's safely under the limit (e.g., 5%)
        if (yieldAmount > uint256(USDCAmount) * 500 / 10_000) { 
            yieldAmount = uint256(USDCAmount) * 500 / 10_000;
        }

        // Ensure yield is at least 1 to be meaningful
        vm.assume(yieldAmount > 0);

        //vest some yield
        deal(address(USDC), address(boringVault), secondDepositAmount * 2);
        accountant.vestYield(yieldAmount, 24 hours); 

        skip(23 hours);

        accountant.updateExchangeRate();

        //now the state of the contract should be 
        //totalSupply > 1
        //exchange rate > 1 

        deal(address(USDC), address(this), secondDepositAmount);
        uint256 shares1 = teller.deposit(USDC, secondDepositAmount, 0, referrer);

        // Check rate AFTER deposit

        boringVault.approve(address(teller), shares1);
        uint256 assetsOut = teller.withdraw(USDC, shares1, 0, address(this));

        assertLe(assetsOut, secondDepositAmount, "should not profit");
    }

    function testRoundingIssuesAfterYieldStreamAlmostEndsMinorWeiVestFuzzGreaterDecimals(uint96 USDEAmount, uint96 secondDepositAmount, uint256 yieldAmount) external {
        USDEAmount = uint96(bound(USDEAmount, 1e12, 1e18));
        secondDepositAmount = uint96(bound(secondDepositAmount, 1e13, 1e27)); 
        yieldAmount = uint256(bound(yieldAmount, 1e12, 1e32)); 
        //vm.assume(secondDepositAmount > 1e1 && secondDepositAmount <= 1e11); 
        deal(address(USDE), address(this), USDEAmount);
        USDE.approve(address(boringVault), type(uint256).max);
        uint256 shares0 = teller.deposit(USDE, USDEAmount, 0, referrer);
        //assertEq(USDEAmount, shares0); 
        
        uint256 depositInBase = uint256(USDEAmount) * 1e6 / 1e18;

        // Cap yield at 5% of deposit in base terms
        if (yieldAmount > depositInBase * 500 / 10_000) {
            yieldAmount = depositInBase * 500 / 10_000;
        }

        // Ensure yield is at least 1 to be meaningful
        vm.assume(yieldAmount > 0);

        //vest some yield
        deal(address(USDE), address(boringVault), secondDepositAmount);
        accountant.vestYield(yieldAmount, 24 hours); 

        skip(23 hours);

        accountant.updateExchangeRate();

        //now the state of the contract should be 
        //totalSupply > 1
        //exchange rate > 1 

        deal(address(USDE), address(this), secondDepositAmount);
        uint256 shares1 = teller.deposit(USDE, secondDepositAmount, 0, referrer);

        // Check rate AFTER deposit

        boringVault.approve(address(teller), shares1);
        uint256 assetsOut = teller.withdraw(USDE, shares1, 0, address(this));

        assertLe(assetsOut, secondDepositAmount, "should not profit");
    }

    // ========================================= HELPER FUNCTIONS =========================================
    
    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
