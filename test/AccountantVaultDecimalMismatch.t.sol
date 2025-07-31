// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {MerkleTreeHelper, ERC20} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";

contract AccountantVaultDecimalsMismatchTest is Test, MerkleTreeHelper {
    using Address for address;

    RolesAuthority rolesAuthority = RolesAuthority(0x49F954c67ff235034b69b8a59fbe309A40256c8d);
    BoringVault bv = BoringVault(payable(0x5f46d540b6eD704C3c8789105F30E075AA900726));
    AccountantWithRateProviders accountant = AccountantWithRateProviders(0xEa23aC6D7D11f6b181d6B98174D334478ADAe6b0);
    TellerWithMultiAssetSupport teller = TellerWithMultiAssetSupport(0x9E88C603307fdC33aA5F26E38b6f6aeF3eE92d48);
    ERC20 WBTCN = ERC20(0xda5dDd7270381A7C2717aD10D1c0ecB19e3CDFb2);
    ERC20 LBTC = ERC20(0xecAc9C5F704e954931349Da37F60E39f515c11c1);
    address user = vm.addr(0xBEEF);
    address auth;

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "CORN_MAIZENET_RPC_URL";
        uint256 blockNumber = 565228;

        _startFork(rpcKey, blockNumber);
        setSourceChainName("corn");

        auth = rolesAuthority.owner();

        deal(address(LBTC), address(bv), 1e8);
        deal(address(WBTCN), address(bv), 1e18);

        // Correct the wrong rate, and open deposits, and let user call bulkWithdraw
        vm.startPrank(auth);
        rolesAuthority.setUserRole(auth, 11, true);
        accountant.updateExchangeRate(1e18);
        accountant.unpause();
        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.deposit.selector, true);
        rolesAuthority.setUserRole(user, 12, true);
        vm.stopPrank();
    }

    function testDepositAndWithdrawWBTCN() external {
        // Give user WBTCN and approve.
        deal(address(WBTCN), user, 1e18);
        vm.prank(user);
        WBTCN.approve(address(bv), 1e18);

        vm.prank(user);
        teller.deposit(WBTCN, 1e18, 0);

        assertEq(bv.balanceOf(user), 1e8, "User should have received one share.");

        vm.prank(user);
        teller.bulkWithdraw(WBTCN, 1e8, 0, user);

        assertEq(WBTCN.balanceOf(user), 1e18, "User should have received one WBTCN.");
    }

    function testDepositAndWithdrawLBTC() external {
        // Give user LBTC and approve.
        deal(address(LBTC), user, 1e8);
        vm.prank(user);
        LBTC.approve(address(bv), 1e8);

        vm.prank(user);
        teller.deposit(LBTC, 1e8, 0);

        assertEq(bv.balanceOf(user), 1e8, "User should have received one share.");

        vm.prank(user);
        teller.bulkWithdraw(LBTC, 1e8, 0, user);

        assertEq(LBTC.balanceOf(user), 1e8, "User should have received one WBTCN.");
    }

    function testUserDepositWBTCNWithdrawLBTC() external {
        // Give user WBTCN and approve.
        deal(address(WBTCN), user, 1e18);
        vm.prank(user);
        WBTCN.approve(address(bv), 1e18);

        vm.prank(user);
        teller.deposit(WBTCN, 1e18, 0);

        assertEq(bv.balanceOf(user), 1e8, "User should have received one share.");

        vm.prank(user);
        teller.bulkWithdraw(LBTC, 1e8, 0, user);

        assertEq(LBTC.balanceOf(user), 1e8, "User should have received one LBTC.");
    }

    function testUserDepositLBTCWithdrawWBTCN() external {
        // Give user LBTC and approve.
        deal(address(LBTC), user, 1e8);
        vm.prank(user);
        LBTC.approve(address(bv), 1e8);

        vm.prank(user);
        teller.deposit(LBTC, 1e8, 0);

        assertEq(bv.balanceOf(user), 1e8, "User should have received one share.");

        vm.prank(user);
        teller.bulkWithdraw(WBTCN, 1e8, 0, user);

        assertEq(WBTCN.balanceOf(user), 1e18, "User should have received one WBTCN.");
    }

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
