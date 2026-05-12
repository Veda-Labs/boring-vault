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
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {MorphoMarketBufferHelper} from "src/base/Roles/MorphoMarketBufferHelper.sol";
import {IBufferHelper} from "src/interfaces/IBufferHelper.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

interface IMorphoLite {
    struct Position {
        uint256 supplyShares;
        uint128 borrowShares;
        uint128 collateral;
    }

    function position(bytes32 id, address user) external view returns (Position memory);

    function market(bytes32 id)
        external
        view
        returns (
            uint128 totalSupplyAssets,
            uint128 totalSupplyShares,
            uint128 totalBorrowAssets,
            uint128 totalBorrowShares,
            uint128 lastUpdate,
            uint128 fee
        );
}

/**
 * @title MorphoMarketBufferHelperTest
 * @notice Integration tests for the MorphoMarketBufferHelper using the weETH/WETH 86% LLTV market on mainnet.
 *         The market loan token is WETH; the helper supplies / withdraws WETH on behalf of the BoringVault.
 */
contract MorphoMarketBufferHelperTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    BoringVault public boringVault;

    uint8 public constant ADMIN_ROLE = 1;
    uint8 public constant MINTER_ROLE = 7;
    uint8 public constant BURNER_ROLE = 8;
    uint8 public constant TELLER_MANAGER_ROLE = 62;

    TellerWithBuffer public teller;
    AccountantWithRateProviders public accountant;
    address public payout_address = vm.addr(7777777);
    RolesAuthority public rolesAuthority;

    ERC20 internal WETH;
    address internal MORPHO_BLUE;

    // weETH/WETH 86% LLTV market parameters (mainnet)
    address internal constant WEETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    address internal constant WEETH_ORACLE = 0x3fa58b74e9a8eA8768eb33c8453e9C2Ed089A40a;
    address internal constant WEETH_IRM = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;
    uint256 internal constant WEETH_LLTV = 0.86e18;
    bytes32 internal MARKET_ID;

    address public referrer = vm.addr(1337);

    MorphoMarketBufferHelper public bufferHelper;

    function setUp() public {
        setSourceChainName("mainnet");
        string memory rpcKey = "MAINNET_RPC_URL";
        // Block at which the weETH/WETH 86 market exists (same block used by MorphoBlueIntegration tests).
        uint256 blockNumber = 19826676;
        vm.createSelectFork(vm.envString(rpcKey), blockNumber);

        WETH = getERC20(sourceChain, "WETH");
        MORPHO_BLUE = getAddress(sourceChain, "morphoBlue");
        MARKET_ID = getBytes32(sourceChain, "weETH_wETH_86_market");

        bytes32 salt = keccak256("morpho-market-buffer-test");
        boringVault = new BoringVault{salt: salt}(address(this), "Boring Vault", "BV", 18);

        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), payout_address, 1e18, address(WETH), 1.1e4, 0.9e4, 1, 0, 0
        );

        bufferHelper = new MorphoMarketBufferHelper(
            MORPHO_BLUE, address(boringVault), address(WETH), WEETH, WEETH_ORACLE, WEETH_IRM, WEETH_LLTV
        );

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
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.updateAssetData.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.bulkDeposit.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(teller), TellerWithMultiAssetSupport.bulkWithdraw.selector, true
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

        rolesAuthority.setPublicCapability(
            address(teller), bytes4(keccak256("deposit(address,uint256,uint256,address)")), true
        );
        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.withdraw.selector, true);

        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), TELLER_MANAGER_ROLE, true);

        teller.updateAssetData(WETH, true, true, 0);
        accountant.setRateProviderData(WETH, true, address(0));

        teller.allowBufferHelper(WETH, IBufferHelper(address(bufferHelper)));
        teller.setDepositBufferHelper(WETH, IBufferHelper(address(bufferHelper)));
        teller.setWithdrawBufferHelper(WETH, IBufferHelper(address(bufferHelper)));
    }

    // ============================= IMMUTABLES =============================

    function testImmutables() external {
        assertEq(bufferHelper.MORPHO_BLUE(), MORPHO_BLUE, "MORPHO_BLUE");
        assertEq(bufferHelper.VAULT(), address(boringVault), "VAULT");
        assertEq(bufferHelper.LOAN_TOKEN(), address(WETH), "LOAN_TOKEN");
        assertEq(bufferHelper.COLLATERAL_TOKEN(), WEETH, "COLLATERAL_TOKEN");
        assertEq(bufferHelper.ORACLE(), WEETH_ORACLE, "ORACLE");
        assertEq(bufferHelper.IRM(), WEETH_IRM, "IRM");
        assertEq(bufferHelper.LLTV(), WEETH_LLTV, "LLTV");

        DecoderCustomTypes.MarketParams memory mp = bufferHelper.marketParams();
        assertEq(mp.loanToken, address(WETH), "marketParams.loanToken");
        assertEq(mp.collateralToken, WEETH, "marketParams.collateralToken");
        assertEq(mp.oracle, WEETH_ORACLE, "marketParams.oracle");
        assertEq(mp.irm, WEETH_IRM, "marketParams.irm");
        assertEq(mp.lltv, WEETH_LLTV, "marketParams.lltv");
    }

    // ============================= DEPOSIT TESTS =============================

    function testUserDeposit() external {
        uint256 amount = 1e18;

        deal(address(WETH), address(this), amount);
        WETH.safeApprove(address(boringVault), amount);

        uint96 currentNonce = teller.depositNonce();
        teller.deposit(WETH, amount, 0, referrer);

        assertEq(teller.depositNonce(), currentNonce + 1, "Deposit nonce should have increased by 1");
        assertEq(boringVault.balanceOf(address(this)), amount, "Should have received expected shares");

        // All WETH should now be supplied to Morpho.
        assertEq(WETH.balanceOf(address(boringVault)), 0, "No WETH should remain in the vault");
        IMorphoLite.Position memory pos = IMorphoLite(MORPHO_BLUE).position(MARKET_ID, address(boringVault));
        assertGt(pos.supplyShares, 0, "Supply shares should be > 0");
    }

    function testBulkDeposit() external {
        uint256 amount = 1e18;

        deal(address(WETH), address(this), amount);
        WETH.safeApprove(address(boringVault), amount);

        teller.bulkDeposit(WETH, amount, 0, address(this));

        assertEq(boringVault.balanceOf(address(this)), amount, "Should have received expected shares");
        assertEq(WETH.balanceOf(address(boringVault)), 0, "No WETH should remain in the vault");

        IMorphoLite.Position memory pos = IMorphoLite(MORPHO_BLUE).position(MARKET_ID, address(boringVault));
        assertGt(pos.supplyShares, 0, "Supply shares should be > 0");
    }

    function testDepositWithSufficientOpenApproval() external {
        uint256 amount = 1e18;
        deal(address(WETH), address(this), amount);

        // Pre-approve Morpho Blue from boring vault with sufficient allowance.
        address[] memory targets = new address[](1);
        targets[0] = address(WETH);
        bytes[] memory data = new bytes[](1);
        data[0] = abi.encodeWithSelector(WETH.approve.selector, MORPHO_BLUE, amount);
        uint256[] memory values = new uint256[](1);

        rolesAuthority.setUserRole(address(this), TELLER_MANAGER_ROLE, true);
        boringVault.manage(targets, data, values);

        WETH.safeApprove(address(boringVault), amount);
        teller.deposit(WETH, amount, 0, referrer);

        assertEq(boringVault.balanceOf(address(this)), amount, "Should have received expected shares");
        assertEq(WETH.balanceOf(address(boringVault)), 0, "No WETH should remain in the vault");
        IMorphoLite.Position memory pos = IMorphoLite(MORPHO_BLUE).position(MARKET_ID, address(boringVault));
        assertGt(pos.supplyShares, 0, "Supply shares should be > 0");
    }

    // ============================= WITHDRAW TESTS =============================

    function testWithdraw() external {
        uint256 amount = 1e18;

        // Deposit first.
        deal(address(WETH), address(this), amount);
        WETH.safeApprove(address(boringVault), amount);
        teller.deposit(WETH, amount, 0, referrer);

        IMorphoLite.Position memory posBefore = IMorphoLite(MORPHO_BLUE).position(MARKET_ID, address(boringVault));
        assertGt(posBefore.supplyShares, 0, "Supply shares should be > 0 after deposit");

        // Withdraw slightly less than the supplied amount to avoid hitting share-rounding edge.
        uint256 withdrawAmount = amount - 1;
        teller.withdraw(WETH, withdrawAmount, 0, address(this));

        assertApproxEqAbs(boringVault.balanceOf(address(this)), 0, 2, "Should have ~0 remaining shares");
        assertApproxEqAbs(WETH.balanceOf(address(this)), amount, 2, "Should have received WETH back");
    }

    function testBulkWithdraw() external {
        uint256 amount = 1e18;

        // Deposit first.
        deal(address(WETH), address(this), amount);
        WETH.safeApprove(address(boringVault), amount);
        teller.bulkDeposit(WETH, amount, 0, address(this));

        uint256 withdrawAmount = amount - 1;
        teller.bulkWithdraw(WETH, withdrawAmount, 0, address(this));

        assertApproxEqAbs(boringVault.balanceOf(address(this)), 0, 2, "Should have ~0 remaining shares");
        assertApproxEqAbs(WETH.balanceOf(address(this)), amount, 2, "Should have received WETH back");
    }

    // ============================= DEPOSIT + WITHDRAW COMBO TESTS =============================

    function testMultipleDepositWithdraws() external {
        uint256 amount = 1e18;

        deal(address(WETH), address(this), amount);
        WETH.safeApprove(address(boringVault), amount);

        // Deposit 1/10.
        teller.deposit(WETH, amount / 10, 0, referrer);
        assertApproxEqAbs(boringVault.balanceOf(address(this)), amount / 10, 2, "Shares after first deposit");

        // Deposit another 1/10 via bulkDeposit.
        teller.bulkDeposit(WETH, amount / 10, 0, address(this));
        assertApproxEqAbs(boringVault.balanceOf(address(this)), amount / 5, 4, "Shares after second deposit");

        IMorphoLite.Position memory pos = IMorphoLite(MORPHO_BLUE).position(MARKET_ID, address(boringVault));
        assertGt(pos.supplyShares, 0, "Should have supply shares");

        // bulkWithdraw half the shares.
        uint256 sharesBefore = boringVault.balanceOf(address(this));
        teller.bulkWithdraw(WETH, sharesBefore / 2, 0, address(this));

        assertApproxEqAbs(boringVault.balanceOf(address(this)), sharesBefore / 2, 4, "Should have half the shares left");
        assertGt(WETH.balanceOf(address(this)), 0, "Should have received WETH");

        // Withdraw rest via regular withdraw.
        uint256 remainingShares = boringVault.balanceOf(address(this));
        teller.withdraw(WETH, remainingShares - 1, 0, address(this));

        assertApproxEqAbs(boringVault.balanceOf(address(this)), 0, 4, "Should have ~0 shares left");
    }

    // ============================= BUFFER HELPER MANAGEMENT TESTS =============================

    function testBufferHelperZeroAddress() external {
        uint256 amount = 1e18;
        deal(address(WETH), address(this), amount);
        WETH.safeApprove(address(boringVault), amount);

        // Disable buffer helpers.
        teller.setWithdrawBufferHelper(WETH, IBufferHelper(address(0)));
        teller.setDepositBufferHelper(WETH, IBufferHelper(address(0)));

        teller.deposit(WETH, amount, 0, referrer);

        assertEq(boringVault.balanceOf(address(this)), amount, "Shares should match deposit");
        assertEq(WETH.balanceOf(address(boringVault)), amount, "WETH should stay in vault (no buffer helper)");

        teller.withdraw(WETH, amount / 2, 0, address(this));
        assertApproxEqAbs(WETH.balanceOf(address(this)), amount / 2, 4, "Should have received WETH");
        assertApproxEqAbs(WETH.balanceOf(address(boringVault)), amount / 2, 4, "Half WETH should remain in vault");
    }

    function testBufferHelperChange() external {
        uint256 amount = 1e18;
        deal(address(WETH), address(this), amount);
        WETH.safeApprove(address(boringVault), amount);

        // Create a new buffer helper (same config, different instance).
        MorphoMarketBufferHelper newHelper = new MorphoMarketBufferHelper(
            MORPHO_BLUE, address(boringVault), address(WETH), WEETH, WEETH_ORACLE, WEETH_IRM, WEETH_LLTV
        );

        teller.allowBufferHelper(WETH, IBufferHelper(address(newHelper)));
        teller.setDepositBufferHelper(WETH, IBufferHelper(address(newHelper)));
        teller.setWithdrawBufferHelper(WETH, IBufferHelper(address(newHelper)));

        teller.deposit(WETH, amount, 0, referrer);

        assertEq(boringVault.balanceOf(address(this)), amount, "Shares should match deposit");
        assertEq(WETH.balanceOf(address(boringVault)), 0, "No WETH should remain in vault");
        IMorphoLite.Position memory pos = IMorphoLite(MORPHO_BLUE).position(MARKET_ID, address(boringVault));
        assertGt(pos.supplyShares, 0, "Supply shares should be > 0");

        teller.withdraw(WETH, amount / 2, 0, address(this));
        assertApproxEqAbs(WETH.balanceOf(address(this)), amount / 2, 4, "Should have received WETH");
        assertApproxEqAbs(boringVault.balanceOf(address(this)), amount / 2, 4, "Half of shares should remain");
    }

    function testShareLock() external {
        uint256 amount = 1e18;
        deal(address(WETH), address(this), amount);

        teller.setShareLockPeriod(10);
        WETH.safeApprove(address(boringVault), amount);
        teller.deposit(WETH, amount, 0, referrer);

        // Should revert because shares are locked.
        vm.expectRevert(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__SharesAreLocked.selector);
        teller.withdraw(WETH, amount / 10, 0, address(this));

        // bulkWithdraw should bypass share lock.
        teller.bulkWithdraw(WETH, amount / 10, 0, address(this));
        assertApproxEqAbs(WETH.balanceOf(address(this)), amount / 10, 4, "Should have received WETH via bulkWithdraw");

        // Skip to end of share lock period; regular withdraw should work.
        vm.warp(block.timestamp + 10);
        teller.withdraw(WETH, amount / 5, 0, address(this));
        assertApproxEqAbs(
            WETH.balanceOf(address(this)), amount / 5 + amount / 10, 8, "Should have received WETH after lock expires"
        );
    }

    // ============================= ASSET MISMATCH SAFETY CHECK =============================

    /**
     * @notice Verifies that getDepositManageCall reverts when invoked with an asset that is
     *         not the configured LOAN_TOKEN, guarding against misconfigured teller registrations.
     */
    function testGetDepositManageCallRevertsOnAssetMismatch() external {
        address wrongAsset = WEETH; // collateral token of the market – not the loan token
        vm.expectRevert(
            abi.encodeWithSelector(
                MorphoMarketBufferHelper.MorphoMarketBufferHelper__AssetMismatch.selector, wrongAsset, address(WETH)
            )
        );
        bufferHelper.getDepositManageCall(wrongAsset, 1e18);
    }

    /**
     * @notice Verifies that getWithdrawManageCall reverts when invoked with an asset that is
     *         not the configured LOAN_TOKEN, preventing a misconfigured registration from
     *         silently withdrawing the wrong token.
     */
    function testGetWithdrawManageCallRevertsOnAssetMismatch() external {
        address wrongAsset = WEETH;
        vm.expectRevert(
            abi.encodeWithSelector(
                MorphoMarketBufferHelper.MorphoMarketBufferHelper__AssetMismatch.selector, wrongAsset, address(WETH)
            )
        );
        bufferHelper.getWithdrawManageCall(wrongAsset, 1e18);
    }

    /**
     * @notice End-to-end: if the teller is wired to route a non-loan asset through this
     *         helper, the deposit reverts with the asset-mismatch error rather than
     *         silently approving / supplying the wrong token.
     * @dev Uses WEETH as the registered asset on the teller, but the helper is locked to
     *      WETH as its LOAN_TOKEN.
     */
    function testTellerDepositRevertsWhenHelperRegisteredForWrongAsset() external {
        ERC20 weeth = ERC20(WEETH);
        // Register WEETH as a depositable asset and bind this helper (which expects WETH) to it.
        teller.updateAssetData(weeth, true, true, 0);
        accountant.setRateProviderData(weeth, true, address(0));
        teller.allowBufferHelper(weeth, IBufferHelper(address(bufferHelper)));
        teller.setDepositBufferHelper(weeth, IBufferHelper(address(bufferHelper)));

        uint256 amount = 1e18;
        deal(WEETH, address(this), amount);
        weeth.safeApprove(address(boringVault), amount);

        vm.expectRevert(
            abi.encodeWithSelector(
                MorphoMarketBufferHelper.MorphoMarketBufferHelper__AssetMismatch.selector, WEETH, address(WETH)
            )
        );
        teller.deposit(weeth, amount, 0, referrer);
    }

    // ============================= ENCODING TESTS =============================

    /**
     * @notice Verifies that getDepositManageCall returns the canonical 3-call sequence
     *         (approve(0), approve(amount), supply) regardless of pre-existing allowance.
     */
    function testGetDepositManageCallEncoding() external {
        uint256 depositAmount = 1e18;
        (address[] memory targets, bytes[] memory data, uint256[] memory values) =
            bufferHelper.getDepositManageCall(address(WETH), depositAmount);

        assertEq(targets.length, 3, "should return exactly 3 targets");
        assertEq(targets[0], address(WETH), "first target must be WETH (reset allowance)");
        assertEq(targets[1], address(WETH), "second target must be WETH (re-approve)");
        assertEq(targets[2], MORPHO_BLUE, "third target must be Morpho Blue");
        assertEq(
            data[0],
            abi.encodeWithSignature("approve(address,uint256)", MORPHO_BLUE, 0),
            "first call must reset allowance to 0"
        );
        assertEq(
            data[1],
            abi.encodeWithSignature("approve(address,uint256)", MORPHO_BLUE, depositAmount),
            "second call must approve the full deposit amount"
        );

        DecoderCustomTypes.MarketParams memory mp = bufferHelper.marketParams();
        bytes memory expectedSupply = abi.encodeWithSignature(
            "supply((address,address,address,address,uint256),uint256,uint256,address,bytes)",
            mp,
            depositAmount,
            uint256(0),
            address(boringVault),
            bytes("")
        );
        assertEq(data[2], expectedSupply, "third call must be Morpho supply with assets-form");

        assertEq(values[0], 0, "first ETH value must be 0");
        assertEq(values[1], 0, "second ETH value must be 0");
        assertEq(values[2], 0, "third ETH value must be 0");
    }

    /**
     * @notice Verifies that getWithdrawManageCall returns a single withdraw call.
     *         The asset parameter is intentionally unused — the Morpho Blue singleton is always the target.
     */
    function testGetWithdrawManageCallEncoding() external {
        uint256 withdrawAmount = 1e18;
        (address[] memory targets, bytes[] memory data, uint256[] memory values) =
            bufferHelper.getWithdrawManageCall(address(WETH), withdrawAmount);

        assertEq(targets.length, 1, "Withdraw: should return exactly 1 target");
        assertEq(targets[0], MORPHO_BLUE, "Withdraw: target must be Morpho Blue");

        DecoderCustomTypes.MarketParams memory mp = bufferHelper.marketParams();
        bytes memory expectedWithdraw = abi.encodeWithSignature(
            "withdraw((address,address,address,address,uint256),uint256,uint256,address,address)",
            mp,
            withdrawAmount,
            uint256(0),
            address(boringVault),
            address(boringVault)
        );
        assertEq(data[0], expectedWithdraw, "Withdraw: call must be Morpho withdraw with assets-form");
        assertEq(values[0], 0, "Withdraw: ETH value must be 0");
    }
}
