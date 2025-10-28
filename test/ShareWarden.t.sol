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
        shareWarden.updateVaultTeller(address(boringVault), address(teller));
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

        // Setup OFAC oracle and enable OFAC list for vault
        shareWarden.updateOFACOracle(address(ofacOracle));
        uint8[] memory listIds = new uint8[](1);
        listIds[0] = 1; // LIST_ID_OFAC
        shareWarden.updateVaultListIds(address(boringVault), listIds);
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

        // Setup OFAC oracle and enable OFAC list for vault
        shareWarden.updateOFACOracle(address(ofacOracle));
        uint8[] memory listIds = new uint8[](1);
        listIds[0] = 1; // LIST_ID_OFAC
        shareWarden.updateVaultListIds(address(boringVault), listIds);
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

        // Setup OFAC oracle and enable OFAC list for vault
        shareWarden.updateOFACOracle(address(ofacOracle));
        uint8[] memory listIds = new uint8[](1);
        listIds[0] = 1; // LIST_ID_OFAC
        shareWarden.updateVaultListIds(address(boringVault), listIds);
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

        // Setup OFAC oracle and enable OFAC list for vault and sanction user
        shareWarden.updateOFACOracle(address(ofacOracle));
        uint8[] memory listIds = new uint8[](1);
        listIds[0] = 1; // LIST_ID_OFAC
        shareWarden.updateVaultListIds(address(boringVault), listIds);
        ofacOracle.setSanctioned(user1, true);

        // Transfer should fail
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__OFACBlacklisted.selector, user1));
        boringVault.transfer(user2, shares);

        // Remove OFAC list from vault
        uint8[] memory emptyListIds = new uint8[](0);
        shareWarden.updateVaultListIds(address(boringVault), emptyListIds);

        // Transfer should work now
        vm.prank(user1);
        boringVault.transfer(user2, shares);

        assertEq(boringVault.balanceOf(user2), shares, "Transfer should succeed after removing OFAC list");
    }

    // ========================================= Custom Blacklist Tests =========================================

    function testCustomBlacklistBlocksTransferFrom() external {
        uint256 depositAmount = 1e18;
        
        // User deposits
        deal(address(WETH), user1, depositAmount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        // Setup custom blacklist (list ID 2)
        uint8[] memory listIds = new uint8[](1);
        listIds[0] = 2;
        shareWarden.updateVaultListIds(address(boringVault), listIds);
        
        bytes32[] memory addressHashes = new bytes32[](1);
        addressHashes[0] = keccak256(abi.encodePacked(user1));
        shareWarden.updateBlacklist(2, addressHashes, true);

        // Transfer should fail due to custom blacklist
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__VedaBlacklisted.selector, user1, uint8(2)));
        boringVault.transfer(user2, shares);
    }

    function testCustomBlacklistBlocksTransferTo() external {
        uint256 depositAmount = 1e18;
        
        // User deposits
        deal(address(WETH), user1, depositAmount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        // Setup custom blacklist (list ID 2)
        uint8[] memory listIds = new uint8[](1);
        listIds[0] = 2;
        shareWarden.updateVaultListIds(address(boringVault), listIds);
        
        bytes32[] memory addressHashes = new bytes32[](1);
        addressHashes[0] = keccak256(abi.encodePacked(user2));
        shareWarden.updateBlacklist(2, addressHashes, true);

        // Transfer should fail due to custom blacklist on recipient
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__VedaBlacklisted.selector, user2, uint8(2)));
        boringVault.transfer(user2, shares);
    }

    function testMultipleListsWorkTogether() external {
        uint256 depositAmount = 1e18;
        
        // User deposits
        deal(address(WETH), user1, depositAmount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        // Setup OFAC oracle and enable both OFAC and custom list
        shareWarden.updateOFACOracle(address(ofacOracle));
        uint8[] memory listIds = new uint8[](2);
        listIds[0] = 1; // OFAC
        listIds[1] = 2; // Custom list
        shareWarden.updateVaultListIds(address(boringVault), listIds);

        // Sanction on OFAC
        ofacOracle.setSanctioned(user1, true);
        
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__OFACBlacklisted.selector, user1));
        boringVault.transfer(user2, shares);

        // Clear OFAC, add to custom list
        ofacOracle.setSanctioned(user1, false);
        bytes32[] memory addressHashes = new bytes32[](1);
        addressHashes[0] = keccak256(abi.encodePacked(user1));
        shareWarden.updateBlacklist(2, addressHashes, true);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__VedaBlacklisted.selector, user1, uint8(2)));
        boringVault.transfer(user2, shares);

        // Clear custom list
        shareWarden.updateBlacklist(2, addressHashes, false);

        vm.prank(user1);
        boringVault.transfer(user2, shares);

        assertEq(boringVault.balanceOf(user2), shares, "Transfer should succeed when all lists clear");
    }

    function testCustomBlacklistBlocksOperator() external {
        uint256 depositAmount = 1e18;
        
        // User deposits
        deal(address(WETH), user1, depositAmount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(WETH, depositAmount, 0, referrer);
        boringVault.approve(address(this), shares);
        vm.stopPrank();

        // Setup custom blacklist (list ID 2) and blacklist operator
        uint8[] memory listIds = new uint8[](1);
        listIds[0] = 2;
        shareWarden.updateVaultListIds(address(boringVault), listIds);
        
        bytes32[] memory addressHashes = new bytes32[](1);
        addressHashes[0] = keccak256(abi.encodePacked(address(this)));
        shareWarden.updateBlacklist(2, addressHashes, true);

        // TransferFrom should fail due to blacklisted operator
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__VedaBlacklisted.selector, address(this), uint8(2)));
        boringVault.transferFrom(user1, user2, shares);
    }

    function testCanUnblacklistAddress() external {
        uint256 depositAmount = 1e18;
        
        // User deposits
        deal(address(WETH), user1, depositAmount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        // Setup custom blacklist and blacklist user1
        uint8[] memory listIds = new uint8[](1);
        listIds[0] = 2;
        shareWarden.updateVaultListIds(address(boringVault), listIds);
        
        bytes32[] memory addressHashes = new bytes32[](1);
        addressHashes[0] = keccak256(abi.encodePacked(user1));
        shareWarden.updateBlacklist(2, addressHashes, true);

        // Transfer should fail
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__VedaBlacklisted.selector, user1, uint8(2)));
        boringVault.transfer(user2, shares);

        // Unblacklist user1
        shareWarden.updateBlacklist(2, addressHashes, false);

        // Transfer should succeed
        vm.prank(user1);
        boringVault.transfer(user2, shares);

        assertEq(boringVault.balanceOf(user2), shares, "Transfer should succeed after unblacklisting");
    }

    function testBatchUpdateBlacklistMultipleAddresses() external {
        uint256 depositAmount = 1e18;
        
        // Setup multiple users with shares
        deal(address(WETH), user1, depositAmount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares1 = teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        deal(address(WETH), user2, depositAmount);
        vm.startPrank(user2);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares2 = teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        address user3 = vm.addr(103);
        deal(address(WETH), user3, depositAmount);
        vm.startPrank(user3);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares3 = teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        // Setup custom blacklist
        uint8[] memory listIds = new uint8[](1);
        listIds[0] = 3;
        shareWarden.updateVaultListIds(address(boringVault), listIds);

        // Batch blacklist user1 and user2 to list 3
        bytes32[] memory addressHashes = new bytes32[](2);
        addressHashes[0] = keccak256(abi.encodePacked(user1));
        addressHashes[1] = keccak256(abi.encodePacked(user2));
        shareWarden.updateBlacklist(3, addressHashes, true);

        // User1 transfer should fail
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__VedaBlacklisted.selector, user1, uint8(3)));
        boringVault.transfer(referrer, shares1);

        // User2 transfer should fail
        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__VedaBlacklisted.selector, user2, uint8(3)));
        boringVault.transfer(referrer, shares2);

        // User3 transfer should succeed (not blacklisted)
        vm.prank(user3);
        boringVault.transfer(referrer, shares3);
        assertEq(boringVault.balanceOf(referrer), shares3, "User3 transfer should succeed");

        // Batch unblacklist user1 and user2
        shareWarden.updateBlacklist(3, addressHashes, false);

        // Both users should now be able to transfer
        vm.prank(user1);
        boringVault.transfer(referrer, shares1);
        
        vm.prank(user2);
        boringVault.transfer(referrer, shares2);

        assertEq(boringVault.balanceOf(referrer), shares1 + shares2 + shares3, "All transfers should succeed after unblacklisting");
    }

    function testUpdateBlacklistMultipleLists() external {
        uint256 depositAmount = 1e18;
        
        // User deposits
        deal(address(WETH), user1, depositAmount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        // Setup multiple custom lists
        uint8[] memory listIds = new uint8[](2);
        listIds[0] = 4;
        listIds[1] = 5;
        shareWarden.updateVaultListIds(address(boringVault), listIds);

        // Add user1 to both list 4 and list 5 (requires separate calls per list)
        bytes32[] memory user1Hash = new bytes32[](1);
        user1Hash[0] = keccak256(abi.encodePacked(user1));
        shareWarden.updateBlacklist(4, user1Hash, true);
        shareWarden.updateBlacklist(5, user1Hash, true);

        // Transfer should fail (will hit list 4 first)
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__VedaBlacklisted.selector, user1, uint8(4)));
        boringVault.transfer(user2, shares);

        // Remove from list 4 only
        shareWarden.updateBlacklist(4, user1Hash, false);

        // Transfer should still fail (still on list 5)
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__VedaBlacklisted.selector, user1, uint8(5)));
        boringVault.transfer(user2, shares);

        // Remove from list 5
        shareWarden.updateBlacklist(5, user1Hash, false);

        // Transfer should now succeed
        vm.prank(user1);
        boringVault.transfer(user2, shares);
        assertEq(boringVault.balanceOf(user2), shares, "Transfer should succeed after removing from all lists");
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

        // Setup OFAC oracle and enable OFAC list
        shareWarden.updateOFACOracle(address(ofacOracle));
        uint8[] memory listIds = new uint8[](1);
        listIds[0] = 1; // LIST_ID_OFAC
        shareWarden.updateVaultListIds(address(boringVault), listIds);
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
        teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        // Setup OFAC oracle and enable OFAC list and sanction user1
        shareWarden.updateOFACOracle(address(ofacOracle));
        uint8[] memory listIds = new uint8[](1);
        listIds[0] = 1; // LIST_ID_OFAC
        shareWarden.updateVaultListIds(address(boringVault), listIds);
        ofacOracle.setSanctioned(user1, true);

        // This would typically be called by the vault's transfer function
        // Simulating the single-parameter version
        vm.prank(address(boringVault));
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
        uint8[] memory listIds = new uint8[](1);
        listIds[0] = 1; // LIST_ID_OFAC
        shareWarden.updateVaultListIds(address(boringVault), listIds);
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

        // Setup OFAC oracle and enable OFAC list
        shareWarden.updateOFACOracle(address(ofacOracle));
        uint8[] memory listIds = new uint8[](1);
        listIds[0] = 1; // LIST_ID_OFAC
        shareWarden.updateVaultListIds(address(boringVault), listIds);

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

    event Paused();
    event Unpaused();
    event OFACOracleUpdated(address indexed oracle);
    event VaultTellerUpdated(address indexed vault, address indexed teller);
    event VaultListIdsUpdated(address indexed vault, uint8[] listIds);

    function testShareWardenUpdateVaultTeller() external {
        // Create a new teller
        TellerWithMultiAssetSupport newTeller =
            new TellerWithMultiAssetSupport(address(this), address(boringVault), address(accountant), address(WETH));

        // Update mapping
        vm.expectEmit(true, true, false, false);
        emit VaultTellerUpdated(address(boringVault), address(newTeller));
        shareWarden.updateVaultTeller(address(boringVault), address(newTeller));

        // Verify mapping updated
        (address _teller,) = shareWarden.getVaultData(address(boringVault));
        assertEq(_teller, address(newTeller), "Mapping should be updated");
    }

    function testOracleUpdateEvents() external {
        // Test OFAC oracle update event
        vm.expectEmit(true, false, false, false);
        emit OFACOracleUpdated(address(ofacOracle));
        shareWarden.updateOFACOracle(address(ofacOracle));
    }

    function testVaultListIdsUpdateEvent() external {
        uint8[] memory listIds = new uint8[](2);
        listIds[0] = 1;
        listIds[1] = 2;

        vm.expectEmit(true, false, false, true);
        emit VaultListIdsUpdated(address(boringVault), listIds);
        shareWarden.updateVaultListIds(address(boringVault), listIds);
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

