// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {
    TellerWithMultiAssetSupport,
    DepositParams,
    ComplianceData,
    PermitData,
    PrincipalCheckpoint
} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract PrincipalHistoryTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    BoringVault public boringVault;

    uint8 public constant ADMIN_ROLE = 1;
    uint8 public constant MINTER_ROLE = 7;
    uint8 public constant BURNER_ROLE = 8;
    uint8 public constant SOLVER_ROLE = 9;

    TellerWithMultiAssetSupport public teller;
    AccountantWithRateProviders public accountant;
    address public payout_address = vm.addr(7777777);
    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    RolesAuthority public rolesAuthority;

    ERC20 internal WETH;

    address public user = vm.addr(100);

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
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.bulkDeposit.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector, true
        );

        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.deposit.selector, true);
        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.withdraw.selector, true);

        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);

        teller.updateAssetData(WETH, true, true, 0);
        teller.updateAssetData(ERC20(NATIVE), true, true, 0);
    }

    function testPrincipalHistory_SingleDeposit() external {
        uint256 amount = 1e18;
        deal(address(WETH), user, amount);

        vm.startPrank(user);
        WETH.safeApprove(address(boringVault), amount);
        teller.deposit(DepositParams(WETH, amount, 0), address(0), ComplianceData(0, ""));
        vm.stopPrank();

        PrincipalCheckpoint[] memory history = teller.getPrincipalHistory(user);
        assertEq(history.length, 1, "history length after single deposit");
        assertEq(history[0].timestamp, uint48(block.timestamp), "checkpoint timestamp");
        // Rate is 1:1, so principal equals deposit amount
        assertEq(history[0].cumulativePrincipalInBaseAsset, uint208(amount), "principal equals deposit amount at 1:1 rate");
    }

    function testPrincipalHistory_TwoDeposits() external {
        uint256 amount1 = 1e18;
        uint256 amount2 = 2e18;
        deal(address(WETH), user, amount1 + amount2);

        vm.startPrank(user);
        WETH.safeApprove(address(boringVault), amount1 + amount2);
        teller.deposit(DepositParams(WETH, amount1, 0), address(0), ComplianceData(0, ""));
        teller.deposit(DepositParams(WETH, amount2, 0), address(0), ComplianceData(0, ""));
        vm.stopPrank();

        PrincipalCheckpoint[] memory history = teller.getPrincipalHistory(user);
        assertEq(history.length, 2, "history length after two deposits");
        assertEq(history[0].cumulativePrincipalInBaseAsset, uint208(amount1), "first checkpoint principal");
        assertEq(history[1].cumulativePrincipalInBaseAsset, uint208(amount1 + amount2), "second checkpoint is cumulative");
    }

    function testPrincipalHistory_PartialWithdraw() external {
        uint256 depositAmount = 4e18;
        deal(address(WETH), user, depositAmount);

        vm.startPrank(user);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(DepositParams(WETH, depositAmount, 0), address(0), ComplianceData(0, ""));

        // Withdraw half the shares
        uint256 halfShares = shares / 2;
        teller.withdraw(WETH, halfShares, 0, user);
        vm.stopPrank();

        PrincipalCheckpoint[] memory history = teller.getPrincipalHistory(user);
        assertEq(history.length, 2, "history length: 1 deposit + 1 withdraw");
        assertEq(history[0].cumulativePrincipalInBaseAsset, uint208(depositAmount), "deposit checkpoint");
        // At 1:1 rate, withdrawing half shares removes half the principal
        assertEq(history[1].cumulativePrincipalInBaseAsset, uint208(depositAmount / 2), "principal decreased after partial withdraw");
    }

    function testPrincipalHistory_FullWithdrawClampsToZero() external {
        uint256 depositAmount = 1e18;
        deal(address(WETH), user, depositAmount);

        vm.startPrank(user);
        WETH.safeApprove(address(boringVault), depositAmount);
        uint256 shares = teller.deposit(DepositParams(WETH, depositAmount, 0), address(0), ComplianceData(0, ""));

        // Withdraw all shares
        teller.withdraw(WETH, shares, 0, user);
        vm.stopPrank();

        PrincipalCheckpoint[] memory history = teller.getPrincipalHistory(user);
        assertEq(history.length, 2, "history length: 1 deposit + 1 withdraw");
        assertEq(history[1].cumulativePrincipalInBaseAsset, 0, "principal clamped to zero on full withdraw");
    }

    function testPrincipalHistory_BulkDepositNoCheckpoint() external {
        uint256 amount = 1e18;
        deal(address(WETH), address(this), amount);
        WETH.safeApprove(address(boringVault), amount);

        teller.bulkDeposit(WETH, amount, 0, address(this));

        PrincipalCheckpoint[] memory history = teller.getPrincipalHistory(address(this));
        assertEq(history.length, 0, "bulkDeposit should not create checkpoint");
    }

    function testPrincipalHistory_BulkWithdrawNoCheckpoint() external {
        // First do a bulkDeposit to get shares
        uint256 amount = 1e18;
        deal(address(WETH), address(this), amount);
        WETH.safeApprove(address(boringVault), amount);
        uint256 shares = teller.bulkDeposit(WETH, amount, 0, address(this));

        // Now bulkWithdraw
        teller.bulkWithdraw(WETH, shares, 0, address(this));

        PrincipalCheckpoint[] memory history = teller.getPrincipalHistory(address(this));
        assertEq(history.length, 0, "bulkWithdraw should not create checkpoint (no deposit history)");
    }

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }

    function testPrincipalHistory_NativeDeposit() external {
        uint256 amount = 1e18;
        vm.deal(user, amount);

        vm.prank(user);
        teller.deposit{value: amount}(DepositParams(ERC20(NATIVE), 0, 0), address(0), ComplianceData(0, ""));

        PrincipalCheckpoint[] memory history = teller.getPrincipalHistory(user);
        assertEq(history.length, 1, "native deposit creates checkpoint");
        assertEq(history[0].cumulativePrincipalInBaseAsset, uint208(amount), "native deposit principal at 1:1 rate");
    }
}
