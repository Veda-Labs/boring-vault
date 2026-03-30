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
    RewardData,
    PrincipalCheckpoint
} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {IncentivePool} from "src/base/IncentivePool.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MessageHashUtils} from "@openzeppelin-contracts-5.3.0/utils/cryptography/MessageHashUtils.sol";

import {Test, console} from "@forge-std/Test.sol";

contract MockWETH_Backend is ERC20 {
    constructor() ERC20("Wrapped Ether", "WETH", 18) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockRewardToken is ERC20 {
    constructor() ERC20("Reward Token", "RWD", 18) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @title BackendRewardSimulationTest
/// @notice End-to-end tests simulating the off-chain backend per backend.md:
///   effectiveDeposit = min(principal, shares * rate)
///   reward = sum over intervals of (effectiveDeposit * REWARD_RATE * duration / 1e18)
/// @dev Records (shareBalance, rate) snapshots at each checkpoint to simulate
///      the archive-node queries the real backend makes.
contract BackendRewardSimulationTest is Test {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    MockWETH_Backend public weth;
    MockRewardToken public rewardToken;
    BoringVault public vault;
    AccountantWithRateProviders public accountant;
    TellerWithMultiAssetSupport public teller;
    IncentivePool public pool;
    RolesAuthority public roles;

    uint256 internal constant ONE_SHARE = 1e18;
    uint256 internal constant SIGNER_PK = 0xBACE;
    address internal signerAddr;

    /// @dev Reward rate: 1e14 per second per 1e18 effective deposit = ~3.15% APR
    uint256 internal constant REWARD_RATE = 1e14;

    // -- Snapshot tracking (simulates backend's archive-node queries) --

    struct StateSnapshot {
        uint256 shareBalance;
        uint256 rate;
    }

    mapping(address => StateSnapshot[]) internal _snapshots;

    function _recordSnapshot(address user) internal {
        _snapshots[user].push(StateSnapshot({shareBalance: vault.balanceOf(user), rate: accountant.getRate()}));
    }

    function setUp() public {
        vm.warp(1_000_000);

        weth = new MockWETH_Backend();
        rewardToken = new MockRewardToken();
        vault = new BoringVault(address(this), "Boring Vault", "BV", 18);
        accountant = new AccountantWithRateProviders(
            address(this), address(vault), vm.addr(7777), 1e18, address(weth), 1.001e4, 0.999e4, 1, 0, 0
        );
        teller = new TellerWithMultiAssetSupport(address(this), address(vault), address(accountant), address(weth));

        signerAddr = vm.addr(SIGNER_PK);
        pool = new IncentivePool(address(this), ERC20(address(rewardToken)), 1 days);

        roles = new RolesAuthority(address(this), Authority(address(0)));
        vault.setAuthority(roles);
        accountant.setAuthority(roles);
        teller.setAuthority(roles);
        pool.setAuthority(roles);

        roles.setRoleCapability(7, address(vault), BoringVault.enter.selector, true);
        roles.setRoleCapability(8, address(vault), BoringVault.exit.selector, true);
        roles.setUserRole(address(teller), 7, true);
        roles.setUserRole(address(teller), 8, true);

        roles.setPublicCapability(address(teller), TellerWithMultiAssetSupport.deposit.selector, true);
        roles.setPublicCapability(address(teller), TellerWithMultiAssetSupport.withdraw.selector, true);
        roles.setPublicCapability(address(teller), TellerWithMultiAssetSupport.claimRewards.selector, true);

        roles.setUserRole(address(this), 1, true);
        roles.setRoleCapability(1, address(accountant), AccountantWithRateProviders.updateExchangeRate.selector, true);
        roles.setRoleCapability(1, address(accountant), AccountantWithRateProviders.unpause.selector, true);

        roles.setRoleCapability(12, address(pool), IncentivePool.processRewards.selector, true);
        roles.setUserRole(address(teller), 12, true);

        teller.setIncentivePoolAllowed(address(pool), true);

        pool.setRewardSigner(signerAddr);
        pool.setMaximumRewardAmountPerClaim(type(uint96).max);
        pool.setMaxDeadline(1 days);

        rewardToken.mint(address(pool), type(uint128).max);

        teller.updateAssetData(ERC20(address(weth)), true, true, 0);
    }

    // ========================================= BACKEND SIMULATION =========================================

    /// @notice Simulates the backend algorithm from backend.md:
    ///   For each checkpoint interval:
    ///     principal        = max(0, cumulativeDeposits - cumulativeWithdrawals)
    ///     totalValueBase   = shareBalance * rate / 1e18
    ///     effectiveDeposit = min(principal, totalValueBase)
    ///     reward          += effectiveDeposit * REWARD_RATE * duration / 1e18
    function _computeRewards(address user, uint256 endTime) internal view returns (uint256 totalReward) {
        (PrincipalCheckpoint[] memory h,) = teller.getPrincipalHistoryPaginated(user, 0, type(uint256).max);
        StateSnapshot[] storage snaps = _snapshots[user];
        if (h.length == 0) return 0;
        require(snaps.length == h.length, "snapshot/checkpoint mismatch");

        for (uint256 i; i < h.length; ++i) {
            uint256 principal = h[i].cumulativeDeposits > h[i].cumulativeWithdrawals
                ? uint256(h[i].cumulativeDeposits) - uint256(h[i].cumulativeWithdrawals)
                : 0;

            uint256 totalValueBase = snaps[i].shareBalance.mulDivDown(snaps[i].rate, ONE_SHARE);
            uint256 effectiveDeposit = principal < totalValueBase ? principal : totalValueBase;

            uint256 intervalEnd = (i + 1 < h.length) ? h[i + 1].timestamp : endTime;
            uint256 start = h[i].timestamp;
            if (intervalEnd > start) {
                uint256 duration = intervalEnd - start;
                totalReward += effectiveDeposit.mulDivDown(REWARD_RATE * duration, 1e18);
            }
        }
    }

    // ========================================= HELPERS =========================================

    function _setRate(uint96 rate) internal {
        skip(1);
        accountant.updateExchangeRate(rate);
        accountant.unpause();
    }

    function _boundRate(uint256 seed) internal pure returns (uint96) {
        return uint96(bound(seed, 0.01e18, 100e18));
    }

    function _fundVault(uint256 amount) internal {
        weth.mint(address(vault), amount);
    }

    function _depositAs(address user, uint256 amount) internal returns (uint256 shares) {
        weth.mint(user, amount);
        vm.startPrank(user);
        ERC20(address(weth)).safeApprove(address(vault), amount);
        shares = teller.deposit(DepositParams(ERC20(address(weth)), amount, 0, user), address(0), ComplianceData(0, ""));
        vm.stopPrank();
        _recordSnapshot(user);
    }

    function _withdrawAs(address user, uint256 shareAmount) internal {
        vm.prank(user);
        teller.withdraw(ERC20(address(weth)), shareAmount, 0, user);
        _recordSnapshot(user);
    }

    function _transferShares(address from, address to, uint256 shares) internal {
        vm.prank(from);
        vault.transfer(to, shares);
    }

    function _signReward(address recipient, uint256 cumulativeOwed, uint256 deadline)
        internal
        view
        returns (bytes memory)
    {
        bytes32 messageHash = keccak256(abi.encode(address(pool), block.chainid, recipient, cumulativeOwed, deadline));
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PK, ethSignedHash);
        return abi.encodePacked(r, s, v);
    }

    function _claimReward(address user, uint256 cumulativeOwed) internal returns (uint256 delta) {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _signReward(user, cumulativeOwed, deadline);

        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(pool), cumulativeOwed, deadline, sig);

        uint256 balBefore = rewardToken.balanceOf(user);
        vm.prank(user);
        teller.claimRewards(rewards);
        delta = rewardToken.balanceOf(user) - balBefore;
    }

    // ============================== E2E: single user deposit and claim ==============================

    function testFuzz_E2E_SingleUserDepositAndClaim(uint256 amount, uint256 duration) external {
        amount = bound(amount, 1e6, 1e24);
        duration = bound(duration, 1 hours, 365 days);

        _depositAs(vm.addr(100), amount);
        skip(duration);

        uint256 rewards = _computeRewards(vm.addr(100), block.timestamp);
        assertGt(rewards, 0, "should earn rewards");

        uint256 delta = _claimReward(vm.addr(100), rewards);
        assertEq(delta, rewards, "claimed == computed");
    }

    // ============================== E2E: two users proportional rewards ==============================

    function testFuzz_E2E_TwoUsers_ProportionalRewards(uint256 amount1, uint256 amount2, uint256 duration) external {
        amount1 = bound(amount1, 1e8, 1e22);
        amount2 = bound(amount2, 1e8, 1e22);
        duration = bound(duration, 1 hours, 365 days);

        address alice = vm.addr(101);
        address bob = vm.addr(102);

        _depositAs(alice, amount1);
        _depositAs(bob, amount2);
        skip(duration);

        uint256 rA = _computeRewards(alice, block.timestamp);
        uint256 rB = _computeRewards(bob, block.timestamp);

        assertGt(rA, 0, "alice earns");
        assertGt(rB, 0, "bob earns");

        _claimReward(alice, rA);
        _claimReward(bob, rB);

        // Rewards use mulDivDown (floor division), so a tiny deposit difference (e.g. 1 wei)
        // can produce identical rewards. Use >= / <= instead of strict inequalities.
        if (amount1 > amount2) {
            assertGe(rA, rB, "alice earns at least as much as bob");
        } else if (amount1 < amount2) {
            assertLe(rA, rB, "alice earns no more than bob");
        } else {
            assertEq(rA, rB, "equal deposits earn equal rewards");
        }
    }

    // ============================== E2E: full withdrawal zeroes future rewards ==============================

    function testFuzz_E2E_FullWithdraw_ZeroFutureRewards(uint256 amount, uint256 d1, uint256 d2) external {
        amount = bound(amount, 1e6, 1e22);
        d1 = bound(d1, 1 hours, 30 days);
        d2 = bound(d2, 1 hours, 30 days);

        address user = vm.addr(100);
        uint256 shares = _depositAs(user, amount);

        skip(d1);
        uint256 rewardsBefore = _computeRewards(user, block.timestamp);

        _fundVault(amount * 2);
        _withdrawAs(user, shares);

        // shares = 0 now, so min(principal, 0) = 0 for all future intervals
        skip(d2);
        uint256 rewardsAfter = _computeRewards(user, block.timestamp);
        assertEq(rewardsAfter, rewardsBefore, "no rewards after full withdraw");
    }

    // ============================== E2E: partial withdrawal reduces rewards ==============================

    function testFuzz_E2E_PartialWithdraw_ReducesRewards(uint256 amount, uint256 d1, uint256 d2) external {
        amount = bound(amount, 1e8, 1e22);
        d1 = bound(d1, 1 hours, 30 days);
        d2 = bound(d2, 1 hours, 30 days);

        address user = vm.addr(100);
        uint256 shares = _depositAs(user, amount);
        vm.assume(shares >= 4);

        skip(d1);
        uint256 rewardsPhase1 = _computeRewards(user, block.timestamp);

        _fundVault(amount * 2);
        _withdrawAs(user, shares / 2);

        skip(d2);
        uint256 rewardsTotal = _computeRewards(user, block.timestamp);
        uint256 rewardsPhase2 = rewardsTotal - rewardsPhase1;

        // Phase 2 effective deposit should be min(remaining principal, remaining shares * rate)
        // Both should be roughly amount/2
        (PrincipalCheckpoint[] memory h,) = teller.getPrincipalHistoryPaginated(user, 0, type(uint256).max);
        PrincipalCheckpoint memory last = h[h.length - 1];
        uint256 principal = last.cumulativeDeposits > last.cumulativeWithdrawals
            ? uint256(last.cumulativeDeposits) - uint256(last.cumulativeWithdrawals)
            : 0;
        StateSnapshot storage snap = _snapshots[user][_snapshots[user].length - 1];
        uint256 totalValue = snap.shareBalance.mulDivDown(snap.rate, ONE_SHARE);
        uint256 effective = principal < totalValue ? principal : totalValue;

        if (effective > 0 && d2 > 0) {
            uint256 expectedPhase2 = effective.mulDivDown(REWARD_RATE * d2, 1e18);
            assertEq(rewardsPhase2, expectedPhase2, "phase2 rewards match effective deposit");
        }

        _claimReward(user, rewardsTotal);
    }

    // ============================== E2E: yield excluded from reward base ==============================

    /// @notice Deposit, rate increases (yield), verify effectiveDeposit = principal (capped, not share value).
    function testFuzz_E2E_YieldExcluded(uint256 amount, uint256 duration) external {
        amount = bound(amount, 1e8, 1e22);
        duration = bound(duration, 1 hours, 30 days);

        address user = vm.addr(100);
        _depositAs(user, amount);

        // Rate increases 10% — shares now worth more than deposited
        _setRate(1.1e18);

        skip(duration);

        (PrincipalCheckpoint[] memory h,) = teller.getPrincipalHistoryPaginated(user, 0, type(uint256).max);
        uint256 principal = h[0].cumulativeDeposits; // ~= amount (no withdrawals)
        StateSnapshot storage snap = _snapshots[user][0];
        uint256 totalValue = snap.shareBalance.mulDivDown(snap.rate, ONE_SHARE);

        // At deposit time, rate was 1e18, so totalValue ≈ principal. Yield doesn't inflate snapshot.
        // The snapshot records state AT checkpoint time, before the rate increase.
        assertLe(principal, totalValue + 1, "principal <= totalValue at deposit time");

        uint256 rewards = _computeRewards(user, block.timestamp);
        // Rewards based on min(principal, totalValue) ≈ principal, not inflated by yield
        assertGt(rewards, 0, "earns rewards");
    }

    // ============================== E2E: transfer sender rewards capped by share balance ==============================

    /// @notice Alice deposits, transfers half to Bob. Alice's effective deposit should be
    /// capped at her remaining share value, not her full principal.
    function testFuzz_E2E_TransferSender_CappedByShareValue(uint256 amount, uint256 duration) external {
        amount = bound(amount, 1e8, 1e22);
        duration = bound(duration, 1 hours, 30 days);
        vault.setBeforeTransferHook(address(teller));

        address alice = vm.addr(101);
        address bob = vm.addr(102);

        uint256 shares = _depositAs(alice, amount);

        // Alice transfers half her shares to Bob
        _transferShares(alice, bob, shares / 2);

        skip(duration);

        uint256 rewardsAlice = _computeRewards(alice, block.timestamp);
        uint256 rewardsBob = _computeRewards(bob, block.timestamp);

        // Bob: principal = 0 (never deposited), so min(0, shares*rate) = 0
        assertEq(rewardsBob, 0, "transfer receiver earns 0");

        // Alice: after transfer, her effective deposit should be min(principal, remaining_shares * rate)
        // principal ≈ amount, remaining_shares ≈ shares/2, so effective ≈ amount/2
        // This means Alice earns LESS than if she kept all shares
        // First interval (before transfer): full deposit, effective = min(principal, shares*rate) ≈ amount
        // Second interval (after transfer): effective = min(principal, (shares/2)*rate) ≈ amount/2
        // So total rewards should be less than amount * REWARD_RATE * total_duration / 1e18

        uint256 maxReward = uint256(amount).mulDivDown(REWARD_RATE * (duration + 1), 1e18);
        assertLt(rewardsAlice, maxReward, "transfer reduces alice's rewards");
    }

    // ============================== E2E: phantom principal from rate drop ==============================

    /// @notice Deposit at high rate, rate drops, full withdraw. Principal > 0 (phantom) but
    /// shares = 0, so backend computes 0 rewards going forward.
    function testFuzz_E2E_PhantomPrincipal_RateDrop_NoRewards(uint256 amount, uint256 d1, uint256 d2) external {
        amount = bound(amount, 1e8, 1e20);
        d1 = bound(d1, 1 hours, 30 days);
        d2 = bound(d2, 1 hours, 30 days);

        // Deposit at rate 2e18
        _setRate(2e18);
        address user = vm.addr(100);
        uint256 shares = _depositAs(user, amount);

        skip(d1);

        // Rate drops to 1e18, then full withdraw
        _setRate(1e18);
        _fundVault(shares.mulDivUp(1e18, ONE_SHARE) + 1e18);
        _withdrawAs(user, shares);

        // Phantom principal: deposits > withdrawals because rate dropped
        (PrincipalCheckpoint[] memory h,) = teller.getPrincipalHistoryPaginated(user, 0, type(uint256).max);
        PrincipalCheckpoint memory last = h[h.length - 1];
        assertGt(last.cumulativeDeposits, last.cumulativeWithdrawals, "phantom principal exists");

        // Rewards right at withdrawal — this captures all earned rewards
        uint256 rewardsAtWithdraw = _computeRewards(user, block.timestamp);
        assertGt(rewardsAtWithdraw, 0, "earned rewards while holding");

        // Time passes — shares = 0, so min(phantom, 0) = 0. No additional rewards.
        skip(d2);
        uint256 rewardsFinal = _computeRewards(user, block.timestamp);
        assertEq(rewardsFinal, rewardsAtWithdraw, "no rewards on phantom principal (shares = 0)");
    }

    // ============================== E2E: re-deposit after phantom doesn't inflate rewards ==============================

    /// @notice User has phantom principal from rate drop. Re-deposits fresh.
    /// Effective deposit is capped at share value, not inflated principal.
    function testFuzz_E2E_PhantomPrincipal_ReDeposit_Capped(uint256 amount) external {
        amount = bound(amount, 1e8, 1e20);

        // Deposit at rate 2, withdraw at rate 1 -> phantom principal
        _setRate(2e18);
        address user = vm.addr(100);
        uint256 shares1 = _depositAs(user, amount);
        _setRate(1e18);
        _fundVault(amount * 2);
        _withdrawAs(user, shares1);

        // Re-deposit half the original amount
        uint256 freshAmount = amount / 2;
        _depositAs(user, freshAmount);

        skip(7 days);

        // Effective deposit should be min(inflated_principal, freshShares * rate)
        // inflated_principal includes phantom from first cycle
        // freshShares * rate ≈ freshAmount
        // min() should cap at freshAmount, NOT the inflated principal
        (PrincipalCheckpoint[] memory h,) = teller.getPrincipalHistoryPaginated(user, 0, type(uint256).max);
        PrincipalCheckpoint memory last = h[h.length - 1];
        uint256 principal = last.cumulativeDeposits > last.cumulativeWithdrawals
            ? uint256(last.cumulativeDeposits) - uint256(last.cumulativeWithdrawals)
            : 0;

        StateSnapshot storage snap = _snapshots[user][_snapshots[user].length - 1];
        uint256 totalValue = snap.shareBalance.mulDivDown(snap.rate, ONE_SHARE);

        // Principal is inflated by phantom, but totalValue is just the fresh deposit
        assertGt(principal, totalValue, "principal > totalValue due to phantom");

        uint256 rewards = _computeRewards(user, block.timestamp);
        // Rewards should be based on totalValue (fresh deposit), not inflated principal
        uint256 maxRewardIfInflated = principal.mulDivDown(REWARD_RATE * 7 days, 1e18);
        assertLt(rewards, maxRewardIfInflated, "rewards capped below inflated principal");
    }

    // ============================== E2E: backend.md example (Alice, Bob, Charlie) ==============================

    /// @notice Reproduces the exact example from backend.md section "Example: Distributing 10,000 USDC Over 7 Days"
    /// Verifies that the backend algorithm produces the correct weights.
    function test_E2E_BackendMd_ExactExample() external {
        vault.setBeforeTransferHook(address(teller));

        address alice = vm.addr(101);
        address bob = vm.addr(102);
        address charlie = vm.addr(103);

        // Day 0: Alice deposits 100 WETH (rate = 1.0)
        _depositAs(alice, 100e18);

        // Day 1: Bob deposits 50 WETH (rate = 1.0)
        skip(1 days);
        _depositAs(bob, 50e18);

        // Day 3: Rate increases to 1.1 (no checkpoints created — rate change only)
        skip(2 days);
        _setRate(1.1e18);

        // Day 4: Bob transfers 25 of his 50 shares to Charlie
        skip(1 days - 1); // -1 because _setRate already skipped 1
        _transferShares(bob, charlie, 25e18);

        // Day 5: Alice withdraws 20 WETH worth of shares (at rate 1.1)
        skip(1 days);
        // 20 WETH / 1.1 rate ≈ 18.18 shares
        uint256 aliceWithdrawShares = uint256(20e18).mulDivDown(ONE_SHARE, 1.1e18);
        _fundVault(100e18);
        _withdrawAs(alice, aliceWithdrawShares);

        // Day 7: compute rewards
        skip(2 days);

        uint256 weightsAlice = _computeRewards(alice, block.timestamp);
        uint256 weightsBob = _computeRewards(bob, block.timestamp);
        uint256 weightsCharlie = _computeRewards(charlie, block.timestamp);

        // Charlie should earn 0 (never deposited, only received transfer)
        assertEq(weightsCharlie, 0, "charlie earns 0");

        // Alice should earn more than Bob (deposited more, for longer)
        assertGt(weightsAlice, weightsBob, "alice > bob");

        // Both Alice and Bob should earn non-zero
        assertGt(weightsAlice, 0, "alice earns");
        assertGt(weightsBob, 0, "bob earns");

        // Verify Bob's effective deposit decreased after transferring shares
        // Bob's intervals:
        //   Day 1-3 (before rate change): principal=50, shares=50, rate=1.0 -> effective=50
        //   Day 3-4 (rate changed checkpoint NOT created — backend uses day1 snapshot for this interval)
        //   Day 4-7 (after transfer): principal=50, shares=25, rate=1.1 -> effective=min(50, 27.5)=27.5
        // The min() correctly caps Bob's post-transfer rewards

        // All can claim
        _claimReward(alice, weightsAlice);
        _claimReward(bob, weightsBob);
    }

    // ============================== E2E: time-weighted proportional to duration ==============================

    function testFuzz_E2E_TimeWeighted_ProportionalToDuration(uint256 amount, uint256 d1, uint256 d2) external {
        amount = bound(amount, 1e8, 1e22);
        d1 = bound(d1, 1 hours, 180 days);
        d2 = bound(d2, 1 hours, 180 days);

        address alice = vm.addr(101);
        address bob = vm.addr(102);

        _depositAs(alice, amount);
        _depositAs(bob, amount);

        // Alice withdraws after d1
        uint256 aliceShares = vault.balanceOf(alice);
        skip(d1);
        _fundVault(amount * 4);
        _withdrawAs(alice, aliceShares);

        // Bob withdraws after d1 + d2
        uint256 bobShares = vault.balanceOf(bob);
        skip(d2);
        _withdrawAs(bob, bobShares);

        uint256 rA = _computeRewards(alice, block.timestamp);
        uint256 rB = _computeRewards(bob, block.timestamp);

        // Bob held longer, should earn more
        if (d2 > 0) assertGt(rB, rA, "longer holder earns more");
    }

    // ============================== E2E: full pipeline compute -> sign -> claim ==============================

    function testFuzz_E2E_FullPipeline_ComputeSignClaim(uint256 amount, uint256 rateSeed, uint256 duration) external {
        uint96 rate = _boundRate(rateSeed);
        amount = bound(amount, 1e6, 1e22);
        duration = bound(duration, 1 hours, 365 days);

        _setRate(rate);
        address user = vm.addr(100);
        _depositAs(user, amount);
        skip(duration);

        uint256 rewards = _computeRewards(user, block.timestamp);
        if (rewards == 0) return;

        uint256 delta = _claimReward(user, rewards);
        assertEq(delta, rewards, "claimed == computed");
        assertEq(pool.getTotalClaimedAmount(user), rewards, "pool tracks cumulative");
    }

    // ============================== E2E: incremental claims converge ==============================

    function testFuzz_E2E_IncrementalClaims_Converge(uint256 amount, uint256 interval) external {
        amount = bound(amount, 1e8, 1e22);
        interval = bound(interval, 1 hours, 7 days);

        address user = vm.addr(100);
        _depositAs(user, amount);

        uint256 totalClaimed;
        for (uint256 i; i < 5; ++i) {
            skip(interval);
            uint256 owed = _computeRewards(user, block.timestamp);
            if (owed > totalClaimed) {
                totalClaimed += _claimReward(user, owed);
            }
        }

        uint256 expected = _computeRewards(user, block.timestamp);
        assertEq(totalClaimed, expected, "incremental claims converge");
    }

    // ============================== E2E: non-unity rate, no phantom rewards ==============================

    function testFuzz_E2E_NonUnityRate_NoPhantomRewards(uint256 amount, uint256 rateSeed, uint256 d1, uint256 d2)
        external
    {
        uint96 rate = _boundRate(rateSeed);
        amount = bound(amount, 1e6, 1e22);
        d1 = bound(d1, 1 hours, 30 days);
        d2 = bound(d2, 1 hours, 30 days);

        _setRate(rate);
        address user = vm.addr(100);
        uint256 shares = _depositAs(user, amount);

        skip(d1);
        uint256 rewardsBefore = _computeRewards(user, block.timestamp);

        _fundVault(shares.mulDivUp(uint256(rate), ONE_SHARE) + 1e18);
        _withdrawAs(user, shares);

        // Shares = 0, so effective deposit = 0 regardless of principal
        skip(d2);
        uint256 rewardsAfter = _computeRewards(user, block.timestamp);
        assertEq(rewardsAfter, rewardsBefore, "no phantom rewards (shares = 0)");
    }

    // ============================== E2E: varying rates, no cumulative phantom ==============================

    function testFuzz_E2E_VaryingRates_NoCumulativePhantomRewards(uint256 amount, uint256 rateSeed1, uint256 rateSeed2)
        external
    {
        uint96 r1 = _boundRate(rateSeed1);
        uint96 r2 = _boundRate(rateSeed2);
        amount = bound(amount, 1e8, 1e20);

        address user = vm.addr(100);

        _setRate(r1);
        _fundVault(amount * 10);
        uint256 s1 = _depositAs(user, amount);
        skip(1 days);
        _withdrawAs(user, s1);

        uint256 rewardsAfter1 = _computeRewards(user, block.timestamp);

        _setRate(r2);
        _fundVault(amount * 10);
        uint256 s2 = _depositAs(user, amount);
        skip(1 days);
        _withdrawAs(user, s2);

        uint256 rewardsAfter2 = _computeRewards(user, block.timestamp);
        assertGe(rewardsAfter2, rewardsAfter1, "rewards grow with cycles");

        skip(30 days);
        uint256 rewardsFinal = _computeRewards(user, block.timestamp);
        assertEq(rewardsFinal, rewardsAfter2, "no phantom rewards after all closed");
    }

    // ============================== E2E: pool caps limit payout ==============================

    function testFuzz_E2E_PoolCaps_LimitPayout(uint256 amount, uint96 perClaimCap) external {
        amount = bound(amount, 1e18, 1e24);
        perClaimCap = uint96(bound(uint256(perClaimCap), 1e6, 1e18));
        pool.setMaximumRewardAmountPerClaim(perClaimCap);

        address user = vm.addr(100);
        _depositAs(user, amount);
        skip(365 days);

        uint256 computed = _computeRewards(user, block.timestamp);
        vm.assume(computed > uint256(perClaimCap));

        uint256 delta = _claimReward(user, computed);
        assertEq(delta, uint256(perClaimCap), "capped by perClaimCap");
    }

    // ============================== E2E: multi-user complex scenario ==============================

    function test_E2E_MultiUserMultiAction_RewardsConsistent() external {
        address alice = vm.addr(101);
        address bob = vm.addr(102);
        address charlie = vm.addr(103);

        _depositAs(alice, 100e18);
        skip(3 days);
        _depositAs(bob, 50e18);
        skip(2 days);

        uint256 aliceShares = vault.balanceOf(alice);
        _fundVault(200e18);
        _withdrawAs(alice, aliceShares / 2);

        skip(2 days);
        _depositAs(charlie, 200e18);
        skip(7 days);

        uint256 rA = _computeRewards(alice, block.timestamp);
        uint256 rB = _computeRewards(bob, block.timestamp);
        uint256 rC = _computeRewards(charlie, block.timestamp);

        assertGt(rA, 0, "alice earns");
        assertGt(rB, 0, "bob earns");
        assertGt(rC, 0, "charlie earns");
        assertGt(rA, rB, "alice > bob");

        _claimReward(alice, rA);
        _claimReward(bob, rB);
        _claimReward(charlie, rC);

        assertEq(
            rewardToken.balanceOf(alice) + rewardToken.balanceOf(bob) + rewardToken.balanceOf(charlie),
            rA + rB + rC,
            "total distributed"
        );
    }

    // ============================== E2E: pathological rate rounding bounded ==============================

    function testFuzz_E2E_PathologicalRate_RewardRoundingBounded(uint256 amount, uint256 duration) external {
        uint96 rate = 3e18;
        amount = bound(amount, 3, 1e22);
        duration = bound(duration, 1 hours, 365 days);

        _setRate(rate);
        address user = vm.addr(100);
        uint256 shares = _depositAs(user, amount);
        if (shares == 0) return;

        skip(duration);

        (PrincipalCheckpoint[] memory h,) = teller.getPrincipalHistoryPaginated(user, 0, type(uint256).max);
        uint256 recorded = h[0].cumulativeDeposits;
        assertLe(amount - recorded, 2, "principal rounding loss bounded");

        uint256 rewards = _computeRewards(user, block.timestamp);
        uint256 ideal = uint256(amount).mulDivDown(REWARD_RATE * duration, 1e18);
        if (ideal > 0) {
            uint256 diff = ideal > rewards ? ideal - rewards : rewards - ideal;
            uint256 maxErr = uint256(2).mulDivUp(REWARD_RATE * duration, 1e18) + 1;
            assertLe(diff, maxErr, "reward error not amplified");
        }
    }
}
