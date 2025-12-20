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

    address internal USER = address(this); 
    uint256 internal ACCEPTABLE_PRECISION_LOSS = 1e13; 

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

    uint256 internal constant RAY = 1e27;
    uint256 internal constant ONE_SHARE = 1e6; // vault has 6 decimals
    // Maximum precision loss when scaling from RAY to ONE_SHARE and back
    // This is approximately RAY / ONE_SHARE = 1e21
    uint256 internal constant MAX_PRECISION_LOSS_RAY = 1e21;

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
        _deposit(USDCAmount, USER); 
        _assertExchangeRateVsVirtualSharePrice();
        
        uint256 totalAssetsBefore = accountant.totalAssets();         

        //deposit 2
        uint256 shares1 = _deposit(USDCAmount, USER);
        assertEq(shares1, USDCAmount - 10); //same rate as first, (1:1 - rate favoring protocol)
        _assertExchangeRateVsVirtualSharePrice();
        
        //check we actually increased our total assets 
        uint256 totalAssetsAfter = accountant.totalAssets();         
        assertGt(totalAssetsAfter, totalAssetsBefore); 
    }

    function testDepositsWithYield() external {
        uint256 USDCAmount = 10e6; 
        uint256 shares0 = _deposit(USDCAmount, USER); 
        assertLe(shares0, USDCAmount); 
        _assertExchangeRateVsVirtualSharePrice();

        //vest some yield
        uint256 yieldAmount = 10e6; 
        _vestYieldAndSkip(yieldAmount, 24 hours, 12 hours); 
        _assertExchangeRateVsVirtualSharePrice();

        //==== BEGIN DEPOSIT 2 ====
        uint256 shares1 = _deposit(USDCAmount, USER); 
        vm.assertApproxEqAbs(shares1, 6666666, 10); 
        assertLe(shares1, 6666666);
        _assertExchangeRateVsVirtualSharePrice();

        //total of 2 deposits to 10 weth each + 5 vested yield 
        
        uint256 totalAssets = accountant.totalAssets(); 
        vm.assertApproxEqRel(totalAssets, 25e6, ACCEPTABLE_PRECISION_LOSS); //delta is 22 here, is acceptable
        assertLe(totalAssets, 25e6);
    }

    function testWithdrawNoYieldStream() external {
        uint256 USDCAmount = 10e6; 
        uint256 shares0 = _deposit(USDCAmount, USER); 
        assertLe(shares0, USDCAmount); 
        _assertExchangeRateVsVirtualSharePrice();

        //deposit 2
        _deposit(USDCAmount, USER); 
        _assertExchangeRateVsVirtualSharePrice();

        uint256 assetsOut = teller.withdraw(USDC, shares0, 0, address(boringVault));   
        assertApproxEqRel(assetsOut, USDCAmount, ACCEPTABLE_PRECISION_LOSS); 
        assertLe(assetsOut, USDCAmount); 
        _assertExchangeRateVsVirtualSharePrice();
    }

    function testWithdrawWithYieldStream() external {
        uint256 USDCAmount = 10e6; 
        uint256 shares0 = _deposit(USDCAmount, USER); 
        assertLe(shares0, USDCAmount); 
        _assertExchangeRateVsVirtualSharePrice();

        //==== Add Vesting Yield Stream ====
        _vestYieldAndSkip(USDCAmount, 24 hours, 12 hours); 
        _assertExchangeRateVsVirtualSharePrice();
        
        //second deposit midstream 
        uint256 shares1 = _deposit(USDCAmount, alice); 
        _assertExchangeRateVsVirtualSharePrice();
        
        //withdraw first deposit 
        uint256 assetsOut0 = teller.withdraw(USDC, shares0, 0, address(boringVault));   
        assertApproxEqRel(assetsOut0, 15e6, ACCEPTABLE_PRECISION_LOSS); 
        assertLe(assetsOut0, 15e6); 
        _assertExchangeRateVsVirtualSharePrice();
        
        //withdraw second deposit
        vm.prank(alice); 
        uint256 assetsOut1 = teller.withdraw(USDC, shares1, 0, address(alice));   
        vm.assertApproxEqRel(assetsOut1, 10e6, ACCEPTABLE_PRECISION_LOSS); 
        assertLe(assetsOut1, USDCAmount); //initial deposit out, no yield was obtained
        _assertExchangeRateVsVirtualSharePrice();
    }

    function testWithdrawWithYieldStreamUser2WaitsForYield() external {
        uint256 USDCAmount = 10e6; 
        uint256 shares0 = _deposit(USDCAmount, USER); 
        assertLe(shares0, USDCAmount); 
        
        //vest some yield
        uint256 yieldAmount = 10e6; 
        _vestYieldAndSkip(yieldAmount, 24 hours, 12 hours); 
        
        //second deposit midstream
        uint256 aliceAmount = 10e6; 
        uint256 shares1 = _deposit(aliceAmount, alice); 
        
        //withdraw user 1 
        uint256 expectedYield = USDCAmount + (yieldAmount / 2); //halfway through stream, so half of yield should be distributed
        uint256 assetsOut0 = teller.withdraw(USDC, shares0, 0, address(boringVault));   
        assertApproxEqRel(assetsOut0, expectedYield, ACCEPTABLE_PRECISION_LOSS); 
        assertLe(assetsOut0, expectedYield); 
        
        skip(12 hours); 
        
        //withdraw 2 after stream ends, rest of yield should be distributed to alice 
        vm.prank(alice); 
        uint256 assetsOut1 = teller.withdraw(USDC, shares1, 0, address(alice));   
        vm.assertApproxEqRel(assetsOut1, expectedYield, ACCEPTABLE_PRECISION_LOSS); 
        assertLe(assetsOut1, expectedYield); 
    }

    function testVestLossAbsorbBuffer() external {
        accountant.updateMaximumDeviationLoss(10_000); 
        uint256 USDCAmount = 10e6; 
        uint256 shares0 = _deposit(USDCAmount, USER); 
        assertLe(shares0, USDCAmount); 
        _assertExchangeRateVsVirtualSharePrice();
        
        //vest yield
        uint256 yieldAmount = 10e6; 
        _vestYieldAndSkip(yieldAmount, 24 hours, 12 hours); 
        _assertExchangeRateVsVirtualSharePrice();
        
        uint256 totalAssetsBeforeLoss = accountant.totalAssets(); 
        uint256 unvested = accountant.getPendingVestingGains(); //5e6 after 12 hours (10 - 5) = 5; 
        
        //post a small loss
        uint256 lossAmount = 2.5e6; 
        accountant.postLoss(lossAmount); //smaller loss than buffer (5 weth at this point)
        _assertExchangeRateVsVirtualSharePrice();

        uint256 totalAssetsAfterLoss = accountant.totalAssets(); 
        
        //assert the vestingGains is removed from  
        (, uint128 vestingGains, , , ) = accountant.vestingState(); 
        assertEq(unvested - lossAmount, vestingGains); 

        //total assets should remain the same as the buffer absorbed the entire loss
        assertApproxEqRel(totalAssetsBeforeLoss, totalAssetsAfterLoss, ACCEPTABLE_PRECISION_LOSS); //should be a minor difference between the due to rounding
        assertGt(totalAssetsBeforeLoss, totalAssetsAfterLoss); //make sure the rounding is the correct direction 
        
        //finish the vesting period
        skip(12 hours); 
        _assertExchangeRateVsVirtualSharePrice();
        
        //grab the remainder of the gains 
        uint256 expectedYield = USDCAmount + (yieldAmount - lossAmount);   
        uint256 assetsOut = teller.withdraw(USDC, shares0, 0, address(boringVault)); 
        assertApproxEqRel(assetsOut, expectedYield, ACCEPTABLE_PRECISION_LOSS); //10 USDC deposit -> 5 usdc is vested -> 2.5 loss -> remaining 2.5 vests over the next 12 hours = total of 17.5 earned
        assertLe(assetsOut, expectedYield); 
        _assertExchangeRateVsVirtualSharePrice();
    }

    function testVestLossAffectsSharePrice() external {
        accountant.updateMaximumDeviationLoss(10_000); 
        uint256 USDCAmount = 10e6; 
        uint256 shares0 = _deposit(USDCAmount, USER);  
        assertLe(shares0, USDCAmount); 
        _assertExchangeRateVsVirtualSharePrice();

        //vest yield
        uint256 yieldAmount = 10e6; 
        _vestYieldAndSkip(yieldAmount, 24 hours, 12 hours);
        _assertExchangeRateVsVirtualSharePrice();

        //total assets = 15
        uint256 expectedTotalAssets = USDCAmount + (yieldAmount / 2); 
        uint256 totalAssetsInBaseBefore = accountant.totalAssets();  
        assertApproxEqRel(totalAssetsInBaseBefore, expectedTotalAssets, ACCEPTABLE_PRECISION_LOSS); 
        assertLe(totalAssetsInBaseBefore, expectedTotalAssets); 
        
        (uint128 lastSharePrice, , , , ) = accountant.vestingState(); 
        uint256 sharePriceInitial = lastSharePrice; 
        
        //post a loss 
        uint256 lossAmount = 15e6; 
        accountant.postLoss(lossAmount); //this moves vested yield -> share price (to protect share price)
        //note: the buffer absorbs the loss, so we're left with 5 remaining (the vested yield)
        _assertExchangeRateVsVirtualSharePrice();
        
        //15 - 15 with (5 unvested remaining) = 5 left

        uint256 totalAssetsInBaseAfter = accountant.totalAssets();  
        
        //vesting gains should be 0
        (, uint128 vestingGains, , , ) = accountant.vestingState(); 
        assertEq(0, vestingGains); 

        //total assets should be 5e6 -> 10 initial, 5 yield, 5 unvested -> 15 usdc loss (5 from buffer) -> 15 - 10 = 5 totalAssets remaining
        //after positing a loss the yield earned is moved into the share price first, then because we have a buffer left over the math is 15 - 10 = 5; 
        uint256 remainingUnvested = yieldAmount / 2; 
        assertApproxEqRel(totalAssetsInBaseAfter, remainingUnvested, ACCEPTABLE_PRECISION_LOSS); 
        assertLe(totalAssetsInBaseAfter, remainingUnvested); //make sure we rounded down

        skip(12 hours); 
        _assertExchangeRateVsVirtualSharePrice();
        
        //TA should be same as remaining yield has been wiped
        uint256 totalAssetsInBaseAfterVest = accountant.totalAssets();  
        assertEq(totalAssetsInBaseAfter, totalAssetsInBaseAfterVest);

        //check that the share price was affected
        
        (uint128 sharePriceAfter, , , , ) = accountant.vestingState(); 
        assertLt(sharePriceAfter, sharePriceInitial, "share price should be less after loss exceeds buffer"); 

        //console.log("difference: ", sharePriceInitial - sharePriceAfter); //diff = 50% 
        assertApproxEqRel(sharePriceInitial / 2, sharePriceAfter, ACCEPTABLE_PRECISION_LOSS); 
        assertLe(sharePriceAfter, sharePriceInitial / 2); //should be slightly less due to rounding
    }

    function testGetPendingVestingGains() external {
        uint256 USDCAmount = 10e6; 
        uint256 shares = _deposit(USDCAmount, USER); 
        assertLe(shares, USDCAmount); 
        
        uint256 yieldAmount = 10e6;  
        _vestYieldAndSkip(yieldAmount, 24 hours, 6 hours); 

        //total should be 10 + (10 / 4) = 2.5
        uint256 expectedTotalAssets = USDCAmount + (yieldAmount / 4); 
        uint256 totalAssets = accountant.totalAssets();  
        assertApproxEqRel(totalAssets, expectedTotalAssets, ACCEPTABLE_PRECISION_LOSS); 
        assertLe(totalAssets, expectedTotalAssets); 
    }

    function testYieldStreamUpdateDuringExistingStream() external {
        uint256 USDCAmount = 10e6; 
        uint256 shares = _deposit(USDCAmount, USER); 
        assertLe(shares, USDCAmount); 
        
        uint256 yieldAmount = 10e6;  
        _vestYieldAndSkip(yieldAmount, 24 hours, 12 hours); 

        accountant.updateMinimumVestDuration(6 hours); 

        //total assets = 15
        uint256 unvested = accountant.getPendingVestingGains(); //unvested = 5
        assertEq(unvested, yieldAmount / 2); 
        
        //strategist posts another yield update, halfway through the remaining update 
        //recall that the strategist MUST account for unvested yield in the update if they wish to include it in the next update
        uint256 newYieldAmount = yieldAmount + unvested;  
        _vestYieldAndSkip(newYieldAmount, 24 hours, 12 hours); 

        //15 + 7.5 = 22.5
        uint256 expectedTotalAssets = newYieldAmount + (newYieldAmount / 2); 
        uint256 totalAssets = accountant.totalAssets();  
        assertApproxEqAbs(totalAssets, expectedTotalAssets, ACCEPTABLE_PRECISION_LOSS); 
        assertLe(totalAssets, expectedTotalAssets); 
        
        (, uint128 gains, uint128 lastVestingUpdate, uint64 startVestingTime, uint64 endVestingTime) = accountant.vestingState(); 
        uint256 expectedVestingGains = yieldAmount + unvested;  
        assertEq(gains, expectedVestingGains); 
        
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
        uint256 shares = _deposit(USDCAmount, USER); 
        assertLe(shares, USDCAmount); 
        
        //vest and skip 1 year
        _vestYieldAndSkip(USDCAmount, 24 hours, 365 days); 
        
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
        assertApproxEqRel(USDC.balanceOf(payoutAddress), expectedFees, ACCEPTABLE_PRECISION_LOSS);
        assertLe(USDC.balanceOf(payoutAddress), expectedFees);
    }
    
    function testPerformanceFeesAfterYield() external {
        uint256 performanceFeeRate = 0.1e4; // 10%
    
        uint256 USDCAmount = 10e6;
        _deposit(USDCAmount, USER); 
        _assertExchangeRateVsVirtualSharePrice();
    
        // Record initial state
        (, uint96 initialHighwaterMark, ,,,,,,,,,) = accountant.accountantState();
        (uint128 initialSharePrice,,,,) = accountant.vestingState(); 
        //uint256 initialSharePrice = uint256(lastSharePrice); 
        uint256 totalShares = boringVault.totalSupply();
    
        _vestYieldAndSkip(USDCAmount, 24 hours, 1 days); 
        _assertExchangeRateVsVirtualSharePrice();
    
        //update exchange rate to trigger fee calculation
        accountant.updateExchangeRate();
        _assertExchangeRateVsVirtualSharePrice();
    
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

        uint128 platformFee = 2739; //1 day of platform fees (10 USDC / 365) = 2739
    
        // Allow for small rounding difference
        assertEq(actualFees - platformFee, expectedPerformanceFees, "Performance fees should match share price appreciation");
    
        // Verify high water mark updated
        assertGt(nextHighwaterMark, initialHighwaterMark, "HWM should increase");
        assertEq(uint256(nextHighwaterMark), finalSharePrice, "HWM should equal new share price");
    }

    // ========================= EDGE CASES ===============================
    
    function testDonationsShouldNotBeConsideredInCalculations() external {
        uint256 USDCAmount = 10e6; 
        uint256 shares0 = _deposit(USDCAmount, USER); 
        assertLe(shares0, USDCAmount); 
        
        //vest some yield 
        uint256 yieldAmount = 10e6; 
        _vestYieldAndSkip(yieldAmount, 24 hours, 12 hours); 
        
        deal(address(USDC), alice, 10e6); 
        vm.prank(alice);
        USDC.transfer(address(boringVault), 10e6); 

        //deposit 2 uint256 shares1 = teller.deposit(USDC, USDCAmount, 0);
        uint256 expectedTotalAssets = USDCAmount + (yieldAmount / 2); 
        uint256 totalAssets = accountant.totalAssets(); 
        vm.assertApproxEqRel(totalAssets, expectedTotalAssets, ACCEPTABLE_PRECISION_LOSS); 
        assertLe(totalAssets, expectedTotalAssets); 
        
        uint256 expectedAssetsOut = USDCAmount + (yieldAmount / 2); 
        uint256 assetsOut = teller.withdraw(USDC, shares0, 0, address(boringVault));   
        assertApproxEqRel(assetsOut, expectedAssetsOut, ACCEPTABLE_PRECISION_LOSS); 
        assertLe(assetsOut, expectedAssetsOut); 
    }

    function testDoubleDepositInSameBlock() external {
        uint256 USDCAmount0 = 10e6; 
        uint256 shares0 = _deposit(USDCAmount0, USER);
        assertLe(shares0, USDCAmount0); 
        
        uint256 USDCAmount1 = 10e6;
        uint256 shares1 = _deposit(USDCAmount1, USER);
        assertApproxEqRel(USDCAmount1, shares1, ACCEPTABLE_PRECISION_LOSS);
        assertLe(shares1, USDCAmount1);
        
        uint256 currentShares = boringVault.totalSupply();
        (uint128 lsp, , , ,) = accountant.vestingState();
        uint256 lastSharePrice = uint256(lsp);
        uint256 totalAssetsInBase = ((currentShares * lastSharePrice) / 1e6) + accountant.getPendingVestingGains(); 
        uint256 expectedTotalAssets = USDCAmount0 + USDCAmount1; 
        assertApproxEqRel(totalAssetsInBase, expectedTotalAssets, ACCEPTABLE_PRECISION_LOSS); 
        assertLe(totalAssetsInBase, expectedTotalAssets);
    }

    function testDoubleDepositInSameBlockAfterYieldEvent() external {
        uint256 USDCAmount = 10e6; 
        uint256 shares0 = _deposit(USDCAmount, USER);  
        assertLe(shares0, USDCAmount); 

        //vest some yield
        uint256 yieldAmount = 10e6;
        _vestYieldAndSkip(yieldAmount, 24 hours, 12 hours);
        
        //double deposit -> alice, bill both deposit in the same block 
        uint256 sharesAlice = _deposit(USDCAmount, alice); 
        uint256 sharesBill  = _deposit(USDCAmount, bill); 

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
        uint256 shares0 = _deposit(USDCAmount, USER); 
        assertLe(shares0, USDCAmount); 

        //vest some yield
        uint256 yieldAmount = 10e6;
        _vestYieldAndSkip(yieldAmount, 24 hours, 12 hours);
        
        //double deposit -> alice, bill both deposit in the same block 
        uint256 sharesAlice = _deposit(USDCAmount, alice);
        
        //bill deposits before alice withdraws
        _deposit(USDCAmount, bill); 

        //alice withdraws
        vm.prank(alice); 
        uint256 assetsOutAlice = teller.withdraw(USDC, sharesAlice, 0, address(boringVault));   
        
        assertApproxEqRel(assetsOutAlice, USDCAmount, ACCEPTABLE_PRECISION_LOSS); 
        assertLe(assetsOutAlice, USDCAmount); 
    }

    function testLoopDepositWithdrawDepositDuringVest() external {
        uint256 USDCAmount = 10e6; 
        uint256 shares0 = _deposit(USDCAmount, USER); 
        assertLe(shares0, USDCAmount); 

        //vest some yield
        uint256 yieldAmount = 10e6; 
        _vestYieldAndSkip(yieldAmount, 24 hours, 12 hours); 
        
        uint256 sharesAlice = _deposit(USDCAmount, alice); 
        
        //alice withdraws
        vm.prank(alice); 
        uint256 assetsOutAlice = teller.withdraw(USDC, sharesAlice, 0, address(boringVault));   
        assertLt(assetsOutAlice, USDCAmount); 

        uint256 sharesBill = _deposit(USDCAmount, bill); 

        vm.prank(bill); 
        uint256 assetsOutBill = teller.withdraw(USDC, sharesBill, 0, address(boringVault));   
        assertApproxEqRel(USDCAmount, assetsOutBill, ACCEPTABLE_PRECISION_LOSS);
        assertLe(assetsOutBill, USDCAmount);
    }

    function testDepositDuringSameBlockAsYieldIsDeposited() external {
        uint256 USDCAmount = 10e6; 
        uint256 shares0 = _deposit(USDCAmount, USER); 
        assertLt(shares0, USDCAmount); 

        //vest some yield
        deal(address(USDC), address(boringVault), USDCAmount * 2);
        accountant.vestYield(USDCAmount, 24 hours); 
        
        uint256 sharesAlice = _deposit(USDCAmount, alice); 

        //alice withdraws
        vm.prank(alice); 
        uint256 assetsOutAlice = teller.withdraw(USDC, sharesAlice, 0, address(boringVault));   

        assertLe(assetsOutAlice, USDCAmount); //assert slight dilution, no extra yield
    }

    function testRoundingIssuesAfterYieldStreamEndsNoFuzz() external {
        uint256 USDCAmount = 1e6; 
        uint256 shares0 = _deposit(USDCAmount, USER); 
        assertLe(shares0, USDCAmount); 

        uint256 yieldAmount = 1;  
        _vestYieldAndSkip(1, 24 hours, 24 hours); 

        accountant.updateExchangeRate();

        //now the state of the contract should be 
        //totalSupply > 1
        //exchange rate > 1 
        uint256 supplyBefore = boringVault.totalSupply();
        uint256 rateBefore = accountant.getRate();
        
        //exact magic number gotten from fuzz testing
        uint256 depositAmount = 389998;
        uint256 shares1 = _deposit(depositAmount, USER); 

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
        _deposit(USDCAmount, USER); 

        //vest some yield
        deal(address(USDC), address(boringVault), USDCAmount * 2);
        vm.expectRevert(AccountantWithYieldStreaming.AccountantWithYieldStreaming__DurationExceedsMaximum.selector); 
        accountant.vestYield(USDCAmount, 7 days + 1 hours); 
    }

    function testVestYieldUnderMinimumDuration() external {
        //by default, maximum duration is 7 days
        uint256 USDCAmount = 10e6; 
        _deposit(USDCAmount, USER); 

        //vest some yield
        deal(address(USDC), address(boringVault), USDCAmount * 2);
        vm.expectRevert(AccountantWithYieldStreaming.AccountantWithYieldStreaming__DurationUnderMinimum.selector); 
        accountant.vestYield(USDCAmount, 23 hours); 
    }

    function testVestYieldZeroAmount() external {
        //by default, maximum duration is 7 days
        uint256 USDCAmount = 10e6; 
        _deposit(USDCAmount, USER); 

        //vest some yield
        deal(address(USDC), address(boringVault), USDCAmount * 2);
        vm.expectRevert(AccountantWithYieldStreaming.AccountantWithYieldStreaming__ZeroYieldUpdate.selector); 
        accountant.vestYield(0, 24 hours); 
    }

    // ========================= FUZZ TESTS ===============================
    
    function testFuzzDepositsWithNoYield(uint96 USDCAmount0, uint96 USDCAmount1) external {
        USDCAmount0 = uint96(bound(USDCAmount0, 1e1, 1e12)); 
        USDCAmount1 = uint96(bound(USDCAmount1, 1e1, 1e12)); 
        
        uint256 tolerance0 = USDCAmount0 < 1e6 ? 10e16 : ACCEPTABLE_PRECISION_LOSS;  //scale to get amounts under 1e6
        uint256 shares0 = _deposit(USDCAmount0, USER); 
        assertApproxEqRel(shares0, USDCAmount0, tolerance0, "should be almost equal"); 
        assertLe(shares0, USDCAmount0); 
        _assertExchangeRateVsVirtualSharePrice();

        uint256 tolerance1 = USDCAmount1 < 1e6 ? 10e16 : ACCEPTABLE_PRECISION_LOSS;  //scale to get amounts under 1e6
        uint256 shares1 = _deposit(USDCAmount1, USER); 
        assertApproxEqRel(shares1, USDCAmount1, tolerance1, "should be almost equal"); 
        assertLe(shares1, USDCAmount1); 
        _assertExchangeRateVsVirtualSharePrice();

        uint256 toleranceTotal = USDCAmount1 < 1e6 ? 10e16 : ACCEPTABLE_PRECISION_LOSS;  //scale to get amounts under 1e6
        uint256 totalAssetsAfter = accountant.totalAssets();         
        assertApproxEqRel(totalAssetsAfter, uint256(USDCAmount0) + uint256(USDCAmount1), toleranceTotal, "total assets mismatch"); 
        assertLe(totalAssetsAfter, uint256(USDCAmount0) + uint256(USDCAmount1)); 
    }

    function testFuzzDepositsWithYield(uint96 USDCAmount0, uint96 USDCAmount1, uint96 yieldVestAmount) external {
        accountant.updateMaximumDeviationYield(5000000);
        
        USDCAmount0 = uint96(bound(USDCAmount0, 1e6, 10e12)); 
        USDCAmount1 = uint96(bound(USDCAmount1, 1e6, 10e12)); 
        yieldVestAmount = uint96(bound(yieldVestAmount, 1e6, USDCAmount0 * 100)); 
        
        uint256 tolerance0 = USDCAmount0 < 1e6 ? 10e16 : ACCEPTABLE_PRECISION_LOSS;  //scale to get amounts under 1e6
        uint256 tolerance1 = USDCAmount1 < 1e6 ? 10e16 : ACCEPTABLE_PRECISION_LOSS;  //scale to get amounts under 1e6

        uint256 shares0 = _deposit(USDCAmount0, USER); 
        
        //first deposit should be 1:1 at initial rate
        assertApproxEqRel(shares0, USDCAmount0, tolerance0, "First deposit should be close to 1:1");
        assertLe(shares0, USDCAmount0, "Less than deposit by slight amount");
        _assertExchangeRateVsVirtualSharePrice();
        
        _vestYieldAndSkip(yieldVestAmount, 24 hours, 12 hours); 
        _assertExchangeRateVsVirtualSharePrice();
        
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
        
        uint256 expectedShares1 = uint256(USDCAmount1).mulDivDown(1e6, sharePrice + 1); //account for rounding

        //when calling deposit, the rate is updated before getting the rate 
        //rate before deposit should be totalassets * 1e6 / shares0  where totalassets == (last share price * shares0) / 1e6
        
        uint256 shares1 = _deposit(USDCAmount1, USER); 
        _assertExchangeRateVsVirtualSharePrice();
        
        //check total assets after
        uint256 totalAssetsAfter = accountant.totalAssets();
        uint256 expectedTotalAssets = (shares0 + expectedShares1).mulDivDown(sharePrice, 1e6) + accountant.getPendingVestingGains(); //verify the total assets == amount of shares
        assertApproxEqAbs(totalAssetsAfter, expectedTotalAssets, 1, "Total assets mismatch");
        assertLe(totalAssetsAfter, expectedTotalAssets);  
        
        // === VERIFY ===
        assertApproxEqRel(shares1, expectedShares1, ACCEPTABLE_PRECISION_LOSS, "Second deposit shares mismatch"); //1e5 diff is expected
        assertLe(shares1, expectedShares1, "shares mismatch");  
    }

    function testFuzzWithdrawWithYield(uint96 USDCAmount0, uint96 USDCAmount1, uint96 yieldVestAmount) external {
        accountant.updateMaximumDeviationYield(5000000);
        
        USDCAmount0 = uint96(bound(USDCAmount0, 1e6, 1e22)); 
        USDCAmount1 = uint96(bound(USDCAmount1, 1e6, 1e22)); 
        yieldVestAmount = uint96(bound(yieldVestAmount, 1e1, USDCAmount0 * 500 / 10_000)); 

        //first deposit 
        uint256 shares0 = _deposit(USDCAmount0, USER); 
        assertLe(shares0, USDCAmount0); 
        _assertExchangeRateVsVirtualSharePrice();
        
        _vestYieldAndSkip(yieldVestAmount, 24 hours, 12 hours); 
        _assertExchangeRateVsVirtualSharePrice();
        
        //second deposit
        uint256 expectedVestedYield = yieldVestAmount / 2;
        deal(address(USDC), address(this), USDCAmount1);
        uint256 shares1 = _deposit(USDCAmount1, USER);
        _assertExchangeRateVsVirtualSharePrice();

        // === CHECK WITHDRAW AMOUNTS ===
        
        // get current rate after deposits and vesting
        uint256 currentRate = accountant.getRate();
        
        
        //make sure the vault has the funds
        deal(address(USDC), address(boringVault), yieldVestAmount + USDCAmount0 + USDCAmount1); 

        //first depositor withdraws half their shares
        uint256 sharesToWithdraw0 = shares0 / 2;
        uint256 expectedWithdrawAmount0 = sharesToWithdraw0.mulDivDown(currentRate, 1e6);
        
        //approve shares for withdrawal
        uint256 actualWithdrawn0 = teller.withdraw(USDC, sharesToWithdraw0, 0, address(this)); 
        assertApproxEqRel(
            actualWithdrawn0, 
            expectedWithdrawAmount0, 
            ACCEPTABLE_PRECISION_LOSS,
            "First depositor withdraw amount mismatch"
        );
        assertLe(actualWithdrawn0, expectedWithdrawAmount0, "first deposit actual withdraw > expected withdraw"); 
        _assertExchangeRateVsVirtualSharePrice();
        
        //verify first depositor got their principal + share of yield
        //we need a large net to account for the large dis
        uint256 firstDepositorExpectedValue = (USDCAmount0 + expectedVestedYield) / 2; // They withdraw half
        assertApproxEqRel(
            actualWithdrawn0,
            firstDepositorExpectedValue,
            ACCEPTABLE_PRECISION_LOSS,
            "First depositor should get principal + yield share"
        );
        assertLe(actualWithdrawn0, firstDepositorExpectedValue, "first deposit actual withdrawn > first depositor expected value"); 
        
        //second depositor withdraws all their shares
        uint256 rateBeforeWithdraw1 = accountant.getRate(); //rate changes due to the withdraw
        uint256 expectedWithdrawAmount1 = shares1.mulDivDown(rateBeforeWithdraw1, 1e6);
        uint256 actualWithdrawn1 = teller.withdraw(USDC, shares1, 0, address(this));
        vm.stopPrank();
        _assertExchangeRateVsVirtualSharePrice();
        
        assertApproxEqRel(
            actualWithdrawn1,
            expectedWithdrawAmount1,
            ACCEPTABLE_PRECISION_LOSS,
            "Second depositor withdraw amount mismatch"
        );
        assertLe(actualWithdrawn1, expectedWithdrawAmount1, "second deposit actual withdraw > expected withdraw"); 
        
        // Second depositor should get back approximately what they deposited (no yield share)
        assertApproxEqRel(
            actualWithdrawn1,
            USDCAmount1,
            ACCEPTABLE_PRECISION_LOSS,
            "Second depositor should get back their deposit"
        );
        assertLe(actualWithdrawn1, USDCAmount1, "second deposit > weth amount"); 
    }

    function testRoundingIssuesAfterYieldStreamEndsFuzz(uint96 USDCAmount0, uint96 USDCAmount1) external {
        USDCAmount0 = uint96(bound(USDCAmount0, 1, 1e6)); //bound to small amounts
        USDCAmount1 = uint96(bound(USDCAmount1, 1e1, 1e12)); 

        uint256 shares0 = _deposit(USDCAmount0, USER);
        assertLe(shares0, USDCAmount0); 
        _assertExchangeRateVsVirtualSharePrice();

        // use a yield that's safely under the limit (e.g., 5%)
        uint256 yieldAmount = uint256(USDCAmount0) * 500 / 10_000;

        // Ensure yield is at least 1 to be meaningful
        vm.assume(yieldAmount > 0);

        //vest some yield
        _vestYieldAndSkip(yieldAmount, 24 hours, 23 hours); 
        _assertExchangeRateVsVirtualSharePrice();

        accountant.updateExchangeRate();
        _assertExchangeRateVsVirtualSharePrice();
        
        //make sure the vault has enough funds to fund withdraws
        deal(address(USDC), address(boringVault), USDCAmount0 + USDCAmount1 + yieldAmount);

        //now the state of the contract should be 
        //totalSupply > 1
        //exchange rate > 1 
        
        //second deposit
        uint256 shares1 = _deposit(USDCAmount1, USER);
        _assertExchangeRateVsVirtualSharePrice();

        //check rate AFTER deposit
        boringVault.approve(address(teller), shares1);
        uint256 assetsOut = teller.withdraw(USDC, shares1, 0, address(this));
        assertLe(assetsOut, USDCAmount1, "should not profit");
        _assertExchangeRateVsVirtualSharePrice();
    }

    function testRoundingIssuesAfterYieldStreamAlmostEndsMinorWeiVestFuzz(uint96 USDCAmount0, uint96 USDCAmount1, uint256 yieldAmount) external {
        USDCAmount0 = uint96(bound(USDCAmount0, 1, 1e6));
        USDCAmount1 = uint96(bound(USDCAmount1, 1e1, 1e11)); 
        yieldAmount = uint256(bound(yieldAmount, 1e1, 1e5)); 

        uint256 shares0 = _deposit(USDCAmount0, USER);
        assertLe(shares0, USDCAmount0); 
        _assertExchangeRateVsVirtualSharePrice();

        // Use a yield that's safely under the limit (e.g., 5%)
        if (yieldAmount > uint256(USDCAmount0) * 500 / 10_000) { 
            yieldAmount = uint256(USDCAmount0) * 500 / 10_000;
        }

        // Ensure yield is at least 1 to be meaningful
        vm.assume(yieldAmount > 0);

        //vest some yield
        _vestYieldAndSkip(yieldAmount, 24 hours, 23 hours); 
        _assertExchangeRateVsVirtualSharePrice();

        accountant.updateExchangeRate();
        _assertExchangeRateVsVirtualSharePrice();

        //now the state of the contract should be 
        //totalSupply > 1
        //exchange rate > 1 

        deal(address(USDC), address(this), USDCAmount1);
        uint256 shares1 = _deposit(USDCAmount1, USER);
        _assertExchangeRateVsVirtualSharePrice();

        //check rate AFTER deposit
        uint256 assetsOut = teller.withdraw(USDC, shares1, 0, address(this));
        assertLe(assetsOut, USDCAmount1, "should not profit");
        _assertExchangeRateVsVirtualSharePrice();
    }

    /**
     * @notice Fuzz test to ensure exchangeRate scaled to RAY is always <= lastVirtualSharePrice
     * @dev Tests the invariant across many deposit/yield/withdraw scenarios
     */
    function testFuzzExchangeRateVsVirtualSharePriceInvariant(
        uint96 depositAmount,
        uint96 yieldAmount,
        uint64 vestDuration,
        uint64 timeElapsed,
        bool doWithdraw
    ) external {
        accountant.updateMaximumDeviationYield(500000); // 5000% for testing flexibility
        
        // Bound inputs to reasonable ranges
        depositAmount = uint96(bound(depositAmount, 2, 1e12)); // 0.000002 USDC to 1M USDC
        yieldAmount = uint96(bound(yieldAmount, 1, depositAmount)); // Up to 100% yield
        vestDuration = uint64(bound(vestDuration, 1 days, 7 days));
        timeElapsed = uint64(bound(timeElapsed, 0, vestDuration));
        
        // Initial deposit
        uint256 shares0 = _deposit(depositAmount, USER);
        _assertExchangeRateVsVirtualSharePrice();
        
        // Vest yield
        deal(address(USDC), address(boringVault), uint256(depositAmount) + uint256(yieldAmount) * 2);
        accountant.vestYield(yieldAmount, vestDuration);
        _assertExchangeRateVsVirtualSharePrice();
        
        // Skip some time
        skip(timeElapsed);
        _assertExchangeRateVsVirtualSharePrice();
        
        // Update exchange rate
        accountant.updateExchangeRate();
        _assertExchangeRateVsVirtualSharePrice();
        
        // Optionally do a withdraw
        if (doWithdraw && shares0 > 1) {
            uint256 sharesToWithdraw = shares0 / 2;
            teller.withdraw(USDC, sharesToWithdraw, 0, address(this));
            _assertExchangeRateVsVirtualSharePrice();
        }
        
        // Second deposit
        uint256 shares1 = _deposit(depositAmount / 2, alice);
        _assertExchangeRateVsVirtualSharePrice();
        
        // Skip to end of vesting
        skip(vestDuration - timeElapsed);
        _assertExchangeRateVsVirtualSharePrice();
        
        // Final exchange rate update
        accountant.updateExchangeRate();
        _assertExchangeRateVsVirtualSharePrice();
    }

    /**
     * @notice Fuzz test specifically for the exchange rate invariant with loss scenarios
     */
    function testFuzzExchangeRateVsVirtualSharePriceWithLoss(
        uint96 depositAmount,
        uint96 yieldAmount,
        uint96 lossAmount
    ) external {
        accountant.updateMaximumDeviationYield(500000); // 5000% for testing
        accountant.updateMaximumDeviationLoss(10_000); // Allow up to 100% loss for testing
        
        // Bound inputs
        depositAmount = uint96(bound(depositAmount, 2, 1e12));
        yieldAmount = uint96(bound(yieldAmount, 1, depositAmount));
        lossAmount = uint96(bound(lossAmount, 1, yieldAmount)); // Loss <= yield to avoid pause
        
        // Initial deposit
        _deposit(depositAmount, USER);
        _assertExchangeRateVsVirtualSharePrice();
        
        // Vest yield
        deal(address(USDC), address(boringVault), uint256(depositAmount) + uint256(yieldAmount) * 2);
        accountant.vestYield(yieldAmount, 24 hours);
        _assertExchangeRateVsVirtualSharePrice();
        
        // Skip halfway through vesting
        skip(12 hours);
        _assertExchangeRateVsVirtualSharePrice();
        
        // Post a loss
        accountant.postLoss(lossAmount);
        _assertExchangeRateVsVirtualSharePrice();
        
        // Skip to end
        skip(12 hours);
        _assertExchangeRateVsVirtualSharePrice();
        
        // Final update
        accountant.updateExchangeRate();
        _assertExchangeRateVsVirtualSharePrice();
    }

    /**
     * @notice Test the invariant holds across multiple sequential yield vests
     */
    function testFuzzMultipleYieldVestsInvariant(
        uint96 depositAmount,
        uint96 yield1,
        uint96 yield2,
        uint96 yield3
    ) external {
        accountant.updateMaximumDeviationYield(500000);
        accountant.updateMinimumVestDuration(1 hours); // Reduce for faster testing
        
        // Bound inputs
        depositAmount = uint96(bound(depositAmount, 2, 1e12));
        yield1 = uint96(bound(yield1, 1, depositAmount));
        yield2 = uint96(bound(yield2, 1, depositAmount));
        yield3 = uint96(bound(yield3, 1, depositAmount));
        
        // Initial deposit
        _deposit(depositAmount, USER);
        _assertExchangeRateVsVirtualSharePrice();
        
        // First yield vest
        deal(address(USDC), address(boringVault), depositAmount + yield1 + yield2 + yield3);
        accountant.vestYield(yield1, 24 hours);
        _assertExchangeRateVsVirtualSharePrice();
        
        // Let first vest complete
        skip(24 hours + 1);
        accountant.updateExchangeRate();
        _assertExchangeRateVsVirtualSharePrice();
        
        // Second yield vest
        accountant.vestYield(yield2, 24 hours);
        _assertExchangeRateVsVirtualSharePrice();
        
        // Partial vest
        skip(12 hours);
        _assertExchangeRateVsVirtualSharePrice();
        
        // Let second vest complete
        skip(12 hours + 1);
        accountant.updateExchangeRate();
        _assertExchangeRateVsVirtualSharePrice();
        
        // Third yield vest
        accountant.vestYield(yield3, 24 hours);
        _assertExchangeRateVsVirtualSharePrice();
        
        // Let third vest complete
        skip(24 hours + 1);
        accountant.updateExchangeRate();
        _assertExchangeRateVsVirtualSharePrice();
    }

    // ========================================= HELPER FUNCTIONS =========================================
    
    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }

    /**
     * @notice Asserts that exchangeRate scaled to RAY is always <= lastVirtualSharePrice
     *         and that lastVirtualSharePrice is not too much higher (bounded by precision loss)
     * @dev This invariant ensures we never overpay users due to rounding issues
     */
    function _assertExchangeRateVsVirtualSharePrice() internal view {
        (uint128 lastSharePrice, , , , ) = accountant.vestingState();
        uint256 lastVirtualSharePrice = accountant.lastVirtualSharePrice();
        
        // Scale exchangeRate (lastSharePrice) to RAY precision
        uint256 exchangeRateScaledToRay = uint256(lastSharePrice).mulDivDown(RAY, ONE_SHARE);
        
        // Assertion 1: exchangeRate scaled to RAY should always be <= lastVirtualSharePrice
        assertLe(
            exchangeRateScaledToRay, 
            lastVirtualSharePrice, 
            "exchangeRate scaled to RAY must be <= lastVirtualSharePrice"
        );

        // Assertion 2: lastVirtualSharePrice scaled to ONE_SHARE should always be == exchangeRate
        uint256 lastVirtualSharePriceScaledToOneShare = lastVirtualSharePrice.mulDivDown(ONE_SHARE, RAY);
        assertEq(
            lastVirtualSharePriceScaledToOneShare,
            lastSharePrice,
            "lastVirtualSharePrice scaled to ONE_SHARE must be == exchangeRate"
        );
        
        // Assertion 3: lastVirtualSharePrice should not be too much higher than scaled exchangeRate
        // The maximum difference should be bounded by precision loss during scaling
        uint256 difference = lastVirtualSharePrice - exchangeRateScaledToRay;
        assertLt(
            difference, 
            MAX_PRECISION_LOSS_RAY, 
            "lastVirtualSharePrice is too much higher than scaled exchangeRate"
        );
    }

    function _deposit(uint256 amount, address user) internal returns (uint256) {
        uint256 USDCAmount = amount; 
        vm.startPrank(user);
        deal(address(USDC), user, amount);
        USDC.approve(address(boringVault), amount);
        uint256 shares = teller.deposit(USDC, USDCAmount, 0, referrer);
        vm.stopPrank(); 
        return shares; 
    }

    function _vestYieldAndSkip(uint256 amount, uint256 duration, uint256 skipDuration) internal {
        deal(address(USDC), address(boringVault), amount * 2); //give the vault funds for withdraw + buffer
        accountant.vestYield(amount, duration); 
        skip(skipDuration); 
    }
}
