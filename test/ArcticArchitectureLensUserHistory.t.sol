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
import {ArcticArchitectureLens} from "src/helper/ArcticArchitectureLens.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MessageHashUtils} from "@openzeppelin-contracts-5.3.0/utils/cryptography/MessageHashUtils.sol";

import {Test} from "@forge-std/Test.sol";

contract MockWETH_Helper is ERC20 {
    constructor() ERC20("Wrapped Ether", "WETH", 18) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockRewardToken_Helper is ERC20 {
    constructor() ERC20("Reward Token", "RWD", 18) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract ArcticArchitectureLensTest is Test {
    using SafeTransferLib for ERC20;

    MockWETH_Helper public weth;
    MockRewardToken_Helper public rewardToken;
    MockRewardToken_Helper public rewardToken2;
    BoringVault public vault;
    AccountantWithRateProviders public accountant;
    TellerWithMultiAssetSupport public teller;
    IncentivePool public poolA;
    IncentivePool public poolB;
    ArcticArchitectureLens public helper;
    RolesAuthority public roles;

    uint256 internal constant SIGNER_PK = 0xBACE;
    address internal signerAddr;

    address internal user = address(0xBEEF);

    function setUp() public {
        vm.warp(1_000_000);

        weth = new MockWETH_Helper();
        rewardToken = new MockRewardToken_Helper();
        rewardToken2 = new MockRewardToken_Helper();
        vault = new BoringVault(address(this), "Boring Vault", "BV", 18);
        accountant = new AccountantWithRateProviders(
            address(this), address(vault), vm.addr(7777), 1e18, address(weth), 1.001e4, 0.999e4, 1, 0, 0
        );
        teller = new TellerWithMultiAssetSupport(address(this), address(vault), address(accountant), address(weth));

        signerAddr = vm.addr(SIGNER_PK);
        poolA = new IncentivePool(address(this), ERC20(address(rewardToken)), 1 days);
        poolB = new IncentivePool(address(this), ERC20(address(rewardToken2)), 1 days);
        helper = new ArcticArchitectureLens();

        roles = new RolesAuthority(address(this), Authority(address(0)));
        vault.setAuthority(roles);
        accountant.setAuthority(roles);
        teller.setAuthority(roles);
        poolA.setAuthority(roles);
        poolB.setAuthority(roles);

        roles.setRoleCapability(7, address(vault), BoringVault.enter.selector, true);
        roles.setRoleCapability(8, address(vault), BoringVault.exit.selector, true);
        roles.setUserRole(address(teller), 7, true);
        roles.setUserRole(address(teller), 8, true);

        roles.setPublicCapability(address(teller), TellerWithMultiAssetSupport.deposit.selector, true);
        roles.setPublicCapability(address(teller), TellerWithMultiAssetSupport.claimRewards.selector, true);

        roles.setRoleCapability(12, address(poolA), IncentivePool.processRewards.selector, true);
        roles.setRoleCapability(12, address(poolB), IncentivePool.processRewards.selector, true);
        roles.setUserRole(address(teller), 12, true);

        teller.setIncentivePoolAllowed(address(poolA), true);
        teller.setIncentivePoolAllowed(address(poolB), true);

        // Configure pools
        poolA.setRewardSigner(signerAddr);
        poolA.setMaximumRewardAmountPerClaim(type(uint96).max);
        poolA.setMaxDeadline(1 days);

        poolB.setRewardSigner(signerAddr);
        poolB.setMaximumRewardAmountPerClaim(type(uint96).max);
        poolB.setMaxDeadline(1 days);

        rewardToken.mint(address(poolA), type(uint128).max);
        rewardToken2.mint(address(poolB), type(uint128).max);

        teller.updateAssetData(ERC20(address(weth)), true, true, 0);
    }

    // ========================================= HELPERS =========================================

    function _deposit(address depositor, uint256 amount) internal {
        weth.mint(depositor, amount);
        vm.startPrank(depositor);
        ERC20(address(weth)).safeApprove(address(vault), amount);
        teller.deposit(DepositParams(ERC20(address(weth)), amount, 0), depositor, address(0), ComplianceData(0, ""));
        vm.stopPrank();
    }

    function _claimRewards(address claimer, IncentivePool pool, uint256 cumulativeOwed) internal {
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _signReward(address(pool), claimer, cumulativeOwed, deadline);

        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(pool), cumulativeOwed, deadline, sig);

        vm.prank(claimer);
        teller.claimRewards(rewards);
    }

    function _signReward(address pool, address recipient, uint256 cumulativeOwed, uint256 deadline)
        internal
        view
        returns (bytes memory)
    {
        bytes32 messageHash = keccak256(abi.encode(pool, block.chainid, recipient, cumulativeOwed, deadline));
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_PK, ethSignedHash);
        return abi.encodePacked(r, s, v);
    }

    // ========================================= FULL HISTORY TESTS =========================================

    function test_getUserHistory_empty() public view {
        address[] memory pools = new address[](2);
        pools[0] = address(poolA);
        pools[1] = address(poolB);

        ArcticArchitectureLens.UserHistory memory h = helper.getUserHistory(teller, user, pools);

        assertEq(h.principalCheckpoints.length, 0);
        assertEq(h.principalTotalLength, 0);
        assertEq(h.claimHistories.length, 2);
        assertEq(h.claimHistories[0].checkpoints.length, 0);
        assertEq(h.claimHistories[0].totalLength, 0);
        assertEq(h.claimHistories[1].checkpoints.length, 0);
        assertEq(h.claimHistories[1].totalLength, 0);
    }

    function test_getUserHistory_depositsOnly() public {
        _deposit(user, 1e18);
        skip(1 hours);
        _deposit(user, 2e18);

        address[] memory pools = new address[](1);
        pools[0] = address(poolA);

        ArcticArchitectureLens.UserHistory memory h = helper.getUserHistory(teller, user, pools);

        assertEq(h.principalCheckpoints.length, 2);
        assertEq(h.principalTotalLength, 2);
        assertEq(h.principalCheckpoints[0].cumulativeDeposits, 1e18);
        assertEq(h.principalCheckpoints[1].cumulativeDeposits, 3e18);
        assertEq(h.claimHistories[0].checkpoints.length, 0);
    }

    function test_getUserHistory_depositsAndClaims() public {
        _deposit(user, 5e18);

        skip(1 days);
        _claimRewards(user, poolA, 1e17);

        skip(1 days);
        _claimRewards(user, poolB, 2e17);

        address[] memory pools = new address[](2);
        pools[0] = address(poolA);
        pools[1] = address(poolB);

        ArcticArchitectureLens.UserHistory memory h = helper.getUserHistory(teller, user, pools);

        // 1 deposit checkpoint
        assertEq(h.principalCheckpoints.length, 1);
        assertEq(h.principalTotalLength, 1);
        assertEq(h.principalCheckpoints[0].cumulativeDeposits, 5e18);

        // Pool A: 1 claim
        assertEq(h.claimHistories[0].pool, address(poolA));
        assertEq(h.claimHistories[0].checkpoints.length, 1);
        assertEq(h.claimHistories[0].totalLength, 1);
        assertEq(h.claimHistories[0].checkpoints[0].cumulativeClaimed, 1e17);

        // Pool B: 1 claim
        assertEq(h.claimHistories[1].pool, address(poolB));
        assertEq(h.claimHistories[1].checkpoints.length, 1);
        assertEq(h.claimHistories[1].totalLength, 1);
        assertEq(h.claimHistories[1].checkpoints[0].cumulativeClaimed, 2e17);
    }

    function test_getUserHistory_noPools() public {
        _deposit(user, 1e18);

        address[] memory pools = new address[](0);
        ArcticArchitectureLens.UserHistory memory h = helper.getUserHistory(teller, user, pools);

        assertEq(h.principalCheckpoints.length, 1);
        assertEq(h.claimHistories.length, 0);
    }

    // ========================================= PAGINATED HISTORY TESTS =========================================

    function test_getUserHistoryPaginated_slicesPrincipal() public {
        // Create 4 principal checkpoints
        _deposit(user, 1e18);
        skip(1 hours);
        _deposit(user, 2e18);
        skip(1 hours);
        _deposit(user, 3e18);
        skip(1 hours);
        _deposit(user, 4e18);

        address[] memory pools = new address[](0);
        uint256[] memory starts = new uint256[](0);
        uint256[] memory lengths = new uint256[](0);

        // Request 2 checkpoints starting at index 1
        ArcticArchitectureLens.UserHistory memory h = helper.getUserHistory(teller, user, 1, 2, pools, starts, lengths);

        assertEq(h.principalTotalLength, 4);
        assertEq(h.principalCheckpoints.length, 2);
        // Index 1: cumulative deposits = 1e18 + 2e18 = 3e18
        assertEq(h.principalCheckpoints[0].cumulativeDeposits, 3e18);
        // Index 2: cumulative deposits = 1e18 + 2e18 + 3e18 = 6e18
        assertEq(h.principalCheckpoints[1].cumulativeDeposits, 6e18);
    }

    function test_getUserHistoryPaginated_slicesClaims() public {
        _deposit(user, 10e18);

        // Create 3 claim checkpoints on pool A
        skip(1 days);
        _claimRewards(user, poolA, 1e17);
        skip(1 days);
        _claimRewards(user, poolA, 3e17);
        skip(1 days);
        _claimRewards(user, poolA, 6e17);

        address[] memory pools = new address[](1);
        pools[0] = address(poolA);
        uint256[] memory starts = new uint256[](1);
        starts[0] = 1;
        uint256[] memory lengths = new uint256[](1);
        lengths[0] = 2;

        // Get all principal, 2 claims starting at index 1
        ArcticArchitectureLens.UserHistory memory h =
            helper.getUserHistory(teller, user, 0, type(uint256).max, pools, starts, lengths);

        assertEq(h.principalCheckpoints.length, 1);
        assertEq(h.claimHistories[0].totalLength, 3);
        assertEq(h.claimHistories[0].checkpoints.length, 2);
        assertEq(h.claimHistories[0].checkpoints[0].cumulativeClaimed, 3e17);
        assertEq(h.claimHistories[0].checkpoints[1].cumulativeClaimed, 6e17);
    }

    function test_getUserHistoryPaginated_outOfBoundsPrincipal() public {
        _deposit(user, 1e18);

        address[] memory pools = new address[](0);
        uint256[] memory starts = new uint256[](0);
        uint256[] memory lengths = new uint256[](0);

        // Start beyond total length
        ArcticArchitectureLens.UserHistory memory h =
            helper.getUserHistory(teller, user, 100, 200, pools, starts, lengths);

        assertEq(h.principalTotalLength, 1);
        assertEq(h.principalCheckpoints.length, 0);
    }

    function test_getUserHistoryPaginated_lengthClampedToRemaining() public {
        _deposit(user, 1e18);
        skip(1 hours);
        _deposit(user, 2e18);

        address[] memory pools = new address[](0);
        uint256[] memory starts = new uint256[](0);
        uint256[] memory lengths = new uint256[](0);

        // Length exceeds remaining — should clamp
        ArcticArchitectureLens.UserHistory memory h =
            helper.getUserHistory(teller, user, 0, 999, pools, starts, lengths);

        assertEq(h.principalTotalLength, 2);
        assertEq(h.principalCheckpoints.length, 2);
    }

    function test_getUserHistoryPaginated_arrayLengthMismatch() public {
        address[] memory pools = new address[](1);
        pools[0] = address(poolA);
        uint256[] memory starts = new uint256[](0);
        uint256[] memory lengths = new uint256[](1);

        vm.expectRevert(ArcticArchitectureLens.ArrayLengthMismatch.selector);
        helper.getUserHistory(teller, user, 0, 0, pools, starts, lengths);
    }

    function test_getUserHistoryPaginated_multiplePools() public {
        _deposit(user, 10e18);

        // 2 claims on pool A, 1 on pool B
        skip(1 days);
        _claimRewards(user, poolA, 1e17);
        skip(1 days);
        _claimRewards(user, poolA, 3e17);
        skip(1 days);
        _claimRewards(user, poolB, 5e17);

        address[] memory pools = new address[](2);
        pools[0] = address(poolA);
        pools[1] = address(poolB);
        uint256[] memory starts = new uint256[](2);
        starts[0] = 0;
        starts[1] = 0;
        uint256[] memory lengths = new uint256[](2);
        lengths[0] = 1; // only first claim from pool A
        lengths[1] = 1; // only first claim from pool B

        ArcticArchitectureLens.UserHistory memory h =
            helper.getUserHistory(teller, user, 0, type(uint256).max, pools, starts, lengths);

        // Pool A: 1 of 2 claims
        assertEq(h.claimHistories[0].totalLength, 2);
        assertEq(h.claimHistories[0].checkpoints.length, 1);
        assertEq(h.claimHistories[0].checkpoints[0].cumulativeClaimed, 1e17);

        // Pool B: 1 of 1 claims
        assertEq(h.claimHistories[1].totalLength, 1);
        assertEq(h.claimHistories[1].checkpoints.length, 1);
        assertEq(h.claimHistories[1].checkpoints[0].cumulativeClaimed, 5e17);
    }
}
