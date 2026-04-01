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
import {TellerWithMultiAssetSupportLib} from "src/base/Roles/TellerWithMultiAssetSupportLib.sol";
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

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol, uint8 decimals_) ERC20(name, symbol, decimals_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @dev Abstract base containing all negative tests. Concrete contracts configure the reward token.
abstract contract RewardRoutingNegativeBase is Test {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    BoringVault public boringVault;
    TellerWithYieldStreaming public teller;
    AccountantWithYieldStreaming public accountant;
    RolesAuthority public rolesAuthority;
    IncentivePool public pool;
    MockERC20 public usdc;
    ERC20 public rewardToken; // set by concrete setUp

    uint8 public constant ADMIN_ROLE = 1;
    uint8 public constant MINTER_ROLE = 7;
    uint8 public constant BURNER_ROLE = 8;
    uint8 public constant UPDATE_EXCHANGE_RATE_ROLE = 3;
    uint8 public constant TELLER_ROLE = 12;

    address public payout_address = vm.addr(7777777);
    address public user = vm.addr(100);
    address public attacker = vm.addr(200);

    uint256 internal signerPrivateKey = 0xA11CE;
    address internal signer;

    /// @dev 1 "unit" of the reward token, accounting for its decimals
    uint256 internal rewardUnit;

    /// @dev Concrete tests set usdc, rewardToken, and rewardUnit, then call this
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

        pool = new IncentivePool(address(this), rewardToken, 1 days);

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

        teller.setIncentivePoolAllowed(address(pool), true);

        pool.setRewardSigner(signer);
        pool.setMaximumRewardAmountPerClaim(uint96(1_000 * rewardUnit));
        pool.setMaxDeadline(1 days);
        MockERC20(address(rewardToken)).mint(address(pool), 1_000_000 * rewardUnit);

        teller.updateAssetData(ERC20(address(usdc)), true, true, 0);
    }

    // ========================= SIGNATURE REPLAY =========================

    function test_claimRewards_signatureReplay_noOpNothingToClaim() external {
        uint256 cumulativeOwed = 100 * rewardUnit;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(address(pool), user, cumulativeOwed, deadline);

        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(pool), cumulativeOwed, deadline, sig);

        vm.prank(user);
        teller.claimRewards(rewards);

        uint256 balanceAfterFirst = rewardToken.balanceOf(user);

        // Second call is a no-op: succeeds but transfers nothing
        vm.prank(user);
        teller.claimRewards(rewards);

        assertEq(rewardToken.balanceOf(user), balanceAfterFirst);
    }

    function test_claimRewards_lowerCumulative_noOpNothingToClaim() external {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig1 = _sign(address(pool), user, 200 * rewardUnit, deadline);
        RewardData[] memory r1 = new RewardData[](1);
        r1[0] = RewardData(address(pool), 200 * rewardUnit, deadline, sig1);

        vm.prank(user);
        teller.claimRewards(r1);

        uint256 balanceAfterFirst = rewardToken.balanceOf(user);

        pool.setSecondsBetweenClaims(0);
        bytes memory sig2 = _sign(address(pool), user, 100 * rewardUnit, deadline);
        RewardData[] memory r2 = new RewardData[](1);
        r2[0] = RewardData(address(pool), 100 * rewardUnit, deadline, sig2);

        // Lower cumulative is a no-op: succeeds but transfers nothing
        vm.prank(user);
        teller.claimRewards(r2);

        assertEq(rewardToken.balanceOf(user), balanceAfterFirst);
    }

    // ========================= CROSS-USER SIGNATURE THEFT =========================

    function test_claimRewards_stolenSignature_noOp() external {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(address(pool), user, 100 * rewardUnit, deadline);

        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(pool), 100 * rewardUnit, deadline, sig);

        // No-op: returns 0 instead of reverting when signature is invalid
        vm.prank(attacker);
        teller.claimRewards(rewards);

        assertEq(rewardToken.balanceOf(attacker), 0);
    }

    // ========================= CROSS-POOL SIGNATURE REUSE =========================

    function test_claimRewards_crossPoolSignatureReuse_noOp() external {
        IncentivePool pool2 = _createAndEnablePool(rewardToken);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(address(pool), user, 100 * rewardUnit, deadline);

        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(pool2), 100 * rewardUnit, deadline, sig);

        // No-op: returns 0 instead of reverting when signature is invalid
        vm.prank(user);
        teller.claimRewards(rewards);

        assertEq(rewardToken.balanceOf(user), 0);
    }

    // ========================= DUPLICATE POOL IN SINGLE TX =========================

    function test_claimRewards_duplicatePoolInArray_noOpNothingToClaim() external {
        uint256 cumulativeOwed = 100 * rewardUnit;
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(address(pool), user, cumulativeOwed, deadline);

        RewardData[] memory rewards = new RewardData[](2);
        rewards[0] = RewardData(address(pool), cumulativeOwed, deadline, sig);
        rewards[1] = RewardData(address(pool), cumulativeOwed, deadline, sig);

        // Duplicate pool entry is a no-op for the second entry: succeeds, only pays once
        vm.prank(user);
        teller.claimRewards(rewards);

        assertEq(rewardToken.balanceOf(user), cumulativeOwed);
    }

    // ========================= RATE LIMITING THROUGH TELLER =========================

    function test_claimRewards_rateLimited_noOp() external {
        pool.setSecondsBetweenClaims(1 hours);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig1 = _sign(address(pool), user, 100 * rewardUnit, deadline);

        RewardData[] memory r1 = new RewardData[](1);
        r1[0] = RewardData(address(pool), 100 * rewardUnit, deadline, sig1);

        vm.prank(user);
        teller.claimRewards(r1);

        uint256 balanceAfterFirst = rewardToken.balanceOf(user);

        bytes memory sig2 = _sign(address(pool), user, 200 * rewardUnit, deadline);
        RewardData[] memory r2 = new RewardData[](1);
        r2[0] = RewardData(address(pool), 200 * rewardUnit, deadline, sig2);

        // No-op: returns 0 instead of reverting when rate limit exceeded
        vm.prank(user);
        teller.claimRewards(r2);

        assertEq(rewardToken.balanceOf(user), balanceAfterFirst);
    }

    function test_claimRewards_rateLimitBoundary_succeedsAfterCooldown() external {
        pool.setSecondsBetweenClaims(1 hours);

        uint256 deadline = block.timestamp + 2 hours;
        bytes memory sig1 = _sign(address(pool), user, 100 * rewardUnit, deadline);
        RewardData[] memory r1 = new RewardData[](1);
        r1[0] = RewardData(address(pool), 100 * rewardUnit, deadline, sig1);

        vm.prank(user);
        teller.claimRewards(r1);

        vm.warp(block.timestamp + 1 hours);

        bytes memory sig2 = _sign(address(pool), user, 200 * rewardUnit, deadline);
        RewardData[] memory r2 = new RewardData[](1);
        r2[0] = RewardData(address(pool), 200 * rewardUnit, deadline, sig2);

        vm.prank(user);
        teller.claimRewards(r2);

        assertEq(rewardToken.balanceOf(user), 200 * rewardUnit);
    }

    // ========================= EXPIRED / FUTURE DEADLINES =========================

    function test_claimRewards_expiredDeadline_noOp() external {
        uint256 expiredDeadline = block.timestamp - 1;
        bytes memory sig = _sign(address(pool), user, 100 * rewardUnit, expiredDeadline);
        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(pool), 100 * rewardUnit, expiredDeadline, sig);

        // No-op: returns 0 instead of reverting when deadline has expired
        vm.prank(user);
        teller.claimRewards(rewards);

        assertEq(rewardToken.balanceOf(user), 0);
    }

    function test_claimRewards_deadlineTooFarInFuture_noOp() external {
        uint256 farDeadline = block.timestamp + 2 days;
        bytes memory sig = _sign(address(pool), user, 100 * rewardUnit, farDeadline);
        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(pool), 100 * rewardUnit, farDeadline, sig);

        // No-op: returns 0 instead of reverting when deadline is too far in the future
        vm.prank(user);
        teller.claimRewards(rewards);

        assertEq(rewardToken.balanceOf(user), 0);
    }

    // ========================= REWARDS DISABLED =========================

    function test_claimRewards_rewardsDisabledZeroMaxPerClaim_noOp() external {
        pool.setMaximumRewardAmountPerClaim(0);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(address(pool), user, 100 * rewardUnit, deadline);
        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(pool), 100 * rewardUnit, deadline, sig);

        // No-op: returns 0 instead of reverting when rewards are disabled
        vm.prank(user);
        teller.claimRewards(rewards);

        assertEq(rewardToken.balanceOf(user), 0);
    }

    // ========================= PER-CLAIM CAP =========================

    function test_claimRewards_perClaimCap_clampsToMax() external {
        pool.setMaximumRewardAmountPerClaim(uint96(50 * rewardUnit));

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(address(pool), user, 200 * rewardUnit, deadline);
        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(pool), 200 * rewardUnit, deadline, sig);

        vm.prank(user);
        teller.claimRewards(rewards);

        assertEq(rewardToken.balanceOf(user), 50 * rewardUnit);
    }

    // ========================= POOL INSUFFICIENT BALANCE =========================

    function test_claimRewards_poolInsufficientBalance_reverts() external {
        IncentivePool poorPool = new IncentivePool(address(this), rewardToken, 1 days);
        poorPool.setAuthority(rolesAuthority);
        rolesAuthority.setRoleCapability(TELLER_ROLE, address(poorPool), IncentivePool.processRewards.selector, true);
        teller.setIncentivePoolAllowed(address(poorPool), true);
        poorPool.setRewardSigner(signer);
        poorPool.setMaximumRewardAmountPerClaim(uint96(1_000 * rewardUnit));
        poorPool.setMaxDeadline(1 days);
        MockERC20(address(rewardToken)).mint(address(poorPool), 10 * rewardUnit);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(address(poorPool), user, 100 * rewardUnit, deadline);
        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(poorPool), 100 * rewardUnit, deadline, sig);

        vm.prank(user);
        vm.expectRevert("TRANSFER_FAILED");
        teller.claimRewards(rewards);
    }

    // ========================= ATOMICITY: withdrawWithRewards =========================

    function test_withdrawWithRewards_withdrawFailure_neverReachesRewards() external {
        uint256 shares = _depositForUser(user, 1_000e6);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(address(pool), user, 100 * rewardUnit, deadline);
        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(pool), 100 * rewardUnit, deadline, sig);

        vm.prank(user);
        vm.expectRevert(stdError.arithmeticError);
        teller.withdrawWithRewards(ERC20(address(usdc)), shares + 1, 0, user, rewards);

        assertEq(rewardToken.balanceOf(user), 0);
    }

    function test_withdrawWithRewards_pausedTeller_revertsBeforeRewards() external {
        uint256 shares = _depositForUser(user, 1_000e6);
        teller.pause();

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(address(pool), user, 100 * rewardUnit, deadline);
        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(pool), 100 * rewardUnit, deadline, sig);

        vm.prank(user);
        vm.expectRevert(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__Paused.selector);
        teller.withdrawWithRewards(ERC20(address(usdc)), shares, 0, user, rewards);

        assertEq(rewardToken.balanceOf(user), 0);
        assertEq(boringVault.balanceOf(user), shares);
    }

    // ========================= DENY LIST + REWARDS =========================

    function test_withdrawWithRewards_deniedUser_revertsBeforeRewards() external {
        uint256 shares = _depositForUser(user, 1_000e6);
        teller.denyAll(user);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(address(pool), user, 100 * rewardUnit, deadline);
        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(pool), 100 * rewardUnit, deadline, sig);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__TransferDenied.selector, user, address(0), user
            )
        );
        teller.withdrawWithRewards(ERC20(address(usdc)), shares, 0, user, rewards);

        assertEq(rewardToken.balanceOf(user), 0);
    }

    // ========================= SHARE LOCK + REWARDS =========================

    function test_withdrawWithRewards_sharesLocked_revertsBeforeRewards() external {
        teller.setShareLockPeriod(1 hours);
        uint256 shares = _depositForUser(user, 1_000e6);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(address(pool), user, 100 * rewardUnit, deadline);
        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(pool), 100 * rewardUnit, deadline, sig);

        vm.prank(user);
        vm.expectRevert(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__SharesAreLocked.selector);
        teller.withdrawWithRewards(ERC20(address(usdc)), shares, 0, user, rewards);

        assertEq(rewardToken.balanceOf(user), 0);
    }

    // ========================= POOL RE-ENABLE =========================

    function test_claimRewards_tellerReAuthorized_succeeds() external {
        rolesAuthority.setRoleCapability(TELLER_ROLE, address(pool), IncentivePool.processRewards.selector, false);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(address(pool), user, 100 * rewardUnit, deadline);
        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(pool), 100 * rewardUnit, deadline, sig);

        vm.prank(user);
        vm.expectRevert("UNAUTHORIZED");
        teller.claimRewards(rewards);

        rolesAuthority.setRoleCapability(TELLER_ROLE, address(pool), IncentivePool.processRewards.selector, true);

        vm.prank(user);
        teller.claimRewards(rewards);

        assertEq(rewardToken.balanceOf(user), 100 * rewardUnit);
    }

    // ========================= ZERO AMOUNT CLAIM =========================

    function test_claimRewards_zeroCumulativeOwed_noOpNothingToClaim() external {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(address(pool), user, 0, deadline);
        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(pool), 0, deadline, sig);

        // Zero cumulative is a no-op: succeeds but transfers nothing
        vm.prank(user);
        teller.claimRewards(rewards);

        assertEq(rewardToken.balanceOf(user), 0);
    }

    // ========================= NON-CONTRACT ENABLED AS POOL =========================

    function test_claimRewards_nonContractPool_reverts() external {
        address eoa = vm.addr(999);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _sign(eoa, user, 100 * rewardUnit, deadline);
        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(eoa, 100 * rewardUnit, deadline, sig);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupportLib.TellerWithMultiAssetSupport__IncentivePoolNotAllowed.selector, eoa
            )
        );
        teller.claimRewards(rewards);
    }

    // ========================= MULTI-POOL PARTIAL FAILURE =========================

    function test_claimRewards_secondPoolUnauthorized_revertsEntireTx() external {
        IncentivePool pool2 = _createPool(rewardToken);
        // pool2 is not allowlisted on the teller, so the allowlist check reverts before reaching processRewards.

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig1 = _sign(address(pool), user, 100 * rewardUnit, deadline);
        bytes memory sig2 = _sign(address(pool2), user, 50 * rewardUnit, deadline);

        RewardData[] memory rewards = new RewardData[](2);
        rewards[0] = RewardData(address(pool), 100 * rewardUnit, deadline, sig1);
        rewards[1] = RewardData(address(pool2), 50 * rewardUnit, deadline, sig2);

        vm.prank(user);
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupportLib.TellerWithMultiAssetSupport__IncentivePoolNotAllowed.selector,
                address(pool2)
            )
        );
        teller.claimRewards(rewards);

        assertEq(rewardToken.balanceOf(user), 0);
    }

    function test_claimRewards_firstPoolUnauthorized_revertsEntireTx() external {
        IncentivePool pool2 = _createAndEnablePool(rewardToken);

        rolesAuthority.setRoleCapability(TELLER_ROLE, address(pool), IncentivePool.processRewards.selector, false);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig1 = _sign(address(pool), user, 100 * rewardUnit, deadline);
        bytes memory sig2 = _sign(address(pool2), user, 50 * rewardUnit, deadline);

        RewardData[] memory rewards = new RewardData[](2);
        rewards[0] = RewardData(address(pool), 100 * rewardUnit, deadline, sig1);
        rewards[1] = RewardData(address(pool2), 50 * rewardUnit, deadline, sig2);

        vm.prank(user);
        vm.expectRevert("UNAUTHORIZED");
        teller.claimRewards(rewards);

        assertEq(rewardToken.balanceOf(user), 0);
    }

    // ========================= SIGNER ROTATION =========================

    function test_claimRewards_oldSignerAfterRotation_noOp() external {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory oldSig = _sign(address(pool), user, 100 * rewardUnit, deadline);

        uint256 newSignerKey = 0xBEEF;
        address newSigner = vm.addr(newSignerKey);
        pool.setRewardSigner(newSigner);

        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(pool), 100 * rewardUnit, deadline, oldSig);

        // No-op: returns 0 instead of reverting when signature is invalid
        vm.prank(user);
        teller.claimRewards(rewards);

        assertEq(rewardToken.balanceOf(user), 0);
    }

    // ========================= SAME-TOKEN: withdrawWithRewards balance accounting =========================

    function test_withdrawWithRewards_validClaim_balancesCorrect() external {
        uint256 shares = _depositForUser(user, 10_000e6);

        uint256 deadline = block.timestamp + 1 hours;
        uint256 rewardAmount = 50 * rewardUnit;
        bytes memory sig = _sign(address(pool), user, rewardAmount, deadline);
        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(pool), rewardAmount, deadline, sig);

        uint256 usdcBalBefore = usdc.balanceOf(user);
        uint256 rewardBalBefore = rewardToken.balanceOf(user);

        vm.prank(user);
        uint256 assetsOut = teller.withdrawWithRewards(ERC20(address(usdc)), shares, 0, user, rewards);

        assertGt(assetsOut, 0);

        if (address(rewardToken) == address(usdc)) {
            // Same token: user receives both withdrawal + reward in USDC
            assertEq(usdc.balanceOf(user) - usdcBalBefore, assetsOut + rewardAmount);
        } else {
            // Different tokens: check independently
            assertEq(usdc.balanceOf(user) - usdcBalBefore, assetsOut);
            assertEq(rewardToken.balanceOf(user) - rewardBalBefore, rewardAmount);
        }
    }

    // ========================= HELPERS =========================

    function _depositForUser(address depositor, uint256 amount) internal returns (uint256 shares) {
        usdc.mint(depositor, amount);
        vm.startPrank(depositor);
        ERC20(address(usdc)).safeApprove(address(boringVault), amount);
        shares = teller.deposit(
            DepositParams(ERC20(address(usdc)), amount, 0), depositor, address(0), ComplianceData(0, "")
        );
        vm.stopPrank();
    }

    function _createPool(ERC20 token) internal returns (IncentivePool p) {
        p = new IncentivePool(address(this), token, 1 days);
        p.setAuthority(rolesAuthority);
        rolesAuthority.setRoleCapability(TELLER_ROLE, address(p), IncentivePool.processRewards.selector, true);
        p.setRewardSigner(signer);
        p.setMaximumRewardAmountPerClaim(uint96(1_000 * rewardUnit));
        p.setMaxDeadline(1 days);
        MockERC20(address(token)).mint(address(p), 1_000_000 * rewardUnit);
    }

    function _createAndEnablePool(ERC20 token) internal returns (IncentivePool p) {
        p = _createPool(token);
        teller.setIncentivePoolAllowed(address(p), true);
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

contract RewardRoutingNegative_SameTokenTest is RewardRoutingNegativeBase {
    function setUp() external {
        rewardUnit = 1e6;
        usdc = new MockERC20("USD Coin", "USDC", 6);
        rewardToken = ERC20(address(usdc));
        _baseSetUp();
    }
}

// ========================= CONCRETE: incentive token = separate 18-decimal token =========================

contract RewardRoutingNegative_DifferentTokenTest is RewardRoutingNegativeBase {
    function setUp() external {
        rewardUnit = 1e18;
        usdc = new MockERC20("USD Coin", "USDC", 6);
        rewardToken = ERC20(address(new MockERC20("Reward Token", "RWD", 18)));
        _baseSetUp();
    }
}
