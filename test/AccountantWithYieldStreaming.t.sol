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

    address internal USER = address(this); 
    uint256 internal ACCEPTABLE_PRECISION_LOSS = 1e13; 

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
    uint256 internal constant ONE_SHARE = 1e18; // vault has 18 decimals
    // Maximum precision loss when scaling from RAY to ONE_SHARE and back
    // This is approximately RAY / ONE_SHARE = 1e9
    uint256 internal constant MAX_PRECISION_LOSS_RAY = 1e9;

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 23039901;
        _startFork(rpcKey, blockNumber);

        WETH = getERC20(sourceChain, "WETH");

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
       
        teller.updateAssetData(WETH, true, true, 0);

        accountant.updateMaximumDeviationYield(50000); //500% allowable (for testing)
    }

    //test
    function testDepositsWithNoYield() external {
        uint256 WETHAmount = 10e18; 
        _deposit(WETHAmount, USER); 
        _assertExchangeRateVsVirtualSharePrice();
        
        uint256 totalAssetsBefore = accountant.totalAssets();         

        //deposit 2
        uint256 shares1 = _deposit(WETHAmount, USER);
        assertEq(shares1, WETHAmount - 10); //same rate as first, (1:1 - rate favoring protocol)
        _assertExchangeRateVsVirtualSharePrice();
        
        //check we actually increased our total assets 
        uint256 totalAssetsAfter = accountant.totalAssets();         
        assertGt(totalAssetsAfter, totalAssetsBefore); 
    }

    function testDepositsWithYield() external {
        uint256 WETHAmount = 10e18; 
        uint256 shares0 = _deposit(WETHAmount, USER); 
        assertLe(shares0, WETHAmount); 
        _assertExchangeRateVsVirtualSharePrice();

        //vest some yield
        uint256 yieldAmount = 10e18; 
        _vestYieldAndSkip(yieldAmount, 24 hours, 12 hours); 
        _assertExchangeRateVsVirtualSharePrice();

        //==== BEGIN DEPOSIT 2 ====
        uint256 shares1 = _deposit(WETHAmount, USER); 
        vm.assertApproxEqAbs(shares1, 6666666666666666666, 10); 
        assertLe(shares1, 6666666666666666666);
        _assertExchangeRateVsVirtualSharePrice();

        //total of 2 deposits to 10 weth each + 5 vested yield 
        
        uint256 totalAssets = accountant.totalAssets(); 
        vm.assertApproxEqRel(totalAssets, 25e18, ACCEPTABLE_PRECISION_LOSS); 
        assertLe(totalAssets, 25e18);
    }

    function testDepositsUpdateFirstDepositTimestamp() external {
        uint256 WETHAmount = 10e18;

        //before deposit, last share price is updated
        (, , , uint64 startVestingTimeLast, ) = accountant.vestingState(); 
        assertEq(startVestingTimeLast, block.timestamp);  
            
        skip(1 days); 

        _deposit(WETHAmount, USER);
       
        (, , , uint64 startVestingTimeNow, ) = accountant.vestingState(); 
        assertEq(startVestingTimeLast + 1 days, startVestingTimeNow);  
    }

    function testWithdrawNoYieldStream() external {
        uint256 WETHAmount = 10e18; 
        uint256 shares0 = _deposit(WETHAmount, USER); 
        assertLe(shares0, WETHAmount); 
        _assertExchangeRateVsVirtualSharePrice();

        //deposit 2
        _deposit(WETHAmount, USER); 
        _assertExchangeRateVsVirtualSharePrice();

        uint256 assetsOut = teller.withdraw(WETH, shares0, 0, address(boringVault));   
        assertApproxEqRel(assetsOut, WETHAmount, ACCEPTABLE_PRECISION_LOSS); 
        assertLe(assetsOut, WETHAmount); 
        _assertExchangeRateVsVirtualSharePrice();
    }

    function testWithdrawWithYieldStream() external {
        uint256 WETHAmount = 10e18; 
        uint256 shares0 = _deposit(WETHAmount, USER); 
        assertLe(shares0, WETHAmount); 
        _assertExchangeRateVsVirtualSharePrice();

        //==== Add Vesting Yield Stream ====
        _vestYieldAndSkip(WETHAmount, 24 hours, 12 hours); 
        _assertExchangeRateVsVirtualSharePrice();
        
        //second deposit midstream 
        uint256 shares1 = _deposit(WETHAmount, alice); 
        _assertExchangeRateVsVirtualSharePrice();
        
        //withdraw first deposit 
        uint256 assetsOut0 = teller.withdraw(WETH, shares0, 0, address(boringVault));   
        assertApproxEqRel(assetsOut0, 15e18, ACCEPTABLE_PRECISION_LOSS); 
        assertLe(assetsOut0, 15e18); 
        _assertExchangeRateVsVirtualSharePrice();
        
        //withdraw second deposit
        vm.prank(alice); 
        uint256 assetsOut1 = teller.withdraw(WETH, shares1, 0, address(alice));   
        vm.assertApproxEqRel(assetsOut1, 10e18, ACCEPTABLE_PRECISION_LOSS); 
        assertLe(assetsOut1, WETHAmount); //initial deposit out, no yield was obtained
        _assertExchangeRateVsVirtualSharePrice();
    }

    function testWithdrawWithYieldStreamUser2WaitsForYield() external {
        uint256 WETHAmount = 10e18; 
        uint256 shares0 = _deposit(WETHAmount, USER); 
        assertLe(shares0, WETHAmount); 
        
        //vest some yield
        uint256 yieldAmount = 10e18; 
        _vestYieldAndSkip(yieldAmount, 24 hours, 12 hours); 
        
        //second deposit midstream
        uint256 aliceAmount = 10e18; 
        uint256 shares1 = _deposit(aliceAmount, alice); 
        
        //withdraw user 1 
        uint256 expectedYield = WETHAmount + (yieldAmount / 2); //halfway through stream, so half of yield should be distributed
        uint256 assetsOut0 = teller.withdraw(WETH, shares0, 0, address(boringVault));   
        assertApproxEqRel(assetsOut0, expectedYield, ACCEPTABLE_PRECISION_LOSS); 
        assertLe(assetsOut0, expectedYield); 
        
        skip(12 hours); 
        
        //withdraw 2 after stream ends, rest of yield should be distributed to alice 
        vm.prank(alice); 
        uint256 assetsOut1 = teller.withdraw(WETH, shares1, 0, address(alice));   
        vm.assertApproxEqRel(assetsOut1, expectedYield, ACCEPTABLE_PRECISION_LOSS); 
        assertLe(assetsOut1, expectedYield); 
    }

    function testVestLossAbsorbBuffer() external {
        accountant.updateMaximumDeviationLoss(10_000); 
        uint256 WETHAmount = 10e18; 
        uint256 shares0 = _deposit(WETHAmount, USER); 
        assertLe(shares0, WETHAmount); 
        _assertExchangeRateVsVirtualSharePrice();
        
        //vest yield
        uint256 yieldAmount = 10e18; 
        _vestYieldAndSkip(yieldAmount, 24 hours, 12 hours); 
        _assertExchangeRateVsVirtualSharePrice();
        
        uint256 totalAssetsBeforeLoss = accountant.totalAssets(); 
        uint256 unvested = accountant.getPendingVestingGains(); //5e18 after 12 hours (10 - 5) = 5; 
        
        //post a small loss
        uint256 lossAmount = 2.5e18; 
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
        uint256 expectedYield = WETHAmount + (yieldAmount - lossAmount);   
        uint256 assetsOut = teller.withdraw(WETH, shares0, 0, address(boringVault)); 
        assertApproxEqRel(assetsOut, expectedYield, ACCEPTABLE_PRECISION_LOSS); //10 WETH deposit -> 5 weth is vested -> 2.5 loss -> remaining 2.5 vests over the next 12 hours = total of 17.5 earned
        assertLe(assetsOut, expectedYield); 
        _assertExchangeRateVsVirtualSharePrice();
    }

    function testVestLossAffectsSharePrice() external {
        accountant.updateMaximumDeviationLoss(10_000); 
        uint256 WETHAmount = 10e18; 
        uint256 shares0 = _deposit(WETHAmount, USER);  
        assertLe(shares0, WETHAmount); 
        _assertExchangeRateVsVirtualSharePrice();

        //vest yield
        uint256 yieldAmount = 10e18; 
        _vestYieldAndSkip(yieldAmount, 24 hours, 12 hours);
        _assertExchangeRateVsVirtualSharePrice();

        //total assets = 15
        uint256 expectedTotalAssets = WETHAmount + (yieldAmount / 2); 
        uint256 totalAssetsInBaseBefore = accountant.totalAssets();  
        assertApproxEqRel(totalAssetsInBaseBefore, expectedTotalAssets, ACCEPTABLE_PRECISION_LOSS); 
        assertLe(totalAssetsInBaseBefore, expectedTotalAssets); 
        
        (uint128 lastSharePrice, , , , ) = accountant.vestingState(); 
        uint256 sharePriceInitial = lastSharePrice; 
        
        //post a loss 
        uint256 lossAmount = 15e18; 
        accountant.postLoss(lossAmount); //this moves vested yield -> share price (to protect share price)
        //note: the buffer absorbs the loss, so we're left with 5 remaining (the vested yield)
        _assertExchangeRateVsVirtualSharePrice();
        
        //15 - 15 with (5 unvested remaining) = 5 left

        uint256 totalAssetsInBaseAfter = accountant.totalAssets();  
        
        //vesting gains should be 0
        (, uint128 vestingGains, , , ) = accountant.vestingState(); 
        assertEq(0, vestingGains); 

        //total assets should be 5e18 -> 10 initial, 5 yield, 5 unvested -> 15 weth loss (5 from buffer) -> 15 - 10 = 5 totalAssets remaining
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
        uint256 WETHAmount = 10e18; 
        uint256 shares = _deposit(WETHAmount, USER); 
        assertLe(shares, WETHAmount); 
        
        uint256 yieldAmount = 10e18;  
        _vestYieldAndSkip(yieldAmount, 24 hours, 6 hours); 

        //total should be 10 + (10 / 4) = 2.5
        uint256 expectedTotalAssets = WETHAmount + (yieldAmount / 4); 
        uint256 totalAssets = accountant.totalAssets();  
        assertApproxEqRel(totalAssets, expectedTotalAssets, ACCEPTABLE_PRECISION_LOSS); 
        assertLe(totalAssets, expectedTotalAssets); 
    }

    function testYieldStreamUpdateDuringExistingStream() external {
        uint256 WETHAmount = 10e18; 
        uint256 shares = _deposit(WETHAmount, USER); 
        assertLe(shares, WETHAmount); 
        
        uint256 yieldAmount = 10e18;  
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

        uint256 WETHAmount = 10e18; 
        uint256 shares = _deposit(WETHAmount, USER); 
        assertLe(shares, WETHAmount); 
        
        //vest and skip 1 year
        _vestYieldAndSkip(WETHAmount, 24 hours, 365 days); 
        
        //update the rate
        accountant.updateExchangeRate();  
        
        //check the fees owned 
        (,, uint128 feesOwedInBase,,,,,,,,,) = accountant.accountantState();
        uint256 expectedFees = (WETHAmount * 2) * platformFeeRate / 1e4; // 20 WETH (10 over day 1, 20 over 364 days for total of 2)
        assertApproxEqAbs(feesOwedInBase, expectedFees, 1e15);

        //claim fees
        vm.startPrank(address(boringVault));
        WETH.approve(address(accountant), feesOwedInBase);
        accountant.claimFees(WETH);
        vm.stopPrank();
        
        //verify we got paid
        assertApproxEqRel(WETH.balanceOf(payoutAddress), expectedFees, ACCEPTABLE_PRECISION_LOSS);
        assertLe(WETH.balanceOf(payoutAddress), expectedFees);
    }
    
    function testPerformanceFeesAfterYield() external {
        uint256 performanceFeeRate = 0.1e4; // 10%
    
        uint256 WETHAmount = 10e18;
        _deposit(WETHAmount, USER); 
        _assertExchangeRateVsVirtualSharePrice();
    
        // Record initial state
        (, uint96 initialHighwaterMark, ,,,,,,,,,) = accountant.accountantState();
        (uint128 initialSharePrice,,,,) = accountant.vestingState(); 
        uint256 totalShares = boringVault.totalSupply();
    
        _vestYieldAndSkip(WETHAmount, 24 hours, 1 days); 
        _assertExchangeRateVsVirtualSharePrice();
    
        //update exchange rate to trigger fee calculation
        accountant.updateExchangeRate();
        _assertExchangeRateVsVirtualSharePrice();
    
        (, uint96 nextHighwaterMark, uint128 feesOwedInBase,,,,,,,,,) = accountant.accountantState();
        (uint128 finalSharePrice,,,,) = accountant.vestingState(); 
    
        // Calculate expected performance fees based on SHARE PRICE APPRECIATION
        uint256 sharePriceIncrease = uint256(finalSharePrice - initialSharePrice); 
    
        // The appreciation in value = price increase * total shares / 10^18
        uint256 valueAppreciation = (sharePriceIncrease * totalShares) / 1e18;
    
        // Expected fees = 10% of appreciation
        uint256 expectedPerformanceFees = (valueAppreciation * performanceFeeRate) / 1e4;
        uint256 actualFees = feesOwedInBase;

        uint128 platformFee = 2739726027397260; //1 day of platform fees (10 WETH / 365)
    
        // Allow for small rounding difference
        assertEq(actualFees - platformFee, expectedPerformanceFees, "Performance fees should match share price appreciation");
    
        // Verify high water mark updated
        assertGt(nextHighwaterMark, initialHighwaterMark, "HWM should increase");
        assertEq(uint256(nextHighwaterMark), finalSharePrice, "HWM should equal new share price");
    }

    function testTWASWorksAsExpectedWhenUpdatingYield() external {
        accountant.updateMaximumDeviationYield(500); // 5%
    
        uint256 WETHAmount = 100e18;
        uint256 shares0 = _deposit(WETHAmount, USER);
        assertApproxEqRel(WETHAmount, shares0, ACCEPTABLE_PRECISION_LOSS);
        assertLe(shares0, WETHAmount);
    
        _vestYieldAndSkip(1e18, 1 days, 0); // 1% of vault, don't skip yet
    
        // T=12 hours: Deposit more to change supply
        skip(12 hours);
    
        // Get supply before deposit
        uint256 supplyBefore = boringVault.totalSupply();
        assertApproxEqRel(supplyBefore, 100e18, ACCEPTABLE_PRECISION_LOSS, "Supply should still be ~100e18");
        assertLe(supplyBefore, 100e18);
    
        //will get fewer shares due to yield
        _deposit(100e18, USER);
    
        // Get actual supply after deposit (not exactly 200e18 due to share price)
        uint256 supplyAfter = boringVault.totalSupply();
        assertApproxEqRel(supplyAfter, 199.5e18, 0.01e18, "Supply should be ~199.5e18");
    
        (uint256 cumulative,,) = accountant.supplyObservation();
        uint256 expectedCumulative = supplyBefore * 12 hours; 
        assertApproxEqAbs(cumulative, expectedCumulative, 1e20, "Cumulative should be ~100e18 * 12 hours");
    
        skip(12 hours);
        deal(address(WETH), address(boringVault), WETH.balanceOf(address(boringVault)) + 2e18);
        accountant.vestYield(2e18, 1 days);
    
        // After second vestYield, cumulative should account for actual supply
        (cumulative,,) = accountant.supplyObservation();
        expectedCumulative = (supplyBefore * 12 hours) + (supplyAfter * 12 hours);
        assertApproxEqAbs(cumulative, expectedCumulative, 1e20, "Cumulative should match actual supply changes");
    
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
        uint256 shares0 = _deposit(WETHAmount, USER);
        assertApproxEqRel(WETHAmount, shares0, ACCEPTABLE_PRECISION_LOSS);
        assertLe(shares0, WETHAmount);
    
        _vestYieldAndSkip(1e18, 1 days, 0); // 1% of vault, don't skip yet
    
        // T=12 hours: Deposit more to change supply
        skip(12 hours);
    
        // Get supply before deposit
        uint256 supplyBefore = boringVault.totalSupply();
        assertApproxEqRel(supplyBefore, 100e18, ACCEPTABLE_PRECISION_LOSS, "Supply should still be ~100e18");
        assertLe(supplyBefore, 100e18);
    
        //will get fewer shares due to yield
        _deposit(100e18, USER);
    
        // Get actual supply after deposit (not exactly 200e18 due to share price)
        uint256 supplyAfter = boringVault.totalSupply();
        assertApproxEqRel(supplyAfter, 199.5e18, 0.01e18, "Supply should be ~199.5e18");
    
        (uint256 cumulativeBefore, uint256 cumulativeLastBefore,) = accountant.supplyObservation();
        uint256 expectedCumulative = supplyBefore * 12 hours;
        assertApproxEqAbs(cumulativeBefore, expectedCumulative, 1e20, "Cumulative should be ~100e18 * 12 hours");
        

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
        vm.expectEmit(address(accountant));
        emit Paused();

        accountant.postLoss(10e18);
    }

    // ========================= EDGE CASES ===============================
    
    function testDonationsShouldNotBeConsideredInCalculations() external {
        uint256 WETHAmount = 10e18; 
        uint256 shares0 = _deposit(WETHAmount, USER); 
        assertLe(shares0, WETHAmount); 
        
        //vest some yield 
        uint256 yieldAmount = 10e18; 
        _vestYieldAndSkip(yieldAmount, 24 hours, 12 hours); 
        
        deal(address(WETH), alice, 10e18); 
        vm.prank(alice);
        WETH.transfer(address(boringVault), 10e18); 

        //deposit 2 uint256 shares1 = teller.deposit(WETH, WETHAmount, 0);
        uint256 expectedTotalAssets = WETHAmount + (yieldAmount / 2); 
        uint256 totalAssets = accountant.totalAssets(); 
        vm.assertApproxEqRel(totalAssets, expectedTotalAssets, ACCEPTABLE_PRECISION_LOSS); 
        assertLe(totalAssets, expectedTotalAssets); 
        
        uint256 expectedAssetsOut = WETHAmount + (yieldAmount / 2); 
        uint256 assetsOut = teller.withdraw(WETH, shares0, 0, address(boringVault));   
        assertApproxEqRel(assetsOut, expectedAssetsOut, ACCEPTABLE_PRECISION_LOSS); 
        assertLe(assetsOut, expectedAssetsOut); 
    }

    function testDoubleDepositInSameBlock() external {
        uint256 WETHAmount0 = 10e18; 
        uint256 shares0 = _deposit(WETHAmount0, USER);
        assertLe(shares0, WETHAmount0); 
        
        uint256 WETHAmount1 = 10e18;
        uint256 shares1 = _deposit(WETHAmount1, USER);
        assertApproxEqRel(WETHAmount1, shares1, ACCEPTABLE_PRECISION_LOSS);
        assertLe(shares1, WETHAmount1);
        
        uint256 currentShares = boringVault.totalSupply();
        (uint128 lsp, , , ,) = accountant.vestingState();
        uint256 lastSharePrice = uint256(lsp);
        uint256 totalAssetsInBase = ((currentShares * lastSharePrice) / 1e18) + accountant.getPendingVestingGains(); 
        uint256 expectedTotalAssets = WETHAmount0 + WETHAmount1; 
        assertApproxEqRel(totalAssetsInBase, expectedTotalAssets, ACCEPTABLE_PRECISION_LOSS); 
        assertLe(totalAssetsInBase, expectedTotalAssets);
    }

    function testDoubleDepositInSameBlockAfterYieldEvent() external {
        uint256 WETHAmount = 10e18; 
        uint256 shares0 = _deposit(WETHAmount, USER);  
        assertLe(shares0, WETHAmount); 

        //vest some yield
        uint256 yieldAmount = 10e18;
        _vestYieldAndSkip(yieldAmount, 24 hours, 12 hours);
        
        //double deposit -> alice, bill both deposit in the same block 
        uint256 sharesAlice = _deposit(WETHAmount, alice); 
        uint256 sharesBill  = _deposit(WETHAmount, bill); 

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
        uint256 shares0 = _deposit(WETHAmount, USER); 
        assertLe(shares0, WETHAmount); 

        //vest some yield
        uint256 yieldAmount = 10e18;
        _vestYieldAndSkip(yieldAmount, 24 hours, 12 hours);
        
        //double deposit -> alice, bill both deposit in the same block 
        uint256 sharesAlice = _deposit(WETHAmount, alice);
        
        //bill deposits before alice withdraws
        _deposit(WETHAmount, bill); 

        //alice withdraws
        vm.prank(alice); 
        uint256 assetsOutAlice = teller.withdraw(WETH, sharesAlice, 0, address(boringVault));   
        
        assertApproxEqRel(assetsOutAlice, WETHAmount, ACCEPTABLE_PRECISION_LOSS); 
        assertLe(assetsOutAlice, WETHAmount); 
    }

    function testLoopDepositWithdrawDepositDuringVest() external {
        uint256 WETHAmount = 10e18; 
        uint256 shares0 = _deposit(WETHAmount, USER); 
        assertLe(shares0, WETHAmount); 

        //vest some yield
        uint256 yieldAmount = 10e18; 
        _vestYieldAndSkip(yieldAmount, 24 hours, 12 hours); 
        
        uint256 sharesAlice = _deposit(WETHAmount, alice); 
        
        //alice withdraws
        vm.prank(alice); 
        uint256 assetsOutAlice = teller.withdraw(WETH, sharesAlice, 0, address(boringVault));   
        assertLt(assetsOutAlice, WETHAmount); 

        uint256 sharesBill = _deposit(WETHAmount, bill); 

        vm.prank(bill); 
        uint256 assetsOutBill = teller.withdraw(WETH, sharesBill, 0, address(boringVault));   
        assertApproxEqRel(WETHAmount, assetsOutBill, ACCEPTABLE_PRECISION_LOSS);
        assertLe(assetsOutBill, WETHAmount);
    }

    function testDepositDuringSameBlockAsYieldIsDeposited() external {
        uint256 WETHAmount = 10e18; 
        uint256 shares0 = _deposit(WETHAmount, USER); 
        assertLe(shares0, WETHAmount); 

        //vest some yield
        deal(address(WETH), address(boringVault), WETHAmount * 2);
        accountant.vestYield(WETHAmount, 24 hours); 
        
        uint256 sharesAlice = _deposit(WETHAmount, alice); 

        //alice withdraws
        vm.prank(alice); 
        uint256 assetsOutAlice = teller.withdraw(WETH, sharesAlice, 0, address(boringVault));   

        assertLe(assetsOutAlice, WETHAmount); //assert slight dilution, no extra yield
    }

    function testRoundingIssuesAfterYieldStreamEndsNoFuzz() external {
        uint256 WETHAmount = 1e18; 
        uint256 shares0 = _deposit(WETHAmount, USER); 
        assertLe(shares0, WETHAmount); 

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

        uint256 assetsOut = teller.withdraw(WETH, shares1, 0, address(this));
        assertLt(assetsOut, depositAmount, "should not profit");
    }

    // ========================= REVERT TESTS / FAILURE CASES ===============================
    
    function testVestYieldCannotExceedMaximumDuration() external {
        //by default, maximum duration is 7 days
        uint256 WETHAmount = 10e18; 
        _deposit(WETHAmount, USER); 

        //vest some yield
        deal(address(WETH), address(boringVault), WETHAmount * 2);
        vm.expectRevert(AccountantWithYieldStreaming.AccountantWithYieldStreaming__DurationExceedsMaximum.selector); 
        accountant.vestYield(WETHAmount, 7 days + 1 hours); 
    }

    function testVestYieldUnderMinimumDuration() external {
        //by default, maximum duration is 7 days
        uint256 WETHAmount = 10e18; 
        _deposit(WETHAmount, USER); 

        //vest some yield
        deal(address(WETH), address(boringVault), WETHAmount * 2);
        vm.expectRevert(AccountantWithYieldStreaming.AccountantWithYieldStreaming__DurationUnderMinimum.selector); 
        accountant.vestYield(WETHAmount, 23 hours); 
    }

    function testVestYieldZeroAmount() external {
        //by default, maximum duration is 7 days
        uint256 WETHAmount = 10e18; 
        _deposit(WETHAmount, USER); 

        //vest some yield
        deal(address(WETH), address(boringVault), WETHAmount * 2);
        vm.expectRevert(AccountantWithYieldStreaming.AccountantWithYieldStreaming__ZeroYieldUpdate.selector); 
        accountant.vestYield(0, 24 hours); 
    }

    // ========================= FUZZ TESTS ===============================
    
    function testFuzzDepositsWithNoYield(uint96 WETHAmount0, uint96 WETHAmount1) external {
        WETHAmount0 = uint96(bound(WETHAmount0, 1e13, 1e26)); 
        WETHAmount1 = uint96(bound(WETHAmount1, 1e13, 1e26)); 
        
        uint256 shares0 = _deposit(WETHAmount0, USER); 
        assertApproxEqRel(shares0, WETHAmount0, ACCEPTABLE_PRECISION_LOSS, "should be almost equal"); 
        assertLe(shares0, WETHAmount0); 
        _assertExchangeRateVsVirtualSharePrice();

        uint256 shares1 = _deposit(WETHAmount1, USER); 
        assertApproxEqRel(shares1, WETHAmount1, ACCEPTABLE_PRECISION_LOSS, "should be almost equal"); 
        assertLe(shares1, WETHAmount1); 
        _assertExchangeRateVsVirtualSharePrice();

        uint256 totalAssetsAfter = accountant.totalAssets();         
        assertApproxEqRel(totalAssetsAfter, uint256(WETHAmount0) + uint256(WETHAmount1), ACCEPTABLE_PRECISION_LOSS, "total assets mismatch"); 
        assertLe(totalAssetsAfter, uint256(WETHAmount0) + uint256(WETHAmount1)); 
    }

    function testFuzzDepositsWithYield(uint96 WETHAmount0, uint96 WETHAmount1, uint96 yieldVestAmount) external {
        accountant.updateMaximumDeviationYield(5000000);
        
        WETHAmount0 = uint96(bound(WETHAmount0, 1e18, 10e24)); 
        WETHAmount1 = uint96(bound(WETHAmount1, 1e18, 10e24)); 
        yieldVestAmount = uint96(bound(yieldVestAmount, 1e18, WETHAmount0 * 100)); 

        uint256 shares0 = _deposit(WETHAmount0, USER); 
        
        //first deposit should be 1:1 at initial rate
        assertApproxEqRel(shares0, WETHAmount0, ACCEPTABLE_PRECISION_LOSS, "First deposit should be close to 1:1");
        assertLe(shares0, WETHAmount0, "Less than deposit by slight amount");
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

        uint256 sharePrice = totalValueInVault.mulDivDown(1e18, totalSharesBefore);
        assertEq(sharePrice, accountant.getRate());  
        
        uint256 expectedShares1 = uint256(WETHAmount1).mulDivDown(1e18, sharePrice + 1); //account for rounding

        //when calling deposit, the rate is updated before getting the rate 
        //rate before deposit should be totalassets * 1e18 / shares0  where totalassets == (last share price * shares0) / 1e18
        
        uint256 shares1 = _deposit(WETHAmount1, USER); 
        _assertExchangeRateVsVirtualSharePrice();
        
        //check total assets after
        uint256 totalAssetsAfter = accountant.totalAssets();
        uint256 expectedTotalAssets = (shares0 + expectedShares1).mulDivDown(sharePrice, 1e18) + accountant.getPendingVestingGains(); //verify the total assets == amount of shares
        assertApproxEqAbs(totalAssetsAfter, expectedTotalAssets, 1, "Total assets mismatch");
        assertLe(totalAssetsAfter, expectedTotalAssets);  
        
        // === VERIFY ===
        assertApproxEqRel(shares1, expectedShares1, ACCEPTABLE_PRECISION_LOSS, "Second deposit shares mismatch");
        assertLe(shares1, expectedShares1, "shares mismatch");  
    }

    function testFuzzWithdrawWithYield(uint96 WETHAmount0, uint96 WETHAmount1, uint96 yieldVestAmount) external {
        accountant.updateMaximumDeviationYield(5000000);
        
        WETHAmount0 = uint96(bound(WETHAmount0, 1e18, 1e26)); 
        WETHAmount1 = uint96(bound(WETHAmount1, 1e18, 1e26)); 
        yieldVestAmount = uint96(bound(yieldVestAmount, 1e13, WETHAmount0 * 500 / 10_000)); 

        //first deposit 
        uint256 shares0 = _deposit(WETHAmount0, USER); 
        assertLe(shares0, WETHAmount0); 
        _assertExchangeRateVsVirtualSharePrice();
        
        _vestYieldAndSkip(yieldVestAmount, 24 hours, 12 hours); 
        _assertExchangeRateVsVirtualSharePrice();
        
        //second deposit
        uint256 expectedVestedYield = yieldVestAmount / 2;
        deal(address(WETH), address(this), WETHAmount1);
        uint256 shares1 = _deposit(WETHAmount1, USER);
        _assertExchangeRateVsVirtualSharePrice();

        // === CHECK WITHDRAW AMOUNTS ===
        
        // get current rate after deposits and vesting
        uint256 currentRate = accountant.getRate();
        
        
        //make sure the vault has the funds
        deal(address(WETH), address(boringVault), yieldVestAmount + WETHAmount0 + WETHAmount1); 

        //first depositor withdraws half their shares
        uint256 sharesToWithdraw0 = shares0 / 2;
        uint256 expectedWithdrawAmount0 = sharesToWithdraw0.mulDivDown(currentRate, 1e18);
        
        //approve shares for withdrawal
        uint256 actualWithdrawn0 = teller.withdraw(WETH, sharesToWithdraw0, 0, address(this)); 
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
        uint256 firstDepositorExpectedValue = (WETHAmount0 + expectedVestedYield) / 2; // They withdraw half
        assertApproxEqRel(
            actualWithdrawn0,
            firstDepositorExpectedValue,
            ACCEPTABLE_PRECISION_LOSS,
            "First depositor should get principal + yield share"
        );
        assertLe(actualWithdrawn0, firstDepositorExpectedValue, "first deposit actual withdrawn > first depositor expected value"); 
        
        //second depositor withdraws all their shares
        uint256 rateBeforeWithdraw1 = accountant.getRate(); //rate changes due to the withdraw
        uint256 expectedWithdrawAmount1 = shares1.mulDivDown(rateBeforeWithdraw1, 1e18);
        uint256 actualWithdrawn1 = teller.withdraw(WETH, shares1, 0, address(this));
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
            WETHAmount1,
            ACCEPTABLE_PRECISION_LOSS,
            "Second depositor should get back their deposit"
        );
        assertLe(actualWithdrawn1, WETHAmount1, "second deposit > weth amount"); 
    }

    function testRoundingIssuesAfterYieldStreamEndsFuzz(uint96 WETHAmount0, uint96 WETHAmount1) external {
        WETHAmount0 = uint96(bound(WETHAmount0, 1, 1e18)); //bound to small amounts
        WETHAmount1 = uint96(bound(WETHAmount1, 1e13, 1e24)); 

        uint256 shares0 = _deposit(WETHAmount0, USER);
        assertLe(shares0, WETHAmount0); 
        _assertExchangeRateVsVirtualSharePrice();

        // use a yield that's safely under the limit (e.g., 5%)
        uint256 yieldAmount = uint256(WETHAmount0) * 500 / 10_000;

        // Ensure yield is at least 1 to be meaningful
        vm.assume(yieldAmount > 0);

        //vest some yield
        _vestYieldAndSkip(yieldAmount, 24 hours, 23 hours); 
        _assertExchangeRateVsVirtualSharePrice();

        accountant.updateExchangeRate();
        _assertExchangeRateVsVirtualSharePrice();
        
        //make sure the vault has enough funds to fund withdraws
        deal(address(WETH), address(boringVault), WETHAmount0 + WETHAmount1 + yieldAmount);

        //now the state of the contract should be 
        //totalSupply > 1
        //exchange rate > 1 
        
        //second deposit
        uint256 shares1 = _deposit(WETHAmount1, USER);
        _assertExchangeRateVsVirtualSharePrice();

        //check rate AFTER deposit
        boringVault.approve(address(teller), shares1);
        uint256 assetsOut = teller.withdraw(WETH, shares1, 0, address(this));
        assertLe(assetsOut, WETHAmount1, "should not profit");
        _assertExchangeRateVsVirtualSharePrice();
    }

    function testRoundingIssuesAfterYieldStreamAlmostEndsMinorWeiVestFuzz(uint96 WETHAmount0, uint96 WETHAmount1, uint256 yieldAmount) external {
        WETHAmount0 = uint96(bound(WETHAmount0, 1, 1e18));
        WETHAmount1 = uint96(bound(WETHAmount1, 1e13, 1e23)); 
        yieldAmount = uint256(bound(yieldAmount, 1e13, 1e17)); 

        uint256 shares0 = _deposit(WETHAmount0, USER);
        assertLe(shares0, WETHAmount0); 
        _assertExchangeRateVsVirtualSharePrice();

        // Use a yield that's safely under the limit (e.g., 5%)
        if (yieldAmount > uint256(WETHAmount0) * 500 / 10_000) { 
            yieldAmount = uint256(WETHAmount0) * 500 / 10_000;
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

        deal(address(WETH), address(this), WETHAmount1);
        uint256 shares1 = _deposit(WETHAmount1, USER);
        _assertExchangeRateVsVirtualSharePrice();

        //check rate AFTER deposit
        uint256 assetsOut = teller.withdraw(WETH, shares1, 0, address(this));
        assertLe(assetsOut, WETHAmount1, "should not profit");
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
        depositAmount = uint96(bound(depositAmount, 2, 1e24)); // 2 wei to 1M WETH
        yieldAmount = uint96(bound(yieldAmount, 1, depositAmount)); // Up to 100% yield
        vestDuration = uint64(bound(vestDuration, 1 days, 7 days));
        timeElapsed = uint64(bound(timeElapsed, 0, vestDuration));
        
        // Initial deposit
        uint256 shares0 = _deposit(depositAmount, USER);
        _assertExchangeRateVsVirtualSharePrice();
        
        // Vest yield
        deal(address(WETH), address(boringVault), uint256(depositAmount) + uint256(yieldAmount) * 2);
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
            teller.withdraw(WETH, sharesToWithdraw, 0, address(this));
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
        depositAmount = uint96(bound(depositAmount, 2, 1e24));
        yieldAmount = uint96(bound(yieldAmount, 1, depositAmount));
        lossAmount = uint96(bound(lossAmount, 1, yieldAmount)); // Loss <= yield to avoid pause
        
        // Initial deposit
        _deposit(depositAmount, USER);
        _assertExchangeRateVsVirtualSharePrice();
        
        // Vest yield
        deal(address(WETH), address(boringVault), uint256(depositAmount) + uint256(yieldAmount) * 2);
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
        depositAmount = uint96(bound(depositAmount, 2, 1e24));
        yield1 = uint96(bound(yield1, 1, depositAmount));
        yield2 = uint96(bound(yield2, 1, depositAmount));
        yield3 = uint96(bound(yield3, 1, depositAmount));
        
        // Initial deposit
        _deposit(depositAmount, USER);
        _assertExchangeRateVsVirtualSharePrice();
        
        // First yield vest
        deal(address(WETH), address(boringVault), depositAmount + yield1 + yield2 + yield3);
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
        uint256 WETHAmount = amount; 
        vm.startPrank(user);
        deal(address(WETH), user, amount);
        WETH.approve(address(boringVault), amount);
        uint256 shares = teller.deposit(WETH, WETHAmount, 0, referrer);
        vm.stopPrank(); 
        return shares; 
    }

    function _vestYieldAndSkip(uint256 amount, uint256 duration, uint256 skipDuration) internal {
        deal(address(WETH), address(boringVault), amount * 2); //give the vault funds for withdraw + buffer
        accountant.vestYield(amount, duration); 
        skip(skipDuration); 
    }
}
