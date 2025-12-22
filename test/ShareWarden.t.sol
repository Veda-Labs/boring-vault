// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { MainnetAddresses } from "test/resources/MainnetAddresses.sol";
import { BoringVault } from "src/base/BoringVault.sol";
import { TellerWithMultiAssetSupport } from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import { ShareWarden } from "src/base/Roles/ShareWarden.sol";
import { AccountantWithRateProviders } from "src/base/Roles/AccountantWithRateProviders.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";
import { FixedPointMathLib } from "@solmate/utils/FixedPointMathLib.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { IRateProvider } from "src/interfaces/IRateProvider.sol";
import { ILiquidityPool } from "src/interfaces/IStaking.sol";
import { ISanctionsList } from "src/interfaces/ISanctionsList.sol";
import { RolesAuthority, Authority } from "@solmate/auth/authorities/RolesAuthority.sol";
import { MerkleTreeHelper } from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import { Test, stdStorage, StdStorage, stdError, console } from "@forge-std/Test.sol";

// Full interface for sanctions list for testing
interface ISanctionsListFull is ISanctionsList {
    function addToSanctionsList(address[] memory newSanctions) external;
    function removeFromSanctionsList(address[] memory removeSanctions) external;
    function owner() external view returns (address);
}

contract ShareWardenTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    // golden goose vault
    BoringVault public boringVault = BoringVault(payable(0xef417FCE1883c6653E7dC6AF7c6F85CCDE84Aa09));
    AccountantWithRateProviders public accountant =
        AccountantWithRateProviders(0xc873F2b7b3BA0a7faA2B56e210E3B965f2b618f5);
    TellerWithMultiAssetSupport public teller = TellerWithMultiAssetSupport(0x4C74ccA483A278Bcb90Aea3f8F565e56202D82B2);
    RolesAuthority public rolesAuthority = RolesAuthority(0x9778D78495cBbfce0B1F6194526a8c3D4b9C3AAF);
    address public owner;
    ShareWarden public shareWarden;
    ISanctionsListFull public sanctionsList;
    address public sanctionsListOwner;
    uint64 public shareLockPeriod;

    uint8 public constant OWNER_ROLE = 8;
    uint8 internal constant CUSTOM_LIST_ONE = 1 << 0;
    uint8 internal constant CUSTOM_LIST_TWO = 1 << 1;
    uint8 internal constant CUSTOM_LIST_THREE = 1 << 2;
    uint8 internal constant CUSTOM_LIST_FOUR = 1 << 3;
    uint8 internal constant CUSTOM_LIST_FIVE = 1 << 4;
    uint8 internal constant CUSTOM_LIST_SIX = 1 << 5;

    address public payout_address = vm.addr(7_777_777);
    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    ERC20 internal constant NATIVE_ERC20 = ERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);

    ERC20 internal WETH;

    address public user1 = vm.addr(101);
    address public user2 = vm.addr(102);
    address public referrer = vm.addr(1337);

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 23_649_055;
        _startFork(rpcKey, blockNumber);

        shareLockPeriod = teller.shareLockPeriod();
        owner = rolesAuthority.owner();

        WETH = getERC20(sourceChain, "WETH");

        shareWarden = new ShareWarden(address(this));

        // Get Chainalysis sanctions list address and owner
        sanctionsList = ISanctionsListFull(getAddress(sourceChain, "sanctionsList"));
        sanctionsListOwner = sanctionsList.owner();

        vm.startPrank(owner);
        rolesAuthority.setRoleCapability(OWNER_ROLE, address(teller), teller.allowAll.selector, true);
        rolesAuthority.setRoleCapability(OWNER_ROLE, address(teller), teller.denyAll.selector, true);
        vm.stopPrank();

        // Connect ShareWarden to vault and teller
        vm.prank(owner);
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

        // User can transfer (after lock period)
        skip(shareLockPeriod);
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
        skip(shareLockPeriod);
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

    // ========================================= SanctionsList Oracle Tests =========================================

    function testSanctionsListSanctionBlocksTransferFrom() external {
        uint256 depositAmount = 1e18;

        // User deposits
        deal(address(WETH), user1, depositAmount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        // Setup SanctionsList oracle and enable SanctionsList list for vault
        shareWarden.updateSanctionsList(address(sanctionsList));
        shareWarden.updateVaultListIds(address(boringVault), shareWarden.LIST_ID_SANCTIONS());
        _addUserToSanctionsList(user1);

        // Transfer should fail due to SanctionsList sanction
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__SanctionsListBlacklisted.selector, user1));
        boringVault.transfer(user2, shares);
    }

    function testSanctionsListSanctionBlocksTransferTo() external {
        uint256 depositAmount = 1e18;

        // User deposits
        deal(address(WETH), user1, depositAmount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        // Setup SanctionsList oracle and enable SanctionsList list for vault
        shareWarden.updateSanctionsList(address(sanctionsList));
        shareWarden.updateVaultListIds(address(boringVault), shareWarden.LIST_ID_SANCTIONS());
        _addUserToSanctionsList(user2);

        // Transfer should fail due to SanctionsList sanction on recipient
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__SanctionsListBlacklisted.selector, user2));
        boringVault.transfer(user2, shares);
    }

    function testSanctionsListSanctionBlocksOperator() external {
        uint256 depositAmount = 1e18;

        // User deposits
        deal(address(WETH), user1, depositAmount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(WETH, depositAmount, 0, referrer);
        boringVault.approve(address(this), shares);
        vm.stopPrank();

        // Setup SanctionsList oracle and enable SanctionsList list for vault
        shareWarden.updateSanctionsList(address(sanctionsList));
        shareWarden.updateVaultListIds(address(boringVault), shareWarden.LIST_ID_SANCTIONS());
        _addUserToSanctionsList(address(this));

        // TransferFrom should fail due to SanctionsList sanction on operator
        vm.expectRevert(
            abi.encodeWithSelector(ShareWarden.ShareWarden__SanctionsListBlacklisted.selector, address(this))
        );
        boringVault.transferFrom(user1, user2, shares);
    }

    function testSanctionsListCanBeRemoved() external {
        uint256 depositAmount = 1e18;

        // User deposits
        deal(address(WETH), user1, depositAmount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        // Setup SanctionsList oracle and enable SanctionsList list for vault and sanction user
        shareWarden.updateSanctionsList(address(sanctionsList));
        shareWarden.updateVaultListIds(address(boringVault), shareWarden.LIST_ID_SANCTIONS());
        _addUserToSanctionsList(user1);

        // Transfer should fail
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__SanctionsListBlacklisted.selector, user1));
        boringVault.transfer(user2, shares);

        // Remove SanctionsList list from vault
        shareWarden.updateVaultListIds(address(boringVault), 0);

        // Transfer should work now
        skip(shareLockPeriod);
        vm.prank(user1);
        boringVault.transfer(user2, shares);

        assertEq(boringVault.balanceOf(user2), shares, "Transfer should succeed after removing SanctionsList list");
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

        // Setup custom blacklist (list ID CUSTOM_LIST_TWO)
        shareWarden.updateVaultListIds(address(boringVault), CUSTOM_LIST_TWO);

        bytes32[] memory addressHashes = new bytes32[](1);
        addressHashes[0] = keccak256(abi.encodePacked(user1));
        shareWarden.updateBlacklist(CUSTOM_LIST_TWO, addressHashes, true);

        // Transfer should fail due to custom blacklist
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__Blacklisted.selector, user1, CUSTOM_LIST_TWO));
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

        // Setup custom blacklist (list ID CUSTOM_LIST_TWO)
        shareWarden.updateVaultListIds(address(boringVault), CUSTOM_LIST_TWO);

        bytes32[] memory addressHashes = new bytes32[](1);
        addressHashes[0] = keccak256(abi.encodePacked(user2));
        shareWarden.updateBlacklist(CUSTOM_LIST_TWO, addressHashes, true);

        // Transfer should fail due to custom blacklist on recipient
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__Blacklisted.selector, user2, CUSTOM_LIST_TWO));
        boringVault.transfer(user2, shares);
    }

    function testUpdateBlacklistRevertsForZeroListId() external {
        bytes32[] memory addressHashes = new bytes32[](1);
        addressHashes[0] = keccak256(abi.encodePacked(user1));
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__InvalidListId.selector, uint8(0)));
        shareWarden.updateBlacklist(0, addressHashes, true);
    }

    function testUpdateBlacklistRevertsForNonBitAlignedListId() external {
        bytes32[] memory addressHashes = new bytes32[](1);
        addressHashes[0] = keccak256(abi.encodePacked(user1));
        uint8 invalidListId = CUSTOM_LIST_TWO | CUSTOM_LIST_THREE;
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__InvalidListId.selector, invalidListId));
        shareWarden.updateBlacklist(invalidListId, addressHashes, true);
    }

    function testMultipleListsWorkTogether() external {
        uint256 depositAmount = 1e18;

        // User deposits
        deal(address(WETH), user1, depositAmount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(WETH, depositAmount, 0, referrer);
        vm.stopPrank();

        // Setup SanctionsList oracle and enable both SanctionsList and custom list
        shareWarden.updateSanctionsList(address(sanctionsList));
        uint8 listBitmap = shareWarden.LIST_ID_SANCTIONS() | CUSTOM_LIST_TWO;
        shareWarden.updateVaultListIds(address(boringVault), listBitmap);

        // Sanction on SanctionsList
        _addUserToSanctionsList(user1);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__SanctionsListBlacklisted.selector, user1));
        boringVault.transfer(user2, shares);

        // Clear SanctionsList, add to custom list
        _removeUserFromSanctionsList(user1);
        bytes32[] memory addressHashes = new bytes32[](1);
        addressHashes[0] = keccak256(abi.encodePacked(user1));
        shareWarden.updateBlacklist(CUSTOM_LIST_TWO, addressHashes, true);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__Blacklisted.selector, user1, CUSTOM_LIST_TWO));
        boringVault.transfer(user2, shares);

        // Clear custom list
        shareWarden.updateBlacklist(CUSTOM_LIST_TWO, addressHashes, false);

        skip(shareLockPeriod);
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

        // Setup custom blacklist (list ID CUSTOM_LIST_TWO) and blacklist operator
        shareWarden.updateVaultListIds(address(boringVault), CUSTOM_LIST_TWO);

        bytes32[] memory addressHashes = new bytes32[](1);
        addressHashes[0] = keccak256(abi.encodePacked(address(this)));
        shareWarden.updateBlacklist(CUSTOM_LIST_TWO, addressHashes, true);

        // TransferFrom should fail due to blacklisted operator
        vm.expectRevert(
            abi.encodeWithSelector(ShareWarden.ShareWarden__Blacklisted.selector, address(this), CUSTOM_LIST_TWO)
        );
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
        shareWarden.updateVaultListIds(address(boringVault), CUSTOM_LIST_TWO);

        bytes32[] memory addressHashes = new bytes32[](1);
        addressHashes[0] = keccak256(abi.encodePacked(user1));
        shareWarden.updateBlacklist(CUSTOM_LIST_TWO, addressHashes, true);

        // Transfer should fail
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__Blacklisted.selector, user1, CUSTOM_LIST_TWO));
        boringVault.transfer(user2, shares);

        // Unblacklist user1
        shareWarden.updateBlacklist(CUSTOM_LIST_TWO, addressHashes, false);

        // Transfer should succeed
        skip(shareLockPeriod);
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
        shareWarden.updateVaultListIds(address(boringVault), CUSTOM_LIST_THREE);

        // Batch blacklist user1 and user2 to list 3
        bytes32[] memory addressHashes = new bytes32[](2);
        addressHashes[0] = keccak256(abi.encodePacked(user1));
        addressHashes[1] = keccak256(abi.encodePacked(user2));
        shareWarden.updateBlacklist(CUSTOM_LIST_THREE, addressHashes, true);

        // User1 transfer should fail
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__Blacklisted.selector, user1, CUSTOM_LIST_THREE));
        boringVault.transfer(referrer, shares1);

        // User2 transfer should fail
        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__Blacklisted.selector, user2, CUSTOM_LIST_THREE));
        boringVault.transfer(referrer, shares2);

        // User3 transfer should succeed (not blacklisted)
        skip(shareLockPeriod);
        vm.prank(user3);
        boringVault.transfer(referrer, shares3);
        assertEq(boringVault.balanceOf(referrer), shares3, "User3 transfer should succeed");

        // Batch unblacklist user1 and user2
        shareWarden.updateBlacklist(CUSTOM_LIST_THREE, addressHashes, false);

        // Both users should now be able to transfer
        vm.prank(user1);
        boringVault.transfer(referrer, shares1);

        vm.prank(user2);
        boringVault.transfer(referrer, shares2);

        assertEq(
            boringVault.balanceOf(referrer),
            shares1 + shares2 + shares3,
            "All transfers should succeed after unblacklisting"
        );
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
        uint8 listBitmap = CUSTOM_LIST_FOUR | CUSTOM_LIST_FIVE;
        shareWarden.updateVaultListIds(address(boringVault), listBitmap);

        // Add user1 to both list 4 and list 5 (requires separate calls per list)
        bytes32[] memory user1Hash = new bytes32[](1);
        user1Hash[0] = keccak256(abi.encodePacked(user1));
        shareWarden.updateBlacklist(CUSTOM_LIST_FOUR, user1Hash, true);
        shareWarden.updateBlacklist(CUSTOM_LIST_FIVE, user1Hash, true);

        // Transfer should fail (will hit list 4 first)
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__Blacklisted.selector, user1, CUSTOM_LIST_FOUR));
        boringVault.transfer(user2, shares);

        // Remove from list 4 only
        shareWarden.updateBlacklist(CUSTOM_LIST_FOUR, user1Hash, false);

        // Transfer should still fail (still on list 5)
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__Blacklisted.selector, user1, CUSTOM_LIST_FIVE));
        boringVault.transfer(user2, shares);

        // Remove from list 5
        shareWarden.updateBlacklist(CUSTOM_LIST_FIVE, user1Hash, false);

        // Transfer should now succeed
        skip(shareLockPeriod);
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
        vm.prank(owner);
        teller.denyAll(user1);

        // Transfer should fail due to teller deny list
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__TransferDenied.selector, user1, user2, user1
            )
        );
        boringVault.transfer(user2, shares);

        // Remove from deny list
        vm.prank(owner);
        teller.allowAll(user1);

        // Transfer should work now
        skip(shareLockPeriod);
        vm.prank(user1);
        boringVault.transfer(user2, shares);

        assertEq(boringVault.balanceOf(user2), shares, "Transfer should succeed after removing from deny list");
    }

    function testShareWardenDelegatesToTellerShareLockPeriod() external {
        uint256 depositAmount = 1e18;

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

        // Transfer should work now
        skip(shareLockPeriod);
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
        vm.prank(owner);
        teller.denyAll(user1);

        // Should fail at teller level now
        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__TransferDenied.selector, user1, user2, user1
            )
        );
        boringVault.transfer(user2, shares);
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

        // Setup SanctionsList oracle and enable SanctionsList list and sanction user1
        shareWarden.updateSanctionsList(address(sanctionsList));
        shareWarden.updateVaultListIds(address(boringVault), shareWarden.LIST_ID_SANCTIONS());
        _addUserToSanctionsList(user1);

        // This would typically be called by the vault's transfer function
        // Simulating the single-parameter version
        vm.prank(address(boringVault));
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__SanctionsListBlacklisted.selector, user1));
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
        skip(shareLockPeriod);
        vm.prank(user1);
        boringVault.transfer(user2, shares / 4);
        assertEq(boringVault.balanceOf(user2), shares / 4, "First transfer should succeed");

        // Setup SanctionsList, transfer fails
        shareWarden.updateSanctionsList(address(sanctionsList));
        shareWarden.updateVaultListIds(address(boringVault), shareWarden.LIST_ID_SANCTIONS());
        _addUserToSanctionsList(user1);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(ShareWarden.ShareWarden__SanctionsListBlacklisted.selector, user1));
        boringVault.transfer(user2, shares / 4);

        // Clear SanctionsList, add teller deny
        _removeUserFromSanctionsList(user1);
        vm.prank(owner);
        teller.denyAll(user1);

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__TransferDenied.selector, user1, user2, user1
            )
        );
        boringVault.transfer(user2, shares / 4);

        // Clear deny list, transfer works again
        vm.prank(owner);
        teller.allowAll(user1);

        skip(shareLockPeriod);
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
        skip(shareLockPeriod);
        vm.prank(user1);
        boringVault.transfer(user2, shares / 2);

        assertEq(boringVault.balanceOf(user2), shares / 2, "User2 should receive half the shares");
        assertEq(boringVault.balanceOf(user1), shares - shares / 2, "User1 should have remaining shares");
    }

    function testFuzzSanctionsListSanction(uint256 amount, bool sanctionFrom, bool sanctionTo, bool sanctionOperator)
        external
    {
        amount = bound(amount, 0.0001e18, 10_000e18);

        // User deposits
        deal(address(WETH), user1, amount);
        vm.startPrank(user1);
        WETH.safeApprove(address(boringVault), amount);
        uint256 shares = teller.deposit(WETH, amount, 0, referrer);
        boringVault.approve(address(this), shares);
        vm.stopPrank();

        // Setup SanctionsList oracle and enable SanctionsList list
        shareWarden.updateSanctionsList(address(sanctionsList));
        shareWarden.updateVaultListIds(address(boringVault), shareWarden.LIST_ID_SANCTIONS());

        if (sanctionFrom) {
            _addUserToSanctionsList(user1);
        }
        if (sanctionTo) {
            _addUserToSanctionsList(user2);
        }
        if (sanctionOperator) {
            _addUserToSanctionsList(address(this));
        }

        bool shouldFail = sanctionFrom || sanctionTo || sanctionOperator;

        if (shouldFail) {
            address sanctionedAddr = sanctionFrom ? user1 : (sanctionTo ? user2 : address(this));
            vm.expectRevert(
                abi.encodeWithSelector(ShareWarden.ShareWarden__SanctionsListBlacklisted.selector, sanctionedAddr)
            );
        }

        skip(shareLockPeriod);
        boringVault.transferFrom(user1, user2, shares);

        if (!shouldFail) {
            assertEq(boringVault.balanceOf(user2), shares, "Transfer should succeed when no one is sanctioned");
        }
    }

    // ========================================= Events Tests =========================================

    event Paused();
    event Unpaused();
    event SanctionsListUpdated(address indexed sanctionsList);
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
        // Test SanctionsList oracle update event
        vm.expectEmit(true, false, false, false);
        emit SanctionsListUpdated(address(sanctionsList));
        shareWarden.updateSanctionsList(address(sanctionsList));
    }

    function testVaultListIdsUpdateEvent() external {
        uint8 listBitmap = CUSTOM_LIST_FIVE | CUSTOM_LIST_SIX;
        uint8[] memory expectedListIds = new uint8[](2);
        expectedListIds[0] = CUSTOM_LIST_FIVE;
        expectedListIds[1] = CUSTOM_LIST_SIX;

        vm.expectEmit(true, false, false, true);
        emit VaultListIdsUpdated(address(boringVault), expectedListIds);
        shareWarden.updateVaultListIds(address(boringVault), listBitmap);
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

    function _addUserToSanctionsList(address user) internal {
        address[] memory newSanctions = new address[](1);
        newSanctions[0] = user;
        vm.prank(sanctionsListOwner);
        sanctionsList.addToSanctionsList(newSanctions);
    }

    function _removeUserFromSanctionsList(address user) internal {
        address[] memory removeSanctions = new address[](1);
        removeSanctions[0] = user;
        vm.prank(sanctionsListOwner);
        sanctionsList.removeFromSanctionsList(removeSanctions);
    }
}
