// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {TellerWithBuffer, TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithBuffer.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {HastraPrimeBufferHelper} from "src/base/Roles/HastraPrimeBufferHelper.sol";
import {IBufferHelper} from "src/interfaces/IBufferHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract HastraPrimeBufferHelperTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;

    uint8 public constant ADMIN_ROLE = 1;
    uint8 public constant MINTER_ROLE = 7;
    uint8 public constant BURNER_ROLE = 8;
    uint8 public constant TELLER_MANAGER_ROLE = 62;

    BoringVault public boringVault;
    TellerWithBuffer public teller;
    AccountantWithRateProviders public accountant;
    RolesAuthority public rolesAuthority;
    HastraPrimeBufferHelper public bufferHelper;

    ERC20 internal USDC;
    ERC4626 internal wylds;
    ERC4626 internal prime;

    address public referrer = vm.addr(1337);

    function setUp() public {
        setSourceChainName("mainnet");
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"), 26047800);

        USDC = getERC20(sourceChain, "USDC");
        wylds = ERC4626(getAddress(sourceChain, "wYLDS"));
        prime = ERC4626(getAddress(sourceChain, "PRIME"));

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 6);
        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), vm.addr(7777777), 1e6, address(USDC), 1.1e4, 0.9e4, 1, 0, 0
        );
        bufferHelper = new HastraPrimeBufferHelper(address(wylds), address(prime), address(boringVault));
        teller = new TellerWithBuffer(
            address(this), address(boringVault), address(accountant), getAddress(sourceChain, "WETH")
        );

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
        rolesAuthority.setRoleCapability(
            TELLER_MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address[],bytes[],uint256[])"))),
            true
        );
        rolesAuthority.setPublicCapability(
            address(teller), bytes4(keccak256("deposit(address,uint256,uint256,address)")), true
        );
        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.withdraw.selector, true);

        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), TELLER_MANAGER_ROLE, true);

        teller.updateAssetData(USDC, true, true, 0);

        teller.allowBufferHelper(USDC, IBufferHelper(address(bufferHelper)));
        teller.setDepositBufferHelper(USDC, IBufferHelper(address(bufferHelper)));
        teller.setWithdrawBufferHelper(USDC, IBufferHelper(address(bufferHelper)));
    }

    function testDepositUSDC(uint256 amount) external {
        amount = bound(amount, 1e6, 1_000_000e6);
        uint256 expectedPrime = prime.previewDeposit(wylds.previewDeposit(amount));

        deal(address(USDC), address(this), amount);
        USDC.safeApprove(address(boringVault), amount);
        teller.deposit(USDC, amount, 0, referrer);

        assertEq(boringVault.balanceOf(address(this)), amount);
        assertEq(USDC.balanceOf(address(boringVault)), 0);
        assertEq(ERC20(address(wylds)).balanceOf(address(boringVault)), 0);
        assertEq(ERC20(address(prime)).balanceOf(address(boringVault)), expectedPrime);
        assertGt(expectedPrime, 0);
        assertEq(USDC.allowance(address(boringVault), address(wylds)), 0);
        assertEq(ERC20(address(wylds)).allowance(address(boringVault), address(prime)), 0);
    }

    function testBulkDepositUSDC(uint256 amount) external {
        amount = bound(amount, 1e6, 1_000_000e6);
        uint256 expectedPrime = prime.previewDeposit(wylds.previewDeposit(amount));

        deal(address(USDC), address(this), amount);
        USDC.safeApprove(address(boringVault), amount);
        teller.bulkDeposit(USDC, amount, 0, address(this));

        assertEq(boringVault.balanceOf(address(this)), amount);
        assertEq(USDC.balanceOf(address(boringVault)), 0);
        assertEq(ERC20(address(prime)).balanceOf(address(boringVault)), expectedPrime);
    }

    function testWithdrawServedFromIdle() external {
        uint256 amount = 10_000e6;
        deal(address(USDC), address(this), amount);
        USDC.safeApprove(address(boringVault), amount);
        teller.deposit(USDC, amount, 0, referrer);

        uint256 primeBal = ERC20(address(prime)).balanceOf(address(boringVault));
        deal(address(USDC), address(boringVault), amount);

        teller.withdraw(USDC, amount, 0, address(this));

        assertEq(boringVault.balanceOf(address(this)), 0);
        assertEq(USDC.balanceOf(address(this)), amount);
        assertEq(USDC.balanceOf(address(boringVault)), 0);
        assertEq(ERC20(address(prime)).balanceOf(address(boringVault)), primeBal);
    }

    function testBulkWithdrawServedFromIdle() external {
        uint256 amount = 10_000e6;
        deal(address(USDC), address(this), amount);
        USDC.safeApprove(address(boringVault), amount);
        teller.bulkDeposit(USDC, amount, 0, address(this));

        uint256 primeBal = ERC20(address(prime)).balanceOf(address(boringVault));
        deal(address(USDC), address(boringVault), amount);

        teller.bulkWithdraw(USDC, amount, 0, address(this));

        assertEq(USDC.balanceOf(address(this)), amount);
        assertEq(ERC20(address(prime)).balanceOf(address(boringVault)), primeBal);
    }

    function testWithdrawRevertsWithoutIdle() external {
        uint256 amount = 10_000e6;
        deal(address(USDC), address(this), amount);
        USDC.safeApprove(address(boringVault), amount);
        teller.deposit(USDC, amount, 0, referrer);

        vm.expectRevert();
        teller.withdraw(USDC, amount, 0, address(this));
    }

    function testWithdrawManageCallIsEmpty() external view {
        (address[] memory targets, bytes[] memory data, uint256[] memory values) =
            bufferHelper.getWithdrawManageCall(address(USDC), 1e6);
        assertEq(targets.length, 0);
        assertEq(data.length, 0);
        assertEq(values.length, 0);
    }

    function testDepositManageCallUSDC() external view {
        uint256 amount = 1_000e6;
        uint256 wyldsAmount = wylds.previewDeposit(amount);
        (address[] memory targets, bytes[] memory data, uint256[] memory values) =
            bufferHelper.getDepositManageCall(address(USDC), amount);

        assertEq(targets.length, 4);
        assertEq(values.length, 4);
        assertEq(targets[0], address(USDC));
        assertEq(data[0], abi.encodeWithSignature("approve(address,uint256)", address(wylds), amount));
        assertEq(targets[1], address(wylds));
        assertEq(data[1], abi.encodeWithSignature("deposit(uint256,address)", amount, address(boringVault)));
        assertEq(targets[2], address(wylds));
        assertEq(data[2], abi.encodeWithSignature("approve(address,uint256)", address(prime), wyldsAmount));
        assertEq(targets[3], address(prime));
        assertEq(data[3], abi.encodeWithSignature("deposit(uint256,address)", wyldsAmount, address(boringVault)));
    }

    function testUnsupportedAssetReverts() external {
        address dai = getAddress(sourceChain, "DAI");
        vm.expectRevert(
            abi.encodeWithSelector(HastraPrimeBufferHelper.HastraPrimeBufferHelper__UnsupportedAsset.selector, dai)
        );
        bufferHelper.getDepositManageCall(dai, 1e18);

        vm.expectRevert(
            abi.encodeWithSelector(
                HastraPrimeBufferHelper.HastraPrimeBufferHelper__UnsupportedAsset.selector, address(wylds)
            )
        );
        bufferHelper.getDepositManageCall(address(wylds), 1e6);
    }

    function testDepositRevertsWhenNavStale() external {
        vm.warp(block.timestamp + 3601);

        uint256 amount = 10_000e6;
        deal(address(USDC), address(this), amount);
        USDC.safeApprove(address(boringVault), amount);

        vm.expectRevert();
        teller.deposit(USDC, amount, 0, referrer);
    }

    function testConstructorZeroAddressReverts() external {
        vm.expectRevert(HastraPrimeBufferHelper.HastraPrimeBufferHelper__ZeroAddress.selector);
        new HastraPrimeBufferHelper(address(wylds), address(prime), address(0));
    }
}
