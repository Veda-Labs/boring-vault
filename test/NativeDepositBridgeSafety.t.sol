// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {
    LayerZeroTeller,
    CrossChainTellerWithGenericBridge
} from "src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTeller.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {
    TellerWithMultiAssetSupport,
    DepositParams,
    ComplianceData,
    PermitData
} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

/**
 * Tests that native ETH cannot be accidentally lost through bridge functions
 * after the removal of the `revertOnNativeDeposit` modifier.
 *
 * The key invariants:
 * 1. depositAndBridge with NATIVE sentinel as depositAsset must revert
 * 2. depositAndBridge with ERC20 + correct msg.value (bridge fee) must succeed
 * 3. depositAndBridge with ERC20 + wrong msg.value must revert (LZ strict equality)
 * 4. bridge with correct msg.value for fees must succeed
 * 5. deposit() DualDeposit guard remains intact
 */
contract NativeDepositBridgeSafetyTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;
    using AddressToBytes32Lib for address;

    BoringVault public boringVault;

    uint8 public constant MINTER_ROLE = 7;
    uint8 public constant BURNER_ROLE = 8;

    address public endPoint;
    LayerZeroTeller public sourceTeller;
    AccountantWithRateProviders public accountant;
    address public payout_address = vm.addr(7777777);
    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    ERC20 internal constant NATIVE_ERC20 = ERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    RolesAuthority public rolesAuthority;

    ERC20 internal WETH;
    ERC20 internal ZRO;

    address public referrer = vm.addr(1337);

    function setUp() external {
        setSourceChainName("mainnet");
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 21023546;
        _startFork(rpcKey, blockNumber);

        endPoint = getAddress(sourceChain, "LayerZeroEndPoint");
        WETH = getERC20(sourceChain, "WETH");
        ZRO = getERC20(sourceChain, "ZRO");

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), payout_address, 1e18, address(WETH), 1.001e4, 0.999e4, 1, 0, 0
        );

        sourceTeller = new LayerZeroTeller(
            address(this),
            address(boringVault),
            address(accountant),
            address(WETH),
            address(endPoint),
            address(this),
            address(ZRO)
        );

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));

        boringVault.setAuthority(rolesAuthority);
        accountant.setAuthority(rolesAuthority);
        sourceTeller.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(MINTER_ROLE, address(boringVault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(boringVault), BoringVault.exit.selector, true);
        rolesAuthority.setPublicCapability(
            address(sourceTeller), CrossChainTellerWithGenericBridge.depositAndBridge.selector, true
        );
        rolesAuthority.setPublicCapability(
            address(sourceTeller), CrossChainTellerWithGenericBridge.depositAndBridgeWithPermit.selector, true
        );
        rolesAuthority.setPublicCapability(address(sourceTeller), TellerWithMultiAssetSupport.deposit.selector, true);
        rolesAuthority.setPublicCapability(
            address(sourceTeller), CrossChainTellerWithGenericBridge.bridge.selector, true
        );

        rolesAuthority.setUserRole(address(sourceTeller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(sourceTeller), BURNER_ROLE, true);

        sourceTeller.updateAssetData(WETH, true, true, 0);
        sourceTeller.updateAssetData(ERC20(NATIVE), true, true, 0);

        // Give BoringVault some WETH and this address some shares.
        deal(address(WETH), address(boringVault), 1_000e18);
        deal(address(boringVault), address(this), 1_000e18, true);

        sourceTeller.addChain(layerZeroArbitrumEndpointId, true, true, address(sourceTeller), 1_000_000);
    }

    // ================================ NATIVE SENTINEL + BRIDGE REVERTS ================================

    /// @notice depositAndBridge with NATIVE sentinel as deposit asset must revert.
    /// This replaces the old `revertOnNativeDeposit` modifier -- the revert now comes from
    /// safeTransferFrom on the non-contract sentinel address.
    function testDepositAndBridge_NativeSentinelReverts() external {
        address user = vm.addr(1);
        uint256 depositAmount = 1e18;
        deal(user, depositAmount + 1 ether);

        vm.startPrank(user);
        vm.expectRevert();
        sourceTeller.depositAndBridge{value: depositAmount}(
            DepositParams(NATIVE_ERC20, depositAmount, 0, user),
            user,
            abi.encode(layerZeroArbitrumEndpointId),
            NATIVE_ERC20,
            1 ether,
            referrer,
            ComplianceData(0, "")
        );
        vm.stopPrank();
    }

    /// @notice depositAndBridgeWithPermit with NATIVE sentinel must revert.
    function testDepositAndBridgeWithPermit_NativeSentinelReverts() external {
        address user = vm.addr(1);
        uint256 depositAmount = 1e18;
        deal(user, depositAmount + 1 ether);

        CrossChainTellerWithGenericBridge.DepositAndBridgeWithPermitParams memory params =
            CrossChainTellerWithGenericBridge.DepositAndBridgeWithPermitParams({
                depositParams: DepositParams(NATIVE_ERC20, depositAmount, 0, user),
                permit: PermitData(block.timestamp, 0, bytes32(0), bytes32(0)),
                to: user,
                bridgeWildCard: abi.encode(layerZeroArbitrumEndpointId),
                feeToken: NATIVE_ERC20,
                maxFee: 1 ether,
                referralAddress: referrer,
                compliance: ComplianceData(0, "")
            });

        vm.startPrank(user);
        vm.expectRevert();
        sourceTeller.depositAndBridgeWithPermit{value: depositAmount}(params);
        vm.stopPrank();
    }

    // ================================ ETH CANNOT BE SILENTLY LOCKED ================================

    /// @notice ERC20 depositAndBridge with correct bridge fee in msg.value must succeed.
    /// The msg.value goes entirely to LayerZero as the bridge fee, not as a deposit.
    function testDepositAndBridge_ERC20WithBridgeFeeSucceeds() external {
        address user = vm.addr(1);
        uint256 depositAmount = 1e18;

        deal(address(WETH), user, depositAmount);
        uint256 fee =
            sourceTeller.previewFee(uint96(depositAmount), user, abi.encode(layerZeroArbitrumEndpointId), NATIVE_ERC20);
        deal(user, fee);

        uint256 tellerBalanceBefore = address(sourceTeller).balance;

        vm.startPrank(user);
        WETH.approve(address(boringVault), depositAmount);
        sourceTeller.depositAndBridge{value: fee}(
            DepositParams(WETH, depositAmount, 0, user),
            user,
            abi.encode(layerZeroArbitrumEndpointId),
            NATIVE_ERC20,
            fee,
            referrer,
            ComplianceData(0, "")
        );
        vm.stopPrank();

        // No ETH should remain locked in the teller -- it all goes to LZ endpoint.
        assertEq(address(sourceTeller).balance, tellerBalanceBefore, "No ETH locked in teller");
        // User's shares were bridged (burned), so balance is 0.
        assertEq(boringVault.balanceOf(user), 0, "All shares bridged");
    }

    /// @notice ERC20 depositAndBridge with excess msg.value must revert.
    /// LayerZero's _payNative enforces strict equality: msg.value == nativeFee.
    function testDepositAndBridge_ExcessMsgValueReverts() external {
        address user = vm.addr(1);
        uint256 depositAmount = 1e18;

        deal(address(WETH), user, depositAmount);
        uint256 fee =
            sourceTeller.previewFee(uint96(depositAmount), user, abi.encode(layerZeroArbitrumEndpointId), NATIVE_ERC20);
        uint256 excessFee = fee + 1 ether;
        deal(user, excessFee);

        vm.startPrank(user);
        WETH.approve(address(boringVault), depositAmount);
        vm.expectRevert();
        sourceTeller.depositAndBridge{value: excessFee}(
            DepositParams(WETH, depositAmount, 0, user),
            user,
            abi.encode(layerZeroArbitrumEndpointId),
            NATIVE_ERC20,
            excessFee,
            referrer,
            ComplianceData(0, "")
        );
        vm.stopPrank();
    }

    /// @notice ERC20 depositAndBridge with zero msg.value when paying native fee must revert.
    function testDepositAndBridge_ZeroMsgValueWithNativeFeeReverts() external {
        address user = vm.addr(1);
        uint256 depositAmount = 1e18;

        deal(address(WETH), user, depositAmount);
        uint256 fee =
            sourceTeller.previewFee(uint96(depositAmount), user, abi.encode(layerZeroArbitrumEndpointId), NATIVE_ERC20);

        vm.startPrank(user);
        WETH.approve(address(boringVault), depositAmount);
        vm.expectRevert();
        // No msg.value sent but fee expects native payment.
        sourceTeller.depositAndBridge(
            DepositParams(WETH, depositAmount, 0, user),
            user,
            abi.encode(layerZeroArbitrumEndpointId),
            NATIVE_ERC20,
            fee,
            referrer,
            ComplianceData(0, "")
        );
        vm.stopPrank();
    }

    // ================================ BRIDGE-ONLY NATIVE FEE ================================

    /// @notice bridge() with correct native fee succeeds and doesn't lock ETH.
    function testBridge_NativeFeeSucceeds() external {
        uint96 sharesToBridge = 1e18;
        address user = vm.addr(42);

        deal(address(boringVault), user, uint256(sharesToBridge), true);
        uint256 fee =
            sourceTeller.previewFee(sharesToBridge, user, abi.encode(layerZeroArbitrumEndpointId), NATIVE_ERC20);
        deal(user, fee);

        uint256 tellerBalanceBefore = address(sourceTeller).balance;

        vm.startPrank(user);
        sourceTeller.bridge{value: fee}(
            sharesToBridge, user, abi.encode(layerZeroArbitrumEndpointId), NATIVE_ERC20, fee, ComplianceData(0, "")
        );
        vm.stopPrank();

        assertEq(address(sourceTeller).balance, tellerBalanceBefore, "No ETH locked in teller");
        assertEq(boringVault.balanceOf(user), 0, "Shares burned after bridge");
    }

    /// @notice bridge() with excess msg.value must revert.
    function testBridge_ExcessMsgValueReverts() external {
        uint96 sharesToBridge = 1e18;
        address user = vm.addr(42);

        deal(address(boringVault), user, uint256(sharesToBridge), true);
        uint256 fee =
            sourceTeller.previewFee(sharesToBridge, user, abi.encode(layerZeroArbitrumEndpointId), NATIVE_ERC20);
        uint256 excessFee = fee + 1 ether;
        deal(user, excessFee);

        vm.startPrank(user);
        vm.expectRevert();
        sourceTeller.bridge{value: excessFee}(
            sharesToBridge,
            user,
            abi.encode(layerZeroArbitrumEndpointId),
            NATIVE_ERC20,
            excessFee,
            ComplianceData(0, "")
        );
        vm.stopPrank();
    }

    // ================================ DUAL DEPOSIT GUARD ================================

    /// @notice deposit() with ERC20 + msg.value still reverts with DualDeposit.
    function testDeposit_DualDepositGuardIntact() external {
        address user = vm.addr(1);
        uint256 depositAmount = 1e18;

        deal(address(WETH), user, depositAmount);
        deal(user, 1 ether);

        vm.startPrank(user);
        WETH.approve(address(boringVault), depositAmount);
        vm.expectRevert(
            abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__DualDeposit.selector)
        );
        sourceTeller.deposit{value: 1}(DepositParams(WETH, depositAmount, 0, user), referrer, ComplianceData(0, ""));
        vm.stopPrank();
    }

    /// @notice deposit() with NATIVE sentinel + msg.value succeeds (native deposit path).
    function testDeposit_NativeDepositSucceeds() external {
        address user = vm.addr(1);
        uint256 depositAmount = 1e18;

        deal(user, depositAmount);

        vm.startPrank(user);
        sourceTeller.deposit{value: depositAmount}(
            DepositParams(NATIVE_ERC20, 0, 0, user), referrer, ComplianceData(0, "")
        );
        vm.stopPrank();

        assertEq(boringVault.balanceOf(user), depositAmount, "Native deposit mints correct shares");
    }

    // ================================ NO ETH LOCKED AFTER REVERT ================================

    /// @notice When depositAndBridge with NATIVE sentinel reverts, no ETH is consumed.
    function testDepositAndBridge_NativeRevertNoEthLost() external {
        address user = vm.addr(1);
        uint256 depositAmount = 1e18;
        deal(user, depositAmount + 1 ether);

        uint256 userBalanceBefore = user.balance;
        uint256 tellerBalanceBefore = address(sourceTeller).balance;

        vm.startPrank(user);
        try sourceTeller.depositAndBridge{value: depositAmount}(
            DepositParams(NATIVE_ERC20, depositAmount, 0, user),
            user,
            abi.encode(layerZeroArbitrumEndpointId),
            NATIVE_ERC20,
            1 ether,
            referrer,
            ComplianceData(0, "")
        ) {
            revert("Should have reverted");
        } catch {
            // Expected revert
        }
        vm.stopPrank();

        assertEq(user.balance, userBalanceBefore, "User ETH balance unchanged after revert");
        assertEq(address(sourceTeller).balance, tellerBalanceBefore, "Teller ETH balance unchanged after revert");
    }

    // ================================ HELPERS ================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
