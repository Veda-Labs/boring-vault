// SPDX-License-Identifier: SEL-1.0
// Copyright (c) 2025 Veda Tech Labs
// Derived from Boring Vault Software (c) 2025 Veda Tech Labs (TEST ONLY - NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {
    TellerWithMultiAssetSupport,
    DepositParams,
    ComplianceData,
    PermitData
} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, console, Vm} from "@forge-std/Test.sol";

contract TellerDepositForOthersTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;

    BoringVault public boringVault;
    TellerWithMultiAssetSupport public teller;
    AccountantWithRateProviders public accountant;
    RolesAuthority public rolesAuthority;

    uint8 public constant ADMIN_ROLE = 1;
    uint8 public constant MINTER_ROLE = 7;
    uint8 public constant BURNER_ROLE = 8;
    uint8 public constant DEPOSIT_FOR_OTHERS_ROLE = 50;

    ERC20 internal WETH;
    address public payout_address = vm.addr(7777777);
    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    address public alice = vm.addr(0xA11CE);
    address public attacker = vm.addr(0xB0B);
    address public router = vm.addr(0x12047E12);
    address public referrer = vm.addr(1337);

    function setUp() external {
        setSourceChainName("mainnet");
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 19363419;
        _startFork(rpcKey, blockNumber);

        WETH = getERC20(sourceChain, "WETH");

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);
        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), payout_address, 1e18, address(WETH), 1.001e4, 0.999e4, 1, 0, 0
        );
        teller =
            new TellerWithMultiAssetSupport(address(this), address(boringVault), address(accountant), address(WETH));

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
        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.withdraw.selector, true);

        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);

        teller.updateAssetData(WETH, true, true, 0);
    }

    // -- Helpers --

    function _depositAs(address depositor, address recipient, uint256 amount) internal returns (uint256 shares) {
        deal(address(WETH), depositor, amount);
        vm.startPrank(depositor);
        WETH.safeApprove(address(boringVault), amount);
        shares = teller.deposit(DepositParams(WETH, amount, 0), recipient, referrer, ComplianceData(0, ""));
        vm.stopPrank();
    }

    // -- Default (disabled) --

    function testDepositForOthersDisabledByDefault() external {
        assertEq(teller.depositForOthersRole(), type(uint8).max, "Default should disable deposit-for-others");

        deal(address(WETH), alice, 1e18);
        vm.startPrank(alice);
        WETH.safeApprove(address(boringVault), 1e18);
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__DepositForOthersNotAllowed.selector
            )
        );
        teller.deposit(DepositParams(WETH, 1e18, 0), attacker, referrer, ComplianceData(0, ""));
        vm.stopPrank();
    }

    // -- Role enabled: self-deposit always works --

    function testSelfDepositAlwaysAllowed() external {
        teller.setTransferRestrictions(type(uint8).max, DEPOSIT_FOR_OTHERS_ROLE);

        uint256 shares = _depositAs(alice, alice, 1e18);
        assertGt(shares, 0);
        assertEq(boringVault.balanceOf(alice), shares);
    }

    // -- Role enabled: deposit-to-other without role reverts --

    function testDepositForOtherRevertsWithoutRole() external {
        teller.setTransferRestrictions(type(uint8).max, DEPOSIT_FOR_OTHERS_ROLE);

        deal(address(WETH), alice, 1e18);
        vm.startPrank(alice);
        WETH.safeApprove(address(boringVault), 1e18);
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__DepositForOthersNotAllowed.selector
            )
        );
        teller.deposit(DepositParams(WETH, 1e18, 0), attacker, referrer, ComplianceData(0, ""));
        vm.stopPrank();
    }

    // -- Role enabled: deposit-to-other with role succeeds --

    function testDepositForOtherSucceedsWithRole() external {
        teller.setTransferRestrictions(type(uint8).max, DEPOSIT_FOR_OTHERS_ROLE);
        rolesAuthority.setUserRole(router, DEPOSIT_FOR_OTHERS_ROLE, true);

        uint256 shares = _depositAs(router, attacker, 1e18);
        assertGt(shares, 0);
        assertEq(boringVault.balanceOf(attacker), shares);
    }

    // -- Griefing prevention: attacker cannot reset share lock for victim --

    function testPreventsShareLockGriefing() external {
        boringVault.setBeforeTransferHook(address(teller));
        teller.setShareLockPeriod(1 days);
        teller.setTransferRestrictions(type(uint8).max, DEPOSIT_FOR_OTHERS_ROLE);

        // Alice deposits for herself — lock set
        _depositAs(alice, alice, 1e18);

        // Advance half the lock period
        skip(12 hours);

        // Attacker tries to grief Alice by depositing dust to her — should revert
        deal(address(WETH), attacker, 1);
        vm.startPrank(attacker);
        WETH.safeApprove(address(boringVault), 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__DepositForOthersNotAllowed.selector
            )
        );
        teller.deposit(DepositParams(WETH, 1, 0), alice, referrer, ComplianceData(0, ""));
        vm.stopPrank();

        // Alice's lock was NOT reset — she can withdraw after the original lock expires
        skip(12 hours + 1);

        // Verify Alice's shares are still intact and unlocked
        uint256 aliceShares = boringVault.balanceOf(alice);
        assertEq(aliceShares, 1e18, "Alice shares unchanged");
        // beforeTransfer should not revert (lock expired)
        teller.beforeTransfer(alice, address(0), alice);
    }

    // -- Whitelisted router can still deposit for others with share lock --

    function testWhitelistedRouterCanDepositForOthersWithShareLock() external {
        boringVault.setBeforeTransferHook(address(teller));
        teller.setShareLockPeriod(1 days);
        teller.setTransferRestrictions(type(uint8).max, DEPOSIT_FOR_OTHERS_ROLE);
        rolesAuthority.setUserRole(router, DEPOSIT_FOR_OTHERS_ROLE, true);

        uint256 shares = _depositAs(router, alice, 1e18);
        assertGt(shares, 0);
        assertEq(boringVault.balanceOf(alice), shares);
    }

    // -- Role can be toggled back to disabled --

    function testRoleCanBeDisabled() external {
        // Enable the role so router can deposit for others
        teller.setTransferRestrictions(type(uint8).max, DEPOSIT_FOR_OTHERS_ROLE);
        rolesAuthority.setUserRole(router, DEPOSIT_FOR_OTHERS_ROLE, true);

        // Confirm router can deposit for others
        uint256 shares = _depositAs(router, attacker, 1e18);
        assertGt(shares, 0);

        // Disable deposit-for-others by setting back to type(uint8).max
        teller.setTransferRestrictions(type(uint8).max, type(uint8).max);

        // Now router can no longer deposit for others even with the role
        deal(address(WETH), router, 1e18);
        vm.startPrank(router);
        WETH.safeApprove(address(boringVault), 1e18);
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__DepositForOthersNotAllowed.selector
            )
        );
        teller.deposit(DepositParams(WETH, 1e18, 0), attacker, referrer, ComplianceData(0, ""));
        vm.stopPrank();
    }

    // -- bulkDeposit is unaffected --

    function testBulkDepositUnaffected() external {
        teller.setTransferRestrictions(type(uint8).max, DEPOSIT_FOR_OTHERS_ROLE);

        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.bulkDeposit.selector, true
        );

        deal(address(WETH), address(this), 1e18);
        WETH.safeApprove(address(boringVault), 1e18);
        uint256 shares = teller.bulkDeposit(WETH, 1e18, 0, attacker);
        assertGt(shares, 0);
        assertEq(boringVault.balanceOf(attacker), shares);
    }

    // -- Event emission --

    function testSetTransferRestrictionsEmitsEvent() external {
        vm.recordLogs();
        teller.setTransferRestrictions(type(uint8).max, DEPOSIT_FOR_OTHERS_ROLE);
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bool found;
        for (uint256 i; i < logs.length; i++) {
            if (logs[i].topics[0] == keccak256("TransferRestrictionsSet(uint8,uint8)")) {
                found = true;
                (uint8 emittedTransferRole, uint8 emittedDepositRole) = abi.decode(logs[i].data, (uint8, uint8));
                assertEq(emittedTransferRole, type(uint8).max);
                assertEq(emittedDepositRole, DEPOSIT_FOR_OTHERS_ROLE);
                break;
            }
        }
        assertTrue(found, "TransferRestrictionsSet event not emitted");
    }

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
