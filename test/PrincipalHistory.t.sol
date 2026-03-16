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
        assertEq(
            history[0].cumulativePrincipalInBaseAsset, uint208(amount), "principal equals deposit amount at 1:1 rate"
        );
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
        assertEq(
            history[1].cumulativePrincipalInBaseAsset, uint208(amount1 + amount2), "second checkpoint is cumulative"
        );
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
        assertEq(
            history[1].cumulativePrincipalInBaseAsset,
            uint208(depositAmount / 2),
            "principal decreased after partial withdraw"
        );
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

    // ========================================= ROUNDING TESTS =========================================

    function _setRate(uint96 newRate) internal {
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(accountant), AccountantWithRateProviders.updateExchangeRate.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(accountant), AccountantWithRateProviders.unpause.selector, true
        );
        // Skip the minimum update delay
        skip(1);
        accountant.updateExchangeRate(newRate);
        // Large rate changes trigger auto-pause; always unpause for test purposes
        accountant.unpause();
    }

    function testPrincipalHistory_FullWithdrawNonCleanRate_NoDust() external {
        // Rate of 3 causes rounding: shares * 3 / 1e18 won't always divide cleanly
        _setRate(3);

        uint256 amount = 1e18;
        deal(address(WETH), user, amount);

        vm.startPrank(user);
        WETH.safeApprove(address(boringVault), amount);
        uint256 shares = teller.deposit(DepositParams(WETH, amount, 0), address(0), ComplianceData(0, ""));

        teller.withdraw(WETH, shares, 0, user);
        vm.stopPrank();

        PrincipalCheckpoint[] memory history = teller.getPrincipalHistory(user);
        assertEq(history[1].cumulativePrincipalInBaseAsset, 0, "full withdraw must leave zero principal, not dust");
    }

    function testPrincipalHistory_WithdrawRoundsUpSubtractsMoreOrEqual() external {
        // Use a rate that triggers rounding: 1e18 + 1 (just above 1:1)
        _setRate(uint96(1e18 + 1));

        uint256 amount = 1e18;
        deal(address(WETH), user, amount);

        vm.startPrank(user);
        WETH.safeApprove(address(boringVault), amount);
        uint256 shares = teller.deposit(DepositParams(WETH, amount, 0), address(0), ComplianceData(0, ""));
        vm.stopPrank();

        PrincipalCheckpoint[] memory afterDeposit = teller.getPrincipalHistory(user);
        uint208 depositedPrincipal = afterDeposit[0].cumulativePrincipalInBaseAsset;

        vm.prank(user);
        teller.withdraw(WETH, shares, 0, user);

        PrincipalCheckpoint[] memory afterWithdraw = teller.getPrincipalHistory(user);
        // Withdraw rounds up, so it subtracts >= deposit amount, clamping to 0
        assertEq(afterWithdraw[1].cumulativePrincipalInBaseAsset, 0, "withdraw roundUp >= deposit roundDown");
        assertTrue(depositedPrincipal > 0, "deposit should have recorded nonzero principal");
    }

    function testPrincipalHistory_RepeatedCyclesNoPhantomAccumulation() external {
        // Rate that maximizes rounding error per cycle
        _setRate(uint96(333333333333333333));
        uint256 cycles = 10;
        uint256 amount = 1e18;

        for (uint256 i; i < cycles; ++i) {
            deal(address(WETH), user, amount);

            vm.startPrank(user);
            WETH.safeApprove(address(boringVault), amount);
            uint256 shares = teller.deposit(DepositParams(WETH, amount, 0), address(0), ComplianceData(0, ""));
            teller.withdraw(WETH, shares, 0, user);
            vm.stopPrank();
        }

        PrincipalCheckpoint[] memory history = teller.getPrincipalHistory(user);
        // After every full cycle, principal should be 0 — no phantom buildup
        uint208 finalPrincipal = history[history.length - 1].cumulativePrincipalInBaseAsset;
        assertEq(finalPrincipal, 0, "10 deposit+withdraw cycles must not accumulate phantom principal");
    }

    function testPrincipalHistory_RateChangeDoesNotInflatePrincipal() external {
        uint256 amount = 10e18;
        deal(address(WETH), user, amount);

        vm.startPrank(user);
        WETH.safeApprove(address(boringVault), amount);
        uint256 shares = teller.deposit(DepositParams(WETH, amount, 0), address(0), ComplianceData(0, ""));
        vm.stopPrank();

        PrincipalCheckpoint[] memory afterDeposit = teller.getPrincipalHistory(user);
        uint208 principalAtDeposit = afterDeposit[0].cumulativePrincipalInBaseAsset;

        // Rate doubles — shares are now worth 2x. Fund vault so withdrawal succeeds.
        deal(address(WETH), address(boringVault), amount * 2);
        _setRate(uint96(2e18));

        vm.prank(user);
        teller.withdraw(WETH, shares, 0, user);

        PrincipalCheckpoint[] memory afterWithdraw = teller.getPrincipalHistory(user);
        // Withdrawal at 2x rate subtracts 2x the original deposit value,
        // which exceeds the recorded principal, so it clamps to 0
        assertEq(afterWithdraw[1].cumulativePrincipalInBaseAsset, 0, "rate increase clamps principal to zero");
        assertEq(principalAtDeposit, uint208(amount), "deposit at 1:1 should record exact amount");
    }

    function testPrincipalHistory_PartialWithdrawNonCleanRate() external {
        _setRate(uint96(1e18 + 7)); // slightly off 1:1

        uint256 amount = 5e18;
        deal(address(WETH), user, amount);

        vm.startPrank(user);
        WETH.safeApprove(address(boringVault), amount);
        uint256 shares = teller.deposit(DepositParams(WETH, amount, 0), address(0), ComplianceData(0, ""));

        // Withdraw 1/3 of shares — guaranteed rounding
        uint256 withdrawShares = shares / 3;
        teller.withdraw(WETH, withdrawShares, 0, user);
        vm.stopPrank();

        PrincipalCheckpoint[] memory history = teller.getPrincipalHistory(user);
        uint208 depositPrincipal = history[0].cumulativePrincipalInBaseAsset;
        uint208 afterPartialWithdraw = history[1].cumulativePrincipalInBaseAsset;

        // After partial withdraw, remaining principal must be <= deposit principal
        assertTrue(afterPartialWithdraw < depositPrincipal, "partial withdraw reduces principal");
        // Conservative: withdrawal subtracted at least the floor value
        assertTrue(afterPartialWithdraw <= depositPrincipal, "no inflation from partial withdraw");
    }

    // ========================================= HELPERS =========================================

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
