// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {
    TellerWithMultiAssetSupport,
    DepositParams,
    ComplianceData,
    PrincipalCheckpoint
} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import {BoringOnChainQueueWithTracking} from "src/base/Roles/BoringQueue/BoringOnChainQueueWithTracking.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {Test, Vm} from "@forge-std/Test.sol";

contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC", 6) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockRevertingTeller {
    function checkpointQueueWithdrawal(address, uint256) external pure {
        revert("teller: always reverts");
    }
}

contract BoringQueuePrincipalCheckpointTest is Test {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    // ========================================= ROLES =========================================

    uint8 public constant ADMIN_ROLE = 1;
    uint8 public constant MINTER_ROLE = 2;
    uint8 public constant BURNER_ROLE = 3;
    uint8 public constant SOLVER_ROLE = 4;
    uint8 public constant QUEUE_CHECKPOINT_ROLE = 5;

    // ========================================= CONTRACTS =========================================

    MockUSDC public usdc;
    BoringVault public boringVault;
    AccountantWithRateProviders public accountant;
    TellerWithMultiAssetSupport public teller;
    BoringOnChainQueueWithTracking public boringQueue;
    RolesAuthority public rolesAuthority;

    address public payout_address = vm.addr(7777777);
    address public user = vm.addr(1);
    address public user2 = vm.addr(2);
    address public solver = vm.addr(3);

    uint24 internal constant SECONDS_TO_MATURITY = 3 days;
    uint24 internal constant SECONDS_TO_DEADLINE = 1 days;
    uint16 internal constant DISCOUNT = 1; // 0.01% minimum

    function setUp() public {
        usdc = new MockUSDC();
        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 6);
        // Rate is in base-asset units per ONE_SHARE. With a 6-decimal vault (ONE_SHARE = 1e6)
        // and 6-decimal USDC, a rate of 1e6 means 1 share = 1 USDC at inception.
        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), payout_address, 1e6, address(usdc), 1.001e4, 0.999e4, 1, 0, 0
        );
        teller =
            new TellerWithMultiAssetSupport(address(this), address(boringVault), address(accountant), address(usdc));
        boringQueue = new BoringOnChainQueueWithTracking(
            address(this), address(0), payable(address(boringVault)), address(accountant), false
        );
        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));

        boringVault.setAuthority(rolesAuthority);
        accountant.setAuthority(rolesAuthority);
        teller.setAuthority(rolesAuthority);
        boringQueue.setAuthority(rolesAuthority);

        // Vault
        rolesAuthority.setRoleCapability(MINTER_ROLE, address(boringVault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(boringVault), BoringVault.exit.selector, true);

        // Teller
        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.deposit.selector, true);
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.updateAssetData.selector, true
        );
        rolesAuthority.setRoleCapability(
            QUEUE_CHECKPOINT_ROLE, address(teller), TellerWithMultiAssetSupport.checkpointQueueWithdrawal.selector, true
        );

        // Queue
        rolesAuthority.setPublicCapability(
            address(boringQueue), BoringOnChainQueue.requestOnChainWithdraw.selector, true
        );
        rolesAuthority.setPublicCapability(
            address(boringQueue), BoringOnChainQueue.cancelOnChainWithdraw.selector, true
        );
        rolesAuthority.setRoleCapability(
            SOLVER_ROLE, address(boringQueue), BoringOnChainQueue.solveOnChainWithdraws.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(boringQueue), BoringOnChainQueue.updateWithdrawAsset.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(boringQueue), BoringOnChainQueue.setPrincipalTeller.selector, true
        );

        // Role assignments
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);
        rolesAuthority.setUserRole(solver, SOLVER_ROLE, true);
        rolesAuthority.setUserRole(address(boringQueue), QUEUE_CHECKPOINT_ROLE, true);

        teller.updateAssetData(ERC20(address(usdc)), true, true, 0);
        boringQueue.updateWithdrawAsset(address(usdc), SECONDS_TO_MATURITY, SECONDS_TO_DEADLINE, 1, 100, 0.01e6);
        boringQueue.setPrincipalTeller(address(teller));
    }

    // ========================================= TESTS =========================================

    function testSolveCheckpointsWithdrawal() external {
        uint256 depositAmount = 1e6;
        uint128 withdrawShares = 0.5e6;

        // Deposit — creates first checkpoint
        _deposit(user, depositAmount);

        (PrincipalCheckpoint[] memory history,) = teller.getPrincipalHistoryPaginated(user, 0, type(uint256).max);
        assertEq(history.length, 1, "one checkpoint after deposit");
        assertEq(history[0].cumulativeDeposits, depositAmount, "cumulative deposits = deposit amount");
        assertEq(history[0].cumulativeWithdrawals, 0, "no withdrawals yet");

        // Queue withdrawal — no checkpoint
        BoringOnChainQueue.OnChainWithdraw memory request =
            _requestWithdrawal(user, withdrawShares, DISCOUNT, SECONDS_TO_DEADLINE);

        (history,) = teller.getPrincipalHistoryPaginated(user, 0, type(uint256).max);
        assertEq(history.length, 1, "no new checkpoint after queue request");

        skip(SECONDS_TO_MATURITY + 1);

        // Solve — should produce withdrawal checkpoint
        _solve(request);

        (history,) = teller.getPrincipalHistoryPaginated(user, 0, type(uint256).max);
        assertEq(history.length, 2, "second checkpoint after queue solve");
        assertEq(history[1].cumulativeDeposits, depositAmount, "cumulative deposits unchanged");
        // Withdrawals round up: shares * rate / ONE_SHARE (rate = 1e6, ONE_SHARE = 1e6) = withdrawShares
        assertEq(history[1].cumulativeWithdrawals, withdrawShares, "cumulative withdrawals = withdrawn shares");
    }

    function testCancelDoesNotCheckpoint() external {
        _deposit(user, 1e6);

        BoringOnChainQueue.OnChainWithdraw memory request =
            _requestWithdrawal(user, 0.5e6, DISCOUNT, SECONDS_TO_DEADLINE);

        (PrincipalCheckpoint[] memory history,) = teller.getPrincipalHistoryPaginated(user, 0, type(uint256).max);
        assertEq(history.length, 1, "one checkpoint after deposit");

        vm.prank(user);
        boringQueue.cancelOnChainWithdraw(request);

        (history,) = teller.getPrincipalHistoryPaginated(user, 0, type(uint256).max);
        assertEq(history.length, 1, "no new checkpoint after cancel");
        assertEq(history[0].cumulativeWithdrawals, 0, "withdrawals still zero after cancel");
    }

    function testSolveMultipleUsersCheckpointsEach() external {
        uint128 withdrawShares1 = 0.5e6;
        uint128 withdrawShares2 = 1e6;

        _deposit(user, 2e6);
        _deposit(user2, 2e6);

        BoringOnChainQueue.OnChainWithdraw memory request1 =
            _requestWithdrawal(user, withdrawShares1, DISCOUNT, SECONDS_TO_DEADLINE);
        BoringOnChainQueue.OnChainWithdraw memory request2 =
            _requestWithdrawal(user2, withdrawShares2, DISCOUNT, SECONDS_TO_DEADLINE);

        skip(SECONDS_TO_MATURITY + 1);

        BoringOnChainQueue.OnChainWithdraw[] memory requests = new BoringOnChainQueue.OnChainWithdraw[](2);
        requests[0] = request1;
        requests[1] = request2;

        uint256 totalAssets = request1.amountOfAssets + request2.amountOfAssets;
        usdc.mint(solver, totalAssets);
        vm.startPrank(solver);
        ERC20(address(usdc)).safeApprove(address(boringQueue), totalAssets);
        boringQueue.solveOnChainWithdraws(requests, hex"", solver);
        vm.stopPrank();

        (PrincipalCheckpoint[] memory history1,) = teller.getPrincipalHistoryPaginated(user, 0, type(uint256).max);
        (PrincipalCheckpoint[] memory history2,) = teller.getPrincipalHistoryPaginated(user2, 0, type(uint256).max);

        assertEq(history1.length, 2, "user1: deposit + withdrawal checkpoint");
        assertEq(history2.length, 2, "user2: deposit + withdrawal checkpoint");
        assertEq(history1[1].cumulativeWithdrawals, withdrawShares1, "user1 withdrawal checkpointed");
        assertEq(history2[1].cumulativeWithdrawals, withdrawShares2, "user2 withdrawal checkpointed");
    }

    function testNoCheckpointWhenPrincipalTellerNotSet() external {
        // Deploy a queue without setting principalTeller
        BoringOnChainQueueWithTracking bareQueue = new BoringOnChainQueueWithTracking(
            address(this), address(0), payable(address(boringVault)), address(accountant), false
        );
        bareQueue.setAuthority(rolesAuthority);
        rolesAuthority.setUserRole(address(bareQueue), QUEUE_CHECKPOINT_ROLE, true);
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(bareQueue), BoringOnChainQueue.updateWithdrawAsset.selector, true
        );
        rolesAuthority.setRoleCapability(
            SOLVER_ROLE, address(bareQueue), BoringOnChainQueue.solveOnChainWithdraws.selector, true
        );
        rolesAuthority.setPublicCapability(address(bareQueue), BoringOnChainQueue.requestOnChainWithdraw.selector, true);
        bareQueue.updateWithdrawAsset(address(usdc), SECONDS_TO_MATURITY, SECONDS_TO_DEADLINE, 1, 100, 0.01e6);
        // principalTeller intentionally NOT set

        uint128 withdrawShares = 0.5e6;
        _deposit(user, 1e6);

        vm.startPrank(user);
        ERC20(address(boringVault)).safeApprove(address(bareQueue), withdrawShares);
        vm.recordLogs();
        bareQueue.requestOnChainWithdraw(address(usdc), withdrawShares, DISCOUNT, SECONDS_TO_DEADLINE);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        vm.stopPrank();

        BoringOnChainQueue.OnChainWithdraw memory request = _parseRequest(entries);

        skip(SECONDS_TO_MATURITY + 1);

        usdc.mint(solver, request.amountOfAssets);
        vm.startPrank(solver);
        ERC20(address(usdc)).safeApprove(address(bareQueue), request.amountOfAssets);
        BoringOnChainQueue.OnChainWithdraw[] memory requests = new BoringOnChainQueue.OnChainWithdraw[](1);
        requests[0] = request;
        bareQueue.solveOnChainWithdraws(requests, hex"", solver);
        vm.stopPrank();

        (PrincipalCheckpoint[] memory history,) = teller.getPrincipalHistoryPaginated(user, 0, type(uint256).max);
        assertEq(history.length, 1, "no withdrawal checkpoint when principalTeller not set");
    }

    function testFuzz_SolveCheckpointsCorrectAmount(uint128 depositShares, uint128 withdrawShares) external {
        depositShares = uint128(bound(depositShares, 0.01e6, 100e6));
        withdrawShares = uint128(bound(withdrawShares, 0.01e6, depositShares));

        _deposit(user, depositShares); // rate = 1e6, ONE_SHARE = 1e6, so shares == deposit amount

        BoringOnChainQueue.OnChainWithdraw memory request =
            _requestWithdrawal(user, withdrawShares, DISCOUNT, SECONDS_TO_DEADLINE);

        skip(SECONDS_TO_MATURITY + 1);
        _solve(request);

        (PrincipalCheckpoint[] memory history,) = teller.getPrincipalHistoryPaginated(user, 0, type(uint256).max);
        assertEq(history.length, 2, "deposit + withdrawal checkpoint");

        uint256 ONE_SHARE = 10 ** boringVault.decimals();
        uint256 rate = accountant.getRateSafe();
        uint256 expectedWithdrawal = uint256(withdrawShares).mulDivUp(rate, ONE_SHARE);
        assertEq(history[1].cumulativeWithdrawals, expectedWithdrawal, "withdrawal value = mulDivUp(shares, rate)");
        assertEq(history[1].cumulativeDeposits, depositShares, "deposits untouched by withdrawal checkpoint");
    }

    function testReplaceDoesNotCheckpoint() external {
        rolesAuthority.setPublicCapability(
            address(boringQueue), BoringOnChainQueue.replaceOnChainWithdraw.selector, true
        );

        _deposit(user, 1e6);

        BoringOnChainQueue.OnChainWithdraw memory request =
            _requestWithdrawal(user, 0.5e6, DISCOUNT, SECONDS_TO_DEADLINE);

        // Replace before maturity — shares stay in the contract, no solve, no checkpoint.
        vm.prank(user);
        boringQueue.replaceOnChainWithdraw(request, DISCOUNT, SECONDS_TO_DEADLINE);

        (PrincipalCheckpoint[] memory history,) = teller.getPrincipalHistoryPaginated(user, 0, type(uint256).max);
        assertEq(history.length, 1, "no new checkpoint after replace");
        assertEq(history[0].cumulativeWithdrawals, 0, "withdrawals still zero after replace");
    }

    function testClearPrincipalTellerDisablesCheckpoint() external {
        // Teller was set in setUp; clear it before the solve.
        boringQueue.setPrincipalTeller(address(0));

        _deposit(user, 1e6);

        BoringOnChainQueue.OnChainWithdraw memory request =
            _requestWithdrawal(user, 0.5e6, DISCOUNT, SECONDS_TO_DEADLINE);

        skip(SECONDS_TO_MATURITY + 1);
        _solve(request);

        (PrincipalCheckpoint[] memory history,) = teller.getPrincipalHistoryPaginated(user, 0, type(uint256).max);
        assertEq(history.length, 1, "no withdrawal checkpoint when principalTeller cleared at solve time");
        assertEq(history[0].cumulativeWithdrawals, 0, "withdrawals still zero");
    }

    function testSameUserBatchSolveAccumulatesCheckpoints() external {
        uint128 shares1 = 0.3e6;
        uint128 shares2 = 0.4e6;

        _deposit(user, 1e6);

        BoringOnChainQueue.OnChainWithdraw memory req1 =
            _requestWithdrawal(user, shares1, DISCOUNT, SECONDS_TO_DEADLINE);
        BoringOnChainQueue.OnChainWithdraw memory req2 =
            _requestWithdrawal(user, shares2, DISCOUNT, SECONDS_TO_DEADLINE);

        skip(SECONDS_TO_MATURITY + 1);

        BoringOnChainQueue.OnChainWithdraw[] memory requests = new BoringOnChainQueue.OnChainWithdraw[](2);
        requests[0] = req1;
        requests[1] = req2;

        uint256 totalAssets = req1.amountOfAssets + req2.amountOfAssets;
        usdc.mint(solver, totalAssets);
        vm.startPrank(solver);
        ERC20(address(usdc)).safeApprove(address(boringQueue), totalAssets);
        boringQueue.solveOnChainWithdraws(requests, hex"", solver);
        vm.stopPrank();

        uint256 ONE_SHARE = 10 ** boringVault.decimals();
        uint256 rate = accountant.getRateSafe();
        uint256 expectedW1 = uint256(shares1).mulDivUp(rate, ONE_SHARE);
        uint256 expectedW2 = uint256(shares2).mulDivUp(rate, ONE_SHARE);

        (PrincipalCheckpoint[] memory history,) = teller.getPrincipalHistoryPaginated(user, 0, type(uint256).max);
        assertEq(history.length, 3, "deposit + one checkpoint per solved request");
        assertEq(history[1].cumulativeWithdrawals, expectedW1, "first request checkpointed");
        assertEq(history[2].cumulativeWithdrawals, expectedW1 + expectedW2, "second request accumulates onto first");
        assertEq(history[2].cumulativeDeposits, 1e6, "deposits untouched throughout");
    }

    function testFuzz_TwoSequentialWithdrawalsAccumulate(uint128 depositShares, uint128 shares1, uint128 shares2)
        external
    {
        depositShares = uint128(bound(depositShares, 0.02e6, 100e6));
        shares1 = uint128(bound(shares1, 0.01e6, depositShares - 0.01e6));
        shares2 = uint128(bound(shares2, 0.01e6, depositShares - shares1));

        _deposit(user, depositShares);

        BoringOnChainQueue.OnChainWithdraw memory req1 =
            _requestWithdrawal(user, shares1, DISCOUNT, SECONDS_TO_DEADLINE);
        skip(SECONDS_TO_MATURITY + 1);
        _solve(req1);

        BoringOnChainQueue.OnChainWithdraw memory req2 =
            _requestWithdrawal(user, shares2, DISCOUNT, SECONDS_TO_DEADLINE);
        skip(SECONDS_TO_MATURITY + 1);
        _solve(req2);

        uint256 ONE_SHARE = 10 ** boringVault.decimals();
        uint256 rate = accountant.getRateSafe();
        uint256 expectedW1 = uint256(shares1).mulDivUp(rate, ONE_SHARE);
        uint256 expectedW2 = uint256(shares2).mulDivUp(rate, ONE_SHARE);

        (PrincipalCheckpoint[] memory history,) = teller.getPrincipalHistoryPaginated(user, 0, type(uint256).max);
        assertEq(history.length, 3, "deposit + two withdrawal checkpoints");
        assertEq(history[1].cumulativeWithdrawals, expectedW1, "first withdrawal value");
        assertEq(history[2].cumulativeWithdrawals, expectedW1 + expectedW2, "cumulative after two withdrawals");
        assertEq(history[2].cumulativeDeposits, depositShares, "deposits untouched");
    }

    function testSelfSolveCheckpointsWithdrawal() external {
        uint256 depositAmount = 1e6;
        uint128 withdrawShares = 0.5e6;

        _deposit(user, depositAmount);

        BoringOnChainQueue.OnChainWithdraw memory request =
            _requestWithdrawal(user, withdrawShares, DISCOUNT, SECONDS_TO_DEADLINE);

        skip(SECONDS_TO_MATURITY + 1);

        // Grant user solver role so they can act as their own solver.
        rolesAuthority.setUserRole(user, SOLVER_ROLE, true);

        usdc.mint(user, request.amountOfAssets);
        vm.startPrank(user);
        ERC20(address(usdc)).safeApprove(address(boringQueue), request.amountOfAssets);
        BoringOnChainQueue.OnChainWithdraw[] memory requests = new BoringOnChainQueue.OnChainWithdraw[](1);
        requests[0] = request;
        boringQueue.solveOnChainWithdraws(requests, hex"", user);
        vm.stopPrank();

        (PrincipalCheckpoint[] memory history,) = teller.getPrincipalHistoryPaginated(user, 0, type(uint256).max);
        assertEq(history.length, 2, "deposit + withdrawal checkpoint after self-solve");
        assertEq(history[1].cumulativeWithdrawals, withdrawShares, "self-solve: withdrawal checkpointed correctly");
        assertEq(history[1].cumulativeDeposits, depositAmount, "self-solve: deposits untouched");
    }

    // User received shares via transfer (not through the teller) so has no principal history.
    // checkpointQueueWithdrawal hits the `len == 0` early return and creates no checkpoint.
    function testSolveWithNoDepositHistory_NoCheckpoint() external {
        address user3 = vm.addr(4);
        uint128 transferredShares = 0.5e6;

        _deposit(user2, 1e6);
        vm.prank(user2);
        ERC20(address(boringVault)).safeTransfer(user3, transferredShares);

        vm.startPrank(user3);
        ERC20(address(boringVault)).safeApprove(address(boringQueue), transferredShares);
        vm.recordLogs();
        boringQueue.requestOnChainWithdraw(address(usdc), transferredShares, DISCOUNT, SECONDS_TO_DEADLINE);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        vm.stopPrank();

        BoringOnChainQueue.OnChainWithdraw memory request = _parseRequest(entries);

        skip(SECONDS_TO_MATURITY + 1);

        usdc.mint(solver, request.amountOfAssets);
        vm.startPrank(solver);
        ERC20(address(usdc)).safeApprove(address(boringQueue), request.amountOfAssets);
        BoringOnChainQueue.OnChainWithdraw[] memory requests = new BoringOnChainQueue.OnChainWithdraw[](1);
        requests[0] = request;
        boringQueue.solveOnChainWithdraws(requests, hex"", solver);
        vm.stopPrank();

        (, uint256 totalLength) = teller.getPrincipalHistoryPaginated(user3, 0, type(uint256).max);
        assertEq(totalLength, 0, "no checkpoint created when user has no deposit history");
    }

    function testCheckpointQueueWithdrawalRoleEnforced() external {
        address unauthorized = vm.addr(99);
        vm.prank(unauthorized);
        vm.expectRevert();
        teller.checkpointQueueWithdrawal(user, 1e6);
    }

    function testDepositAfterQueueWithdrawalCycleAccumulates() external {
        uint256 firstDeposit = 1e6;
        uint128 withdrawShares = 0.5e6;
        uint256 secondDeposit = 0.5e6;

        _deposit(user, firstDeposit);

        BoringOnChainQueue.OnChainWithdraw memory request =
            _requestWithdrawal(user, withdrawShares, DISCOUNT, SECONDS_TO_DEADLINE);

        skip(SECONDS_TO_MATURITY + 1);
        _solve(request);

        // Second deposit after the withdrawal checkpoint.
        _deposit(user, secondDeposit);

        uint256 ONE_SHARE = 10 ** boringVault.decimals();
        uint256 rate = accountant.getRateSafe();
        uint256 expectedWithdrawal = uint256(withdrawShares).mulDivUp(rate, ONE_SHARE);

        (PrincipalCheckpoint[] memory history,) = teller.getPrincipalHistoryPaginated(user, 0, type(uint256).max);
        assertEq(history.length, 3, "deposit + withdrawal + second deposit checkpoints");
        // Withdrawal checkpoint carries deposits forward unchanged.
        assertEq(history[1].cumulativeDeposits, firstDeposit, "withdrawal checkpoint preserves deposits");
        assertEq(history[1].cumulativeWithdrawals, expectedWithdrawal, "withdrawal checkpoint");
        // Second deposit reads from withdrawal checkpoint and adds.
        assertEq(history[2].cumulativeDeposits, firstDeposit + secondDeposit, "second deposit accumulates");
        assertEq(history[2].cumulativeWithdrawals, expectedWithdrawal, "withdrawals unchanged after deposit");
    }

    // If principalTeller is set to an address that reverts, solveOnChainWithdraws is blocked.
    // EVM revert semantics preserve queue state (the dequeue is rolled back), so the request
    // survives and can be solved after the broken teller is cleared.
    function testRevertingPrincipalTellerBlocksSolvesUntilCleared() external {
        MockRevertingTeller revertingTeller = new MockRevertingTeller();
        boringQueue.setPrincipalTeller(address(revertingTeller));

        _deposit(user, 1e6);
        BoringOnChainQueue.OnChainWithdraw memory request =
            _requestWithdrawal(user, 0.5e6, DISCOUNT, SECONDS_TO_DEADLINE);

        skip(SECONDS_TO_MATURITY + 1);

        BoringOnChainQueue.OnChainWithdraw[] memory requests = new BoringOnChainQueue.OnChainWithdraw[](1);
        requests[0] = request;

        usdc.mint(solver, request.amountOfAssets);
        vm.startPrank(solver);
        ERC20(address(usdc)).safeApprove(address(boringQueue), request.amountOfAssets);
        vm.expectRevert();
        boringQueue.solveOnChainWithdraws(requests, hex"", solver);
        vm.stopPrank();

        // EVM revert rolls back _dequeueOnChainWithdraw — request is still in the queue.
        assertEq(boringQueue.getRequestIds().length, 1, "request survives failed solve");

        // Recovery: clear the broken teller. Approval already in place from above.
        boringQueue.setPrincipalTeller(address(0));

        vm.prank(solver);
        boringQueue.solveOnChainWithdraws(requests, hex"", solver);

        assertEq(boringQueue.getRequestIds().length, 0, "request removed after successful solve");
        // No checkpoint since principalTeller is now zero.
        (PrincipalCheckpoint[] memory history,) = teller.getPrincipalHistoryPaginated(user, 0, type(uint256).max);
        assertEq(history.length, 1, "no withdrawal checkpoint after recovery solve");
    }

    // ========================================= HELPERS =========================================

    function _deposit(address depositor, uint256 amount) internal returns (uint256 shares) {
        usdc.mint(depositor, amount);
        vm.startPrank(depositor);
        ERC20(address(usdc)).safeApprove(address(boringVault), amount);
        shares = teller.deposit(
            DepositParams(ERC20(address(usdc)), amount, 0), depositor, address(0), ComplianceData(0, "")
        );
        vm.stopPrank();
    }

    function _requestWithdrawal(address depositor, uint128 shares, uint16 discount, uint24 secondsToDeadline)
        internal
        returns (BoringOnChainQueue.OnChainWithdraw memory request)
    {
        vm.startPrank(depositor);
        ERC20(address(boringVault)).safeApprove(address(boringQueue), shares);
        vm.recordLogs();
        boringQueue.requestOnChainWithdraw(address(usdc), shares, discount, secondsToDeadline);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        vm.stopPrank();
        request = _parseRequest(entries);
    }

    function _parseRequest(Vm.Log[] memory entries)
        internal
        pure
        returns (BoringOnChainQueue.OnChainWithdraw memory request)
    {
        bytes32 eventSig = keccak256(
            "OnChainWithdrawRequested(bytes32,address,address,uint96,uint128,uint128,uint40,uint24,uint24)"
        );
        for (uint256 i; i < entries.length; ++i) {
            if (entries[i].topics[0] == eventSig) {
                request.user = address(bytes20(entries[i].topics[2] << 96));
                request.assetOut = address(bytes20(entries[i].topics[3] << 96));
                (
                    request.nonce,
                    request.amountOfShares,
                    request.amountOfAssets,
                    request.creationTime,
                    request.secondsToMaturity,
                    request.secondsToDeadline
                ) = abi.decode(entries[i].data, (uint96, uint128, uint128, uint40, uint24, uint24));
                break;
            }
        }
    }

    function _solve(BoringOnChainQueue.OnChainWithdraw memory request) internal {
        BoringOnChainQueue.OnChainWithdraw[] memory requests = new BoringOnChainQueue.OnChainWithdraw[](1);
        requests[0] = request;
        usdc.mint(solver, request.amountOfAssets);
        vm.startPrank(solver);
        ERC20(address(usdc)).safeApprove(address(boringQueue), request.amountOfAssets);
        boringQueue.solveOnChainWithdraws(requests, hex"", solver);
        vm.stopPrank();
    }
}
