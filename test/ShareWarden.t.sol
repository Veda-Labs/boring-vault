// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {ShareWarden} from "src/base/Roles/ShareWarden.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {ILiquidityPool} from "src/interfaces/IStaking.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

// Mock sanctions list for testing
contract MockSanctionsList {
    mapping(address => bool) public sanctioned;

    function setSanctioned(address addr, bool status) external {
        sanctioned[addr] = status;
    }

    function isSanctioned(address addr) external view returns (bool) {
        return sanctioned[addr];
    }
}

contract ShareWardenTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    BoringVault public boringVault;
    TellerWithMultiAssetSupport public teller;
    ShareWarden public shareWarden;
    AccountantWithRateProviders public accountant;
    RolesAuthority public rolesAuthority;
    MockSanctionsList public ofacOracle;
    MockSanctionsList public vedaOracle;

    uint8 public constant ADMIN_ROLE = 1;
    uint8 public constant MINTER_ROLE = 7;
    uint8 public constant BURNER_ROLE = 8;

    address public payout_address = vm.addr(7777777);
    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    ERC20 internal constant NATIVE_ERC20 = ERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    ERC20 internal WETH;
    ERC20 internal EETH;
    ERC20 internal WEETH;
    address internal EETH_LIQUIDITY_POOL;
    address internal WEETH_RATE_PROVIDER;

    address public user1 = vm.addr(101);
    address public user2 = vm.addr(102);
    address public referrer = vm.addr(1337);

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 19363419;
        _startFork(rpcKey, blockNumber);

        WETH = getERC20(sourceChain, "WETH");
        EETH = getERC20(sourceChain, "EETH");
        WEETH = getERC20(sourceChain, "WEETH");
        EETH_LIQUIDITY_POOL = getAddress(sourceChain, "EETH_LIQUIDITY_POOL");
        WEETH_RATE_PROVIDER = getAddress(sourceChain, "WEETH_RATE_PROVIDER");

        // Deploy core contracts
        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), payout_address, 1e18, address(WETH), 1.001e4, 0.999e4, 1, 0, 0
        );

        teller =
            new TellerWithMultiAssetSupport(address(this), address(boringVault), address(accountant), address(WETH));

        shareWarden = new ShareWarden(address(this));

        // Deploy mock oracles
        ofacOracle = new MockSanctionsList();
        vedaOracle = new MockSanctionsList();

        // Setup roles
        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));

        boringVault.setAuthority(rolesAuthority);
        accountant.setAuthority(rolesAuthority);
        teller.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(MINTER_ROLE, address(boringVault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(boringVault), BoringVault.exit.selector, true);
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.updateAssetData.selector, true
        );
        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.deposit.selector, true);
        rolesAuthority.setPublicCapability(
            address(teller), TellerWithMultiAssetSupport.depositWithPermit.selector, true
        );

        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);

        // Setup asset data
        teller.updateAssetData(WETH, true, true, 0);
        teller.updateAssetData(ERC20(NATIVE), true, true, 0);
        teller.updateAssetData(EETH, true, true, 0);
        teller.updateAssetData(WEETH, true, true, 0);

        accountant.setRateProviderData(EETH, true, address(0));
        accountant.setRateProviderData(WEETH, false, address(WEETH_RATE_PROVIDER));

        // Connect ShareWarden to vault and teller
        boringVault.setBeforeTransferHook(address(shareWarden));
        shareWarden.updateVaultToTeller(address(boringVault), address(teller));
    }

    // ========================================= Basic Integration Tests =========================================

    function testBasicDepositAndTransferWithShareWarden() external {
        uint256 depositAmount = 1e18;
        
        // User deposits
        deal(address(WETH), user1, depositAmount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        assertEq(boringVault.balanceOf(user1), shares, "User should receive shares");

        // User can transfer (no lock period set)
        vm.prank(user1);
        boringVault.transfer(user2, shares / 2);

        assertEq(boringVault.balanceOf(user2), shares / 2, "User2 should receive shares");
    }

    function testDepositWithMultipleUsers() external {
        uint256 depositAmount = 1e18;

        // User1 deposits
        deal(address(WETH), user1, depositAmount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares1 = teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        // User2 deposits
        deal(address(WETH), user2, depositAmount);
        vm.startPrank(user2);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares2 = teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        assertEq(shares1, shares2, "Equal deposits should yield equal shares");
        assertEq(boringVault.balanceOf(user1), shares1, "User1 should have shares");
        assertEq(boringVault.balanceOf(user2), shares2, "User2 should have shares");
    }

    // ========================================= ShareWarden Pause Tests =========================================

    function testShareWardenPausePreventsTransfers() external {
        uint256 depositAmount = 1e18;
        
        // User deposits
        deal(address(WETH), user1, depositAmount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        // Pause ShareWarden
        shareWarden.pause();

        // Transfer should fail
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__Paused.selector));
        boringVault.transfer(user2, shares);

        // Unpause ShareWarden
        shareWarden.unpause();

        // Transfer should work now
        vm.prank(user1);
        boringVault.transfer(user2, shares);

        assertEq(boringVault.balanceOf(user2), shares, "Transfer should succeed after unpause");
    }

    function testShareWardenPauseDoesNotPreventDeposits() external {
        // Pause ShareWarden
        shareWarden.pause();

        uint256 depositAmount = 1e18;
        
        // User can still deposit (pause only affects transfers)
        deal(address(WETH), user1, depositAmount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        assertEq(boringVault.balanceOf(user1), shares, "Deposits should work even when ShareWarden is paused");
    }

    // ========================================= OFAC Oracle Tests =========================================

    function testOFACSanctionBlocksTransferFrom() external {
        uint256 depositAmount = 1e18;
        
        // User deposits
        deal(address(WETH), user1, depositAmount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        // Setup OFAC oracle
        shareWarden.updateOFACOracle(address(ofacOracle));
        ofacOracle.setSanctioned(user1, true);

        // Transfer should fail due to OFAC sanction
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__OFACBlacklisted.selector, user1));
        boringVault.transfer(user2, shares);
    }

    function testOFACSanctionBlocksTransferTo() external {
        uint256 depositAmount = 1e18;
        
        // User deposits
        deal(address(WETH), user1, depositAmount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        // Setup OFAC oracle
        shareWarden.updateOFACOracle(address(ofacOracle));
        ofacOracle.setSanctioned(user2, true);

        // Transfer should fail due to OFAC sanction on recipient
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__OFACBlacklisted.selector, user2));
        boringVault.transfer(user2, shares);
    }

    function testOFACSanctionBlocksOperator() external {
        uint256 depositAmount = 1e18;
        
        // User deposits
        deal(address(WETH), user1, depositAmount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(WETH, depositAmount, 0, referrer);
        boringVault.approve(address(this), shares);
        vm.stopPrank();

        // Setup OFAC oracle
        shareWarden.updateOFACOracle(address(ofacOracle));
        ofacOracle.setSanctioned(address(this), true);

        // TransferFrom should fail due to OFAC sanction on operator
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__OFACBlacklisted.selector, address(this)));
        boringVault.transferFrom(user1, user2, shares);
    }

    function testOFACOracleCanBeRemoved() external {
        uint256 depositAmount = 1e18;
        
        // User deposits
        deal(address(WETH), user1, depositAmount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        // Setup OFAC oracle and sanction user
        shareWarden.updateOFACOracle(address(ofacOracle));
        ofacOracle.setSanctioned(user1, true);

        // Transfer should fail
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__OFACBlacklisted.selector, user1));
        boringVault.transfer(user2, shares);

        // Remove OFAC oracle
        shareWarden.updateOFACOracle(address(0));

        // Transfer should work now
        vm.prank(user1);
        boringVault.transfer(user2, shares);

        assertEq(boringVault.balanceOf(user2), shares, "Transfer should succeed after removing OFAC oracle");
    }

    // ========================================= Veda Oracle Tests =========================================

    function testVedaSanctionBlocksTransferFrom() external {
        uint256 depositAmount = 1e18;
        
        // User deposits
        deal(address(WETH), user1, depositAmount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        // Setup Veda oracle
        shareWarden.updateVedaOracle(address(vedaOracle));
        vedaOracle.setSanctioned(user1, true);

        // Transfer should fail due to Veda sanction
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__VedaBlacklisted.selector, user1));
        boringVault.transfer(user2, shares);
    }

    function testVedaSanctionBlocksTransferTo() external {
        uint256 depositAmount = 1e18;
        
        // User deposits
        deal(address(WETH), user1, depositAmount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        // Setup Veda oracle
        shareWarden.updateVedaOracle(address(vedaOracle));
        vedaOracle.setSanctioned(user2, true);

        // Transfer should fail due to Veda sanction on recipient
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__VedaBlacklisted.selector, user2));
        boringVault.transfer(user2, shares);
    }

    function testBothOraclesWorkTogether() external {
        uint256 depositAmount = 1e18;
        
        // User deposits
        deal(address(WETH), user1, depositAmount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        // Setup both oracles
        shareWarden.updateOFACOracle(address(ofacOracle));
        shareWarden.updateVedaOracle(address(vedaOracle));

        // Sanction on OFAC
        ofacOracle.setSanctioned(user1, true);
        
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__OFACBlacklisted.selector, user1));
        boringVault.transfer(user2, shares);

        // Clear OFAC, add to Veda
        ofacOracle.setSanctioned(user1, false);
        vedaOracle.setSanctioned(user1, true);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__VedaBlacklisted.selector, user1));
        boringVault.transfer(user2, shares);

        // Clear both
        vedaOracle.setSanctioned(user1, false);

        vm.prank(user1);
        boringVault.transfer(user2, shares);

        assertEq(boringVault.balanceOf(user2), shares, "Transfer should succeed when both oracles clear");
    }

    // ========================================= Teller Integration Tests =========================================

    function testShareWardenDelegatesToTellerDenyList() external {
        uint256 depositAmount = 1e18;
        
        // User deposits
        deal(address(WETH), user1, depositAmount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        // Add user to teller deny list
        teller.denyAll(user1);

        // Transfer should fail due to teller deny list
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__TransferDenied.selector,
                user1,
                user2,
                user1
            )
        );
        boringVault.transfer(user2, shares);

        // Remove from deny list
        teller.allowAll(user1);

        // Transfer should work now
        vm.prank(user1);
        boringVault.transfer(user2, shares);

        assertEq(boringVault.balanceOf(user2), shares, "Transfer should succeed after removing from deny list");
    }

    function testShareWardenDelegatesToTellerShareLockPeriod() external {
        uint256 depositAmount = 1e18;
        
        // Set share lock period on teller
        teller.setShareLockPeriod(1 days);

        // User deposits
        deal(address(WETH), user1, depositAmount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        // Transfer should fail due to share lock
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__SharesAreLocked.selector)
        );
        boringVault.transfer(user2, shares);

        // Skip past lock period
        skip(1 days + 1);

        // Transfer should work now
        vm.prank(user1);
        boringVault.transfer(user2, shares);

        assertEq(boringVault.balanceOf(user2), shares, "Transfer should succeed after lock period");
    }

    function testCombinedChecks_ShareWardenPausedAndTellerDeny() external {
        uint256 depositAmount = 1e18;
        
        // User deposits
        deal(address(WETH), user1, depositAmount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        // Pause ShareWarden - should fail here first
        shareWarden.pause();

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__Paused.selector));
        boringVault.transfer(user2, shares);

        // Unpause ShareWarden, add to teller deny list
        shareWarden.unpause();
        teller.denyAll(user1);

        // Should fail at teller level now
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__TransferDenied.selector,
                user1,
                user2,
                user1
            )
        );
        boringVault.transfer(user2, shares);
    }

    function testCombinedChecks_OFACAndTellerShareLock() external {
        uint256 depositAmount = 1e18;
        
        // Set share lock period
        teller.setShareLockPeriod(1 days);

        // User deposits
        deal(address(WETH), user1, depositAmount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        // Setup OFAC oracle
        shareWarden.updateOFACOracle(address(ofacOracle));
        ofacOracle.setSanctioned(user1, true);

        // Transfer should fail due to OFAC (checked first)
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__OFACBlacklisted.selector, user1));
        boringVault.transfer(user2, shares);

        // Clear OFAC sanction
        ofacOracle.setSanctioned(user1, false);

        // Should fail due to share lock now
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__SharesAreLocked.selector)
        );
        boringVault.transfer(user2, shares);

        // Skip past lock period
        skip(1 days + 1);

        // Transfer should work now
        vm.prank(user1);
        boringVault.transfer(user2, shares);

        assertEq(boringVault.balanceOf(user2), shares, "Transfer should succeed after all checks pass");
    }

    // ========================================= Edge Cases =========================================

    function testShareWardenWithoutTellerMapping() external {
        // Create a new vault without teller mapping
        BoringVault newVault = new BoringVault(address(this), "New Vault", "NV", 18);
        newVault.setBeforeTransferHook(address(shareWarden));

        // Mint some shares to user
        deal(address(newVault), user1, 1e18, true);

        // Transfer should work (no teller to delegate to)
        vm.prank(user1);
        newVault.transfer(user2, 0.5e18);

        assertEq(newVault.balanceOf(user2), 0.5e18, "Transfer should work without teller mapping");
    }

    function testBeforeTransferWithSingleParameter() external {
        uint256 depositAmount = 1e18;
        
        // User deposits
        deal(address(WETH), user1, depositAmount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        // Setup OFAC oracle and sanction user1
        shareWarden.updateOFACOracle(address(ofacOracle));
        ofacOracle.setSanctioned(user1, true);

        // This would typically be called by the vault's transfer function
        // Simulating the single-parameter version
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__OFACBlacklisted.selector, user1));
        shareWarden.beforeTransfer(user1);
    }

    function testMultipleTransfersWithVaryingChecks() external {
        uint256 depositAmount = 1e18;
        
        // User deposits
        deal(address(WETH), user1, depositAmount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        // First transfer works
        vm.prank(user1);
        boringVault.transfer(user2, shares / 4);
        assertEq(boringVault.balanceOf(user2), shares / 4, "First transfer should succeed");

        // Setup OFAC, transfer fails
        shareWarden.updateOFACOracle(address(ofacOracle));
        ofacOracle.setSanctioned(user1, true);
        
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__OFACBlacklisted.selector, user1));
        boringVault.transfer(user2, shares / 4);

        // Clear OFAC, add teller deny
        ofacOracle.setSanctioned(user1, false);
        teller.denyAll(user1);

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__TransferDenied.selector,
                user1,
                user2,
                user1
            )
        );
        boringVault.transfer(user2, shares / 4);

        // Clear deny list, transfer works again
        teller.allowAll(user1);

        vm.prank(user1);
        boringVault.transfer(user2, shares / 4);
        assertEq(boringVault.balanceOf(user2), shares / 2, "Final transfer should succeed");
    }

    function testFuzzDepositAndTransferWithShareWarden(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 10_000e18);

        // User deposits
        deal(address(WETH), user1, amount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), amount);
        uint256 shares = teller.deposit(WETH, amount, 0, referrer);
        vm.stopPrank();

        assertEq(boringVault.balanceOf(user1), shares, "User should receive shares");

        // User can transfer
        vm.prank(user1);
        boringVault.transfer(user2, shares / 2);

        assertEq(boringVault.balanceOf(user2), shares / 2, "User2 should receive half the shares");
        assertEq(boringVault.balanceOf(user1), shares - shares / 2, "User1 should have remaining shares");
    }

    function testFuzzOFACSanction(uint256 amount, bool sanctionFrom, bool sanctionTo, bool sanctionOperator) external {
        amount = bound(amount, 0.0001e18, 10_000e18);

        // User deposits
        deal(address(WETH), user1, amount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), amount);
        uint256 shares = teller.deposit(WETH, amount, 0, referrer);
        boringVault.approve(address(this), shares);
        vm.stopPrank();

        // Setup OFAC oracle
        shareWarden.updateOFACOracle(address(ofacOracle));

        if (sanctionFrom) {
            ofacOracle.setSanctioned(user1, true);
        }
        if (sanctionTo) {
            ofacOracle.setSanctioned(user2, true);
        }
        if (sanctionOperator) {
            ofacOracle.setSanctioned(address(this), true);
        }

        bool shouldFail = sanctionFrom || sanctionTo || sanctionOperator;

        if (shouldFail) {
            address sanctionedAddr = sanctionFrom ? user1 : (sanctionTo ? user2 : address(this));
            vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__OFACBlacklisted.selector, sanctionedAddr));
        }
        
        boringVault.transferFrom(user1, user2, shares);

        if (!shouldFail) {
            assertEq(boringVault.balanceOf(user2), shares, "Transfer should succeed when no one is sanctioned");
        }
    }

    // ========================================= Events Tests =========================================

    event OFACBlacklisted(address account);
    event VedaBlacklisted(address account);
    event Paused();
    event Unpaused();
    event VaultToTellerUpdated(address indexed vault, address indexed teller);
    event OFACOracleUpdated(address indexed oracle);
    event VedaOracleUpdated(address indexed oracle);

    function testShareWardenUpdateVaultToTeller() external {
        // Create a new teller
        TellerWithMultiAssetSupport newTeller =
            new TellerWithMultiAssetSupport(address(this), address(boringVault), address(accountant), address(WETH));

        // Update mapping
        vm.expectEmit(true, true, false, false);
        emit VaultToTellerUpdated(address(boringVault), address(newTeller));
        shareWarden.updateVaultToTeller(address(boringVault), address(newTeller));

        // Verify mapping updated
        assertEq(shareWarden.vaultToTeller(address(boringVault)), address(newTeller), "Mapping should be updated");
    }

    function testOracleUpdateEvents() external {
        // Test OFAC oracle update event
        vm.expectEmit(true, false, false, false);
        emit OFACOracleUpdated(address(ofacOracle));
        shareWarden.updateOFACOracle(address(ofacOracle));

        // Test Veda oracle update event
        vm.expectEmit(true, false, false, false);
        emit VedaOracleUpdated(address(vedaOracle));
        shareWarden.updateVedaOracle(address(vedaOracle));
    }

    function testPauseUnpauseEvents() external {
        // Test pause event
        vm.expectEmit(false, false, false, false);
        emit Paused();
        shareWarden.pause();

        // Test unpause event
        vm.expectEmit(false, false, false, false);
        emit Unpaused();
        shareWarden.unpause();
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

