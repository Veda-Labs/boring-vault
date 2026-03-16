// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {
    TellerWithMultiAssetSupport,
    DepositParams,
    ComplianceData,
    RewardData
} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {TellerWithYieldStreaming} from "src/base/Roles/TellerWithYieldStreaming.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {AccountantWithYieldStreaming} from "src/base/Roles/AccountantWithYieldStreaming.sol";
import {IncentivePool} from "src/base/IncentivePool.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MessageHashUtils} from "@openzeppelin-contracts-5.3.0/utils/cryptography/MessageHashUtils.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract MockERC20Positive is ERC20 {
    constructor(string memory name, string memory symbol, uint8 decimals_) ERC20(name, symbol, decimals_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @dev Abstract base containing all positive reward routing tests.
abstract contract RewardRoutingPositiveBase is Test {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    BoringVault public boringVault;
    TellerWithYieldStreaming public teller;
    AccountantWithYieldStreaming public accountant;
    RolesAuthority public rolesAuthority;
    IncentivePool public pool;
    MockERC20Positive public usdc;
    ERC20 public rewardToken;

    uint8 public constant ADMIN_ROLE = 1;
    uint8 public constant MINTER_ROLE = 7;
    uint8 public constant BURNER_ROLE = 8;
    uint8 public constant UPDATE_EXCHANGE_RATE_ROLE = 3;
    uint8 public constant TELLER_ROLE = 12;

    address public payout_address = vm.addr(7777777);
    address public user = vm.addr(100);
    address public user2 = vm.addr(101);

    uint256 internal signerPrivateKey = 0xA11CE;
    address internal signer;

    uint256 internal rewardUnit;

    function _baseSetUp() internal {
        vm.warp(1_700_000_000);
        signer = vm.addr(signerPrivateKey);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", usdc.decimals());
        accountant = new AccountantWithYieldStreaming(
            address(this),
            address(boringVault),
            payout_address,
            uint96(10 ** usdc.decimals()),
            address(usdc),
            1.001e4,
            0.999e4,
            1,
            0,
            0
        );
        teller = new TellerWithYieldStreaming(address(this), address(boringVault), address(accountant), address(usdc));

        pool = new IncentivePool(address(this), rewardToken);

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);
        accountant.setAuthority(rolesAuthority);
        teller.setAuthority(rolesAuthority);
        pool.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(MINTER_ROLE, address(boringVault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(boringVault), BoringVault.exit.selector, true);
        rolesAuthority.setRoleCapability(
            MINTER_ROLE, address(accountant), AccountantWithYieldStreaming.setFirstDepositTimestamp.selector, true
        );
        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);

        rolesAuthority.setRoleCapability(
            UPDATE_EXCHANGE_RATE_ROLE,
            address(accountant),
            AccountantWithRateProviders.updateExchangeRate.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            UPDATE_EXCHANGE_RATE_ROLE, address(accountant), bytes4(keccak256("updateExchangeRate()")), true
        );
        rolesAuthority.setUserRole(address(teller), UPDATE_EXCHANGE_RATE_ROLE, true);

        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.deposit.selector, true);
        rolesAuthority.setPublicCapability(address(teller), TellerWithYieldStreaming.withdraw.selector, true);
        rolesAuthority.setPublicCapability(address(teller), TellerWithYieldStreaming.withdrawWithRewards.selector, true);
        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.claimRewards.selector, true);

        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);

        rolesAuthority.setRoleCapability(TELLER_ROLE, address(pool), IncentivePool.processRewards.selector, true);
        rolesAuthority.setUserRole(address(teller), TELLER_ROLE, true);

        pool.setRewardSigner(signer);
        pool.setMaximumRewardAmountPerClaim(uint96(1_000 * rewardUnit));
        pool.setMaxDeadline(1 days);
        pool.setTotalRewardCap(uint104(1_000_000 * rewardUnit));
        MockERC20Positive(address(rewardToken)).mint(address(pool), 1_000_000 * rewardUnit);

        teller.updateAssetData(ERC20(address(usdc)), true, true, 0);
    }

    // ========================= claimRewards: single claim =========================

    function test_claimRewards_singleClaim_correctPayout() external {
        uint256 amount = 100 * rewardUnit;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(address(pool), user, amount, deadline);

        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(pool), amount, deadline, sig);

        uint256 balBefore = rewardToken.balanceOf(user);

        vm.prank(user);
        teller.claimRewards(rewards);

        assertEq(rewardToken.balanceOf(user) - balBefore, amount);
    }

    function test_claimRewards_poolBalanceDecreased() external {
        uint256 amount = 100 * rewardUnit;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(address(pool), user, amount, deadline);

        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(pool), amount, deadline, sig);

        uint256 poolBalBefore = rewardToken.balanceOf(address(pool));

        vm.prank(user);
        teller.claimRewards(rewards);

        assertEq(poolBalBefore - rewardToken.balanceOf(address(pool)), amount);
    }

    function test_claimRewards_emptyRewardsIsNoop() external {
        RewardData[] memory rewards = new RewardData[](0);

        vm.prank(user);
        teller.claimRewards(rewards);

        assertEq(rewardToken.balanceOf(user), 0);
    }

    // ========================= claimRewards: incremental claims =========================

    function test_claimRewards_incrementalClaims_deltaCorrect() external {
        uint256 deadline = block.timestamp + 1 hours;

        // First claim: cumulative 100
        bytes memory sig1 = _sign(address(pool), user, 100 * rewardUnit, deadline);
        RewardData[] memory r1 = new RewardData[](1);
        r1[0] = RewardData(address(pool), 100 * rewardUnit, deadline, sig1);
        vm.prank(user);
        teller.claimRewards(r1);
        assertEq(rewardToken.balanceOf(user), 100 * rewardUnit);

        // Second claim: cumulative 250 -> delta of 150
        bytes memory sig2 = _sign(address(pool), user, 250 * rewardUnit, deadline);
        RewardData[] memory r2 = new RewardData[](1);
        r2[0] = RewardData(address(pool), 250 * rewardUnit, deadline, sig2);
        vm.prank(user);
        teller.claimRewards(r2);
        assertEq(rewardToken.balanceOf(user), 250 * rewardUnit);

        // Third claim: cumulative 400 -> delta of 150
        bytes memory sig3 = _sign(address(pool), user, 400 * rewardUnit, deadline);
        RewardData[] memory r3 = new RewardData[](1);
        r3[0] = RewardData(address(pool), 400 * rewardUnit, deadline, sig3);
        vm.prank(user);
        teller.claimRewards(r3);
        assertEq(rewardToken.balanceOf(user), 400 * rewardUnit);
    }

    function test_claimRewards_checkpointHistoryTracked() external {
        uint256 deadline = block.timestamp + 1 hours;

        bytes memory sig1 = _sign(address(pool), user, 100 * rewardUnit, deadline);
        RewardData[] memory r1 = new RewardData[](1);
        r1[0] = RewardData(address(pool), 100 * rewardUnit, deadline, sig1);
        vm.prank(user);
        teller.claimRewards(r1);

        bytes memory sig2 = _sign(address(pool), user, 300 * rewardUnit, deadline);
        RewardData[] memory r2 = new RewardData[](1);
        r2[0] = RewardData(address(pool), 300 * rewardUnit, deadline, sig2);
        vm.prank(user);
        teller.claimRewards(r2);

        assertEq(pool.getTotalClaimedAmount(user), 300 * rewardUnit);
        assertEq(pool.getLastClaimTimestamp(user), block.timestamp);

        IncentivePool.ClaimCheckpoint[] memory history = pool.getClaimHistory(user);
        assertEq(history.length, 2);
        assertEq(history[0].cumulativeClaimed, 100 * rewardUnit);
        assertEq(history[1].cumulativeClaimed, 300 * rewardUnit);
    }

    // ========================= claimRewards: multiple pools =========================

    function test_claimRewards_multiplePools_bothPaid() external {
        IncentivePool pool2 = _createAndEnablePool(rewardToken);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig1 = _sign(address(pool), user, 100 * rewardUnit, deadline);
        bytes memory sig2 = _sign(address(pool2), user, 200 * rewardUnit, deadline);

        RewardData[] memory rewards = new RewardData[](2);
        rewards[0] = RewardData(address(pool), 100 * rewardUnit, deadline, sig1);
        rewards[1] = RewardData(address(pool2), 200 * rewardUnit, deadline, sig2);

        vm.prank(user);
        teller.claimRewards(rewards);

        assertEq(rewardToken.balanceOf(user), 300 * rewardUnit);
        assertEq(pool.getTotalClaimedAmount(user), 100 * rewardUnit);
        assertEq(pool2.getTotalClaimedAmount(user), 200 * rewardUnit);
    }

    // ========================= claimRewards: multiple users =========================

    function test_claimRewards_multipleUsers_independentBalances() external {
        uint256 deadline = block.timestamp + 1 hours;

        bytes memory sig1 = _sign(address(pool), user, 100 * rewardUnit, deadline);
        RewardData[] memory r1 = new RewardData[](1);
        r1[0] = RewardData(address(pool), 100 * rewardUnit, deadline, sig1);
        vm.prank(user);
        teller.claimRewards(r1);

        bytes memory sig2 = _sign(address(pool), user2, 200 * rewardUnit, deadline);
        RewardData[] memory r2 = new RewardData[](1);
        r2[0] = RewardData(address(pool), 200 * rewardUnit, deadline, sig2);
        vm.prank(user2);
        teller.claimRewards(r2);

        assertEq(rewardToken.balanceOf(user), 100 * rewardUnit);
        assertEq(rewardToken.balanceOf(user2), 200 * rewardUnit);
        assertEq(pool.getTotalClaimedAmount(user), 100 * rewardUnit);
        assertEq(pool.getTotalClaimedAmount(user2), 200 * rewardUnit);
    }

    // ========================= claimRewards: per-claim cap =========================

    function test_claimRewards_perClaimCap_multipleClaimsToExhaust() external {
        pool.setMaximumRewardAmountPerClaim(uint96(50 * rewardUnit));

        uint256 deadline = block.timestamp + 1 hours;

        // First: cumulative 200, capped to 50
        bytes memory sig1 = _sign(address(pool), user, 200 * rewardUnit, deadline);
        RewardData[] memory r1 = new RewardData[](1);
        r1[0] = RewardData(address(pool), 200 * rewardUnit, deadline, sig1);
        vm.prank(user);
        teller.claimRewards(r1);
        assertEq(rewardToken.balanceOf(user), 50 * rewardUnit);

        // Second: same sig, cumulative still 200, delta now 150 -> capped to 50
        vm.prank(user);
        teller.claimRewards(r1);
        assertEq(rewardToken.balanceOf(user), 100 * rewardUnit);

        // Third: delta 100 -> capped to 50
        vm.prank(user);
        teller.claimRewards(r1);
        assertEq(rewardToken.balanceOf(user), 150 * rewardUnit);

        // Fourth: delta 50 -> exactly 50, fits
        vm.prank(user);
        teller.claimRewards(r1);
        assertEq(rewardToken.balanceOf(user), 200 * rewardUnit);
    }

    // ========================= withdrawWithRewards =========================

    function test_withdrawWithRewards_correctPayouts() external {
        uint256 shares = _depositForUser(user, 10_000e6);

        uint256 rewardAmount = 50 * rewardUnit;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(address(pool), user, rewardAmount, deadline);

        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(pool), rewardAmount, deadline, sig);

        uint256 usdcBalBefore = usdc.balanceOf(user);
        uint256 rewardBalBefore = rewardToken.balanceOf(user);

        vm.prank(user);
        uint256 assetsOut = teller.withdrawWithRewards(ERC20(address(usdc)), shares, 0, user, rewards);

        assertGt(assetsOut, 0);
        assertEq(boringVault.balanceOf(user), 0); // all shares burned

        if (address(rewardToken) == address(usdc)) {
            assertEq(usdc.balanceOf(user) - usdcBalBefore, assetsOut + rewardAmount);
        } else {
            assertEq(usdc.balanceOf(user) - usdcBalBefore, assetsOut);
            assertEq(rewardToken.balanceOf(user) - rewardBalBefore, rewardAmount);
        }
    }

    function test_withdrawWithRewards_emptyRewards_stillWithdraws() external {
        uint256 shares = _depositForUser(user, 1_000e6);

        RewardData[] memory rewards = new RewardData[](0);

        vm.prank(user);
        uint256 assetsOut = teller.withdrawWithRewards(ERC20(address(usdc)), shares, 0, user, rewards);

        assertGt(assetsOut, 0);
        assertGt(usdc.balanceOf(user), 0);
        assertEq(boringVault.balanceOf(user), 0);
    }

    function test_withdrawWithRewards_partialShareBurn_correctBalances() external {
        uint256 shares = _depositForUser(user, 10_000e6);
        uint256 halfShares = shares / 2;

        uint256 rewardAmount = 25 * rewardUnit;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(address(pool), user, rewardAmount, deadline);
        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(pool), rewardAmount, deadline, sig);

        vm.prank(user);
        uint256 assetsOut = teller.withdrawWithRewards(ERC20(address(usdc)), halfShares, 0, user, rewards);

        assertGt(assetsOut, 0);
        assertEq(boringVault.balanceOf(user), shares - halfShares);
        assertEq(pool.getTotalClaimedAmount(user), rewardAmount);
    }

    function test_withdrawWithRewards_multiplePools() external {
        uint256 shares = _depositForUser(user, 5_000e6);

        IncentivePool pool2 = _createAndEnablePool(rewardToken);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig1 = _sign(address(pool), user, 100 * rewardUnit, deadline);
        bytes memory sig2 = _sign(address(pool2), user, 75 * rewardUnit, deadline);

        RewardData[] memory rewards = new RewardData[](2);
        rewards[0] = RewardData(address(pool), 100 * rewardUnit, deadline, sig1);
        rewards[1] = RewardData(address(pool2), 75 * rewardUnit, deadline, sig2);

        uint256 usdcBalBefore = usdc.balanceOf(user);
        uint256 rewardBalBefore = rewardToken.balanceOf(user);

        vm.prank(user);
        uint256 assetsOut = teller.withdrawWithRewards(ERC20(address(usdc)), shares, 0, user, rewards);

        assertGt(assetsOut, 0);
        uint256 totalRewards = 175 * rewardUnit;

        if (address(rewardToken) == address(usdc)) {
            assertEq(usdc.balanceOf(user) - usdcBalBefore, assetsOut + totalRewards);
        } else {
            assertEq(usdc.balanceOf(user) - usdcBalBefore, assetsOut);
            assertEq(rewardToken.balanceOf(user) - rewardBalBefore, totalRewards);
        }

        assertEq(pool.getTotalClaimedAmount(user), 100 * rewardUnit);
        assertEq(pool2.getTotalClaimedAmount(user), 75 * rewardUnit);
    }

    // ========================= deposit -> claim -> withdraw lifecycle =========================

    function test_fullLifecycle_depositClaimWithdraw() external {
        // 1. Deposit
        uint256 shares = _depositForUser(user, 5_000e6);
        assertEq(boringVault.balanceOf(user), shares);

        // 2. Claim rewards (standalone)
        uint256 rewardAmount = 200 * rewardUnit;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(address(pool), user, rewardAmount, deadline);
        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(pool), rewardAmount, deadline, sig);

        vm.prank(user);
        teller.claimRewards(rewards);
        assertEq(pool.getTotalClaimedAmount(user), rewardAmount);

        // 3. Withdraw (no additional rewards)
        uint256 balBefore = usdc.balanceOf(user);
        RewardData[] memory empty = new RewardData[](0);
        vm.prank(user);
        uint256 assetsOut = teller.withdrawWithRewards(ERC20(address(usdc)), shares, 0, user, empty);

        assertGt(assetsOut, 0);
        assertEq(boringVault.balanceOf(user), 0);
        assertEq(usdc.balanceOf(user) - balBefore, assetsOut);
        // Pool state unchanged from step 2
        assertEq(pool.getTotalClaimedAmount(user), rewardAmount);
    }

    function test_fullLifecycle_depositThenWithdrawWithRewards() external {
        // 1. Deposit
        uint256 shares = _depositForUser(user, 5_000e6);

        // 2. Withdraw + claim in one tx
        uint256 rewardAmount = 150 * rewardUnit;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(address(pool), user, rewardAmount, deadline);
        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(pool), rewardAmount, deadline, sig);

        uint256 usdcBefore = usdc.balanceOf(user);
        uint256 rewardBefore = rewardToken.balanceOf(user);

        vm.prank(user);
        uint256 assetsOut = teller.withdrawWithRewards(ERC20(address(usdc)), shares, 0, user, rewards);

        assertGt(assetsOut, 0);
        assertEq(boringVault.balanceOf(user), 0);

        if (address(rewardToken) == address(usdc)) {
            assertEq(usdc.balanceOf(user) - usdcBefore, assetsOut + rewardAmount);
        } else {
            assertEq(usdc.balanceOf(user) - usdcBefore, assetsOut);
            assertEq(rewardToken.balanceOf(user) - rewardBefore, rewardAmount);
        }
    }

    // ========================= rate limiting positive path =========================

    function test_claimRewards_respectsRateLimitThenSucceeds() external {
        pool.setSecondsBetweenClaims(1 hours);

        uint256 deadline = block.timestamp + 3 hours;

        // First claim
        bytes memory sig1 = _sign(address(pool), user, 100 * rewardUnit, deadline);
        RewardData[] memory r1 = new RewardData[](1);
        r1[0] = RewardData(address(pool), 100 * rewardUnit, deadline, sig1);
        vm.prank(user);
        teller.claimRewards(r1);

        // Warp past cooldown
        vm.warp(block.timestamp + 1 hours);

        // Second claim succeeds
        bytes memory sig2 = _sign(address(pool), user, 300 * rewardUnit, deadline);
        RewardData[] memory r2 = new RewardData[](1);
        r2[0] = RewardData(address(pool), 300 * rewardUnit, deadline, sig2);
        vm.prank(user);
        teller.claimRewards(r2);

        assertEq(rewardToken.balanceOf(user), 300 * rewardUnit);
    }

    // ========================= unblacklist positive path =========================

    function test_claimRewards_unblacklistedUserCanClaim() external {
        pool.setBlacklisted(user, true);
        pool.setBlacklisted(user, false);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(address(pool), user, 100 * rewardUnit, deadline);
        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(pool), 100 * rewardUnit, deadline, sig);

        vm.prank(user);
        teller.claimRewards(rewards);

        assertEq(rewardToken.balanceOf(user), 100 * rewardUnit);
    }

    // ========================= signer rotation positive path =========================

    function test_claimRewards_newSignerWorksAfterRotation() external {
        uint256 newSignerKey = 0xBEEF;
        address newSigner = vm.addr(newSignerKey);
        pool.setRewardSigner(newSigner);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _signWithKey(newSignerKey, address(pool), user, 100 * rewardUnit, deadline);
        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(pool), 100 * rewardUnit, deadline, sig);

        vm.prank(user);
        teller.claimRewards(rewards);

        assertEq(rewardToken.balanceOf(user), 100 * rewardUnit);
    }

    // ========================= cap raised =========================

    function test_claimRewards_capRaisedAllowsMoreClaims() external {
        pool.setTotalRewardCap(uint104(100 * rewardUnit));

        uint256 deadline = block.timestamp + 1 hours;

        // Claim up to cap
        bytes memory sig1 = _sign(address(pool), user, 100 * rewardUnit, deadline);
        RewardData[] memory r1 = new RewardData[](1);
        r1[0] = RewardData(address(pool), 100 * rewardUnit, deadline, sig1);
        vm.prank(user);
        teller.claimRewards(r1);
        assertEq(rewardToken.balanceOf(user), 100 * rewardUnit);

        // Raise cap
        pool.setTotalRewardCap(uint104(500 * rewardUnit));

        // Now can claim more
        bytes memory sig2 = _sign(address(pool), user, 300 * rewardUnit, deadline);
        RewardData[] memory r2 = new RewardData[](1);
        r2[0] = RewardData(address(pool), 300 * rewardUnit, deadline, sig2);
        vm.prank(user);
        teller.claimRewards(r2);
        assertEq(rewardToken.balanceOf(user), 300 * rewardUnit);
    }

    // ========================= deadline boundary =========================

    function test_claimRewards_deadlineAtExactBoundary() external {
        // Exactly at block.timestamp + maxDeadline (1 day)
        uint256 deadline = block.timestamp + 1 days;
        bytes memory sig = _sign(address(pool), user, 100 * rewardUnit, deadline);
        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(pool), 100 * rewardUnit, deadline, sig);

        vm.prank(user);
        teller.claimRewards(rewards);

        assertEq(rewardToken.balanceOf(user), 100 * rewardUnit);
    }

    function test_claimRewards_deadlineAtExactTimestamp() external {
        // deadline == block.timestamp (not expired yet, and within maxDeadline)
        uint256 deadline = block.timestamp;
        bytes memory sig = _sign(address(pool), user, 100 * rewardUnit, deadline);
        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(pool), 100 * rewardUnit, deadline, sig);

        vm.prank(user);
        teller.claimRewards(rewards);

        assertEq(rewardToken.balanceOf(user), 100 * rewardUnit);
    }

    // ========================= HELPERS =========================

    function _depositForUser(address depositor, uint256 amount) internal returns (uint256 shares) {
        usdc.mint(depositor, amount);
        vm.startPrank(depositor);
        ERC20(address(usdc)).safeApprove(address(boringVault), amount);
        shares = teller.deposit(DepositParams(ERC20(address(usdc)), amount, 0), address(0), ComplianceData(0, ""));
        vm.stopPrank();
    }

    function _createPool(ERC20 token) internal returns (IncentivePool p) {
        p = new IncentivePool(address(this), token);
        p.setAuthority(rolesAuthority);
        rolesAuthority.setRoleCapability(TELLER_ROLE, address(p), IncentivePool.processRewards.selector, true);
        p.setRewardSigner(signer);
        p.setMaximumRewardAmountPerClaim(uint96(1_000 * rewardUnit));
        p.setMaxDeadline(1 days);
        p.setTotalRewardCap(uint104(1_000_000 * rewardUnit));
        MockERC20Positive(address(token)).mint(address(p), 1_000_000 * rewardUnit);
    }

    function _createAndEnablePool(ERC20 token) internal returns (IncentivePool p) {
        p = _createPool(token);
    }

    function _sign(address poolAddr, address recipient, uint256 cumulativeOwed, uint256 deadline)
        internal
        view
        returns (bytes memory)
    {
        return _signWithKey(signerPrivateKey, poolAddr, recipient, cumulativeOwed, deadline);
    }

    function _signWithKey(
        uint256 privateKey,
        address poolAddr,
        address recipient,
        uint256 cumulativeOwed,
        uint256 deadline
    ) internal view returns (bytes memory) {
        bytes32 messageHash = keccak256(abi.encode(poolAddr, block.chainid, recipient, cumulativeOwed, deadline));
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSignedHash);
        return abi.encodePacked(r, s, v);
    }
}

// ========================= CONCRETE: incentive token = USDC (same as base, 6 decimals) =========================

contract RewardRouting_SameTokenTest is RewardRoutingPositiveBase {
    function setUp() external {
        rewardUnit = 1e6;
        usdc = new MockERC20Positive("USD Coin", "USDC", 6);
        rewardToken = ERC20(address(usdc));
        _baseSetUp();
    }
}

// ========================= CONCRETE: incentive token = separate 18-decimal token =========================

contract RewardRouting_DifferentTokenTest is RewardRoutingPositiveBase {
    function setUp() external {
        rewardUnit = 1e18;
        usdc = new MockERC20Positive("USD Coin", "USDC", 6);
        rewardToken = ERC20(address(new MockERC20Positive("Reward Token", "RWD", 18)));
        _baseSetUp();
    }
}
