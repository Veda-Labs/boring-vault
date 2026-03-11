// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Test, stdStorage, StdStorage, stdError, console, Vm} from "@forge-std/Test.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {MessageHashUtils} from "@openzeppelin-contracts-5.3.0/utils/cryptography/MessageHashUtils.sol";
import {IncentivePool} from "src/base/IncentivePool.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_, decimals_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract IncentivePoolTest is Test {
    using SafeTransferLib for ERC20;

    event RewardSignerSet(address indexed rewardSigner);
    event RewardsProcessed(address indexed rewardsRecipient, uint256 amountClaimed);
    event MaximumRewardAmountPerClaimSet(uint256 maxRewardAmount);
    event MaxDeadlineSet(uint256 maxDeadline);
    event TotalRewardCapSet(uint256 totalRewardCap);
    event SecondsBetweenClaimsSet(uint256 secondsBetweenClaims);
    event FundsRescued(address indexed token, address indexed to, uint256 amount);
    event BlacklistUpdated(address indexed user, bool status);

    IncentivePool public pool;
    RolesAuthority public rolesAuthority;
    MockERC20 public rewardToken;

    uint256 internal signerPrivateKey = 0xA11CE;
    address internal signer;
    address internal teller = vm.addr(2);
    address internal user = vm.addr(3);

    uint8 internal constant TELLER_ROLE = 1;

    function setUp() external {
        signer = vm.addr(signerPrivateKey);

        rewardToken = new MockERC20("Reward Token", "RWD", 18);
        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        pool = new IncentivePool(address(this), ERC20(address(rewardToken)));

        // Configure auth
        pool.setAuthority(rolesAuthority);
        rolesAuthority.setRoleCapability(TELLER_ROLE, address(pool), IncentivePool.processRewards.selector, true);
        rolesAuthority.setUserRole(teller, TELLER_ROLE, true);

        // Configure pool
        pool.setRewardSigner(signer);
        pool.setMaximumRewardAmountPerClaim(1_000e18);
        pool.setMaxDeadline(1 days);
        pool.setTotalRewardCap(1_000_000e18);

        // Fund pool with reward tokens
        rewardToken.mint(address(pool), 1_000_000e18);
    }

    // ========================= CONSTRUCTOR =========================

    function test_constructor() external view {
        assertEq(address(pool.REWARD_TOKEN()), address(rewardToken));
        assertEq(pool.owner(), address(this));
    }

    function test_constructor_revertsZeroToken() external {
        vm.expectRevert(IncentivePool.InvalidToken.selector);
        new IncentivePool(address(this), ERC20(address(0)));
    }

    // ========================= SET REWARD SIGNER =========================

    function test_setRewardSigner() external {
        address newSigner = vm.addr(99);

        vm.expectEmit(true, false, false, false, address(pool));
        emit RewardSignerSet(newSigner);

        pool.setRewardSigner(newSigner);

        assertEq(pool.rewardSigner(), newSigner);
    }

    function test_setRewardSigner_revertsZeroAddress() external {
        vm.expectRevert(IncentivePool.InvalidSigner.selector);
        pool.setRewardSigner(address(0));
    }

    function test_setRewardSigner_revertsUnauthorized() external {
        vm.prank(user);
        vm.expectRevert("UNAUTHORIZED");
        pool.setRewardSigner(vm.addr(99));
    }

    // ========================= SET MAX REWARD AMOUNT =========================

    function test_setMaximumRewardAmountPerClaim() external {
        vm.expectEmit(false, false, false, true, address(pool));
        emit MaximumRewardAmountPerClaimSet(500e18);

        pool.setMaximumRewardAmountPerClaim(500e18);

        assertEq(pool.maximumRewardAmountPerClaim(), 500e18);
    }

    function test_setMaximumRewardAmountPerClaim_revertsUnauthorized() external {
        vm.prank(user);
        vm.expectRevert("UNAUTHORIZED");
        pool.setMaximumRewardAmountPerClaim(500e18);
    }

    // ========================= SET MAX DEADLINE =========================

    function test_setMaxDeadline() external {
        vm.expectEmit(false, false, false, true, address(pool));
        emit MaxDeadlineSet(2 days);

        pool.setMaxDeadline(2 days);

        assertEq(pool.maxDeadline(), 2 days);
    }

    function test_setMaxDeadline_revertsUnauthorized() external {
        vm.prank(user);
        vm.expectRevert("UNAUTHORIZED");
        pool.setMaxDeadline(2 days);
    }

    // ========================= SET SECONDS BETWEEN CLAIMS =========================

    function test_setSecondsBetweenClaims() external {
        vm.expectEmit(false, false, false, true, address(pool));
        emit SecondsBetweenClaimsSet(1 hours);

        pool.setSecondsBetweenClaims(1 hours);

        assertEq(pool.secondsBetweenClaims(), 1 hours);
    }

    function test_setSecondsBetweenClaims_revertsUnauthorized() external {
        vm.prank(user);
        vm.expectRevert("UNAUTHORIZED");
        pool.setSecondsBetweenClaims(1 hours);
    }

    // ========================= SET TOTAL REWARD CAP =========================

    function test_setTotalRewardCap() external {
        vm.expectEmit(false, false, false, true, address(pool));
        emit TotalRewardCapSet(500_000e18);

        pool.setTotalRewardCap(500_000e18);

        assertEq(pool.totalRewardCap(), 500_000e18);
    }

    function test_setTotalRewardCap_revertsUnauthorized() external {
        vm.prank(user);
        vm.expectRevert("UNAUTHORIZED");
        pool.setTotalRewardCap(500_000e18);
    }

    // ========================= PROCESS REWARDS =========================

    function test_processRewards_revertsUnauthorized() external {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, 100e18, deadline);

        vm.prank(user);
        vm.expectRevert("UNAUTHORIZED");
        pool.processRewards(user, 100e18, deadline, sig);
    }

    function test_processRewards_revertsExpiredDeadline() external {
        vm.warp(1000);
        uint256 deadline = block.timestamp - 1;
        bytes memory sig = _sign(user, 100e18, deadline);

        vm.prank(teller);
        vm.expectRevert(IncentivePool.InvalidDeadline.selector);
        pool.processRewards(user, 100e18, deadline, sig);
    }

    function test_processRewards_revertsDeadlineTooFar() external {
        uint256 deadline = block.timestamp + 1 days + 1;
        bytes memory sig = _sign(user, 100e18, deadline);

        vm.prank(teller);
        vm.expectRevert(IncentivePool.InvalidDeadline.selector);
        pool.processRewards(user, 100e18, deadline, sig);
    }

    function test_processRewards_revertsInvalidSigner() external {
        uint256 deadline = block.timestamp + 1 hours;

        uint256 wrongKey = 0xBAD;
        bytes memory sig = _signWithKey(wrongKey, user, 100e18, deadline);

        vm.prank(teller);
        vm.expectRevert(IncentivePool.InvalidSigner.selector);
        pool.processRewards(user, 100e18, deadline, sig);
    }

    function test_processRewards_revertsReplayNothingToClaim() external {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, 100e18, deadline);

        vm.prank(teller);
        pool.processRewards(user, 100e18, deadline, sig);

        // Same signature with same cumulative amount reverts because nothing new to claim
        vm.prank(teller);
        vm.expectRevert(IncentivePool.NothingToClaim.selector);
        pool.processRewards(user, 100e18, deadline, sig);
    }

    function test_processRewards_capsAtMaxReward() external {
        pool.setMaximumRewardAmountPerClaim(50e18);
        pool.setSecondsBetweenClaims(1 hours);
        vm.warp(2 hours);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, 100e18, deadline);

        vm.prank(teller);
        uint256 delta = pool.processRewards(user, 100e18, deadline, sig);

        // Delta capped to max
        assertEq(delta, 50e18);
        assertEq(rewardToken.balanceOf(user), 50e18);
        assertEq(pool.getTotalClaimedAmount(user), 50e18);

        // Second claim within interval reverts even with a new signature
        uint256 deadline2 = block.timestamp + 1 hours;
        bytes memory sig2 = _sign(user, 150e18, deadline2);
        vm.prank(teller);
        vm.expectRevert(IncentivePool.RateLimitExceeded.selector);
        pool.processRewards(user, 150e18, deadline2, sig2);
    }

    function test_processRewards_happyPath() external {
        uint256 deadline = block.timestamp + 1 hours;
        uint256 amount = 100e18;
        bytes memory sig = _sign(user, amount, deadline);

        uint256 balBefore = rewardToken.balanceOf(user);

        vm.prank(teller);
        uint256 delta = pool.processRewards(user, amount, deadline, sig);

        assertEq(delta, amount);
        assertEq(rewardToken.balanceOf(user), balBefore + amount);
    }

    function test_processRewards_emitsEvent() external {
        uint256 deadline = block.timestamp + 1 hours;
        uint256 amount = 100e18;
        bytes memory sig = _sign(user, amount, deadline);

        vm.expectEmit(true, false, false, true, address(pool));
        emit RewardsProcessed(user, amount);

        vm.prank(teller);
        pool.processRewards(user, amount, deadline, sig);
    }

    function test_processRewards_multipleClaims() external {
        // First claim: 100 tokens
        uint256 deadline1 = block.timestamp + 1 hours;
        bytes memory sig1 = _sign(user, 100e18, deadline1);

        vm.prank(teller);
        uint256 delta1 = pool.processRewards(user, 100e18, deadline1, sig1);
        assertEq(delta1, 100e18);

        // Second claim: 250 cumulative, so delta = 150
        vm.warp(block.timestamp + 1 hours);
        uint256 deadline2 = block.timestamp + 1 hours;
        bytes memory sig2 = _sign(user, 250e18, deadline2);

        vm.prank(teller);
        uint256 delta2 = pool.processRewards(user, 250e18, deadline2, sig2);
        assertEq(delta2, 150e18);

        assertEq(rewardToken.balanceOf(user), 250e18);
    }

    function test_processRewards_crossPoolReplayPrevented() external {
        // Deploy second pool with same signer
        IncentivePool pool2 = new IncentivePool(address(this), ERC20(address(rewardToken)));
        pool2.setAuthority(rolesAuthority);
        rolesAuthority.setRoleCapability(TELLER_ROLE, address(pool2), IncentivePool.processRewards.selector, true);
        pool2.setRewardSigner(signer);
        pool2.setMaximumRewardAmountPerClaim(1_000e18);
        pool2.setMaxDeadline(1 days);
        pool2.setTotalRewardCap(1_000_000e18);
        rewardToken.mint(address(pool2), 1_000_000e18);

        // Signature bound to pool1's address
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, 100e18, deadline);

        // Replay on pool2 fails (different contract address in hash)
        vm.prank(teller);
        vm.expectRevert(IncentivePool.InvalidSigner.selector);
        pool2.processRewards(user, 100e18, deadline, sig);
    }

    function test_processRewards_deadlineAtLowerBoundary() external {
        // deadline == block.timestamp is valid
        uint256 deadline = block.timestamp;
        bytes memory sig = _sign(user, 100e18, deadline);

        vm.prank(teller);
        uint256 delta = pool.processRewards(user, 100e18, deadline, sig);
        assertEq(delta, 100e18);
    }

    function test_processRewards_deadlineAtUpperBoundary() external {
        // deadline == block.timestamp + maxDeadline is valid
        uint256 deadline = block.timestamp + 1 days;
        bytes memory sig = _sign(user, 100e18, deadline);

        vm.prank(teller);
        uint256 delta = pool.processRewards(user, 100e18, deadline, sig);
        assertEq(delta, 100e18);
    }

    function test_processRewards_deltaAtMaxRewardBoundary() external {
        // delta == maximumRewardAmountPerClaim (exactly at limit, not exceeding)
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, 1_000e18, deadline);

        vm.prank(teller);
        uint256 delta = pool.processRewards(user, 1_000e18, deadline, sig);
        assertEq(delta, 1_000e18);
    }

    function test_processRewards_multipleUsers() external {
        address user2 = vm.addr(4);
        uint256 deadline = block.timestamp + 1 hours;

        bytes memory sig1 = _sign(user, 100e18, deadline);
        bytes memory sig2 = _sign(user2, 200e18, deadline);

        vm.prank(teller);
        pool.processRewards(user, 100e18, deadline, sig1);

        vm.prank(teller);
        pool.processRewards(user2, 200e18, deadline, sig2);

        assertEq(rewardToken.balanceOf(user), 100e18);
        assertEq(rewardToken.balanceOf(user2), 200e18);
    }

    // ========================= RATE LIMITING =========================

    function test_processRewards_revertsRateLimited() external {
        pool.setSecondsBetweenClaims(1 hours);
        vm.warp(2 hours);

        // First claim succeeds
        uint256 deadline1 = block.timestamp + 1 hours;
        bytes memory sig1 = _sign(user, 100e18, deadline1);
        vm.prank(teller);
        pool.processRewards(user, 100e18, deadline1, sig1);

        // Second claim too soon (1 second before cooldown expires)
        vm.warp(block.timestamp + 1 hours - 1);
        uint256 deadline2 = block.timestamp + 1 hours;
        bytes memory sig2 = _sign(user, 200e18, deadline2);
        vm.prank(teller);
        vm.expectRevert(IncentivePool.RateLimitExceeded.selector);
        pool.processRewards(user, 200e18, deadline2, sig2);
    }

    function test_processRewards_rateLimitPassesAfterCooldown() external {
        pool.setSecondsBetweenClaims(1 hours);
        vm.warp(2 hours);

        // First claim
        uint256 deadline1 = block.timestamp + 1 hours;
        bytes memory sig1 = _sign(user, 100e18, deadline1);
        vm.prank(teller);
        pool.processRewards(user, 100e18, deadline1, sig1);

        // Warp exactly to cooldown boundary
        vm.warp(block.timestamp + 1 hours);
        uint256 deadline2 = block.timestamp + 1 hours;
        bytes memory sig2 = _sign(user, 200e18, deadline2);
        vm.prank(teller);
        uint256 delta = pool.processRewards(user, 200e18, deadline2, sig2);
        assertEq(delta, 100e18);
    }

    function test_processRewards_rateLimitPerUser() external {
        address user2 = vm.addr(4);
        pool.setSecondsBetweenClaims(1 hours);
        vm.warp(2 hours);

        // User1 claims
        uint256 deadline1 = block.timestamp + 1 hours;
        bytes memory sig1 = _sign(user, 100e18, deadline1);
        vm.prank(teller);
        pool.processRewards(user, 100e18, deadline1, sig1);

        // User2 can claim immediately (independent rate limit)
        bytes memory sig2 = _sign(user2, 100e18, deadline1);
        vm.prank(teller);
        uint256 delta = pool.processRewards(user2, 100e18, deadline1, sig2);
        assertEq(delta, 100e18);
    }

    function test_processRewards_revertsWhenDisabledViaMaxSecondsBetweenClaims() external {
        pool.setSecondsBetweenClaims(type(uint32).max);
        vm.warp(2 hours);

        // lastClaimTimestamp=0 for first claim, 0 + type(uint32).max = type(uint32).max
        // block.timestamp < type(uint32).max is always true, so RateLimitExceeded
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, 100e18, deadline);

        vm.prank(teller);
        vm.expectRevert(IncentivePool.RateLimitExceeded.selector);
        pool.processRewards(user, 100e18, deadline, sig);
    }

    // ========================= TOTAL REWARD CAP =========================

    function test_processRewards_revertsRewardsDisabledZeroCap() external {
        pool.setTotalRewardCap(0);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, 100e18, deadline);

        vm.prank(teller);
        vm.expectRevert(IncentivePool.RewardsDisabled.selector);
        pool.processRewards(user, 100e18, deadline, sig);
    }

    function test_processRewards_revertsRewardsDisabledZeroMaxPerClaim() external {
        pool.setMaximumRewardAmountPerClaim(0);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, 100e18, deadline);

        vm.prank(teller);
        vm.expectRevert(IncentivePool.RewardsDisabled.selector);
        pool.processRewards(user, 100e18, deadline, sig);
    }

    function test_processRewards_partialClaimNearCap() external {
        pool.setTotalRewardCap(150e18);

        // First claim: 100 cumulative, under cap
        uint256 deadline1 = block.timestamp + 1 hours;
        bytes memory sig1 = _sign(user, 100e18, deadline1);
        vm.prank(teller);
        pool.processRewards(user, 100e18, deadline1, sig1);

        // Second claim: 200 cumulative, but cap is 150 -> delta clamped to 50
        vm.warp(block.timestamp + 1);
        uint256 deadline2 = block.timestamp + 1 hours;
        bytes memory sig2 = _sign(user, 200e18, deadline2);
        vm.prank(teller);
        uint256 delta = pool.processRewards(user, 200e18, deadline2, sig2);

        assertEq(delta, 50e18, "delta clamped to remaining cap");
        assertEq(pool.getTotalClaimedAmount(user), 150e18, "cumulative equals cap");
        assertEq(rewardToken.balanceOf(user), 150e18);
    }

    function test_processRewards_totalRewardCapAtBoundary() external {
        pool.setTotalRewardCap(100e18);

        // Exactly at cap
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, 100e18, deadline);
        vm.prank(teller);
        uint256 delta = pool.processRewards(user, 100e18, deadline, sig);
        assertEq(delta, 100e18);
    }

    function test_processRewards_totalRewardCapPerUser() external {
        address user2 = vm.addr(4);
        pool.setTotalRewardCap(100e18);

        uint256 deadline = block.timestamp + 1 hours;

        // User1 claims 100 (at cap)
        bytes memory sig1 = _sign(user, 100e18, deadline);
        vm.prank(teller);
        pool.processRewards(user, 100e18, deadline, sig1);

        // User2 can also claim 100 (independent cap)
        bytes memory sig2 = _sign(user2, 100e18, deadline);
        vm.prank(teller);
        uint256 delta = pool.processRewards(user2, 100e18, deadline, sig2);
        assertEq(delta, 100e18);
    }

    // ========================= RESCUE FUNDS =========================

    function test_rescueFunds() external {
        address recipient = vm.addr(10);
        uint256 amount = 500e18;

        vm.expectEmit(true, true, false, true, address(pool));
        emit FundsRescued(address(rewardToken), recipient, amount);

        pool.rescueFunds(ERC20(address(rewardToken)), recipient, amount);

        assertEq(rewardToken.balanceOf(recipient), amount);
    }

    function test_rescueFunds_revertsZeroAddress() external {
        vm.expectRevert(IncentivePool.InvalidAddress.selector);
        pool.rescueFunds(ERC20(address(rewardToken)), address(0), 100e18);
    }

    function test_rescueFunds_revertsUnauthorized() external {
        vm.prank(user);
        vm.expectRevert("UNAUTHORIZED");
        pool.rescueFunds(ERC20(address(rewardToken)), user, 100e18);
    }

    // ========================= GET CLAIM HISTORY =========================

    function test_getClaimHistory_empty() external view {
        IncentivePool.ClaimCheckpoint[] memory history = pool.getClaimHistory(user);
        assertEq(history.length, 0);
    }

    function test_getClaimHistory_afterClaim() external {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, 100e18, deadline);

        vm.prank(teller);
        pool.processRewards(user, 100e18, deadline, sig);

        IncentivePool.ClaimCheckpoint[] memory history = pool.getClaimHistory(user);
        assertEq(history.length, 1);
        assertEq(pool.getTotalClaimedAmount(user), 100e18);
    }

    // ========================= CLAIM CAPPING =========================

    function test_processRewards_capThenClaimRemainderNextInterval() external {
        pool.setMaximumRewardAmountPerClaim(50e18);
        pool.setSecondsBetweenClaims(1 hours);
        vm.warp(2 hours);

        // Cumulative = 200, max per claim = 50 -> capped to 50
        uint256 deadline1 = block.timestamp + 1 hours;
        bytes memory sig1 = _sign(user, 200e18, deadline1);
        vm.prank(teller);
        uint256 delta1 = pool.processRewards(user, 200e18, deadline1, sig1);
        assertEq(delta1, 50e18);

        // After cooldown, claim again with same cumulative -> delta = 150, capped to 50
        vm.warp(block.timestamp + 1 hours);
        uint256 deadline2 = block.timestamp + 1 hours;
        bytes memory sig2 = _sign(user, 200e18, deadline2);
        vm.prank(teller);
        uint256 delta2 = pool.processRewards(user, 200e18, deadline2, sig2);
        assertEq(delta2, 50e18);

        assertEq(pool.getTotalClaimedAmount(user), 100e18);
        assertEq(rewardToken.balanceOf(user), 100e18);
    }

    function test_processRewards_reuseSignatureAcrossMultipleClaims() external {
        pool.setMaximumRewardAmountPerClaim(50e18);
        pool.setSecondsBetweenClaims(1 hours);
        vm.warp(2 hours);

        // Sign once with a long deadline
        uint256 deadline = block.timestamp + 10 hours;
        bytes memory sig = _sign(user, 200e18, deadline);

        // First claim: delta = 200, capped to 50
        vm.prank(teller);
        uint256 delta1 = pool.processRewards(user, 200e18, deadline, sig);
        assertEq(delta1, 50e18);

        // Second claim with same signature after cooldown: delta = 150, capped to 50
        vm.warp(block.timestamp + 1 hours);
        vm.prank(teller);
        uint256 delta2 = pool.processRewards(user, 200e18, deadline, sig);
        assertEq(delta2, 50e18);

        // Third claim with same signature: delta = 100, capped to 50
        vm.warp(block.timestamp + 1 hours);
        vm.prank(teller);
        uint256 delta3 = pool.processRewards(user, 200e18, deadline, sig);
        assertEq(delta3, 50e18);

        // Fourth claim with same signature: delta = 50, exactly 50
        vm.warp(block.timestamp + 1 hours);
        vm.prank(teller);
        uint256 delta4 = pool.processRewards(user, 200e18, deadline, sig);
        assertEq(delta4, 50e18);

        // Fully drained: fifth claim reverts with NothingToClaim
        vm.warp(block.timestamp + 1 hours);
        vm.prank(teller);
        vm.expectRevert(IncentivePool.NothingToClaim.selector);
        pool.processRewards(user, 200e18, deadline, sig);

        assertEq(pool.getTotalClaimedAmount(user), 200e18);
        assertEq(rewardToken.balanceOf(user), 200e18);
    }

    function test_processRewards_capDoesNotAffectSmallClaims() external {
        pool.setMaximumRewardAmountPerClaim(500e18);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, 100e18, deadline);

        vm.prank(teller);
        uint256 delta = pool.processRewards(user, 100e18, deadline, sig);

        // No capping needed, delta == earned
        assertEq(delta, 100e18);
    }

    function test_processRewards_capInteractsWithTotalRewardCap() external {
        pool.setMaximumRewardAmountPerClaim(200e18);
        pool.setTotalRewardCap(150e18);

        // Cumulative = 300, capped to 200 per claim, then clamped to 150 by totalRewardCap
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, 300e18, deadline);

        vm.prank(teller);
        uint256 delta = pool.processRewards(user, 300e18, deadline, sig);

        assertEq(delta, 150e18, "delta clamped to totalRewardCap");
        assertEq(pool.getTotalClaimedAmount(user), 150e18);
    }

    function test_processRewards_capThenTotalCapReached() external {
        pool.setMaximumRewardAmountPerClaim(80e18);
        pool.setTotalRewardCap(100e18);

        // First claim: cumulative=200, capped to 80
        uint256 deadline1 = block.timestamp + 1 hours;
        bytes memory sig1 = _sign(user, 200e18, deadline1);
        vm.prank(teller);
        uint256 delta1 = pool.processRewards(user, 200e18, deadline1, sig1);
        assertEq(delta1, 80e18);

        // Second claim: delta = 200-80 = 120, capped to 80 by maxPerClaim, then clamped to 20 by totalRewardCap
        vm.warp(block.timestamp + 1);
        uint256 deadline2 = block.timestamp + 1 hours;
        bytes memory sig2 = _sign(user, 200e18, deadline2);
        vm.prank(teller);
        uint256 delta2 = pool.processRewards(user, 200e18, deadline2, sig2);

        assertEq(delta2, 20e18, "delta clamped to remaining cap");
        assertEq(pool.getTotalClaimedAmount(user), 100e18, "user reached exact cap");
    }

    // ========================= PARTIAL CLAIM (CAP CLAMPING) =========================

    function test_processRewards_partialClaimFirstClaimExceedsCap() external {
        pool.setTotalRewardCap(50e18);
        pool.setMaximumRewardAmountPerClaim(1_000e18);

        // First claim overshoots cap -> clamped to cap
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, 200e18, deadline);

        vm.prank(teller);
        uint256 delta = pool.processRewards(user, 200e18, deadline, sig);

        assertEq(delta, 50e18, "first claim clamped to totalRewardCap");
        assertEq(pool.getTotalClaimedAmount(user), 50e18);
    }

    function test_processRewards_partialClaimExactlyAtCap() external {
        pool.setTotalRewardCap(100e18);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, 100e18, deadline);

        vm.prank(teller);
        uint256 delta = pool.processRewards(user, 100e18, deadline, sig);

        assertEq(delta, 100e18, "exact cap claim should succeed fully");
        assertEq(pool.getTotalClaimedAmount(user), 100e18);
    }

    function test_processRewards_revertsAtCapExhausted() external {
        pool.setTotalRewardCap(100e18);

        // Claim exactly to cap
        uint256 deadline1 = block.timestamp + 1 hours;
        bytes memory sig1 = _sign(user, 100e18, deadline1);
        vm.prank(teller);
        pool.processRewards(user, 100e18, deadline1, sig1);

        // Try to claim more -> totalClaimed == totalRewardCap, reverts
        vm.warp(block.timestamp + 1);
        uint256 deadline2 = block.timestamp + 1 hours;
        bytes memory sig2 = _sign(user, 200e18, deadline2);
        vm.prank(teller);
        vm.expectRevert(IncentivePool.TotalRewardCapExceeded.selector);
        pool.processRewards(user, 200e18, deadline2, sig2);
    }

    function test_processRewards_revertsCapLoweredBelowClaimed() external {
        // Claim 100
        uint256 deadline1 = block.timestamp + 1 hours;
        bytes memory sig1 = _sign(user, 100e18, deadline1);
        vm.prank(teller);
        pool.processRewards(user, 100e18, deadline1, sig1);

        // Admin lowers cap below already claimed
        pool.setTotalRewardCap(50e18);

        // Next claim reverts because totalClaimed (100) >= totalRewardCap (50)
        vm.warp(block.timestamp + 1);
        uint256 deadline2 = block.timestamp + 1 hours;
        bytes memory sig2 = _sign(user, 200e18, deadline2);
        vm.prank(teller);
        vm.expectRevert(IncentivePool.TotalRewardCapExceeded.selector);
        pool.processRewards(user, 200e18, deadline2, sig2);
    }

    function test_processRewards_partialClaimBothCapsApply() external {
        // maxPerClaim = 80, totalRewardCap = 60
        // delta from cumulative would be 100, capped to 80 by maxPerClaim, then clamped to 60 by totalRewardCap
        pool.setMaximumRewardAmountPerClaim(80e18);
        pool.setTotalRewardCap(60e18);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, 100e18, deadline);

        vm.prank(teller);
        uint256 delta = pool.processRewards(user, 100e18, deadline, sig);

        assertEq(delta, 60e18, "totalRewardCap is the tighter constraint");
    }

    function test_processRewards_partialClaimMaxPerClaimTighter() external {
        // maxPerClaim = 30, totalRewardCap = 500
        // delta from cumulative = 100, capped to 30 by maxPerClaim (tighter), 30 < 500 remaining
        pool.setMaximumRewardAmountPerClaim(30e18);
        pool.setTotalRewardCap(500e18);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, 100e18, deadline);

        vm.prank(teller);
        uint256 delta = pool.processRewards(user, 100e18, deadline, sig);

        assertEq(delta, 30e18, "maxPerClaim is the tighter constraint");
    }

    function test_processRewards_partialClaimDrainsToCapOverMultipleClaims() external {
        pool.setMaximumRewardAmountPerClaim(40e18);
        pool.setTotalRewardCap(100e18);

        // Claim 1: delta=40 (capped by maxPerClaim), cumulative=40
        uint256 d1 = block.timestamp + 1 hours;
        bytes memory s1 = _sign(user, 500e18, d1);
        vm.prank(teller);
        uint256 delta1 = pool.processRewards(user, 500e18, d1, s1);
        assertEq(delta1, 40e18);

        // Claim 2: delta=40 (capped by maxPerClaim), cumulative=80
        vm.warp(block.timestamp + 1);
        uint256 d2 = block.timestamp + 1 hours;
        bytes memory s2 = _sign(user, 500e18, d2);
        vm.prank(teller);
        uint256 delta2 = pool.processRewards(user, 500e18, d2, s2);
        assertEq(delta2, 40e18);

        // Claim 3: delta would be 40, but only 20 remaining -> clamped to 20
        vm.warp(block.timestamp + 1);
        uint256 d3 = block.timestamp + 1 hours;
        bytes memory s3 = _sign(user, 500e18, d3);
        vm.prank(teller);
        uint256 delta3 = pool.processRewards(user, 500e18, d3, s3);
        assertEq(delta3, 20e18, "final claim clamped to remaining cap");

        assertEq(pool.getTotalClaimedAmount(user), 100e18, "drained exactly to cap");

        // Claim 4: cap exhausted -> revert
        vm.warp(block.timestamp + 1);
        uint256 d4 = block.timestamp + 1 hours;
        bytes memory s4 = _sign(user, 500e18, d4);
        vm.prank(teller);
        vm.expectRevert(IncentivePool.TotalRewardCapExceeded.selector);
        pool.processRewards(user, 500e18, d4, s4);
    }

    function test_processRewards_partialClaimCheckpointCorrect() external {
        pool.setTotalRewardCap(75e18);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, 200e18, deadline);

        vm.prank(teller);
        uint256 delta = pool.processRewards(user, 200e18, deadline, sig);
        assertEq(delta, 75e18);

        IncentivePool.ClaimCheckpoint[] memory history = pool.getClaimHistory(user);
        assertEq(history.length, 1);
        assertEq(history[0].amountClaimed, 75e18, "checkpoint records clamped amount");
        assertEq(history[0].cumulativeClaimed, 75e18, "checkpoint cumulative is clamped");
    }

    function test_processRewards_partialClaimEmitsClampedAmount() external {
        pool.setTotalRewardCap(75e18);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, 200e18, deadline);

        vm.expectEmit(true, false, false, true, address(pool));
        emit RewardsProcessed(user, 75e18);

        vm.prank(teller);
        pool.processRewards(user, 200e18, deadline, sig);
    }

    function test_processRewards_partialClaimCapRaisedUnblocksUser() external {
        pool.setTotalRewardCap(50e18);

        // Claim to cap
        uint256 d1 = block.timestamp + 1 hours;
        bytes memory s1 = _sign(user, 200e18, d1);
        vm.prank(teller);
        pool.processRewards(user, 200e18, d1, s1);
        assertEq(pool.getTotalClaimedAmount(user), 50e18);

        // Cap exhausted
        vm.warp(block.timestamp + 1);
        uint256 d2 = block.timestamp + 1 hours;
        bytes memory s2 = _sign(user, 200e18, d2);
        vm.prank(teller);
        vm.expectRevert(IncentivePool.TotalRewardCapExceeded.selector);
        pool.processRewards(user, 200e18, d2, s2);

        // Admin raises cap
        pool.setTotalRewardCap(120e18);

        // User can claim again, partial to new cap
        vm.warp(block.timestamp + 1);
        uint256 d3 = block.timestamp + 1 hours;
        bytes memory s3 = _sign(user, 200e18, d3);
        vm.prank(teller);
        uint256 delta = pool.processRewards(user, 200e18, d3, s3);
        assertEq(delta, 70e18, "claimed up to new cap");
        assertEq(pool.getTotalClaimedAmount(user), 120e18);
    }

    // ========================= FUZZ TESTS =========================

    function testFuzz_processRewards_deltaAlwaysCapped(uint104 cumulativeRewards, uint96 maxPerClaim) external {
        vm.assume(cumulativeRewards > 0);
        vm.assume(maxPerClaim > 0);
        vm.assume(cumulativeRewards <= 1_000_000e18);

        pool.setMaximumRewardAmountPerClaim(maxPerClaim);
        pool.setTotalRewardCap(type(uint104).max);
        rewardToken.mint(address(pool), uint256(cumulativeRewards));

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, cumulativeRewards, deadline);

        vm.prank(teller);
        uint256 delta = pool.processRewards(user, cumulativeRewards, deadline, sig);

        assertLe(delta, maxPerClaim, "delta must never exceed maxPerClaim");
        assertLe(delta, cumulativeRewards, "delta must never exceed cumulativeRewards");
        if (cumulativeRewards <= maxPerClaim) {
            assertEq(delta, cumulativeRewards, "uncapped claim should equal cumulativeRewards");
        } else {
            assertEq(delta, maxPerClaim, "capped claim should equal maxPerClaim");
        }
    }

    function testFuzz_processRewards_rateLimitBlocksSecondClaim(uint32 cooldown) external {
        cooldown = uint32(bound(cooldown, 1, 365 days));
        pool.setSecondsBetweenClaims(cooldown);
        vm.warp(cooldown + 1);

        uint256 deadline1 = block.timestamp + 1 hours;
        bytes memory sig1 = _sign(user, 100e18, deadline1);
        vm.prank(teller);
        pool.processRewards(user, 100e18, deadline1, sig1);

        // Warp to 1 second before cooldown expires
        vm.warp(block.timestamp + cooldown - 1);
        uint256 deadline2 = block.timestamp + 1 hours;
        bytes memory sig2 = _sign(user, 200e18, deadline2);
        vm.prank(teller);
        vm.expectRevert(IncentivePool.RateLimitExceeded.selector);
        pool.processRewards(user, 200e18, deadline2, sig2);
    }

    function testFuzz_processRewards_cappedClaimCheckpointCorrect(uint104 cumulative, uint96 maxPerClaim) external {
        vm.assume(cumulative > 0);
        vm.assume(maxPerClaim > 0);
        vm.assume(cumulative <= 1_000_000e18);

        pool.setMaximumRewardAmountPerClaim(maxPerClaim);
        pool.setTotalRewardCap(type(uint104).max);
        rewardToken.mint(address(pool), uint256(cumulative));

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, cumulative, deadline);

        vm.prank(teller);
        uint256 delta = pool.processRewards(user, cumulative, deadline, sig);

        // Checkpoint records what was actually claimed
        assertEq(pool.getTotalClaimedAmount(user), delta);
        assertEq(rewardToken.balanceOf(user), delta);
    }

    function testFuzz_processRewards_tokenBalanceInvariant(uint104 cumulativeRewards) external {
        vm.assume(cumulativeRewards > 0);
        vm.assume(cumulativeRewards <= 1_000_000e18);

        pool.setTotalRewardCap(type(uint104).max);
        rewardToken.mint(address(pool), uint256(cumulativeRewards));

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, cumulativeRewards, deadline);

        vm.prank(teller);
        pool.processRewards(user, cumulativeRewards, deadline, sig);

        assertEq(rewardToken.balanceOf(user), pool.getTotalClaimedAmount(user), "balance must equal cumulative claimed");
    }

    function testFuzz_processRewards_deadlineValidRange(uint256 offset) external {
        // Fuzz valid deadlines: offset in [0, maxDeadline]
        offset = bound(offset, 0, 1 days);
        uint256 deadline = block.timestamp + offset;
        bytes memory sig = _sign(user, 100e18, deadline);

        vm.prank(teller);
        uint256 delta = pool.processRewards(user, 100e18, deadline, sig);
        assertEq(delta, 100e18);
    }

    function testFuzz_processRewards_deadlineExpiredReverts(uint256 warpTime) external {
        warpTime = bound(warpTime, 2, 365 days);
        vm.warp(warpTime);

        uint256 deadline = block.timestamp - 1;
        bytes memory sig = _sign(user, 100e18, deadline);

        vm.prank(teller);
        vm.expectRevert(IncentivePool.InvalidDeadline.selector);
        pool.processRewards(user, 100e18, deadline, sig);
    }

    function testFuzz_processRewards_deadlineTooFarReverts(uint256 excess) external {
        excess = bound(excess, 1, 365 days);
        uint256 deadline = block.timestamp + 1 days + excess;
        bytes memory sig = _sign(user, 100e18, deadline);

        vm.prank(teller);
        vm.expectRevert(IncentivePool.InvalidDeadline.selector);
        pool.processRewards(user, 100e18, deadline, sig);
    }

    function testFuzz_processRewards_cumulativeNeverDecreases(uint104 amount1, uint104 amount2) external {
        amount1 = uint104(bound(amount1, 1, 500e18));
        amount2 = uint104(bound(amount2, uint256(amount1) + 1, 1_000e18));

        pool.setTotalRewardCap(type(uint104).max);

        uint256 deadline1 = block.timestamp + 1 hours;
        bytes memory sig1 = _sign(user, amount1, deadline1);
        vm.prank(teller);
        pool.processRewards(user, amount1, deadline1, sig1);

        uint256 cumAfterFirst = pool.getTotalClaimedAmount(user);

        vm.warp(block.timestamp + 1);
        uint256 deadline2 = block.timestamp + 1 hours;
        bytes memory sig2 = _sign(user, amount2, deadline2);
        vm.prank(teller);
        pool.processRewards(user, amount2, deadline2, sig2);

        uint256 cumAfterSecond = pool.getTotalClaimedAmount(user);
        assertGe(cumAfterSecond, cumAfterFirst, "cumulative must never decrease");
    }

    function testFuzz_processRewards_totalCapNeverExceeded(uint104 cap, uint104 cumulative) external {
        cap = uint104(bound(cap, 1, 1_000_000e18));
        cumulative = uint104(bound(cumulative, 1, uint256(cap)));

        pool.setTotalRewardCap(cap);
        pool.setMaximumRewardAmountPerClaim(type(uint96).max);
        rewardToken.mint(address(pool), uint256(cumulative));

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, cumulative, deadline);

        vm.prank(teller);
        pool.processRewards(user, cumulative, deadline, sig);

        assertLe(pool.getTotalClaimedAmount(user), cap, "total claimed must never exceed cap");
    }

    function testFuzz_processRewards_multiClaimConvergence(uint8 numClaims) external {
        numClaims = uint8(bound(numClaims, 2, 10));
        uint256 target = 500e18;
        uint96 maxPerClaim = 100e18;
        pool.setMaximumRewardAmountPerClaim(maxPerClaim);
        pool.setTotalRewardCap(type(uint104).max);

        uint256 totalClaimed;
        for (uint256 i; i < numClaims; i++) {
            vm.warp(block.timestamp + 1);
            uint256 deadline = block.timestamp + 1 hours;
            bytes memory sig = _sign(user, target, deadline);

            vm.prank(teller);
            uint256 delta = pool.processRewards(user, target, deadline, sig);

            totalClaimed += delta;
            assertEq(pool.getTotalClaimedAmount(user), totalClaimed, "cumulative must match sum of deltas");

            if (totalClaimed >= target) break;
        }

        assertLe(totalClaimed, target, "must not exceed target");
    }

    function testFuzz_processRewards_rateLimitCooldownBoundary(uint32 cooldown) external {
        cooldown = uint32(bound(cooldown, 2, 30 days));
        pool.setSecondsBetweenClaims(cooldown);
        vm.warp(cooldown + 1);

        // First claim
        uint256 deadline1 = block.timestamp + 1 hours;
        bytes memory sig1 = _sign(user, 100e18, deadline1);
        vm.prank(teller);
        pool.processRewards(user, 100e18, deadline1, sig1);

        uint256 claimTs = block.timestamp;

        // 1 second before cooldown: must fail
        vm.warp(claimTs + cooldown - 1);
        uint256 deadline2 = block.timestamp + 1 hours;
        bytes memory sig2 = _sign(user, 200e18, deadline2);
        vm.prank(teller);
        vm.expectRevert(IncentivePool.RateLimitExceeded.selector);
        pool.processRewards(user, 200e18, deadline2, sig2);

        // Exactly at cooldown: must succeed
        vm.warp(claimTs + cooldown);
        uint256 deadline3 = block.timestamp + 1 hours;
        bytes memory sig3 = _sign(user, 200e18, deadline3);
        vm.prank(teller);
        uint256 delta = pool.processRewards(user, 200e18, deadline3, sig3);
        assertEq(delta, 100e18);
    }

    function testFuzz_processRewards_independentUserAccounting(uint104 amount1, uint104 amount2) external {
        amount1 = uint104(bound(amount1, 1e18, 500e18));
        amount2 = uint104(bound(amount2, 1e18, 500e18));

        address user2 = vm.addr(4);
        pool.setTotalRewardCap(type(uint104).max);

        uint256 deadline = block.timestamp + 1 hours;

        bytes memory sig1 = _sign(user, amount1, deadline);
        bytes memory sig2 = _sign(user2, amount2, deadline);

        vm.prank(teller);
        pool.processRewards(user, amount1, deadline, sig1);

        vm.prank(teller);
        pool.processRewards(user2, amount2, deadline, sig2);

        assertEq(pool.getTotalClaimedAmount(user), amount1, "user1 accounting independent");
        assertEq(pool.getTotalClaimedAmount(user2), amount2, "user2 accounting independent");
        assertEq(rewardToken.balanceOf(user), amount1);
        assertEq(rewardToken.balanceOf(user2), amount2);
    }

    function testFuzz_processRewards_signatureUniquePerParams(uint104 amount1, uint104 amount2) external {
        amount1 = uint104(bound(amount1, 1e18, 500e18));
        amount2 = uint104(bound(amount2, uint256(amount1) + 1, 1_000e18));

        pool.setTotalRewardCap(type(uint104).max);

        uint256 deadline = block.timestamp + 1 hours;

        // Sign for amount1
        bytes memory sig1 = _sign(user, amount1, deadline);

        // Use sig1 for amount2 should fail (wrong signer recovery)
        vm.prank(teller);
        vm.expectRevert(IncentivePool.InvalidSigner.selector);
        pool.processRewards(user, amount2, deadline, sig1);
    }

    function testFuzz_processRewards_claimHistoryGrowsMonotonically(uint8 numClaims) external {
        numClaims = uint8(bound(numClaims, 1, 10));
        pool.setMaximumRewardAmountPerClaim(type(uint96).max);
        pool.setTotalRewardCap(type(uint104).max);

        uint256 cumulative;
        for (uint256 i; i < numClaims; i++) {
            cumulative += 50e18;
            vm.warp(block.timestamp + 1);
            uint256 deadline = block.timestamp + 1 hours;
            bytes memory sig = _sign(user, cumulative, deadline);

            vm.prank(teller);
            pool.processRewards(user, cumulative, deadline, sig);
        }

        IncentivePool.ClaimCheckpoint[] memory history = pool.getClaimHistory(user);
        assertEq(history.length, numClaims);

        for (uint256 i = 1; i < history.length; i++) {
            assertGe(history[i].timestamp, history[i - 1].timestamp, "timestamps must be non-decreasing");
            assertGe(
                history[i].cumulativeClaimed, history[i - 1].cumulativeClaimed, "cumulative must be non-decreasing"
            );
        }
    }

    function testFuzz_processRewards_partialClaimNeverExceedsCap(uint96 cap, uint96 maxPerClaim, uint104 cumulative)
        external
    {
        cap = uint96(bound(cap, 1, 1_000_000e18));
        maxPerClaim = uint96(bound(maxPerClaim, 1, 1_000_000e18));
        cumulative = uint104(bound(cumulative, 1, 1_000_000e18));

        pool.setTotalRewardCap(cap);
        pool.setMaximumRewardAmountPerClaim(maxPerClaim);
        rewardToken.mint(address(pool), uint256(cumulative));

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, cumulative, deadline);

        vm.prank(teller);
        uint256 delta = pool.processRewards(user, cumulative, deadline, sig);

        assertLe(delta, cap, "delta must never exceed totalRewardCap");
        assertLe(delta, maxPerClaim, "delta must never exceed maxPerClaim");
        assertLe(delta, cumulative, "delta must never exceed cumulative");
        assertEq(pool.getTotalClaimedAmount(user), delta);
    }

    function testFuzz_processRewards_partialClaimMinOfThreeCaps(uint96 cap, uint96 maxPerClaim, uint104 cumulative)
        external
    {
        cap = uint96(bound(cap, 1, 500_000e18));
        maxPerClaim = uint96(bound(maxPerClaim, 1, 500_000e18));
        cumulative = uint104(bound(cumulative, 1, 500_000e18));

        pool.setTotalRewardCap(cap);
        pool.setMaximumRewardAmountPerClaim(maxPerClaim);
        rewardToken.mint(address(pool), uint256(cumulative));

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, cumulative, deadline);

        vm.prank(teller);
        uint256 delta = pool.processRewards(user, cumulative, deadline, sig);

        // delta == min(cumulative, maxPerClaim, cap)
        uint256 expected = cumulative;
        if (maxPerClaim < expected) expected = maxPerClaim;
        if (cap < expected) expected = cap;

        assertEq(delta, expected, "delta must equal min(cumulative, maxPerClaim, cap)");
    }

    function testFuzz_processRewards_partialClaimMultiRoundDrainsToExactCap(uint96 cap, uint96 maxPerClaim) external {
        cap = uint96(bound(cap, 1e18, 500e18));
        maxPerClaim = uint96(bound(maxPerClaim, 1e18, 500e18));

        pool.setTotalRewardCap(cap);
        pool.setMaximumRewardAmountPerClaim(maxPerClaim);

        uint256 largeCumulative = 10_000e18;
        uint256 totalClaimed;
        uint256 rounds = (uint256(cap) / uint256(maxPerClaim)) + 2;

        for (uint256 i; i < rounds; i++) {
            if (totalClaimed >= cap) break;

            vm.warp(block.timestamp + 1);
            uint256 deadline = block.timestamp + 1 hours;
            bytes memory sig = _sign(user, largeCumulative, deadline);

            vm.prank(teller);
            uint256 delta = pool.processRewards(user, largeCumulative, deadline, sig);
            totalClaimed += delta;
        }

        assertEq(totalClaimed, cap, "multi-round claims must drain exactly to cap");
        assertEq(pool.getTotalClaimedAmount(user), cap);
    }

    function testFuzz_processRewards_capLoweredAfterClaimRevertsIfExhausted(uint104 firstClaim, uint104 newCap)
        external
    {
        firstClaim = uint104(bound(firstClaim, 1e18, 500e18));
        newCap = uint104(bound(newCap, 1, uint256(firstClaim)));

        pool.setTotalRewardCap(type(uint104).max);

        uint256 d1 = block.timestamp + 1 hours;
        bytes memory s1 = _sign(user, firstClaim, d1);
        vm.prank(teller);
        pool.processRewards(user, firstClaim, d1, s1);

        // Lower cap to at or below what was already claimed
        pool.setTotalRewardCap(newCap);

        vm.warp(block.timestamp + 1);
        uint256 d2 = block.timestamp + 1 hours;
        bytes memory s2 = _sign(user, uint256(firstClaim) + 100e18, d2);

        vm.prank(teller);
        vm.expectRevert(IncentivePool.TotalRewardCapExceeded.selector);
        pool.processRewards(user, uint256(firstClaim) + 100e18, d2, s2);
    }

    // ========================= BLACKLIST =========================

    function test_setBlacklisted() external {
        vm.expectEmit(true, false, false, true, address(pool));
        emit BlacklistUpdated(user, true);

        pool.setBlacklisted(user, true);

        assertTrue(pool.blacklisted(user));
    }

    function test_setBlacklisted_revertsUnauthorized() external {
        vm.prank(user);
        vm.expectRevert("UNAUTHORIZED");
        pool.setBlacklisted(user, true);
    }

    function test_processRewards_revertsBlacklisted() external {
        pool.setBlacklisted(user, true);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, 100e18, deadline);

        vm.prank(teller);
        vm.expectRevert(IncentivePool.Blacklisted.selector);
        pool.processRewards(user, 100e18, deadline, sig);
    }

    function test_processRewards_unblacklistAllowsClaim() external {
        pool.setBlacklisted(user, true);
        pool.setBlacklisted(user, false);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, 100e18, deadline);

        vm.prank(teller);
        uint256 delta = pool.processRewards(user, 100e18, deadline, sig);
        assertEq(delta, 100e18);
    }

    function test_processRewards_blacklistOnlyAffectsTargetUser() external {
        address user2 = vm.addr(4);
        pool.setBlacklisted(user, true);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user2, 100e18, deadline);

        vm.prank(teller);
        uint256 delta = pool.processRewards(user2, 100e18, deadline, sig);
        assertEq(delta, 100e18);
    }

    // ========================= VIEW FUNCTIONS =========================

    function test_getLastClaimTimestamp_noHistory() external view {
        assertEq(pool.getLastClaimTimestamp(user), 0);
    }

    function test_getLastClaimTimestamp_afterClaim() external {
        vm.warp(12345);
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, 100e18, deadline);

        vm.prank(teller);
        pool.processRewards(user, 100e18, deadline, sig);

        assertEq(pool.getLastClaimTimestamp(user), 12345);
    }

    function test_getLastClaimTimestamp_returnsLatestAfterMultipleClaims() external {
        vm.warp(1000);
        uint256 d1 = block.timestamp + 1 hours;
        bytes memory s1 = _sign(user, 100e18, d1);
        vm.prank(teller);
        pool.processRewards(user, 100e18, d1, s1);

        vm.warp(2000);
        uint256 d2 = block.timestamp + 1 hours;
        bytes memory s2 = _sign(user, 200e18, d2);
        vm.prank(teller);
        pool.processRewards(user, 200e18, d2, s2);

        assertEq(pool.getLastClaimTimestamp(user), 2000);
    }

    function test_getLastCheckpointData_noHistory() external view {
        (uint256 ts, uint256 claimed) = pool.getLastCheckpointData(user);
        assertEq(ts, 0);
        assertEq(claimed, 0);
    }

    function test_getLastCheckpointData_afterMultipleClaims() external {
        vm.warp(1000);
        uint256 d1 = block.timestamp + 1 hours;
        bytes memory s1 = _sign(user, 100e18, d1);
        vm.prank(teller);
        pool.processRewards(user, 100e18, d1, s1);

        vm.warp(2000);
        uint256 d2 = block.timestamp + 1 hours;
        bytes memory s2 = _sign(user, 300e18, d2);
        vm.prank(teller);
        pool.processRewards(user, 300e18, d2, s2);

        (uint256 ts, uint256 claimed) = pool.getLastCheckpointData(user);
        assertEq(ts, 2000);
        assertEq(claimed, 300e18);
    }

    function test_getTotalClaimedAmount_noHistory() external view {
        assertEq(pool.getTotalClaimedAmount(user), 0);
    }

    function test_getClaimHistory_multipleEntries() external {
        vm.warp(1000);
        uint256 d1 = block.timestamp + 1 hours;
        bytes memory s1 = _sign(user, 100e18, d1);
        vm.prank(teller);
        pool.processRewards(user, 100e18, d1, s1);

        vm.warp(2000);
        uint256 d2 = block.timestamp + 1 hours;
        bytes memory s2 = _sign(user, 250e18, d2);
        vm.prank(teller);
        pool.processRewards(user, 250e18, d2, s2);

        vm.warp(3000);
        uint256 d3 = block.timestamp + 1 hours;
        bytes memory s3 = _sign(user, 400e18, d3);
        vm.prank(teller);
        pool.processRewards(user, 400e18, d3, s3);

        IncentivePool.ClaimCheckpoint[] memory history = pool.getClaimHistory(user);
        assertEq(history.length, 3);

        assertEq(history[0].timestamp, 1000);
        assertEq(history[0].amountClaimed, 100e18);
        assertEq(history[0].cumulativeClaimed, 100e18);

        assertEq(history[1].timestamp, 2000);
        assertEq(history[1].amountClaimed, 150e18);
        assertEq(history[1].cumulativeClaimed, 250e18);

        assertEq(history[2].timestamp, 3000);
        assertEq(history[2].amountClaimed, 150e18);
        assertEq(history[2].cumulativeClaimed, 400e18);
    }

    // ========================= EDGE CASES =========================

    function test_processRewards_zeroCumulativeReverts() external {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, 0, deadline);

        vm.prank(teller);
        vm.expectRevert(IncentivePool.NothingToClaim.selector);
        pool.processRewards(user, 0, deadline, sig);
    }

    function test_processRewards_zeroSecondsBetweenClaimsAllowsSameBlockClaims() external {
        pool.setSecondsBetweenClaims(0);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig1 = _sign(user, 100e18, deadline);
        vm.prank(teller);
        pool.processRewards(user, 100e18, deadline, sig1);

        // Second claim in same block (no warp)
        bytes memory sig2 = _sign(user, 200e18, deadline);
        vm.prank(teller);
        uint256 delta = pool.processRewards(user, 200e18, deadline, sig2);
        assertEq(delta, 100e18);
    }

    function test_processRewards_maxDeadlineZeroRequiresExactTimestamp() external {
        pool.setMaxDeadline(0);

        // deadline == block.timestamp is valid (passes both checks)
        uint256 deadline = block.timestamp;
        bytes memory sig = _sign(user, 100e18, deadline);

        vm.prank(teller);
        uint256 delta = pool.processRewards(user, 100e18, deadline, sig);
        assertEq(delta, 100e18);
    }

    function test_processRewards_maxDeadlineZeroRevertsFutureDeadline() external {
        pool.setMaxDeadline(0);

        uint256 deadline = block.timestamp + 1;
        bytes memory sig = _sign(user, 100e18, deadline);

        vm.prank(teller);
        vm.expectRevert(IncentivePool.InvalidDeadline.selector);
        pool.processRewards(user, 100e18, deadline, sig);
    }

    function test_processRewards_signerRotationInvalidatesOldSignatures() external {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, 100e18, deadline);

        // Rotate signer
        uint256 newSignerKey = 0xBEEF;
        address newSigner = vm.addr(newSignerKey);
        pool.setRewardSigner(newSigner);

        // Old signature fails
        vm.prank(teller);
        vm.expectRevert(IncentivePool.InvalidSigner.selector);
        pool.processRewards(user, 100e18, deadline, sig);

        // New signature works
        bytes memory newSig = _signWithKey(newSignerKey, user, 100e18, deadline);
        vm.prank(teller);
        uint256 delta = pool.processRewards(user, 100e18, deadline, newSig);
        assertEq(delta, 100e18);
    }

    function test_processRewards_blacklistAfterPartialClaims() external {
        // User claims 100
        uint256 d1 = block.timestamp + 1 hours;
        bytes memory s1 = _sign(user, 100e18, d1);
        vm.prank(teller);
        pool.processRewards(user, 100e18, d1, s1);

        // Blacklist user
        pool.setBlacklisted(user, true);

        // Further claims revert
        vm.warp(block.timestamp + 1);
        uint256 d2 = block.timestamp + 1 hours;
        bytes memory s2 = _sign(user, 200e18, d2);
        vm.prank(teller);
        vm.expectRevert(IncentivePool.Blacklisted.selector);
        pool.processRewards(user, 200e18, d2, s2);

        // Claim history preserved
        assertEq(pool.getTotalClaimedAmount(user), 100e18);
    }

    function test_rescueFunds_differentToken() external {
        MockERC20 otherToken = new MockERC20("Other", "OTH", 18);
        otherToken.mint(address(pool), 500e18);

        address recipient = vm.addr(10);
        pool.rescueFunds(ERC20(address(otherToken)), recipient, 500e18);

        assertEq(otherToken.balanceOf(recipient), 500e18);
        // Reward token untouched
        assertEq(rewardToken.balanceOf(address(pool)), 1_000_000e18);
    }

    function test_processRewards_revertsInsufficientPoolBalance() external {
        // Drain pool funds via rescue
        pool.rescueFunds(ERC20(address(rewardToken)), address(this), 1_000_000e18);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, 100e18, deadline);

        vm.prank(teller);
        vm.expectRevert("TRANSFER_FAILED");
        pool.processRewards(user, 100e18, deadline, sig);
    }

    function test_processRewards_blacklistCheckedBeforeSignature() external {
        pool.setBlacklisted(user, true);

        // Use invalid signature - should still revert with Blacklisted, not InvalidSigner
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory badSig = _signWithKey(0xBAD, user, 100e18, deadline);

        vm.prank(teller);
        vm.expectRevert(IncentivePool.Blacklisted.selector);
        pool.processRewards(user, 100e18, deadline, badSig);
    }

    function test_processRewards_cumulativeLessThanClaimedReverts() external {
        // Claim 100
        uint256 d1 = block.timestamp + 1 hours;
        bytes memory s1 = _sign(user, 100e18, d1);
        vm.prank(teller);
        pool.processRewards(user, 100e18, d1, s1);

        // Try claiming with lower cumulative
        vm.warp(block.timestamp + 1);
        uint256 d2 = block.timestamp + 1 hours;
        bytes memory s2 = _sign(user, 50e18, d2);
        vm.prank(teller);
        vm.expectRevert(IncentivePool.NothingToClaim.selector);
        pool.processRewards(user, 50e18, d2, s2);
    }

    // ========================= FUZZ EDGE CASES =========================

    function testFuzz_processRewards_zeroSecondsBetweenClaimsNoRateLimit(uint104 amount1, uint104 amount2) external {
        amount1 = uint104(bound(amount1, 1e18, 500e18));
        amount2 = uint104(bound(amount2, uint256(amount1) + 1, 1_000e18));

        pool.setSecondsBetweenClaims(0);
        pool.setTotalRewardCap(type(uint104).max);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig1 = _sign(user, amount1, deadline);
        vm.prank(teller);
        pool.processRewards(user, amount1, deadline, sig1);

        // Same block, no warp
        bytes memory sig2 = _sign(user, amount2, deadline);
        vm.prank(teller);
        uint256 delta = pool.processRewards(user, amount2, deadline, sig2);
        assertEq(delta, amount2 - amount1);
    }

    function testFuzz_processRewards_blacklistPreservesHistory(uint104 amount) external {
        amount = uint104(bound(amount, 1e18, 500e18));
        pool.setTotalRewardCap(type(uint104).max);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(user, amount, deadline);
        vm.prank(teller);
        pool.processRewards(user, amount, deadline, sig);

        pool.setBlacklisted(user, true);

        // History and balance remain intact
        assertEq(pool.getTotalClaimedAmount(user), amount);
        assertEq(pool.getLastClaimTimestamp(user), block.timestamp);
        assertEq(rewardToken.balanceOf(user), amount);
    }

    function testFuzz_getLastCheckpointData_matchesClaimHistory(uint8 numClaims) external {
        numClaims = uint8(bound(numClaims, 1, 10));
        pool.setMaximumRewardAmountPerClaim(type(uint96).max);
        pool.setTotalRewardCap(type(uint104).max);

        uint256 cumulative;
        for (uint256 i; i < numClaims; i++) {
            cumulative += 50e18;
            vm.warp(block.timestamp + 1);
            uint256 deadline = block.timestamp + 1 hours;
            bytes memory sig = _sign(user, cumulative, deadline);
            vm.prank(teller);
            pool.processRewards(user, cumulative, deadline, sig);
        }

        IncentivePool.ClaimCheckpoint[] memory history = pool.getClaimHistory(user);
        (uint256 lastTs, uint256 totalClaimed) = pool.getLastCheckpointData(user);

        // External getLastCheckpointData must match last entry in history
        assertEq(lastTs, history[history.length - 1].timestamp);
        assertEq(totalClaimed, history[history.length - 1].cumulativeClaimed);
        assertEq(pool.getLastClaimTimestamp(user), lastTs);
        assertEq(pool.getTotalClaimedAmount(user), totalClaimed);
    }

    // ========================= HELPERS =========================

    function _sign(address recipient, uint256 cumulativeOwed, uint256 deadline) internal view returns (bytes memory) {
        return _signWithKey(signerPrivateKey, recipient, cumulativeOwed, deadline);
    }

    function _signWithKey(uint256 privateKey, address recipient, uint256 cumulativeOwed, uint256 deadline)
        internal
        view
        returns (bytes memory)
    {
        bytes32 messageHash = keccak256(abi.encode(address(pool), block.chainid, recipient, cumulativeOwed, deadline));
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSignedHash);
        return abi.encodePacked(r, s, v);
    }
}
