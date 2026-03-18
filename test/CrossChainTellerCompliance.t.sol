// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {
    TellerWithMultiAssetSupport,
    DepositParams,
    ComplianceData
} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {PrincipalCheckpoint} from "src/base/Roles/TellerWithMultiAssetSupportLib.sol";
import {CrossChainTellerWithGenericBridge} from "src/base/Roles/CrossChain/CrossChainTellerWithGenericBridge.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {MessageHashUtils} from "@openzeppelin-contracts-5.3.0/utils/cryptography/MessageHashUtils.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract MockCrossChainTeller is CrossChainTellerWithGenericBridge {
    constructor(address _owner, address _vault, address _accountant, address _weth)
        CrossChainTellerWithGenericBridge(_owner, _vault, _accountant, _weth)
    {}

    function _sendMessage(uint256 message, bytes calldata, ERC20, uint256)
        internal
        override
        returns (bytes32 messageId)
    {
        messageId = bytes32(message);
    }

    function _previewFee(uint256, bytes calldata, ERC20) internal pure override returns (uint256) {
        return 0;
    }
}

contract CrossChainTellerComplianceTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    BoringVault public boringVault;

    uint8 public constant MINTER_ROLE = 7;
    uint8 public constant BURNER_ROLE = 8;

    MockCrossChainTeller public teller;
    AccountantWithRateProviders public accountant;
    address public payout_address = vm.addr(7777777);
    RolesAuthority public rolesAuthority;

    ERC20 internal WETH;

    uint256 internal constant ONE_SHARE = 1e18;
    address public user = vm.addr(100);

    uint256 internal constant SIGNER_KEY = 0xBEEF;
    address internal signer;

    function setUp() external {
        setSourceChainName("mainnet");
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 19363419;
        _startFork(rpcKey, blockNumber);

        WETH = getERC20(sourceChain, "WETH");
        signer = vm.addr(SIGNER_KEY);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), payout_address, 1e18, address(WETH), 1.001e4, 0.999e4, 1, 0, 0
        );

        teller = new MockCrossChainTeller(address(this), address(boringVault), address(accountant), address(WETH));

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));

        boringVault.setAuthority(rolesAuthority);
        accountant.setAuthority(rolesAuthority);
        teller.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(MINTER_ROLE, address(boringVault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(boringVault), BoringVault.exit.selector, true);

        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.deposit.selector, true);
        rolesAuthority.setPublicCapability(address(teller), TellerWithMultiAssetSupport.withdraw.selector, true);
        rolesAuthority.setPublicCapability(
            address(teller), CrossChainTellerWithGenericBridge.depositAndBridge.selector, true
        );
        // bridge(uint96,address,bytes,address,uint256,(uint256,bytes))
        rolesAuthority.setPublicCapability(
            address(teller), bytes4(keccak256("bridge(uint96,address,bytes,address,uint256,(uint256,bytes))")), true
        );

        rolesAuthority.setUserRole(address(teller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(teller), BURNER_ROLE, true);

        teller.updateAssetData(WETH, true, true, 0);

        teller.setComplianceSigner(signer);
    }

    // ========================================= HELPERS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }

    function _signDepositCompliance(address depositor, address depositAsset, uint256 depositAmount, uint256 deadline)
        internal
        view
        returns (bytes memory signature)
    {
        bytes32 messageHash =
            keccak256(abi.encode(address(teller), block.chainid, depositor, depositAsset, depositAmount, deadline));
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_KEY, ethSignedHash);
        signature = abi.encodePacked(r, s, v);
    }

    function _signBridgeCompliance(address sender, uint96 shareAmount, address to, uint256 deadline)
        internal
        view
        returns (bytes memory signature)
    {
        bytes32 messageHash = keccak256(abi.encode(address(teller), block.chainid, sender, shareAmount, to, deadline));
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(SIGNER_KEY, ethSignedHash);
        signature = abi.encodePacked(r, s, v);
    }

    // ========================================= DEPOSIT AND BRIDGE COMPLIANCE TESTS =========================================

    function testDepositAndBridgeWithCompliance() external {
        uint256 amount = 1e18;
        deal(address(WETH), user, amount);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _signDepositCompliance(user, address(WETH), amount, deadline);

        vm.startPrank(user);
        WETH.safeApprove(address(boringVault), amount);
        uint256 shares = teller.depositAndBridge(
            DepositParams(WETH, amount, 0, address(0)),
            user,
            "",
            ERC20(address(0)),
            0,
            address(0),
            ComplianceData(deadline, sig)
        );
        vm.stopPrank();

        assertEq(shares, amount, "shares bridged should equal deposit at 1:1 rate");
        assertEq(boringVault.balanceOf(user), 0, "all shares burned after bridge");
    }

    function testDepositAndBridgeComplianceRevertsWithBadSignature() external {
        uint256 amount = 1e18;
        deal(address(WETH), user, amount);

        uint256 deadline = block.timestamp + 1 hours;
        // Sign with wrong key
        bytes32 messageHash =
            keccak256(abi.encode(address(teller), block.chainid, user, address(WETH), amount, deadline));
        bytes32 ethSignedHash = MessageHashUtils.toEthSignedMessageHash(messageHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0xDEAD, ethSignedHash);
        bytes memory badSig = abi.encodePacked(r, s, v);

        vm.startPrank(user);
        WETH.safeApprove(address(boringVault), amount);
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__ComplianceCheckFailed.selector
            )
        );
        teller.depositAndBridge(
            DepositParams(WETH, amount, 0, address(0)),
            user,
            "",
            ERC20(address(0)),
            0,
            address(0),
            ComplianceData(deadline, badSig)
        );
        vm.stopPrank();
    }

    function testDepositAndBridgeCheckpoints() external {
        uint256 amount = 1e18;
        deal(address(WETH), user, amount);

        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _signDepositCompliance(user, address(WETH), amount, deadline);

        vm.startPrank(user);
        WETH.safeApprove(address(boringVault), amount);
        teller.depositAndBridge(
            DepositParams(WETH, amount, 0, address(0)),
            user,
            "",
            ERC20(address(0)),
            0,
            address(0),
            ComplianceData(deadline, sig)
        );
        vm.stopPrank();

        // depositAndBridge creates: 1 deposit checkpoint + 1 bridge withdrawal checkpoint
        PrincipalCheckpoint[] memory history = teller.getPrincipalHistory(user);
        assertEq(history.length, 2, "deposit + bridge withdrawal checkpoints");
        assertEq(history[0].cumulativeDeposits, uint104(amount), "deposit checkpoint recorded");
        assertEq(history[0].cumulativeWithdrawals, 0, "no withdrawals after deposit phase");
        assertTrue(
            history[1].cumulativeWithdrawals >= history[1].cumulativeDeposits,
            "bridge burn: withdrawals >= deposits (no phantom principal on source chain)"
        );
    }

    /// @dev Helper: deposit with a signed compliance signature so bridge tests can get shares.
    function _depositWithCompliance(address depositor, uint256 amount) internal returns (uint256 shares) {
        deal(address(WETH), depositor, amount);
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _signDepositCompliance(depositor, address(WETH), amount, deadline);

        vm.startPrank(depositor);
        WETH.safeApprove(address(boringVault), amount);
        shares = teller.deposit(DepositParams(WETH, amount, 0, address(0)), address(0), ComplianceData(deadline, sig));
        vm.stopPrank();
    }

    // ========================================= BRIDGE WITH COMPLIANCE TESTS =========================================

    function testBridgeWithCompliance() external {
        uint256 amount = 1e18;
        uint256 shares = _depositWithCompliance(user, amount);
        assertEq(shares, amount, "got shares from deposit");

        // Bridge with compliance
        uint96 shareAmount = uint96(shares);
        uint256 deadline = block.timestamp + 1 hours;
        address bridgeTo = vm.addr(200);
        bytes memory sig = _signBridgeCompliance(user, shareAmount, bridgeTo, deadline);

        vm.prank(user);
        teller.bridge(shareAmount, bridgeTo, "", ERC20(address(0)), 0, ComplianceData(deadline, sig));

        assertEq(boringVault.balanceOf(user), 0, "shares burned after bridge");
    }

    function testBridgeComplianceRevertsWithExpiredDeadline() external {
        uint256 amount = 1e18;
        _depositWithCompliance(user, amount);

        uint96 shareAmount = uint96(amount);
        uint256 deadline = block.timestamp - 1; // expired
        address bridgeTo = vm.addr(200);
        bytes memory sig = _signBridgeCompliance(user, shareAmount, bridgeTo, deadline);

        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__ComplianceCheckFailed.selector
            )
        );
        vm.prank(user);
        teller.bridge(shareAmount, bridgeTo, "", ERC20(address(0)), 0, ComplianceData(deadline, sig));
    }

    function testBridgeComplianceRevertsWithReplayedSignature() external {
        uint256 amount = 2e18;
        _depositWithCompliance(user, amount);

        uint96 shareAmount = uint96(1e18);
        uint256 deadline = block.timestamp + 1 hours;
        address bridgeTo = vm.addr(200);
        bytes memory sig = _signBridgeCompliance(user, shareAmount, bridgeTo, deadline);

        // First bridge succeeds
        vm.prank(user);
        teller.bridge(shareAmount, bridgeTo, "", ERC20(address(0)), 0, ComplianceData(deadline, sig));

        // Replay same signature reverts
        vm.expectRevert(
            abi.encodeWithSelector(
                TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__ComplianceCheckFailed.selector
            )
        );
        vm.prank(user);
        teller.bridge(shareAmount, bridgeTo, "", ERC20(address(0)), 0, ComplianceData(deadline, sig));
    }
}
