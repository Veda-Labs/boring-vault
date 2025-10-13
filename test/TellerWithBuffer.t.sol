// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {TellerWithBuffer, TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithBuffer.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {ILiquidityPool} from "src/interfaces/IStaking.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {AaveV3BufferHelper} from "src/base/Roles/AaveV3BufferHelper.sol";
import {GenericRateProviderWithDecimalScaling} from "src/helper/GenericRateProviderWithDecimalScaling.sol";
import {IBufferHelper} from "src/interfaces/IBufferHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract TellerBufferTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    BoringVault public boringVault;

    uint8 public constant ADMIN_ROLE = 1;
    uint8 public constant MINTER_ROLE = 7;
    uint8 public constant BURNER_ROLE = 8;
    uint8 public constant SOLVER_ROLE = 9;
    uint8 public constant QUEUE_ROLE = 10;
    uint8 public constant CAN_SOLVE_ROLE = 11;
    uint8 public constant TELLER_MANAGER_ROLE = 62;

    TellerWithBuffer public teller;
    AccountantWithRateProviders public accountant;
    address public payout_address = vm.addr(7777777);
    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    ERC20 internal constant NATIVE_ERC20 = ERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    RolesAuthority public rolesAuthority;

    ERC20 internal USDT;
    ERC20 internal USDC;
    ERC20 internal sUSDe;
    ERC20 internal aUSDT;
    ERC20 internal aUSDC;
    ERC20 internal asUSDe;

    GenericRateProviderWithDecimalScaling internal sUSDeRateProvider;

    address internal v3Pool;
    address public referrer = vm.addr(1337);

    function setUp() public {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 23091932;
        vm.createSelectFork(vm.envString(rpcKey), blockNumber);

        USDT = getERC20(sourceChain, "USDT");
        USDC = getERC20(sourceChain, "USDC");
        aUSDT = getERC20(sourceChain, "aV3USDT");
        aUSDC = getERC20(sourceChain, "aV3USDC");
        sUSDe = getERC20(sourceChain, "SUSDE");
        asUSDe = ERC20(0x4579a27aF00A62C0EB156349f31B345c08386419); // aV3sUSDe
        v3Pool = getAddress(sourceChain, "v3Pool");
        bytes32 salt = keccak256("boring-vault-salt");
        boringVault = new BoringVault{salt: salt}(address(this), "Boring Vault", "BV", 6);

        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), payout_address, 1e6, address(USDT), 1.1e4, 0.9e4, 1, 0, 0
        );

        address bufferHelper = address(new AaveV3BufferHelper(v3Pool, address(boringVault)));

        teller =
            new TellerWithBuffer(address(this), address(boringVault), address(accountant), getAddress(sourceChain, "WETH"));

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));

        sUSDeRateProvider = new GenericRateProviderWithDecimalScaling(
            GenericRateProviderWithDecimalScaling.ConstructorArgs({
                target: 0xFF3BC18cCBd5999CE63E788A1c250a88626aD099, // sUSDe chainlink
                selector: bytes4(0x50d25bcd), // latestAnswer()
                staticArgument0: bytes32(0),
                staticArgument1: bytes32(0),
                staticArgument2: bytes32(0),
                staticArgument3: bytes32(0),
                staticArgument4: bytes32(0),
                staticArgument5: bytes32(0),
                staticArgument6: bytes32(0),
                staticArgument7: bytes32(0),
                signed: true,
                inputDecimals: 8,
                outputDecimals: 18
            })
        );

        boringVault.setAuthority(rolesAuthority);
        accountant.setAuthority(rolesAuthority);
        teller.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(MINTER_ROLE, address(boringVault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(boringVault), BoringVault.exit.selector, true);
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.updateAssetData.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.bulkDeposit.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.refundDeposit.selector, true
        );
        rolesAuthority.setRoleCapability(
            SOLVER_ROLE, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector, true
        );
        rolesAuthority.setRoleCapability(
            TELLER_MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address,bytes,uint256)"))),
            true
        );
        rolesAuthority.setRoleCapability(
            TELLER_MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address[],bytes[],uint256[])"))),
            true
        );

        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.deposit.selector, true);
        rolesAuthority.setPublicCapability(
            address(teller), TellerWithMultiAssetSupport.depositWithPermit.selector, true
        );
        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.withdraw.selector, true);

        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), TELLER_MANAGER_ROLE, true);

        teller.updateAssetData(USDT, true, true, 0);
        teller.updateAssetData(USDC, true, true, 0);
        teller.updateAssetData(sUSDe, true, true, 0);
        accountant.setRateProviderData(USDC, true, address(0));
        accountant.setRateProviderData(sUSDe, false, address(sUSDeRateProvider));

        teller.allowBufferHelper(USDT, IBufferHelper(bufferHelper));
        teller.allowBufferHelper(USDC, IBufferHelper(bufferHelper));
        teller.allowBufferHelper(sUSDe, IBufferHelper(bufferHelper));

        teller.setWithdrawBufferHelper(USDT, IBufferHelper(bufferHelper));
        teller.setWithdrawBufferHelper(USDC, IBufferHelper(bufferHelper));
        teller.setWithdrawBufferHelper(sUSDe, IBufferHelper(bufferHelper));

        teller.setDepositBufferHelper(USDT, IBufferHelper(bufferHelper));
        teller.setDepositBufferHelper(USDC, IBufferHelper(bufferHelper));
        teller.setDepositBufferHelper(sUSDe, IBufferHelper(bufferHelper));
    }

    function testUserDepositPeggedAssets(uint256 amount) external {
        amount = bound(amount, 0.0001e6, 10_000e6);

        deal(address(USDT), address(this), amount);
        deal(address(USDC), address(this), amount);

        USDT.safeApprove(address(boringVault), amount);
        USDC.safeApprove(address(boringVault), amount);
        uint96 currentNonce = teller.depositNonce();

        teller.deposit(USDT, amount, 0, referrer);
        assertEq(teller.depositNonce(), currentNonce + 1, "Deposit nonce should have increased by 1");

        teller.deposit(USDC, amount, 0, referrer);
        assertEq(teller.depositNonce(), currentNonce + 2, "Deposit nonce should have increased by 2");
        assertEq(teller.depositNonce(), 2, "Deposit nonce should be 2");

        uint256 expected_shares = 2 * amount;

        assertEq(boringVault.balanceOf(address(this)), expected_shares, "Should have received expected shares");

        assertApproxEqAbs(aUSDT.balanceOf(address(boringVault)), amount, 2, "Should have put entire deposit into aave");
        assertApproxEqAbs(aUSDC.balanceOf(address(boringVault)), amount, 2, "Should have put entire deposit into aave");
    }

    function testUserDepositWithSufficientOpenApproval(uint256 amount) external {
        amount = bound(amount, 0.0001e6, 10_000e6);
        deal(address(USDT), address(this), amount);
        deal(address(USDC), address(this), amount);

        // approve >= the amount that will be deposited
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(USDT.approve.selector, v3Pool, amount);
        data[1] = abi.encodeWithSelector(USDC.approve.selector, v3Pool, amount);

        address[] memory targets = new address[](2);
        targets[0] = address(USDT);
        targets[1] = address(USDC);

        uint256[] memory values = new uint256[](2);

        rolesAuthority.setUserRole(address(this), TELLER_MANAGER_ROLE, true);

        boringVault.manage(targets, data, values);

        USDT.safeApprove(address(boringVault), amount);
        USDC.safeApprove(address(boringVault), amount);
        uint96 currentNonce = teller.depositNonce();

        teller.deposit(USDT, amount, 0, referrer);
        assertEq(teller.depositNonce(), currentNonce + 1, "Deposit nonce should have increased by 1");

        teller.deposit(USDC, amount, 0, referrer);
        assertEq(teller.depositNonce(), currentNonce + 2, "Deposit nonce should have increased by 2");
        assertEq(teller.depositNonce(), 2, "Deposit nonce should be 2");

        uint256 expected_shares = 2 * amount;

        assertEq(boringVault.balanceOf(address(this)), expected_shares, "Should have received expected shares");

        assertApproxEqAbs(aUSDT.balanceOf(address(boringVault)), amount, 2, "Should have put entire deposit into aave");
        assertApproxEqAbs(aUSDC.balanceOf(address(boringVault)), amount, 2, "Should have put entire deposit into aave");
    }

    function testUserDepositWithInsufficientOpenApproval(uint256 amount) external {
        amount = bound(amount, 0.0001e6, 10_000e6);
        deal(address(USDT), address(this), amount);
        deal(address(USDC), address(this), amount);

        // approve less than the amount that will be deposited
        bytes[] memory data = new bytes[](2);
        data[0] = abi.encodeWithSelector(USDT.approve.selector, v3Pool, amount - 1);
        data[1] = abi.encodeWithSelector(USDC.approve.selector, v3Pool, amount - 1);

        address[] memory targets = new address[](2);
        targets[0] = address(USDT);
        targets[1] = address(USDC);

        uint256[] memory values = new uint256[](2);
        
        rolesAuthority.setUserRole(address(this), TELLER_MANAGER_ROLE, true);

        boringVault.manage(targets, data, values);

        USDT.safeApprove(address(boringVault), amount);
        USDC.safeApprove(address(boringVault), amount);
        uint96 currentNonce = teller.depositNonce();

        teller.deposit(USDT, amount, 0, referrer);
        assertEq(teller.depositNonce(), currentNonce + 1, "Deposit nonce should have increased by 1");

        teller.deposit(USDC, amount, 0, referrer);
        assertEq(teller.depositNonce(), currentNonce + 2, "Deposit nonce should have increased by 2");
        assertEq(teller.depositNonce(), 2, "Deposit nonce should be 2");

        uint256 expected_shares = 2 * amount;

        assertEq(boringVault.balanceOf(address(this)), expected_shares, "Should have received expected shares");

        assertApproxEqAbs(aUSDT.balanceOf(address(boringVault)), amount, 2, "Should have put entire deposit into aave");
        assertApproxEqAbs(aUSDC.balanceOf(address(boringVault)), amount, 2, "Should have put entire deposit into aave");
    }

    function testBulkDeposit(uint256 amount) external {
        amount = bound(amount, 0.0001e6, 10_000e6);
        deal(address(USDT), address(this), amount);
        deal(address(USDC), address(this), amount);

        USDT.safeApprove(address(boringVault), amount);
        USDC.safeApprove(address(boringVault), amount);

        teller.bulkDeposit(USDT, amount, 0, address(this));
        teller.bulkDeposit(USDC, amount, 0, address(this));

        uint256 expected_shares = 2 * amount;

        assertEq(boringVault.balanceOf(address(this)), expected_shares, "Should have received expected shares");

        assertApproxEqAbs(aUSDT.balanceOf(address(boringVault)), amount, 2, "Should have put entire deposit into aave");
        assertApproxEqAbs(aUSDC.balanceOf(address(boringVault)), amount, 2, "Should have put entire deposit into aave");
    }

    function testBulkWithdraw(uint256 amount) external {
        // first do deposits
        amount = bound(amount, 0.0001e6, 10_000e6);
        deal(address(USDT), address(this), amount);
        deal(address(USDC), address(this), amount);

        USDT.safeApprove(address(boringVault), amount);
        USDC.safeApprove(address(boringVault), amount);

        teller.bulkDeposit(USDT, amount, 0, address(this));
        teller.bulkDeposit(USDC, amount, 0, address(this));

        uint256 expected_shares = 2 * amount;

        assertEq(boringVault.balanceOf(address(this)), expected_shares, "Should have received expected shares");

        assertApproxEqAbs(aUSDT.balanceOf(address(boringVault)), amount, 2, "Should have put entire deposit into aave");
        assertApproxEqAbs(aUSDC.balanceOf(address(boringVault)), amount, 2, "Should have put entire deposit into aave");
        
        // then do withdraws
        teller.bulkWithdraw(USDT, amount - 2, 0, address(this));
        teller.bulkWithdraw(USDC, amount - 2, 0, address(this));

        assertApproxEqAbs(boringVault.balanceOf(address(this)), 0, 4, "Should have eliminated expected shares");

        assertApproxEqAbs(aUSDT.balanceOf(address(boringVault)), 0, 2, "Should have removed entire deposit from aave");
        assertApproxEqAbs(aUSDC.balanceOf(address(boringVault)), 0, 2, "Should have removed entire deposit from aave");

        // check withdrawn balances
        assertApproxEqAbs(USDT.balanceOf(address(this)), amount - 2, 2, "Should have received expected USDT");
        assertApproxEqAbs(USDC.balanceOf(address(this)), amount - 2, 2, "Should have received expected USDC");
    }

    function testWithdraw(uint256 amount) external {
        // first do deposits
        amount = bound(amount, 0.0001e6, 10_000e6);
        deal(address(USDT), address(this), amount);
        deal(address(USDC), address(this), amount);

        USDT.safeApprove(address(boringVault), amount);
        USDC.safeApprove(address(boringVault), amount);

        teller.bulkDeposit(USDT, amount, 0, address(this));
        teller.bulkDeposit(USDC, amount, 0, address(this));

        uint256 expected_shares = 2 * amount;

        assertEq(boringVault.balanceOf(address(this)), expected_shares, "Should have received expected shares");

        assertApproxEqAbs(aUSDT.balanceOf(address(boringVault)), amount, 2, "Should have put entire deposit into aave");
        assertApproxEqAbs(aUSDC.balanceOf(address(boringVault)), amount, 2, "Should have put entire deposit into aave");
        
        // then do withdraws
        teller.withdraw(USDT, amount - 2, 0, address(this));
        teller.withdraw(USDC, amount - 2, 0, address(this));

        assertApproxEqAbs(boringVault.balanceOf(address(this)), 0, 4, "Should have eliminated expected shares");

        assertApproxEqAbs(aUSDT.balanceOf(address(boringVault)), 0, 2, "Should have removed entire deposit from aave");
        assertApproxEqAbs(aUSDC.balanceOf(address(boringVault)), 0, 2, "Should have removed entire deposit from aave");

        // check withdrawn balances
        assertApproxEqAbs(USDT.balanceOf(address(this)), amount - 2, 2, "Should have received expected USDT");
        assertApproxEqAbs(USDC.balanceOf(address(this)), amount - 2, 2, "Should have received expected USDC");
    }

    function testMultipleDepositWithdraws(uint256 amount) external {
        amount = bound(amount, 0.0001e6, 10_000e6);
        deal(address(USDT), address(this), amount);
        deal(address(USDC), address(this), amount);

        USDT.safeApprove(address(boringVault), amount);
        USDC.safeApprove(address(boringVault), amount);

        teller.bulkDeposit(USDT, amount / 10, 0, address(this));
        teller.deposit(USDC, amount / 10, 0, referrer);
        assertApproxEqAbs(boringVault.balanceOf(address(this)), amount / 5, 4, "Should have received expected shares");
        uint256 onePercentYield = amount / 5 / 100 + 100; // add 100 to avoid rounding errors
        deal(address(USDC), address(boringVault), onePercentYield); // 1% of the current total assets
        deal(address(USDT), address(boringVault), onePercentYield); // 1% of the current total assets

        // manage vault to deposit the dealt assets into aave (2% yield, 1% each asset)
        bytes[] memory data = new bytes[](4);
        data[0] = abi.encodeWithSelector(USDC.approve.selector, v3Pool, onePercentYield);
        data[1] = abi.encodeWithSignature("supply(address,uint256,address,uint16)", address(USDC), onePercentYield, address(boringVault), 0);
        data[2] = abi.encodeWithSelector(USDT.approve.selector, v3Pool, onePercentYield);
        data[3] = abi.encodeWithSignature("supply(address,uint256,address,uint16)", address(USDT), onePercentYield, address(boringVault), 0);

        address[] memory targets = new address[](4);
        targets[0] = address(USDC);
        targets[1] = v3Pool;
        targets[2] = address(USDT);
        targets[3] = v3Pool;

        uint256[] memory values = new uint256[](4);
        boringVault.manage(targets, data, values);

        vm.warp(block.timestamp + 10);

        accountant.updateExchangeRate(1.02e6);

        teller.bulkWithdraw(USDC, amount / 10, 0, address(this));

        assertApproxEqAbs(boringVault.balanceOf(address(this)), amount / 10, 200, "Should have eliminated expected shares");

        assertApproxEqAbs(aUSDC.balanceOf(address(boringVault)), 0, 200, "Should have removed entire deposit from aave");

        // check that we got back the amount we deposited plus the yield
        assertApproxEqAbs(USDC.balanceOf(address(this)), amount + onePercentYield, 200, "Should have received expected USDC");

        // test regular withdraw
        teller.withdraw(USDT, amount / 10, 0, address(this));

        assertApproxEqAbs(boringVault.balanceOf(address(this)), 0, 200, "Should have eliminated expected shares");

        assertApproxEqAbs(aUSDT.balanceOf(address(boringVault)), 0, 200, "Should have removed entire deposit from aave");

        assertApproxEqAbs(USDT.balanceOf(address(this)), amount + onePercentYield, 200, "Should have received expected USDT");
    }

    function testNonPeggedAsset(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 10_000e18);
        deal(address(sUSDe), address(this), amount);

        sUSDe.safeApprove(address(boringVault), amount);

        teller.deposit(sUSDe, amount / 2, 0, referrer);
        teller.bulkDeposit(sUSDe, amount / 2, 0, address(this));

        // 1e6 /1e18 adjusts token decimals, getRate / 1e18 adjusts for rate scaling
        uint256 expectedShares = amount * 1e6 * sUSDeRateProvider.getRate() / 1e18 / 1e18;
        assertApproxEqAbs(boringVault.balanceOf(address(this)), expectedShares, 2, "Should have received expected shares");

        assertApproxEqAbs(asUSDe.balanceOf(address(boringVault)), amount, 4, "Should have put entire deposit into aave");
    
        teller.bulkWithdraw(sUSDe, expectedShares / 2, 0, address(this));

        assertApproxEqAbs(boringVault.balanceOf(address(this)), expectedShares / 2, 2, "Should have eliminated expected shares");

        assertApproxEqAbs(asUSDe.balanceOf(address(boringVault)),  amount / 2, 1e12, "Should have removed half of the deposit from aave");

        assertApproxEqAbs(sUSDe.balanceOf(address(this)), amount / 2, 1e12, "Should have received expected sUSDe");

        // test regular withdraw
        teller.withdraw(sUSDe, expectedShares / 2, 0, address(this));

        assertApproxEqAbs(boringVault.balanceOf(address(this)), 0, 2, "Should have eliminated expected shares");

        // increase error to account for 2x rounding errors
        assertApproxEqAbs(asUSDe.balanceOf(address(boringVault)), 0, 2e12, "Should have removed entire remaining deposit from aave");

        assertApproxEqAbs(sUSDe.balanceOf(address(this)), amount, 2e12, "Should have received expected sUSDe");
    }

    function testWithdrawFailureWhenBufferIsTooSmall(uint256 amount) external {
        amount = bound(amount, 0.01e6, 100_000e6);
        deal(address(USDT), address(this), amount);

        USDT.safeApprove(address(boringVault), amount);

        teller.deposit(USDT, amount, 0, referrer);

        // give the vault an additional 1% yield
        // not in the buffer though
        vm.warp(block.timestamp + 10);
        deal(address(USDT), address(boringVault), amount / 100);
        accountant.updateExchangeRate(1.01e6);

        vm.expectRevert(0x47bc4b2c); // aave withdrawal failure error
        teller.bulkWithdraw(USDT, amount, 0, address(this));

        vm.expectRevert(0x47bc4b2c); // aave withdrawal failure error
        teller.withdraw(USDT, amount, 0, address(this));
    }
    
    function testShareLock(uint256 amount) external {
        amount = bound(amount, 0.01e6, 10_000e6);
        deal(address(USDT), address(this), amount);

        teller.setShareLockPeriod(10);
        USDT.safeApprove(address(boringVault), amount);
        teller.deposit(USDT, amount, 0, referrer);

        // should revert because shares are locked
        vm.expectRevert(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__SharesAreLocked.selector);
        teller.withdraw(USDT, amount / 10, 0, address(this));

        // should bypass share lock
        teller.bulkWithdraw(USDT, amount / 10, 0, address(this));
        assertApproxEqAbs(USDT.balanceOf(address(this)), amount / 10, 2, "Should have received expected USDT");

        // skip to end of share lock period, regular withdraw should work
        vm.warp(block.timestamp + 10);
        teller.withdraw(USDT, amount / 5, 0, address(this));
        assertApproxEqAbs(USDT.balanceOf(address(this)), amount / 5 + amount / 10, 4, "Should have received expected USDT");
    }

    function testBufferHelperZeroAddress(uint256 amount) external {
        amount = bound(amount, 0.0001e6, 10_000e6);
        deal(address(USDT), address(this), amount);
        USDT.safeApprove(address(boringVault), amount);

        teller.setWithdrawBufferHelper(USDT, IBufferHelper(address(0)));
        teller.setDepositBufferHelper(USDT, IBufferHelper(address(0)));
        
        teller.deposit(USDT, amount, 0, referrer);

        assertEq(boringVault.balanceOf(address(this)), amount, "Shares should be same as deposit amount");
        assertEq(USDT.balanceOf(address(boringVault)), amount, "USDT should all be in vault");

        teller.withdraw(USDT, amount / 2, 0, address(this));
        assertApproxEqAbs(USDT.balanceOf(address(this)), amount / 2, 4, "Should have received expected USDT");
        assertApproxEqAbs(USDT.balanceOf(address(boringVault)), amount / 2, 4, "half USDT should be in vault");
        assertEq(aUSDT.balanceOf(address(boringVault)), 0, "0 USDT should be in aave");
        assertApproxEqAbs(boringVault.balanceOf(address(this)), amount / 2, 4, "Remaining shares should be half of deposit amount");
    }

    function testBufferHelperChange(uint256 amount) external {
        amount = bound(amount, 0.0001e6, 10_000e6);
        deal(address(USDT), address(this), amount);
        deal(address(USDC), address(this), amount);
        USDT.safeApprove(address(boringVault), amount);
        USDC.safeApprove(address(boringVault), amount);

        address newBufferHelper = address(new AaveV3BufferHelper(v3Pool, address(boringVault)));

        teller.allowBufferHelper(USDT, IBufferHelper(newBufferHelper));

        teller.setWithdrawBufferHelper(USDT, IBufferHelper(newBufferHelper));
        teller.setDepositBufferHelper(USDT, IBufferHelper(newBufferHelper));

        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithBuffer.TellerWithBuffer__BufferHelperNotAllowed.selector,
                USDC,
                IBufferHelper(newBufferHelper)
            )
        );
        teller.setWithdrawBufferHelper(USDC, IBufferHelper(newBufferHelper));
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithBuffer.TellerWithBuffer__BufferHelperNotAllowed.selector,
                USDC,
                IBufferHelper(newBufferHelper)
            )
        );
        teller.setDepositBufferHelper(USDC, IBufferHelper(newBufferHelper));

        teller.allowBufferHelper(USDC, IBufferHelper(newBufferHelper));
        teller.setWithdrawBufferHelper(USDC, IBufferHelper(newBufferHelper));
        teller.setDepositBufferHelper(USDC, IBufferHelper(newBufferHelper));

        teller.deposit(USDT, amount, 0, referrer);

        assertEq(boringVault.balanceOf(address(this)), amount, "Shares should be same as deposit amount");
        assertApproxEqAbs(aUSDT.balanceOf(address(boringVault)), amount, 4, "USDT should all be in aave");

        teller.withdraw(USDT, amount / 2, 0, address(this));
        assertApproxEqAbs(USDT.balanceOf(address(this)), amount / 2, 4, "Should have received expected USDT");
        assertApproxEqAbs(aUSDT.balanceOf(address(boringVault)), amount / 2, 4, "half USDT should be in aave");
        assertApproxEqAbs(boringVault.balanceOf(address(this)), amount / 2, 4, "Remaining shares should be half of deposit amount");
    
        uint256 currentShares = boringVault.balanceOf(address(this));
        teller.deposit(USDC, amount, 0, referrer);
        assertEq(boringVault.balanceOf(address(this)) - currentShares, amount, "Change in shares should be same as deposit amount");
        assertApproxEqAbs(aUSDC.balanceOf(address(boringVault)), amount, 4, "USDC should all be in aave");

        currentShares = boringVault.balanceOf(address(this));
        teller.withdraw(USDC, amount / 2, 0, address(this));
        assertApproxEqAbs(USDC.balanceOf(address(this)), amount / 2, 4, "Should have received expected USDC");
        assertApproxEqAbs(aUSDC.balanceOf(address(boringVault)), amount / 2, 4, "half USDC should be in aave");
        assertApproxEqAbs(currentShares - boringVault.balanceOf(address(this)), amount / 2, 4, "Remaining shares should be half of deposit amount");
    }
    // we will need to remove current buffers when they are disallowed, disallowing will not remove ones set in current mapping
}