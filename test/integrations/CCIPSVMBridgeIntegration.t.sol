// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {
    BridgingDecoderAndSanitizer,
    CCIPDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/BridgingDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract CCIPSVMBridgeIntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority;

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;
    uint8 public constant BALANCER_VAULT_ROLE = 6;

    bytes4 internal constant SVM_EXTRA_ARGS_V1_TAG = 0x1f3b3aba;
    // Arbitrary 32 byte Solana wallet address to receive bridged tokens.
    bytes32 internal constant SOLANA_TOKEN_RECEIVER =
        0x046f9f6b16d2d6a26f6e6f1b9a8f3c1d2e4b5a69788796a5b4c3d2e1f0a1b2c3;

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        // Block must be after the CCIP Solana lane went live on the mainnet router.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 25289000;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new BridgingDecoderAndSanitizer());

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);

        // Setup roles authority.
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address,bytes,uint256)"))),
            true
        );
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address[],bytes[],uint256[])"))),
            true
        );

        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            MANGER_INTERNAL_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(manager), ManagerWithMerkleVerification.setManageRoot.selector, true
        );
        rolesAuthority.setRoleCapability(
            BORING_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.flashLoan.selector, true
        );
        rolesAuthority.setRoleCapability(
            BALANCER_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.receiveFlashLoan.selector, true
        );

        // Grant roles
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
        rolesAuthority.setUserRole(getAddress(sourceChain, "vault"), BALANCER_VAULT_ROLE, true);

        // Allow the boring vault to receive ETH.
        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);
    }

    function testBridgingToSolanaERC20() external {
        deal(getAddress(sourceChain, "LINK"), address(boringVault), 10e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        ERC20[] memory bridgeAssets = new ERC20[](1);
        bridgeAssets[0] = getERC20(sourceChain, "LINK");
        ERC20[] memory feeTokens = new ERC20[](1);
        feeTokens[0] = getERC20(sourceChain, "LINK");
        _addCcipSvmBridgeLeafs(leafs, ccipSolanaChainSelector, SOLANA_TOKEN_RECEIVER, bridgeAssets, feeTokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "LINK");
        targets[1] = getAddress(sourceChain, "ccipRouter");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "ccipRouter"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "ccipSend(uint64,(bytes,bytes,(address,uint256)[],address,bytes))",
            ccipSolanaChainSelector,
            _buildSvmMessage(SOLANA_TOKEN_RECEIVER, 1e18)
        );
        uint256[] memory values = new uint256[](2);
        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // The vault spent the bridged amount plus the LINK fee.
        uint256 remaining = getERC20(sourceChain, "LINK").balanceOf(address(boringVault));
        assertLt(remaining, 9e18, "vault should have spent bridged LINK plus fee");
        assertGt(remaining, 8e18, "fee should be a small fraction of a LINK");
    }

    function testBridgingToSolanaERC20Reverts() external {
        deal(getAddress(sourceChain, "LINK"), address(boringVault), 10e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        ERC20[] memory bridgeAssets = new ERC20[](1);
        bridgeAssets[0] = getERC20(sourceChain, "LINK");
        ERC20[] memory feeTokens = new ERC20[](1);
        feeTokens[0] = getERC20(sourceChain, "LINK");
        _addCcipSvmBridgeLeafs(leafs, ccipSolanaChainSelector, SOLANA_TOKEN_RECEIVER, bridgeAssets, feeTokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "LINK");
        targets[1] = getAddress(sourceChain, "ccipRouter");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "ccipRouter"), type(uint256).max
        );
        uint256[] memory values = new uint256[](2);
        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        // Non zero compute units reverts.
        DecoderCustomTypes.EVM2AnyMessage memory message = _buildSvmMessage(SOLANA_TOKEN_RECEIVER, 1e18);
        DecoderCustomTypes.SVMExtraArgsV1 memory svmArgs = _defaultSvmArgs(SOLANA_TOKEN_RECEIVER);
        svmArgs.computeUnits = 1;
        message.extraArgs = abi.encodePacked(SVM_EXTRA_ARGS_V1_TAG, abi.encode(svmArgs));
        targetData[1] = _ccipSendCalldata(message);
        vm.expectRevert(
            bytes(abi.encodeWithSelector(CCIPDecoderAndSanitizer.CCIPDecoderAndSanitizer__NonZeroComputeUnits.selector))
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // Non empty accounts reverts.
        svmArgs = _defaultSvmArgs(SOLANA_TOKEN_RECEIVER);
        svmArgs.accounts = new bytes32[](1);
        message.extraArgs = abi.encodePacked(SVM_EXTRA_ARGS_V1_TAG, abi.encode(svmArgs));
        targetData[1] = _ccipSendCalldata(message);
        vm.expectRevert(
            bytes(abi.encodeWithSelector(CCIPDecoderAndSanitizer.CCIPDecoderAndSanitizer__NonEmptyAccounts.selector))
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // Non zero writable bitmap reverts.
        svmArgs = _defaultSvmArgs(SOLANA_TOKEN_RECEIVER);
        svmArgs.accountIsWritableBitmap = 1;
        message.extraArgs = abi.encodePacked(SVM_EXTRA_ARGS_V1_TAG, abi.encode(svmArgs));
        targetData[1] = _ccipSendCalldata(message);
        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(CCIPDecoderAndSanitizer.CCIPDecoderAndSanitizer__NonZeroWritableBitmap.selector)
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // Out of order execution must be true.
        svmArgs = _defaultSvmArgs(SOLANA_TOKEN_RECEIVER);
        svmArgs.allowOutOfOrderExecution = false;
        message.extraArgs = abi.encodePacked(SVM_EXTRA_ARGS_V1_TAG, abi.encode(svmArgs));
        targetData[1] = _ccipSendCalldata(message);
        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    CCIPDecoderAndSanitizer.CCIPDecoderAndSanitizer__OutOfOrderExecutionRequired.selector
                )
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // Receiver must be 32 zero bytes.
        message = _buildSvmMessage(SOLANA_TOKEN_RECEIVER, 1e18);
        message.receiver = abi.encode(bytes32(uint256(1)));
        targetData[1] = _ccipSendCalldata(message);
        vm.expectRevert(
            bytes(abi.encodeWithSelector(CCIPDecoderAndSanitizer.CCIPDecoderAndSanitizer__InvalidSVMReceiver.selector))
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        message.receiver = hex"";
        targetData[1] = _ccipSendCalldata(message);
        vm.expectRevert(
            bytes(abi.encodeWithSelector(CCIPDecoderAndSanitizer.CCIPDecoderAndSanitizer__InvalidSVMReceiver.selector))
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // Sending to a token receiver not committed to the leaf fails proof verification. Adding 1
        // perturbs the LOW 16 bytes (second committed slot).
        message = _buildSvmMessage(bytes32(uint256(SOLANA_TOKEN_RECEIVER) + 1), 1e18);
        targetData[1] = _ccipSendCalldata(message);
        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector,
                    targets[1],
                    targetData[1],
                    0
                )
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // Perturbing the HIGH 16 bytes (first committed slot) must also fail, proving both halves of
        // the 32 byte receiver are pinned -- not just the low half.
        message = _buildSvmMessage(SOLANA_TOKEN_RECEIVER ^ bytes32(uint256(1) << 248), 1e18);
        targetData[1] = _ccipSendCalldata(message);
        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector,
                    targets[1],
                    targetData[1],
                    0
                )
            )
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // Fix the message and the call now succeeds.
        message = _buildSvmMessage(SOLANA_TOKEN_RECEIVER, 1e18);
        targetData[1] = _ccipSendCalldata(message);
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testFuzz_SvmReceiverFullyCommitted(bytes32 svmTokenReceiver) external {
        // The decoder must commit the chain selector, BOTH halves of the 32 byte token receiver,
        // the token, and the fee token. The split must also be lossless so distinct receivers can
        // never collide onto the same leaf.
        vm.assume(svmTokenReceiver != bytes32(0));
        DecoderCustomTypes.EVM2AnyMessage memory message = _buildSvmMessage(svmTokenReceiver, 1e18);
        bytes memory sensitive =
            CCIPDecoderAndSanitizer(rawDataDecoderAndSanitizer).ccipSend(ccipSolanaChainSelector, message);

        // Derive the expected slots INDEPENDENTLY of the decoder's bytes20(bytes16(...)) expression,
        // using arithmetic shifts/masks, so a shared slicing bug cannot hide behind a mirror.
        // The high 16 bytes occupy the top of slot 0, the low 16 bytes the top of slot 1 (4 low bytes zero).
        address tokenReceiver0 = address(uint160((uint256(svmTokenReceiver) >> 128) << 32));
        address tokenReceiver1 = address(uint160((uint256(svmTokenReceiver) & type(uint128).max) << 32));
        address link = getAddress(sourceChain, "LINK");
        assertEq(
            sensitive,
            abi.encodePacked(address(uint160(ccipSolanaChainSelector)), tokenReceiver0, tokenReceiver1, link, link),
            "decoder must commit selector + both receiver halves + token + fee"
        );

        // Conservation / injectivity: recombine the two committed slots (top 16 bytes of each) and
        // assert they reproduce the full receiver, so no two distinct receivers can collide onto one leaf.
        uint256 recovered = ((uint256(uint160(tokenReceiver0)) >> 32) << 128) | (uint256(uint160(tokenReceiver1)) >> 32);
        assertEq(bytes32(recovered), svmTokenReceiver, "receiver split must be lossless / injective");
    }

    function testUsdtRouterApproveRace() external {
        // USDT approve() returns no value and reverts on a non-zero -> non-zero change. The bridge
        // approval leaf authorizes approve(router, *any amount*), so a (re)approval uses the reset
        // pattern. Prove the vault can run that pattern on USDT to the CCIP router through the merkle
        // flow. No ccipSend here, so this is independent of which tokens the SVM lane supports.
        ERC20 usdt = getERC20(sourceChain, "USDT");
        deal(address(usdt), address(boringVault), 1_000e6);

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        ERC20[] memory bridgeAssets = new ERC20[](1);
        bridgeAssets[0] = usdt;
        ERC20[] memory feeTokens = new ERC20[](1);
        feeTokens[0] = usdt;
        _addCcipSvmBridgeLeafs(leafs, ccipSolanaChainSelector, SOLANA_TOKEN_RECEIVER, bridgeAssets, feeTokens);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        // leafs[0] = approve USDT to the CCIP router.
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address router = getAddress(sourceChain, "ccipRouter");
        address[] memory targets = new address[](1);
        targets[0] = address(usdt);
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        bytes[] memory targetData = new bytes[](1);

        // 0 -> max succeeds (USDT returns no value; the vault uses a low-level call).
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", router, type(uint256).max);
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](1)
        );
        assertEq(usdt.allowance(address(boringVault), router), type(uint256).max, "USDT approved to router");

        // A naive non-zero -> non-zero re-approve reverts inside USDT: this is why a reset is needed.
        vm.expectRevert();
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](1)
        );

        // Reset to zero then re-approve; both calls are authorized by the same approval leaf.
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", router, 0);
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](1)
        );
        assertEq(usdt.allowance(address(boringVault), router), 0, "USDT allowance reset to zero");

        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", router, 500e6);
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](1)
        );
        assertEq(usdt.allowance(address(boringVault), router), 500e6, "USDT re-approved after reset");
    }

    function testSvmExtraArgsMatchesCanonicalCcipLayout() external {
        // Local source of truth for DecoderCustomTypes.SVMExtraArgsV1: the vendored @ccip submodule
        // predates SVM, so we pin the struct's ABI layout to chainlink-ccip v1.6's canonical
        // Client.SVMExtraArgsV1 here. Build the canonical encoding by hand (raw words in the documented
        // field order) and assert our struct's tagged encoding is byte-identical. A reorder/retype of
        // the struct breaks this locally, rather than only failing against the live router.
        DecoderCustomTypes.SVMExtraArgsV1 memory svmArgs = DecoderCustomTypes.SVMExtraArgsV1({
            computeUnits: 0,
            accountIsWritableBitmap: 0,
            allowOutOfOrderExecution: true,
            tokenReceiver: SOLANA_TOKEN_RECEIVER,
            accounts: new bytes32[](0)
        });
        bytes memory ours = abi.encodePacked(SVM_EXTRA_ARGS_V1_TAG, abi.encode(svmArgs));

        // Canonical tag ++ abi.encode(SVMExtraArgsV1): a dynamic struct, so abi.encode prefixes a 0x20
        // offset, then the 5 head words in field order (the dynamic `accounts` contributes a 0xa0 offset
        // to its tail), then the accounts length.
        bytes memory canonical = abi.encodePacked(
            SVM_EXTRA_ARGS_V1_TAG,
            bytes32(uint256(0x20)), // offset to the (dynamic) struct
            bytes32(uint256(0)), // computeUnits
            bytes32(uint256(0)), // accountIsWritableBitmap
            bytes32(uint256(1)), // allowOutOfOrderExecution = true
            SOLANA_TOKEN_RECEIVER, // tokenReceiver
            bytes32(uint256(0xa0)), // offset to accounts tail (5 head words)
            bytes32(uint256(0)) // accounts.length = 0
        );
        assertEq(ours, canonical, "SVMExtraArgsV1 ABI layout must match canonical chainlink-ccip v1.6");
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _defaultSvmArgs(bytes32 tokenReceiver)
        internal
        pure
        returns (DecoderCustomTypes.SVMExtraArgsV1 memory svmArgs)
    {
        svmArgs.computeUnits = 0;
        svmArgs.accountIsWritableBitmap = 0;
        svmArgs.allowOutOfOrderExecution = true;
        svmArgs.tokenReceiver = tokenReceiver;
        svmArgs.accounts = new bytes32[](0);
    }

    function _buildSvmMessage(bytes32 tokenReceiver, uint256 amount)
        internal
        view
        returns (DecoderCustomTypes.EVM2AnyMessage memory message)
    {
        // Token only transfers to SVM chains use the zero PDA as the receiver, the recipient is
        // committed via extraArgs.tokenReceiver.
        message.receiver = abi.encode(bytes32(0));
        message.data = "";
        message.tokenAmounts = new DecoderCustomTypes.EVMTokenAmount[](1);
        message.tokenAmounts[0].token = getAddress(sourceChain, "LINK");
        message.tokenAmounts[0].amount = amount;
        message.feeToken = getAddress(sourceChain, "LINK");
        message.extraArgs = abi.encodePacked(SVM_EXTRA_ARGS_V1_TAG, abi.encode(_defaultSvmArgs(tokenReceiver)));
    }

    function _ccipSendCalldata(DecoderCustomTypes.EVM2AnyMessage memory message) internal pure returns (bytes memory) {
        return abi.encodeWithSignature(
            "ccipSend(uint64,(bytes,bytes,(address,uint256)[],address,bytes))", ccipSolanaChainSelector, message
        );
    }

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
