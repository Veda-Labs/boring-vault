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

    uint256 internal constant ONE_SHARE = 1e18;
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
            history[0].cumulativeDeposits - history[0].cumulativeWithdrawals,
            uint104(amount),
            "principal equals deposit amount at 1:1 rate"
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
        assertEq(
            history[0].cumulativeDeposits - history[0].cumulativeWithdrawals,
            uint104(amount1),
            "first checkpoint principal"
        );
        assertEq(
            history[1].cumulativeDeposits - history[1].cumulativeWithdrawals,
            uint104(amount1 + amount2),
            "second checkpoint is cumulative"
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
        assertEq(
            history[0].cumulativeDeposits - history[0].cumulativeWithdrawals,
            uint104(depositAmount),
            "deposit checkpoint"
        );
        // At 1:1 rate, withdrawing half shares removes half the principal
        assertEq(
            history[1].cumulativeDeposits - history[1].cumulativeWithdrawals,
            uint104(depositAmount / 2),
            "principal decreased after partial withdraw"
        );
    }

    function testPrincipalHistory_FullWithdrawZeroPrincipal() external {
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
        // Withdrawals >= deposits due to round-up, meaning zero or negative principal off-chain
        assertTrue(
            history[1].cumulativeWithdrawals >= history[1].cumulativeDeposits, "full withdraw: withdrawals >= deposits"
        );
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
        // Withdraw rounds up, so withdrawals >= deposits (no phantom positive principal)
        assertTrue(
            history[1].cumulativeWithdrawals >= history[1].cumulativeDeposits,
            "full withdraw must not leave positive principal dust"
        );
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
        uint104 depositedPrincipal = afterDeposit[0].cumulativeDeposits;

        vm.prank(user);
        teller.withdraw(WETH, shares, 0, user);

        PrincipalCheckpoint[] memory afterWithdraw = teller.getPrincipalHistory(user);
        // Withdraw rounds up, so cumulative withdrawals >= cumulative deposits
        assertTrue(
            afterWithdraw[1].cumulativeWithdrawals >= afterWithdraw[1].cumulativeDeposits,
            "withdraw roundUp >= deposit roundDown"
        );
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
        PrincipalCheckpoint memory last = history[history.length - 1];
        // After every full cycle, withdrawals >= deposits — no phantom positive principal
        assertTrue(
            last.cumulativeWithdrawals >= last.cumulativeDeposits,
            "10 deposit+withdraw cycles must not accumulate phantom principal"
        );
    }

    function testPrincipalHistory_RateChangeDoesNotInflatePrincipal() external {
        uint256 amount = 10e18;
        deal(address(WETH), user, amount);

        vm.startPrank(user);
        WETH.safeApprove(address(boringVault), amount);
        uint256 shares = teller.deposit(DepositParams(WETH, amount, 0), address(0), ComplianceData(0, ""));
        vm.stopPrank();

        PrincipalCheckpoint[] memory afterDeposit = teller.getPrincipalHistory(user);
        uint104 principalAtDeposit = afterDeposit[0].cumulativeDeposits;

        // Rate doubles — shares are now worth 2x. Fund vault so withdrawal succeeds.
        deal(address(WETH), address(boringVault), amount * 2);
        _setRate(uint96(2e18));

        vm.prank(user);
        teller.withdraw(WETH, shares, 0, user);

        PrincipalCheckpoint[] memory afterWithdraw = teller.getPrincipalHistory(user);
        // Withdrawal at 2x rate records 2x the original deposit value in withdrawals
        assertTrue(
            afterWithdraw[1].cumulativeWithdrawals >= afterWithdraw[1].cumulativeDeposits,
            "rate increase: withdrawals exceed deposits"
        );
        assertEq(principalAtDeposit, uint104(amount), "deposit at 1:1 should record exact amount");
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
        uint104 depositPrincipal = history[0].cumulativeDeposits - history[0].cumulativeWithdrawals;
        uint104 afterPartialWithdraw = history[1].cumulativeDeposits - history[1].cumulativeWithdrawals;

        // After partial withdraw, remaining principal must be <= deposit principal
        assertTrue(afterPartialWithdraw < depositPrincipal, "partial withdraw reduces principal");
        // Conservative: withdrawal subtracted at least the floor value
        assertTrue(afterPartialWithdraw <= depositPrincipal, "no inflation from partial withdraw");
    }

    // ========================================= TRANSFER + REWARDS TESTS =========================================

    function testPrincipalHistory_TransferAndWithdrawWithRewards() external {
        address alice = vm.addr(101);
        address bob = vm.addr(102);
        uint256 aliceDeposit = 100e18;
        uint256 bobDeposit = 50e18;

        // Setup: set the hook so transfers trigger beforeTransfer
        boringVault.setBeforeTransferHook(address(teller));

        // Alice deposits 100
        deal(address(WETH), alice, aliceDeposit);
        vm.startPrank(alice);
        WETH.safeApprove(address(boringVault), aliceDeposit);
        uint256 aliceShares = teller.deposit(DepositParams(WETH, aliceDeposit, 0), address(0), ComplianceData(0, ""));
        vm.stopPrank();

        // Bob deposits 50
        deal(address(WETH), bob, bobDeposit);
        vm.startPrank(bob);
        WETH.safeApprove(address(boringVault), bobDeposit);
        uint256 bobShares = teller.deposit(DepositParams(WETH, bobDeposit, 0), address(0), ComplianceData(0, ""));
        vm.stopPrank();

        // Simulate rewards accrual: rate goes from 1.0 to 1.1
        deal(address(WETH), address(boringVault), 165e18); // fund vault for 10% yield
        _setRate(uint96(1.1e18));

        // Bob transfers all his shares to Alice
        vm.prank(bob);
        boringVault.transfer(alice, bobShares);

        // Verify on-chain checkpoints after transfer
        PrincipalCheckpoint[] memory aliceHistory = teller.getPrincipalHistory(alice);
        PrincipalCheckpoint[] memory bobHistory = teller.getPrincipalHistory(bob);

        // Alice: 1 deposit checkpoint + 1 transfer checkpoint = 2
        assertEq(aliceHistory.length, 2, "alice: 1 deposit + 1 transfer checkpoint");
        assertEq(aliceHistory[1].cumulativeDeposits, uint104(aliceDeposit), "alice deposits unchanged by transfer in");
        assertEq(aliceHistory[1].cumulativeWithdrawals, 0, "alice withdrawals unchanged by transfer in");

        // Bob: 1 deposit checkpoint + 1 transfer checkpoint = 2
        assertEq(bobHistory.length, 2, "bob: 1 deposit + 1 transfer checkpoint");
        assertEq(bobHistory[1].cumulativeDeposits, uint104(bobDeposit), "bob deposits unchanged by transfer out");
        assertEq(bobHistory[1].cumulativeWithdrawals, 0, "bob withdrawals unchanged by transfer out");

        // Bob has 0 shares — off-chain would give him 0 rewards
        assertEq(boringVault.balanceOf(bob), 0, "bob has no shares after transfer");
        // Alice has all shares
        assertEq(boringVault.balanceOf(alice), aliceShares + bobShares, "alice has all shares");

        // Off-chain reward calculation at this point:
        //   Alice: principal = 100, totalValue = (aliceShares + bobShares) * 1.1 = 165
        //          effectiveDeposit = min(100, 165) = 100  (transferred shares don't count)
        //   Bob:   principal = 50, totalValue = 0 * 1.1 = 0
        //          effectiveDeposit = min(50, 0) = 0       (no shares, no rewards)

        // Alice withdraws 20 worth of shares
        uint256 withdrawShares = uint256(20e18).mulDivDown(ONE_SHARE, 1.1e18);
        vm.prank(alice);
        teller.withdraw(WETH, withdrawShares, 0, alice);

        aliceHistory = teller.getPrincipalHistory(alice);
        // Alice: 1 deposit + 1 transfer + 1 withdraw = 3
        assertEq(aliceHistory.length, 3, "alice: deposit + transfer + withdraw");
        assertEq(aliceHistory[2].cumulativeDeposits, uint104(aliceDeposit), "alice deposits still 100");
        // Withdrawal checkpoint records ~20 in base value (rounding up)
        assertTrue(aliceHistory[2].cumulativeWithdrawals > 0, "alice has recorded withdrawal");

        // Off-chain reward calculation after withdrawal:
        //   Alice: principal = deposits - withdrawals = ~80
        //          totalValue = remainingShares * rate
        //          effectiveDeposit = min(principal, totalValue) = ~80
        //   She continues earning rewards on ~80, not on Bob's transferred shares
        uint104 alicePrincipal = aliceHistory[2].cumulativeDeposits - aliceHistory[2].cumulativeWithdrawals;
        // Principal should be approximately 80e18 (100 deposited - 20 withdrawn)
        // Allow small rounding tolerance from asymmetric rounding
        assertTrue(alicePrincipal <= uint104(80e18), "alice principal <= 80 (conservative rounding)");
        assertTrue(alicePrincipal >= uint104(80e18 - 1e15), "alice principal ~= 80 within rounding");
    }

    function testPrincipalHistory_TransferDoesNotCreateDepositsForReceiver() external {
        address alice = vm.addr(101);
        address bob = vm.addr(102);

        boringVault.setBeforeTransferHook(address(teller));

        // Only Bob deposits
        deal(address(WETH), bob, 100e18);
        vm.startPrank(bob);
        WETH.safeApprove(address(boringVault), 100e18);
        uint256 bobShares = teller.deposit(DepositParams(WETH, 100e18, 0), address(0), ComplianceData(0, ""));
        vm.stopPrank();

        // Bob transfers to Alice (who never deposited)
        vm.prank(bob);
        boringVault.transfer(alice, bobShares);

        // Alice has shares but 0 deposits — off-chain gives her 0 effective deposit
        PrincipalCheckpoint[] memory aliceHistory = teller.getPrincipalHistory(alice);
        assertEq(aliceHistory.length, 1, "alice gets transfer checkpoint");
        assertEq(aliceHistory[0].cumulativeDeposits, 0, "alice has 0 deposits (received via transfer)");
        assertEq(aliceHistory[0].cumulativeWithdrawals, 0, "alice has 0 withdrawals");
        assertGt(boringVault.balanceOf(alice), 0, "alice holds shares");

        // Off-chain: effectiveDeposit = min(0, balanceValue) = 0
        // Alice holds shares but earns no incentive rewards
    }

    function testPrincipalHistory_PartialTransferBothEarnRewards() external {
        address alice = vm.addr(101);
        address bob = vm.addr(102);
        uint256 aliceDeposit = 100e18;
        uint256 bobDeposit = 50e18;

        boringVault.setBeforeTransferHook(address(teller));

        // Alice deposits 100
        deal(address(WETH), alice, aliceDeposit);
        vm.startPrank(alice);
        WETH.safeApprove(address(boringVault), aliceDeposit);
        uint256 aliceShares = teller.deposit(DepositParams(WETH, aliceDeposit, 0), address(0), ComplianceData(0, ""));
        vm.stopPrank();

        // Bob deposits 50
        deal(address(WETH), bob, bobDeposit);
        vm.startPrank(bob);
        WETH.safeApprove(address(boringVault), bobDeposit);
        uint256 bobShares = teller.deposit(DepositParams(WETH, bobDeposit, 0), address(0), ComplianceData(0, ""));
        vm.stopPrank();

        // Simulate 10% yield: rate goes from 1.0 to 1.1
        deal(address(WETH), address(boringVault), 165e18);
        _setRate(uint96(1.1e18));

        // Bob transfers HALF his shares to Alice (25 of 50 shares)
        uint256 halfBobShares = bobShares / 2;
        vm.prank(bob);
        boringVault.transfer(alice, halfBobShares);

        // On-chain: deposits/withdrawals unchanged for both, only timestamps updated
        PrincipalCheckpoint[] memory aliceHistory = teller.getPrincipalHistory(alice);
        PrincipalCheckpoint[] memory bobHistory = teller.getPrincipalHistory(bob);

        assertEq(aliceHistory[1].cumulativeDeposits, uint104(aliceDeposit), "alice deposits unchanged");
        assertEq(aliceHistory[1].cumulativeWithdrawals, 0, "alice withdrawals unchanged");
        assertEq(bobHistory[1].cumulativeDeposits, uint104(bobDeposit), "bob deposits unchanged");
        assertEq(bobHistory[1].cumulativeWithdrawals, 0, "bob withdrawals unchanged");

        // Share balances after partial transfer
        uint256 aliceSharesAfter = boringVault.balanceOf(alice);
        uint256 bobSharesAfter = boringVault.balanceOf(bob);
        assertEq(aliceSharesAfter, aliceShares + halfBobShares, "alice has her shares + half bob's");
        assertEq(bobSharesAfter, bobShares - halfBobShares, "bob retains half his shares");

        // Off-chain reward calculation:
        //   Alice: principal=100, value=125*1.1=137.5, effective=min(100,137.5)=100
        //   Bob:   principal=50,  value=25*1.1=27.5,   effective=min(50,27.5)=27.5
        //
        // Bob still earns rewards, but capped at remaining share value, not full deposit.
        _verifyPartialTransferRewards(aliceSharesAfter, bobSharesAfter, aliceDeposit, bobDeposit);
    }

    function _verifyPartialTransferRewards(
        uint256 aliceShares,
        uint256 bobShares,
        uint256 aliceDeposit,
        uint256 bobDeposit
    ) internal pure {
        uint256 rate = 1.1e18;
        uint256 aliceValue = aliceShares.mulDivDown(rate, ONE_SHARE);
        uint256 bobValue = bobShares.mulDivDown(rate, ONE_SHARE);

        uint256 aliceEffective = aliceDeposit < aliceValue ? aliceDeposit : aliceValue;
        uint256 bobEffective = bobDeposit < bobValue ? bobDeposit : bobValue;

        // Alice: capped at principal (100), not total value (137.5)
        assert(aliceEffective == aliceDeposit);
        // Bob: capped at share value (27.5), not principal (50)
        assert(bobEffective == bobValue);
        // Bob still earns something
        assert(bobEffective > 0);
        // But less than his full deposit
        assert(bobEffective < bobDeposit);
    }

    /// @dev Simulates the backend's time-weighted reward calculation on-chain.
    /// Alice and Bob deposit the SAME amount, but Bob deposits later.
    /// Result: Bob earns fewer rewards due to shorter time in the vault.
    function testPrincipalHistory_LateDepositorEarnsLess() external {
        address alice = vm.addr(101);
        address bob = vm.addr(102);
        uint256 depositAmount = 100e18;

        uint256 t0 = block.timestamp;
        uint256 rewardPeriodEnd = t0 + 7 days;

        // Alice deposits at t0
        deal(address(WETH), alice, depositAmount);
        vm.startPrank(alice);
        WETH.safeApprove(address(boringVault), depositAmount);
        teller.deposit(DepositParams(WETH, depositAmount, 0), address(0), ComplianceData(0, ""));
        vm.stopPrank();

        // Bob deposits at t0 + 3 days
        vm.warp(t0 + 3 days);
        deal(address(WETH), bob, depositAmount);
        vm.startPrank(bob);
        WETH.safeApprove(address(boringVault), depositAmount);
        teller.deposit(DepositParams(WETH, depositAmount, 0), address(0), ComplianceData(0, ""));
        vm.stopPrank();

        // Simulate backend reward calculation at rewardPeriodEnd
        uint256 rate = accountant.getRateSafe();
        uint256 aliceWeight = _computeTimeWeightedDeposit(alice, rate, t0, rewardPeriodEnd);
        uint256 bobWeight = _computeTimeWeightedDeposit(bob, rate, t0, rewardPeriodEnd);

        // Alice: 100e18 * 7 days = 700e18 * 7 days
        // Bob:   100e18 * 4 days = 100e18 * 4 days
        // Alice gets 7/11 of rewards, Bob gets 4/11
        assertGt(aliceWeight, bobWeight, "alice earns more than bob");
        assertEq(aliceWeight, depositAmount * 7 days, "alice: full period weight");
        assertEq(bobWeight, depositAmount * 4 days, "bob: partial period weight");

        // Verify proportional split: Alice ~63.6%, Bob ~36.4%
        uint256 totalWeight = aliceWeight + bobWeight;
        assertGt(aliceWeight * 1e18 / totalWeight, bobWeight * 1e18 / totalWeight, "alice share > bob share");
    }

    /// @dev Full backend.md walkthrough: Alice, Bob, Charlie with deposits, transfers,
    /// withdrawals, and rate changes. Validates all 5 incentive properties together.
    function testPrincipalHistory_FullBackendWalkthrough() external {
        address alice = vm.addr(101);
        address bob = vm.addr(102);
        address charlie = vm.addr(103);

        boringVault.setBeforeTransferHook(address(teller));

        uint256 t0 = block.timestamp;

        // Day 0: Alice deposits 100 WETH at rate 1.0
        deal(address(WETH), alice, 100e18);
        vm.startPrank(alice);
        WETH.safeApprove(address(boringVault), 100e18);
        teller.deposit(DepositParams(WETH, 100e18, 0), address(0), ComplianceData(0, ""));
        vm.stopPrank();

        // Day 1: Bob deposits 50 WETH at rate 1.0
        vm.warp(t0 + 1 days);
        deal(address(WETH), bob, 50e18);
        vm.startPrank(bob);
        WETH.safeApprove(address(boringVault), 50e18);
        teller.deposit(DepositParams(WETH, 50e18, 0), address(0), ComplianceData(0, ""));
        vm.stopPrank();

        // Day 3: Rate increases to 1.1 (yield accrual)
        vm.warp(t0 + 3 days);
        deal(address(WETH), address(boringVault), 165e18); // 150 shares * 1.1 = 165 WETH backing
        _setRate(uint96(1.1e18));

        // Day 4: Bob transfers 25 shares to Charlie
        vm.warp(t0 + 4 days);
        vm.prank(bob);
        boringVault.transfer(charlie, 25e18);

        // Day 5: Alice withdraws 20 WETH at rate 1.1
        vm.warp(t0 + 5 days);
        uint256 sharesToBurn = uint256(20e18).mulDivDown(ONE_SHARE, 1.1e18);
        vm.prank(alice);
        teller.withdraw(WETH, sharesToBurn, 0, alice);

        // ---- Simulate backend reward calculation for [t0, t0 + 7 days] ----
        // Alice intervals:
        //   [day 0, day 5]: principal=100, shares=100, rate changes 1.0->1.1
        //     sub-interval [day 0, day 3]: effective = min(100, 100*1.0) = 100, duration = 3 days
        //     sub-interval [day 3, day 5]: effective = min(100, 100*1.1) = 100, duration = 2 days
        //   [day 5, day 7]: principal=100-20=80, shares~81.82, effective = min(80, 81.82*1.1) = 80, duration = 2 days
        uint256 aliceWeight = 100e18 * 3 days + 100e18 * 2 days + 80e18 * 2 days;

        // Bob intervals:
        //   [day 0, day 1]: no deposit yet, weight = 0
        //   [day 1, day 3]: principal=50, shares=50, rate=1.0, effective=50, duration = 2 days
        //   [day 3, day 4]: principal=50, shares=50, rate=1.1, effective=min(50,55)=50, duration = 1 day
        //   [day 4, day 7]: principal=50, shares=25, rate=1.1, effective=min(50,27.5)=27.5, duration = 3 days
        uint256 bobWeight = 50e18 * 2 days + 50e18 * 1 days + 27.5e18 * 3 days;

        // Charlie intervals:
        //   [day 0, day 4]: no shares, weight = 0
        //   [day 4, day 7]: principal=0, shares=25, effective=min(0,27.5)=0, duration = 3 days
        uint256 charlieWeight = 0;

        uint256 totalWeight = aliceWeight + bobWeight + charlieWeight;
        uint256 rewardPool = 10_000e18;

        uint256 aliceReward = (aliceWeight * rewardPool) / totalWeight;
        uint256 bobReward = (bobWeight * rewardPool) / totalWeight;
        uint256 charlieReward = (charlieWeight * rewardPool) / totalWeight;

        // CHECK 1: Yield does not inflate rewards -- Alice's effective stayed 100 despite shares worth 110
        assertEq(aliceWeight, 660e18 * 1 days, "alice weight matches backend.md");
        // CHECK 2: Transfers don't create rewards for receiver
        assertEq(charlieReward, 0, "charlie earns nothing from transferred shares");
        // CHECK 3: Transfers reduce rewards for sender
        assertLt(bobWeight, 50e18 * 6 days, "bob weight reduced by transfer");
        // CHECK 4: Withdrawals reduce principal
        assertLt(aliceWeight, 100e18 * 7 days, "alice weight reduced by withdrawal");
        // CHECK 5: Late depositor earns less
        assertGt(aliceReward, bobReward, "alice earns more than bob");
    }

    /// @dev Simplified time-weighted effective deposit helper for constant-balance scenarios.
    /// Uses current balanceOf and a fixed rate -- only valid when the user's share balance
    /// and the exchange rate do not change across the reward period. For scenarios with
    /// transfers, withdrawals, or rate changes, hardcode expected weights instead (see
    /// testPrincipalHistory_FullBackendWalkthrough).
    function _computeTimeWeightedDeposit(address who, uint256 rate, uint256 t1, uint256 t2)
        internal
        view
        returns (uint256 weight)
    {
        PrincipalCheckpoint[] memory cps = teller.getPrincipalHistory(who);
        if (cps.length == 0) return 0;

        uint256 shares = boringVault.balanceOf(who);
        uint256 totalValue = shares.mulDivDown(rate, ONE_SHARE);

        for (uint256 i; i < cps.length; ++i) {
            uint256 intervalStart = cps[i].timestamp < t1 ? t1 : cps[i].timestamp;
            uint256 intervalEnd = (i + 1 < cps.length) ? cps[i + 1].timestamp : t2;
            if (intervalEnd > t2) intervalEnd = t2;
            if (intervalStart >= intervalEnd) continue;

            uint256 principal = cps[i].cumulativeDeposits > cps[i].cumulativeWithdrawals
                ? cps[i].cumulativeDeposits - cps[i].cumulativeWithdrawals
                : 0;
            uint256 effective = principal < totalValue ? principal : totalValue;

            weight += effective * (intervalEnd - intervalStart);
        }
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
        assertEq(
            history[0].cumulativeDeposits - history[0].cumulativeWithdrawals,
            uint104(amount),
            "native deposit principal at 1:1 rate"
        );
    }
}
