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


contract AccountantWithYieldStreamingDepositWithdrawTest is Test, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    event Paused();

    struct VaultComponents {
        BoringVault vault;
        AccountantWithYieldStreaming accountant;
        TellerWithYieldStreaming teller;
    }

    VaultComponents public vaultWETH;
    VaultComponents public vaultUSDC;
    VaultComponents public vaultWBTC;
    RolesAuthority public rolesAuthority;

    address public payoutAddress = vm.addr(7777777);
    ERC20 internal WETH;
    ERC20 internal USDC;
    ERC20 internal WBTC;

    ERC20 internal WEETH;
    address internal WEETH_RATE_PROVIDER;

    // Keep legacy variables for backward compatibility with existing tests
    BoringVault public boringVault;
    AccountantWithYieldStreaming public accountant; 
    TellerWithYieldStreaming public teller;


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
        USDC = getERC20(sourceChain, "USDC");
        WBTC = getERC20(sourceChain, "WBTC");

        WEETH = getERC20(sourceChain, "WEETH");
        WEETH_RATE_PROVIDER = getAddress(sourceChain, "WEETH_RATE_PROVIDER");

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
            STRATEGIST_ROLE, address(accountant_), bytes4(keccak256("updateExchangeRate(bool)")), true
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
        vaultUSDC.accountant.updateExchangeRate(false);

        // Second Depositor deposits
        deal(address(USDC), address(this), secondUSDCAmount);
        uint256 secondDepositorShares = vaultUSDC.teller.deposit(USDC, secondUSDCAmount, 0, referrer);

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
        vaultWBTC.accountant.updateExchangeRate(false);

        // Second Depositor deposits
        deal(address(WBTC), address(this), secondWBTCAmount);
        uint256 secondDepositorShares = vaultWBTC.teller.deposit(WBTC, secondWBTCAmount, 0, referrer);

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
        vaultWETH.accountant.updateExchangeRate(false);

        // Second Depositor deposits
        deal(address(WETH), address(this), secondWETHAmount);
        uint256 secondDepositorShares = vaultWETH.teller.deposit(WETH, secondWETHAmount, 0, referrer);

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

        vaultUSDC.accountant.updateExchangeRate(false);

        //now the state of the contract should be 
        //totalSupply > 1
        //exchange rate > 1 (but still vesting, not fully vested)

        // Second Depositor deposits
        deal(address(USDC), address(this), secondDepositAmount);
        uint256 secondDepositorShares = vaultUSDC.teller.deposit(USDC, secondDepositAmount, 0, referrer);

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

        vaultWBTC.accountant.updateExchangeRate(false);

        //now the state of the contract should be 
        //totalSupply > 1
        //exchange rate > 1 (but still vesting, not fully vested)

        // Second Depositor deposits
        deal(address(WBTC), address(this), secondDepositAmount);
        uint256 secondDepositorShares = vaultWBTC.teller.deposit(WBTC, secondDepositAmount, 0, referrer);

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

        vaultWETH.accountant.updateExchangeRate(false);

        //now the state of the contract should be 
        //totalSupply > 1
        //exchange rate > 1 (but still vesting, not fully vested)

        // Second Depositor deposits
        deal(address(WETH), address(this), secondDepositAmount);
        uint256 secondDepositorShares = vaultWETH.teller.deposit(WETH, secondDepositAmount, 0, referrer);

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

        vaultUSDC.accountant.updateExchangeRate(false);

        //now the state of the contract should be 
        //totalSupply > 1
        //exchange rate > 1 

        // Second Depositor deposits
        deal(address(USDC), address(this), secondDepositAmount);
        uint256 secondDepositorShares = vaultUSDC.teller.deposit(USDC, secondDepositAmount, 0, referrer);

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

        vaultWBTC.accountant.updateExchangeRate(false);

        //now the state of the contract should be 
        //totalSupply > 1
        //exchange rate > 1 

        // Second Depositor deposits
        deal(address(WBTC), address(this), secondDepositAmount);
        uint256 secondDepositorShares = vaultWBTC.teller.deposit(WBTC, secondDepositAmount, 0, referrer);

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

        vaultWETH.accountant.updateExchangeRate(false);

        //now the state of the contract should be 
        //totalSupply > 1
        //exchange rate > 1 

        // Second Depositor deposits
        deal(address(WETH), address(this), secondDepositAmount);
        uint256 secondDepositorShares = vaultWETH.teller.deposit(WETH, secondDepositAmount, 0, referrer);

        uint256 assetsOut = vaultWETH.teller.withdraw(WETH, secondDepositorShares, 0, address(this));

        // Withdrawn amount should be less than or equal to the deposited amount
        assertLe(assetsOut, secondDepositAmount, "Second depositor should not profit");
    }

    // 3d
    function testYieldStreamedWEETHDepositWithdrawWETH(uint96 WEETHAmount, uint96 secondDepositAmount) external {
        // Case 3d: Yield streamed for full vesting period, first depositor is normal, second depositor: deposit WEETH -> withdraw WETH -> deposit WETH -> withdraw WEETH

        WEETHAmount = uint96(bound(WEETHAmount, 1, 2e27));
        secondDepositAmount = uint96(bound(secondDepositAmount, 2, 2e27));

        // --- ENABLE WEETH as a deposit/withdrawal asset in Accountant and Teller (on vaultWETH) ---
        // Enable WEETH as deposit/withdrawal asset on the accountant
        vaultWETH.accountant.setRateProviderData(WEETH, false, address(WEETH_RATE_PROVIDER));
        // Enable WEETH on the teller as well
        vaultWETH.teller.updateAssetData(WEETH, true, true, 0);

        // --- Deposit WEETH ---
        deal(address(WEETH), address(this), WEETHAmount);
        WEETH.approve(address(vaultWETH.vault), type(uint256).max);
        vaultWETH.teller.deposit(WEETH, WEETHAmount, 0, referrer);

        // Use a yield that's safely under the limit (e.g., 5%)
        uint256 yieldAmount = uint256(WEETHAmount) * 500 / 10_000;
        vm.assume(yieldAmount > 0);

        // Vest some yield as WETH into the vault
        deal(address(WETH), address(vaultWETH.vault), secondDepositAmount * 2);
        vaultWETH.accountant.vestYield(yieldAmount, 24 hours);

        skip(24 hours);

        vaultWETH.accountant.updateExchangeRate();

        // Second Depositor deposits WEETH
        deal(address(WEETH), address(this), secondDepositAmount);
        uint256 secondDepositorShares = vaultWETH.teller.deposit(WEETH, secondDepositAmount, 0, referrer);

        // Withdraw and request WETH as the output token
        uint256 assetsOut = vaultWETH.teller.withdraw(WETH, secondDepositorShares, 0, address(this));

        // approve the assetsOut to be deposited into the vault
        WETH.approve(address(vaultWETH.vault), assetsOut);

        // deposit assetsOut into the vault
        secondDepositorShares = vaultWETH.teller.deposit(WETH, assetsOut, 0, referrer);

        // withdraw WEETH from the vault
        uint256 WEETHOut = vaultWETH.teller.withdraw(WEETH, secondDepositorShares, 0, address(this));

        // assert that the WEETHOut is equal to the secondDepositAmount
        assertLe(WEETHOut, secondDepositAmount);
    }

    // 3e
    function testYieldStreamedWETHDepositWithdrawWEETH(uint96 WEETHAmount, uint96 secondDepositAmount) external {
        // Case 3e: Yield streamed for full vesting period, first depositor is normal, second depositor: deposit WETH -> withdraw WEETH -> deposit WEETH -> withdraw WETH

        WEETHAmount = uint96(bound(WEETHAmount, 1, 2e27));
        secondDepositAmount = uint96(bound(secondDepositAmount, 3, 2e27)); //at 2 this rounds down to 0 assets on repeated action -- double check

        // --- ENABLE WEETH as a deposit/withdrawal asset in Accountant and Teller (on vaultWETH) ---
        // Enable WEETH as deposit/withdrawal asset on the accountant
        vaultWETH.accountant.setRateProviderData(WEETH, false, address(WEETH_RATE_PROVIDER));
        // Enable WEETH on the teller as well
        vaultWETH.teller.updateAssetData(WEETH, true, true, 0);

        // --- Deposit WEETH ---
        deal(address(WEETH), address(this), WEETHAmount);
        WEETH.approve(address(vaultWETH.vault), type(uint256).max);
        vaultWETH.teller.deposit(WEETH, WEETHAmount, 0, referrer);

        // Use a yield that's safely under the limit (e.g., 5%)
        uint256 yieldAmount = uint256(WEETHAmount) * 500 / 10_000;
        vm.assume(yieldAmount > 0);

        // Vest some yield as WEETH into the vault
        deal(address(WEETH), address(vaultWETH.vault), secondDepositAmount * 2);
        vaultWETH.accountant.vestYield(yieldAmount, 24 hours);

        skip(24 hours);

        vaultWETH.accountant.updateExchangeRate();

        // Second Depositor deposits WETH
        deal(address(WETH), address(this), secondDepositAmount);
        WETH.approve(address(vaultWETH.vault), secondDepositAmount);
        uint256 secondDepositorShares = vaultWETH.teller.deposit(WETH, secondDepositAmount, 0, referrer);

        // Withdraw and request WEETH as the output token
        uint256 assetsOut = vaultWETH.teller.withdraw(WEETH, secondDepositorShares, 0, address(this));

        // approve the assetsOut to be deposited into the vault
        WEETH.approve(address(vaultWETH.vault), assetsOut);

        // deposit assetsOut into the vault
        secondDepositorShares = vaultWETH.teller.deposit(WEETH, assetsOut, 0, referrer);

        // withdraw WEETH from the vault
        uint256 WETHOut = vaultWETH.teller.withdraw(WETH, secondDepositorShares, 0, address(this));

        // assert that the WEETHOut is equal to the secondDepositAmount
        assertLe(WETHOut, secondDepositAmount);
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

        vaultUSDC.accountant.updateExchangeRate(false);

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

        vaultUSDC.accountant.updateExchangeRate(false);

        // Second Depositor deposits
        deal(address(USDC), address(this), secondDepositAmount);
        uint256 secondDepositorShares = vaultUSDC.teller.deposit(USDC, secondDepositAmount, 0, referrer);

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

        vaultWBTC.accountant.updateExchangeRate(false);

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

        vaultWBTC.accountant.updateExchangeRate(false);

        // Second Depositor deposits
        deal(address(WBTC), address(this), secondDepositAmount);
        uint256 secondDepositorShares = vaultWBTC.teller.deposit(WBTC, secondDepositAmount, 0, referrer);

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

        vaultWETH.accountant.updateExchangeRate(false);

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

        vaultWETH.accountant.updateExchangeRate(false);

        // Second Depositor deposits
        deal(address(WETH), address(this), secondDepositAmount);
        uint256 secondDepositorShares = vaultWETH.teller.deposit(WETH, secondDepositAmount, 0, referrer);

        uint256 assetsOut = vaultWETH.teller.withdraw(WETH, secondDepositorShares, 0, address(this));

        // Withdrawn amount should be less than or equal to the deposited amount
        assertLe(assetsOut, secondDepositAmount, "Second depositor should not profit");
    }

    // ========================================= HELPER FUNCTIONS =========================================
    
    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
