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
import {TestActors} from "test/resources/TestActors.t.sol";
import {RolesConstants} from "test/resources/RolesConstants.t.sol";

contract AccountantWithYieldStreamingDepositWithdraw is Test, TestActors, RolesConstants, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    struct VaultComponents {
        BoringVault vault;
        AccountantWithYieldStreaming accountant;
        TellerWithYieldStreaming teller;
    }

    VaultComponents public vaultWETH;
    VaultComponents public vaultUSDC;
    VaultComponents public vaultWBTC;
    RolesAuthority public rolesAuthority;

    ERC20 internal WETH;
    ERC20 internal USDC;
    ERC20 internal WBTC;

    // Keep legacy variables for backward compatibility with existing tests
    BoringVault public boringVault;
    AccountantWithYieldStreaming public accountant; 
    TellerWithYieldStreaming public teller;

    // Using storage to avoid stack too deep errors
    uint256 expectedAliceUSDCBalance;
    uint256 aliceShares;
    uint256 totalSupplyAfterAliceDeposit;
    uint256 billShares;
    uint256 expectedBillUSDCBalance;
    uint256 charlieShares;
    uint256 davidShares;

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 23039901;
        _startFork(rpcKey, blockNumber);

        WETH = getERC20(sourceChain, "WETH");
        USDC = getERC20(sourceChain, "USDC");
        WBTC = getERC20(sourceChain, "WBTC");

        // Create shared roles authority
        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));

        // Deploy and setup vaults for each asset
        vaultWETH = _deployAndSetupVault(WETH, 18, "Boring Vault WETH", "BV-WETH");
        vaultUSDC = _deployAndSetupVault(USDC, 6, "Boring Vault USDC", "BV-USDC");
        vaultWBTC = _deployAndSetupVault(WBTC, 8, "Boring Vault WBTC", "BV-WBTC");

        // Set legacy variables to WETH vault for backward compatibility
        boringVault = vaultWETH.vault;
        accountant = vaultWETH.accountant;
        teller = vaultWETH.teller;
    }

    function _deployAndSetupVault(
        ERC20 asset,
        uint8 decimals,
        string memory vaultName,
        string memory vaultSymbol
    ) internal returns (VaultComponents memory) {
        BoringVault vault = new BoringVault(address(this), vaultName, vaultSymbol, decimals);
        
        // Calculate initial exchange rate based on decimals (1e18 for 18 decimals, scaled for others)
        uint96 initialExchangeRate = uint96(10 ** decimals);
        
        AccountantWithYieldStreaming accountant_ = new AccountantWithYieldStreaming(
            address(this), address(vault), payoutAddress, initialExchangeRate, address(asset), 1.001e4, 0.999e4, 1, 0.1e4, 0.1e4
        );
        TellerWithYieldStreaming teller_ =
            new TellerWithYieldStreaming(address(this), address(vault), address(accountant_), address(asset));

        accountant_.setAuthority(rolesAuthority);
        teller_.setAuthority(rolesAuthority);
        vault.setAuthority(rolesAuthority);

        // Setup roles authority.
        rolesAuthority.setRoleCapability(MINTER_ROLE, address(vault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(vault), BoringVault.exit.selector, true);
        rolesAuthority.setRoleCapability(MINTER_ROLE, address(accountant_), AccountantWithYieldStreaming.setFirstDepositTimestamp.selector, true);
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(accountant_), AccountantWithRateProviders.pause.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(accountant_), AccountantWithRateProviders.unpause.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(accountant_), AccountantWithRateProviders.updateDelay.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(accountant_), AccountantWithRateProviders.updateUpper.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(accountant_), AccountantWithRateProviders.updateLower.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(accountant_), AccountantWithRateProviders.updatePlatformFee.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(accountant_), AccountantWithRateProviders.updatePayoutAddress.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(accountant_), AccountantWithRateProviders.setRateProviderData.selector, true
        );
        rolesAuthority.setRoleCapability(
            UPDATE_EXCHANGE_RATE_ROLE,
            address(accountant_),
            AccountantWithRateProviders.updateExchangeRate.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            BORING_VAULT_ROLE, address(accountant_), AccountantWithRateProviders.claimFees.selector, true
        );
        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE, address(accountant_), AccountantWithYieldStreaming.vestYield.selector, true
        );
        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE, address(accountant_), AccountantWithYieldStreaming.postLoss.selector, true
        );
        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE, address(accountant_), bytes4(keccak256("updateExchangeRate()")), true
        );
        rolesAuthority.setRoleCapability(
            MINTER_ROLE, address(accountant_), bytes4(keccak256("updateCumulative()")), true
        );
        rolesAuthority.setPublicCapability(address(teller_), TellerWithMultiAssetSupport.deposit.selector, true);
        rolesAuthority.setPublicCapability(
            address(teller_), TellerWithMultiAssetSupport.depositWithPermit.selector, true
        );
        rolesAuthority.setPublicCapability(address(teller_), TellerWithYieldStreaming.withdraw.selector, true);

        // Allow the boring vault to receive ETH.
        rolesAuthority.setPublicCapability(address(vault), bytes4(0), true);

        rolesAuthority.setUserRole(address(this), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(this), UPDATE_EXCHANGE_RATE_ROLE, true);
        rolesAuthority.setUserRole(address(vault), BORING_VAULT_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(teller_), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller_), BURNER_ROLE, true);
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(teller_), STRATEGIST_ROLE, true);
       
        teller_.updateAssetData(asset, true, true, 0);

        accountant_.updateMaximumDeviationYield(50000); //500% allowable (for testing)

        return VaultComponents({
            vault: vault,
            accountant: accountant_,
            teller: teller_
        });
    }
    // possible states of yield streaming:
    // 1. No yield has been streamed yet
    // 2. Yield has been streamed for less than the vesting period -- assume share price starts vesting period at 1 and after its above 1
    // 3. Yield has been streamed for the full vesting period and no new one has been started -- assume share price is above 1
    // 4. Yield has been streamed for the full vesting period and a new one has been started after some gap -- assume share price is above 1

    // possible assets:
    // a. USDC
    // b. WBTC
    // c. WETH

    // 1a
    function testNoYieldStreamedUSDCDepositWithdraw(uint96 USDCAmount, uint96 secondUSDCAmount) external {
        // Case 1: No yield has been streamed yet, asset: USDC
        USDCAmount = uint96(bound(USDCAmount, 1, 1e18));
        secondUSDCAmount = uint96(bound(secondUSDCAmount, 1, 1e18));
        deal(address(USDC), address(this), USDCAmount);
        USDC.approve(address(vaultUSDC.vault), type(uint256).max);
        vaultUSDC.teller.deposit(USDC, USDCAmount, 0, referrer);

        // No yield
        // vaultUSDC.accountant.vestYield(...) is intentionally omitted
        vaultUSDC.accountant.updateExchangeRate();

        // Second Depositor deposits
        deal(address(USDC), address(this), secondUSDCAmount);
        uint256 secondDepositorShares = vaultUSDC.teller.deposit(USDC, secondUSDCAmount, 0, referrer);

        vaultUSDC.vault.approve(address(vaultUSDC.teller), secondDepositorShares);
        uint256 assetsOut = vaultUSDC.teller.withdraw(USDC, secondDepositorShares, 0, address(this));

        // Withdrawn amount should be less than or equal to the deposited amount (with no yield and no fee, this should be exactly equal unless there's rounding)
        assertLe(assetsOut, secondUSDCAmount, "Second depositor should not profit");
    }

    // 1b
    function testNoYieldStreamedWBTCDepositWithdraw(uint96 WBTCAmount, uint96 secondWBTCAmount) external {
        // Case 1: No yield has been streamed yet, asset: WBTC
        WBTCAmount = uint96(bound(WBTCAmount, 1, 1e18));
        secondWBTCAmount = uint96(bound(secondWBTCAmount, 1, 1e18));
        deal(address(WBTC), address(this), WBTCAmount);
        WBTC.approve(address(vaultWBTC.vault), type(uint256).max);
        vaultWBTC.teller.deposit(WBTC, WBTCAmount, 0, referrer);

        // No yield
        // vaultWBTC.accountant.vestYield(...) is intentionally omitted
        vaultWBTC.accountant.updateExchangeRate();

        // Second Depositor deposits
        deal(address(WBTC), address(this), secondWBTCAmount);
        uint256 secondDepositorShares = vaultWBTC.teller.deposit(WBTC, secondWBTCAmount, 0, referrer);

        vaultWBTC.vault.approve(address(vaultWBTC.teller), secondDepositorShares);
        uint256 assetsOut = vaultWBTC.teller.withdraw(WBTC, secondDepositorShares, 0, address(this));

        // Withdrawn amount should be less than or equal to the deposited amount (with no yield and no fee, this should be exactly equal unless there's rounding)
        assertLe(assetsOut, secondWBTCAmount, "Second depositor should not profit");
    }

    // 1c
    function testNoYieldStreamedWETHDepositWithdraw(uint96 WETHAmount, uint96 secondWETHAmount) external {
        // Case 1: No yield has been streamed yet, asset: WETH
        WETHAmount = uint96(bound(WETHAmount, 1, 2e27));
        secondWETHAmount = uint96(bound(secondWETHAmount, 1, 2e27));
        deal(address(WETH), address(this), WETHAmount);
        WETH.approve(address(vaultWETH.vault), type(uint256).max);
        vaultWETH.teller.deposit(WETH, WETHAmount, 0, referrer);

        // No yield
        // vaultWETH.accountant.vestYield(...) is intentionally omitted
        vaultWETH.accountant.updateExchangeRate();

        // Second Depositor deposits
        deal(address(WETH), address(this), secondWETHAmount);
        uint256 secondDepositorShares = vaultWETH.teller.deposit(WETH, secondWETHAmount, 0, referrer);

        vaultWETH.vault.approve(address(vaultWETH.teller), secondDepositorShares);
        uint256 assetsOut = vaultWETH.teller.withdraw(WETH, secondDepositorShares, 0, address(this));

        // Withdrawn amount should be less than or equal to the deposited amount (with no yield and no fee, this should be exactly equal unless there's rounding)
        assertLe(assetsOut, secondWETHAmount, "Second depositor should not profit");
    }

    // 2a
    function testPartialYieldStreamedUSDCDepositWithdraw(uint96 USDCAmount, uint96 secondDepositAmount) external {
        // Case 2: Yield has been streamed for less than the vesting period, asset: USDC
        USDCAmount = uint96(bound(USDCAmount, 1, 1e18));
        secondDepositAmount = uint96(bound(secondDepositAmount, 2, 1e18)); 
        deal(address(USDC), address(this), USDCAmount);
        USDC.approve(address(vaultUSDC.vault), type(uint256).max);
        vaultUSDC.teller.deposit(USDC, USDCAmount, 0, referrer);

        // Use a yield that's safely under the limit (e.g., 5%)
        uint256 yieldAmount = uint256(USDCAmount) * 500 / 10_000;

        // Ensure yield is at least 1 to be meaningful
        vm.assume(yieldAmount > 0);

        //vest some yield
        deal(address(USDC), address(vaultUSDC.vault), secondDepositAmount * 2);
        vaultUSDC.accountant.vestYield(yieldAmount, 24 hours); 

        // Skip less than the full vesting period (12 hours instead of 24)
        skip(12 hours);

        vaultUSDC.accountant.updateExchangeRate();

        //now the state of the contract should be 
        //totalSupply > 1
        //exchange rate > 1 (but still vesting, not fully vested)

        // Second Depositor deposits
        deal(address(USDC), address(this), secondDepositAmount);
        uint256 secondDepositorShares = vaultUSDC.teller.deposit(USDC, secondDepositAmount, 0, referrer);

        vaultUSDC.vault.approve(address(vaultUSDC.teller), secondDepositorShares);
        uint256 assetsOut = vaultUSDC.teller.withdraw(USDC, secondDepositorShares, 0, address(this));

        // Withdrawn amount should be less than or equal to the deposited amount
        assertLe(assetsOut, secondDepositAmount, "Second depositor should not profit");
    }

    // 2b
    function testPartialYieldStreamedWBTCDepositWithdraw(uint96 WBTCAmount, uint96 secondDepositAmount) external {
        // Case 2: Yield has been streamed for less than the vesting period, asset: WBTC
        WBTCAmount = uint96(bound(WBTCAmount, 1, 1e18));
        secondDepositAmount = uint96(bound(secondDepositAmount, 2, 1e18)); 
        deal(address(WBTC), address(this), WBTCAmount);
        WBTC.approve(address(vaultWBTC.vault), type(uint256).max);
        vaultWBTC.teller.deposit(WBTC, WBTCAmount, 0, referrer);

        // Use a yield that's safely under the limit (e.g., 5%)
        uint256 yieldAmount = uint256(WBTCAmount) * 500 / 10_000;

        // Ensure yield is at least 1 to be meaningful
        vm.assume(yieldAmount > 0);

        //vest some yield
        deal(address(WBTC), address(vaultWBTC.vault), secondDepositAmount * 2);
        vaultWBTC.accountant.vestYield(yieldAmount, 24 hours); 

        // Skip less than the full vesting period (12 hours instead of 24)
        skip(12 hours);

        vaultWBTC.accountant.updateExchangeRate();

        //now the state of the contract should be 
        //totalSupply > 1
        //exchange rate > 1 (but still vesting, not fully vested)

        // Second Depositor deposits
        deal(address(WBTC), address(this), secondDepositAmount);
        uint256 secondDepositorShares = vaultWBTC.teller.deposit(WBTC, secondDepositAmount, 0, referrer);

        vaultWBTC.vault.approve(address(vaultWBTC.teller), secondDepositorShares);
        uint256 assetsOut = vaultWBTC.teller.withdraw(WBTC, secondDepositorShares, 0, address(this));

        // Withdrawn amount should be less than or equal to the deposited amount
        assertLe(assetsOut, secondDepositAmount, "Second depositor should not profit");
    }

    // 2c
    function testPartialYieldStreamedWETHDepositWithdraw(uint96 WETHAmount, uint96 secondDepositAmount) external {
        // Case 2: Yield has been streamed for less than the vesting period, asset: WETH
        WETHAmount = uint96(bound(WETHAmount, 1, 2e27));
        secondDepositAmount = uint96(bound(secondDepositAmount, 2, 2e27)); 
        deal(address(WETH), address(this), WETHAmount);
        WETH.approve(address(vaultWETH.vault), type(uint256).max);
        vaultWETH.teller.deposit(WETH, WETHAmount, 0, referrer);

        // Use a yield that's safely under the limit (e.g., 5%)
        uint256 yieldAmount = uint256(WETHAmount) * 500 / 10_000;

        // Ensure yield is at least 1 to be meaningful
        vm.assume(yieldAmount > 0);

        //vest some yield
        deal(address(WETH), address(vaultWETH.vault), secondDepositAmount * 2);
        vaultWETH.accountant.vestYield(yieldAmount, 24 hours); 

        // Skip less than the full vesting period (12 hours instead of 24)
        skip(12 hours);

        vaultWETH.accountant.updateExchangeRate();

        //now the state of the contract should be 
        //totalSupply > 1
        //exchange rate > 1 (but still vesting, not fully vested)

        // Second Depositor deposits
        deal(address(WETH), address(this), secondDepositAmount);
        uint256 secondDepositorShares = vaultWETH.teller.deposit(WETH, secondDepositAmount, 0, referrer);

        vaultWETH.vault.approve(address(vaultWETH.teller), secondDepositorShares);
        uint256 assetsOut = vaultWETH.teller.withdraw(WETH, secondDepositorShares, 0, address(this));

        // Withdrawn amount should be less than or equal to the deposited amount
        assertLe(assetsOut, secondDepositAmount, "Second depositor should not profit");
    }

    // 3a
    function testYieldStreamedUSDCDepositWithdraw(uint96 USDCAmount, uint96 secondDepositAmount) external {
        // Case 3: Yield has been streamed for the full vesting period and no new one has been started, asset: USDC
        USDCAmount = uint96(bound(USDCAmount, 1, 1e18));
        secondDepositAmount = uint96(bound(secondDepositAmount, 2, 1e18)); 
        deal(address(USDC), address(this), USDCAmount);
        USDC.approve(address(vaultUSDC.vault), type(uint256).max);
        vaultUSDC.teller.deposit(USDC, USDCAmount, 0, referrer);

        // Use a yield that's safely under the limit (e.g., 5%)
        uint256 yieldAmount = uint256(USDCAmount) * 500 / 10_000;

        // Ensure yield is at least 1 to be meaningful
        vm.assume(yieldAmount > 0);

        //vest some yield
        deal(address(USDC), address(vaultUSDC.vault), secondDepositAmount * 2);
        vaultUSDC.accountant.vestYield(yieldAmount, 24 hours); 

        skip(24 hours);

        vaultUSDC.accountant.updateExchangeRate();

        //now the state of the contract should be 
        //totalSupply > 1
        //exchange rate > 1 

        // Second Depositor deposits
        deal(address(USDC), address(this), secondDepositAmount);
        uint256 secondDepositorShares = vaultUSDC.teller.deposit(USDC, secondDepositAmount, 0, referrer);

        vaultUSDC.vault.approve(address(vaultUSDC.teller), secondDepositorShares);
        uint256 assetsOut = vaultUSDC.teller.withdraw(USDC, secondDepositorShares, 0, address(this));

        // Withdrawn amount should be less than or equal to the deposited amount
        assertLe(assetsOut, secondDepositAmount, "Second depositor should not profit");
    }

    // 3b
    function testYieldStreamedWBTCDepositWithdraw(uint96 WBTCAmount, uint96 secondDepositAmount) external {
        // Case 3: Yield has been streamed for the full vesting period and no new one has been started, asset: WBTC
        WBTCAmount = uint96(bound(WBTCAmount, 1, 1e18)); 
        secondDepositAmount = uint96(bound(secondDepositAmount, 2, 1e18)); 
        deal(address(WBTC), address(this), WBTCAmount);
        WBTC.approve(address(vaultWBTC.vault), type(uint256).max);
        vaultWBTC.teller.deposit(WBTC, WBTCAmount, 0, referrer);

        // Use a yield that's safely under the limit (e.g., 5%)
        uint256 yieldAmount = uint256(WBTCAmount) * 500 / 10_000;

        // Ensure yield is at least 1 to be meaningful
        vm.assume(yieldAmount > 0);

        //vest some yield
        deal(address(WBTC), address(vaultWBTC.vault), secondDepositAmount * 2);
        vaultWBTC.accountant.vestYield(yieldAmount, 24 hours); 

        skip(24 hours);

        vaultWBTC.accountant.updateExchangeRate();

        //now the state of the contract should be 
        //totalSupply > 1
        //exchange rate > 1 

        // Second Depositor deposits
        deal(address(WBTC), address(this), secondDepositAmount);
        uint256 secondDepositorShares = vaultWBTC.teller.deposit(WBTC, secondDepositAmount, 0, referrer);

        vaultWBTC.vault.approve(address(vaultWBTC.teller), secondDepositorShares);
        uint256 assetsOut = vaultWBTC.teller.withdraw(WBTC, secondDepositorShares, 0, address(this));

        // Withdrawn amount should be less than or equal to the deposited amount
        assertLe(assetsOut, secondDepositAmount, "Second depositor should not profit");
    }

    // 3c
    function testYieldStreamedWETHDepositWithdraw(uint96 WETHAmount, uint96 secondDepositAmount) external {
        // Case 3: Yield has been streamed for the full vesting period and no new one has been started, asset: WETH
        WETHAmount = uint96(bound(WETHAmount, 1, 2e27));
        secondDepositAmount = uint96(bound(secondDepositAmount, 2, 2e27)); 
        deal(address(WETH), address(this), WETHAmount);
        WETH.approve(address(vaultWETH.vault), type(uint256).max);
        vaultWETH.teller.deposit(WETH, WETHAmount, 0, referrer);

        // Use a yield that's safely under the limit (e.g., 5%)
        uint256 yieldAmount = uint256(WETHAmount) * 500 / 10_000;

        // Ensure yield is at least 1 to be meaningful
        vm.assume(yieldAmount > 0);

        //vest some yield
        deal(address(WETH), address(vaultWETH.vault), secondDepositAmount * 2);
        vaultWETH.accountant.vestYield(yieldAmount, 24 hours); 

        skip(24 hours);

        vaultWETH.accountant.updateExchangeRate();

        //now the state of the contract should be 
        //totalSupply > 1
        //exchange rate > 1 

        // Second Depositor deposits
        deal(address(WETH), address(this), secondDepositAmount);
        uint256 secondDepositorShares = vaultWETH.teller.deposit(WETH, secondDepositAmount, 0, referrer);

        vaultWETH.vault.approve(address(vaultWETH.teller), secondDepositorShares);
        uint256 assetsOut = vaultWETH.teller.withdraw(WETH, secondDepositorShares, 0, address(this));

        // Withdrawn amount should be less than or equal to the deposited amount
        assertLe(assetsOut, secondDepositAmount, "Second depositor should not profit");
    }

    // 4a
    function testNewYieldAfterGapUSDCDepositWithdraw(uint96 USDCAmount, uint96 secondDepositAmount) external {
        // Case 4: Yield has been streamed for the full vesting period and a new one has been started after some gap, asset: USDC
        USDCAmount = uint96(bound(USDCAmount, 1, 1e18));
        secondDepositAmount = uint96(bound(secondDepositAmount, 2, 1e18)); 
        deal(address(USDC), address(this), USDCAmount);
        USDC.approve(address(vaultUSDC.vault), type(uint256).max);
        vaultUSDC.teller.deposit(USDC, USDCAmount, 0, referrer);

        // Use a yield that's safely under the limit (e.g., 5%)
        uint256 yieldAmount = uint256(USDCAmount) * 500 / 10_000;

        // Ensure yield is at least 1 to be meaningful
        vm.assume(yieldAmount > 0);

        //vest some yield
        deal(address(USDC), address(vaultUSDC.vault), secondDepositAmount * 2);
        vaultUSDC.accountant.vestYield(yieldAmount, 24 hours); 

        skip(24 hours);

        vaultUSDC.accountant.updateExchangeRate();

        //now the state of the contract should be 
        //totalSupply > 1
        //exchange rate > 1 

        // Skip some gap time before starting a new yield vesting period
        skip(12 hours);

        // Start a new yield vesting period
        deal(address(USDC), address(vaultUSDC.vault), secondDepositAmount * 2);
        vaultUSDC.accountant.vestYield(yieldAmount, 24 hours);

        // Skip midway through the new vesting period (12 hours)
        skip(12 hours);

        vaultUSDC.accountant.updateExchangeRate();

        // Second Depositor deposits
        deal(address(USDC), address(this), secondDepositAmount);
        uint256 secondDepositorShares = vaultUSDC.teller.deposit(USDC, secondDepositAmount, 0, referrer);

        vaultUSDC.vault.approve(address(vaultUSDC.teller), secondDepositorShares);
        uint256 assetsOut = vaultUSDC.teller.withdraw(USDC, secondDepositorShares, 0, address(this));

        // Withdrawn amount should be less than or equal to the deposited amount
        assertLe(assetsOut, secondDepositAmount, "Second depositor should not profit");
    }

    // 4b
    function testNewYieldAfterGapWBTCDepositWithdraw(uint96 WBTCAmount, uint96 secondDepositAmount) external {
        // Case 4: Yield has been streamed for the full vesting period and a new one has been started after some gap, asset: WBTC
        WBTCAmount = uint96(bound(WBTCAmount, 1, 1e18)); 
        secondDepositAmount = uint96(bound(secondDepositAmount, 2, 1e18)); 
        deal(address(WBTC), address(this), WBTCAmount);
        WBTC.approve(address(vaultWBTC.vault), type(uint256).max);
        vaultWBTC.teller.deposit(WBTC, WBTCAmount, 0, referrer);

        // Use a yield that's safely under the limit (e.g., 5%)
        uint256 yieldAmount = uint256(WBTCAmount) * 500 / 10_000;

        // Ensure yield is at least 1 to be meaningful
        vm.assume(yieldAmount > 0);

        //vest some yield
        deal(address(WBTC), address(vaultWBTC.vault), secondDepositAmount * 2);
        vaultWBTC.accountant.vestYield(yieldAmount, 24 hours); 

        skip(24 hours);

        vaultWBTC.accountant.updateExchangeRate();

        //now the state of the contract should be 
        //totalSupply > 1
        //exchange rate > 1 

        // Skip some gap time before starting a new yield vesting period
        skip(12 hours);

        // Start a new yield vesting period
        deal(address(WBTC), address(vaultWBTC.vault), secondDepositAmount * 2);
        vaultWBTC.accountant.vestYield(yieldAmount, 24 hours);

        // Skip midway through the new vesting period (12 hours)
        skip(12 hours);

        vaultWBTC.accountant.updateExchangeRate();

        // Second Depositor deposits
        deal(address(WBTC), address(this), secondDepositAmount);
        uint256 secondDepositorShares = vaultWBTC.teller.deposit(WBTC, secondDepositAmount, 0, referrer);

        vaultWBTC.vault.approve(address(vaultWBTC.teller), secondDepositorShares);
        uint256 assetsOut = vaultWBTC.teller.withdraw(WBTC, secondDepositorShares, 0, address(this));

        // Withdrawn amount should be less than or equal to the deposited amount
        assertLe(assetsOut, secondDepositAmount, "Second depositor should not profit");
    }

    // 4c
    function testNewYieldAfterGapWETHDepositWithdraw(uint96 WETHAmount, uint96 secondDepositAmount) external {
        // Case 4: Yield has been streamed for the full vesting period and a new one has been started after some gap, asset: WETH
        WETHAmount = uint96(bound(WETHAmount, 1, 2e27));
        secondDepositAmount = uint96(bound(secondDepositAmount, 2, 2e27)); 
        deal(address(WETH), address(this), WETHAmount);
        WETH.approve(address(vaultWETH.vault), type(uint256).max);
        vaultWETH.teller.deposit(WETH, WETHAmount, 0, referrer);

        // Use a yield that's safely under the limit (e.g., 5%)
        uint256 yieldAmount = uint256(WETHAmount) * 500 / 10_000;

        // Ensure yield is at least 1 to be meaningful
        vm.assume(yieldAmount > 0);

        //vest some yield
        deal(address(WETH), address(vaultWETH.vault), secondDepositAmount * 2);
        vaultWETH.accountant.vestYield(yieldAmount, 24 hours); 

        skip(24 hours);

        vaultWETH.accountant.updateExchangeRate();

        //now the state of the contract should be 
        //totalSupply > 1
        //exchange rate > 1 

        // Skip some gap time before starting a new yield vesting period
        skip(12 hours);

        // Start a new yield vesting period
        deal(address(WETH), address(vaultWETH.vault), secondDepositAmount * 2);
        vaultWETH.accountant.vestYield(yieldAmount, 24 hours);

        // Skip midway through the new vesting period (12 hours)
        skip(12 hours);

        vaultWETH.accountant.updateExchangeRate();

        // Second Depositor deposits
        deal(address(WETH), address(this), secondDepositAmount);
        uint256 secondDepositorShares = vaultWETH.teller.deposit(WETH, secondDepositAmount, 0, referrer);

        vaultWETH.vault.approve(address(vaultWETH.teller), secondDepositorShares);
        uint256 assetsOut = vaultWETH.teller.withdraw(WETH, secondDepositorShares, 0, address(this));

        // Withdrawn amount should be less than or equal to the deposited amount
        assertLe(assetsOut, secondDepositAmount, "Second depositor should not profit");
    }

    function testFuzz_differentActorsDepositsAndWithdrawals(uint256 yieldAmountBips, uint96 aliceDepositAmount, uint96 billDepositAmount, uint96 charlieDepositAmount, uint96 davidDepositAmount, uint96 eveDepositAmount) external {
        // Yield is fuzzed and constant and deposited multiple times in this test
        yieldAmountBips = bound(yieldAmountBips, 1, 2000); // Yield is between 0.01% and 20%
        assertEq(vaultUSDC.accountant.getRate(), 1e6, "Exchange rate should be 1e6");

        aliceDepositAmount = uint96(bound(aliceDepositAmount, 1, 1e18));
        billDepositAmount = uint96(bound(billDepositAmount, 1, 1e18)); 
        charlieDepositAmount = uint96(bound(charlieDepositAmount, 1, 1e18)); 
        davidDepositAmount = uint96(bound(davidDepositAmount, 1, 1e18)); 
        eveDepositAmount = uint96(bound(eveDepositAmount, 1, 1e18)); 

        aliceShares = _depositToVault({vaultComponents: vaultUSDC, asset: USDC, depositor: alice, depositAmount: aliceDepositAmount});
        assertEq(USDC.balanceOf(alice), 0, "Alice is left with 0 USDC after deposit");
        totalSupplyAfterAliceDeposit = vaultUSDC.vault.totalSupply();

        assertEq(vaultUSDC.accountant.getRate(), 1e6, "Exchange rate is unchaned after Alice deposits");
        assertEq(vaultUSDC.vault.totalSupply(), aliceShares, "Alice is the only one in the vault after her deposit");

        // Assume that the first deposit will mint more than one share
        vm.assume(aliceDepositAmount > 1e6);

        uint256 usdcInTheVaultBeforeYieldVesting = USDC.balanceOf(address(vaultUSDC.vault));

        // Deposit yield the first time =============================================
        // Use a yield that's safely under the limit (e.g., 10%)
        uint256 yieldAmount = uint256(usdcInTheVaultBeforeYieldVesting) * yieldAmountBips / 10_000;

        uint256 newUSDCVaultBalance = USDC.balanceOf(address(vaultUSDC.vault)) + yieldAmount;
        // Give the vault the expected amount of USDC, but the exchange rate is updated slowly
        deal(address(USDC), address(vaultUSDC.vault), newUSDCVaultBalance);
        vaultUSDC.accountant.vestYield(yieldAmount, 24 hours); 

        // Skip less than the full vesting period (12 hours instead of 24)
        skip(12 hours);

        vaultUSDC.accountant.updateExchangeRate();

        // we devide usdc balance by 2 because we skip 12 hours, so only half of the yield is vested
        uint256 expectedTotalAssets = usdcInTheVaultBeforeYieldVesting + yieldAmount / 2;
        uint256 expectedExchangeRate = expectedTotalAssets * 1e6 / vaultUSDC.vault.totalSupply();
        assertEq(vaultUSDC.accountant.getRate(), expectedExchangeRate, "Exchange rate should be correct at half of the vesting period");
        assertEq(vaultUSDC.vault.totalSupply(), totalSupplyAfterAliceDeposit, "Total supply after Alice's deposit should be correct");

        // Bill deposits
        billShares = _depositToVault({vaultComponents: vaultUSDC, asset: USDC, depositor: bill, depositAmount: billDepositAmount});

        // Exchange rate doesn't change, as there was no new yield streamed
        assertEq(vaultUSDC.accountant.getRate(), expectedExchangeRate, "Exchange rate should be correct");
        assertEq(vaultUSDC.vault.totalSupply(), aliceShares + billShares, "Total supply after Bill's deposit should be correct");

        // 24 hours have passed, so the first yield is fully vested
        skip(12 hours);
        vaultUSDC.accountant.updateExchangeRate();

        expectedTotalAssets = usdcInTheVaultBeforeYieldVesting + billDepositAmount + yieldAmount;
        expectedExchangeRate = expectedTotalAssets * 1e6 / vaultUSDC.vault.totalSupply();
        
        // The rounding tolerance is 2 wei, as we are doing 2 exchange rate updates (12 hour mark and 24 hour mark)
        assertApproxEqAbs(vaultUSDC.accountant.getRate(), expectedExchangeRate, 2, "Exchange rate should be correct after the full vesting period");
        assertLe(vaultUSDC.accountant.getRate(), expectedExchangeRate, "Rate should always be less or equal to the expected exchange rate because of the");

        _withdrawFromVault({vaultComponents: vaultUSDC, asset: USDC, withdrawer: alice, shares: aliceShares});
    
        assertEq(vaultUSDC.vault.balanceOf(alice), 0, "Alice should have no shares after withdrawal");

        assertGt(USDC.balanceOf(alice), aliceDepositAmount, "Alice should have more balance after withdrawal + yield");

        // Calculate expected assets using the exchange rate from the accountant:
        // aliceShares * exchangeRate / 1e6 because it is USDC
        expectedAliceUSDCBalance = aliceShares * vaultUSDC.accountant.getRate() / 1e6;
        assertEq(USDC.balanceOf(alice), expectedAliceUSDCBalance, "Alice withdrawals = deposited USDC + yield");
        assertEq(vaultUSDC.vault.totalSupply(), billShares, "Total supply after Alice does a full withdrawal");
        // Bill is the only one left in the vault
        
        // If the second deposit is too small, the next `updateExchangeRate` will revert because of division by zero
        vm.assume(vaultUSDC.vault.totalSupply() > 0);

        charlieShares = _depositToVault({vaultComponents: vaultUSDC, asset: USDC, depositor: charlie, depositAmount: charlieDepositAmount});
        davidShares = _depositToVault({vaultComponents: vaultUSDC, asset: USDC, depositor: david, depositAmount: davidDepositAmount});

        assertEq(vaultUSDC.vault.totalSupply(), billShares + charlieShares + davidShares, "Total supply after Charlie and David deposit");
        assertEq(USDC.balanceOf(charlie), 0, "Charlie is left with 0 USDC after deposit");
        assertEq(USDC.balanceOf(david), 0, "David is left with 0 USDC after deposit");

        // Deposit yield again after Alice withdraws ==========================================
        
        // Update manual exchange rate math
        expectedTotalAssets += charlieDepositAmount + davidDepositAmount;
        expectedExchangeRate = expectedTotalAssets * 1e6 / vaultUSDC.vault.totalSupply();

        // We re-use the same yield amount in this whole test
        newUSDCVaultBalance = USDC.balanceOf(address(vaultUSDC.vault)) + yieldAmount;
        // Give the vault the expected amount of USDC, but the exchange rate is updated slowly
        deal(address(USDC), address(vaultUSDC.vault), newUSDCVaultBalance);
        vaultUSDC.accountant.vestYield(yieldAmount, 24 hours); 

        // Skip less than the full vesting period (11 hours instead of 24), 11/24 = 45.833% of the yield is vested
        skip(11 hours);
        vaultUSDC.accountant.updateExchangeRate();

        // Deposits and withdrawals MUST not affect the exchange rate, it must always be bigger if there is incoming yield or equal if there is no yield
        // It will be equal if the yield deposited is less than 1 USD (1e6 wei)
        if (yieldAmount > 1e6) {
            //@todo This revert doesn't look right
            assertGe(vaultUSDC.accountant.getRate(), expectedExchangeRate, "Exchange rate should be equal or less than the older exchange rate");
        } else {
            assertEq(vaultUSDC.accountant.getRate(), expectedExchangeRate, "Exchange rate should be equal to the older exchange rate");
        }
    }

    function testAliceAndBillDeposits() external {
        // 10,000 USDC Deposit
        aliceShares = _depositToVault({vaultComponents: vaultUSDC, asset: USDC, depositor: alice, depositAmount: 10_000 * 1e6});

        assertEq(vaultUSDC.vault.totalSupply(), aliceShares, "Total supply should be equal to Alice's shares");

        uint256 usdcInTheVaultBeforeYieldVesting = USDC.balanceOf(address(vaultUSDC.vault));

        // Deposit yield the first time =============================================
        
        // Use a yield that's safely under the limit (e.g., 3%)
        uint256 yieldAmount = uint256(usdcInTheVaultBeforeYieldVesting) * 300 / 10_000;

        uint256 newUSDCVaultBalance = USDC.balanceOf(address(vaultUSDC.vault)) + yieldAmount;
        // We re-use the same yield amount in this whole test
        newUSDCVaultBalance = USDC.balanceOf(address(vaultUSDC.vault)) + yieldAmount;
        // Give the vault the expected amount of USDC, but the exchange rate is updated slowly
        deal(address(USDC), address(vaultUSDC.vault), newUSDCVaultBalance);
        vaultUSDC.accountant.vestYield(yieldAmount, 24 hours); 
        
        skip(11 hours);
        vaultUSDC.accountant.updateExchangeRate();

        // Get the rate that will be used for Bill's deposit
        // This rate has rounding down from: getRate() -> totalAssets().mulDivDown() and getPendingVestingGains().mulDivDown()
        uint256 rateUsedForDeposit = vaultUSDC.accountant.getRateInQuote(USDC);
        
        uint256 ONE_SHARE = 10 ** vaultUSDC.vault.decimals();
        uint96 billDepositAmount = 10_000 * 1e6;
        uint256 billDepositAmount256 = uint256(billDepositAmount);
        
        // The deposit formula is: shares = depositAmount.mulDivDown(ONE_SHARE, rate)
        // Key insight: The rate is rounded DOWN (smaller) in getRate() calculations
        // A smaller rate means: depositAmount * ONE_SHARE / smaller_rate = MORE shares
        // Even though mulDivDown rounds down the final share calculation, the rate being smaller
        // means depositors get MORE shares than they would with an exact (larger) rate
        
        // Proof: Calculate what shares would be if the rate was slightly higher
        // (simulating what it might be if rounding was less aggressive)
        // A higher rate results in FEWER shares, so actual shares should be >= shares with higher rate
        uint256 rateIfHigher = rateUsedForDeposit + 1;
        uint256 sharesWithHigherRate = billDepositAmount256.mulDivDown(ONE_SHARE, rateIfHigher);
        
        // Now perform the actual deposit (which uses mulDivDown internally)
        billShares = _depositToVault({vaultComponents: vaultUSDC, asset: USDC, depositor: bill, depositAmount: billDepositAmount});

        // Prove rounding favors depositor: actual shares >= shares with higher rate
        // This proves that the rate being rounded down (smaller) benefits depositors
        assertGe(billShares, sharesWithHigherRate, "Bill should get at least as many shares as with a higher rate, proving rounding down the rate favors depositor");
        
        // Additional verification: Show the difference
        // If the rate wasn't rounded down as much, depositors would get fewer shares
        if (billShares > sharesWithHigherRate) {
            uint256 extraSharesFromRounding = billShares - sharesWithHigherRate;
            console.log("Rate used (rounded down):", rateUsedForDeposit);
            console.log("Bill's actual shares:", billShares);
            console.log("Shares with rate+1:", sharesWithHigherRate);
            console.log("Extra shares from rate rounding:", extraSharesFromRounding);
        }
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _withdrawFromVault(VaultComponents memory vaultComponents, ERC20 asset, address withdrawer, uint256 shares) internal returns (uint256 assetsOut) {
        vm.startPrank(withdrawer);
        vaultComponents.vault.approve(address(vaultComponents.teller), shares);
        // We are missing queue of the withdrawal, but for test purposes there is no need to queue it
        assetsOut = vaultComponents.teller.withdraw(asset, shares, 0, withdrawer);
        vm.stopPrank();
    }

    function _depositToVault(VaultComponents memory vaultComponents, ERC20 asset, address depositor, uint96 depositAmount) internal returns(uint256 shares) {
        deal(address(asset), depositor, depositAmount);
        vm.startPrank(depositor);
        asset.approve(address(vaultComponents.vault), type(uint256).max);
        shares = vaultComponents.teller.deposit(asset, depositAmount, 0, referrer);
        vm.stopPrank();
    }
    
    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
