// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {BridgingDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BridgingDecoderAndSanitizer.sol";
import {MPortalDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/MPortalDecoderAndSanitizer.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

interface MPortalProxy {
    function quote(uint32 destination, uint8 bridgeOperationType) external returns (uint256);
}

// forge test --match-path "test/integrations/MPortalIntegration.t.sol" -vvvv --skip "script/*" --skip "test/integrations/SymbioticIntegration.t.sol" --skip "test/integrations/SymbioticVaultIntegration.t.sol"
contract MPortalIntegrationTest is Test, MerkleTreeHelper {
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

    // Monad chain ID used by MPortal
    uint32 public constant MONAD_CHAIN_ID = 143;

    function setUp() external {
        setSourceChainName("mainnet");
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 25_084_515;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 6);

        manager = new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new BridgingDecoderAndSanitizer());

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(manager));

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(MANAGER_ROLE, address(boringVault), bytes4(keccak256(abi.encodePacked("manage(address,bytes,uint256)"))), true);
        rolesAuthority.setRoleCapability(MANAGER_ROLE, address(boringVault), bytes4(keccak256(abi.encodePacked("manage(address[],bytes[],uint256[])"))), true);
        rolesAuthority.setRoleCapability(STRATEGIST_ROLE, address(manager), ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector, true);
        rolesAuthority.setRoleCapability(MANGER_INTERNAL_ROLE, address(manager), ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector, true);
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(manager), ManagerWithMerkleVerification.setManageRoot.selector, true);
        rolesAuthority.setRoleCapability(BORING_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.flashLoan.selector, true);
        rolesAuthority.setRoleCapability(BALANCER_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.receiveFlashLoan.selector, true);

        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
        rolesAuthority.setUserRole(getAddress(sourceChain, "vault"), BALANCER_VAULT_ROLE, true);

        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);
    }

    function testMPortalBridgeMUSD() external {
        ERC20 mUSD = getERC20(sourceChain, "mUSD");
        address mportalProxy = getAddress(sourceChain, "mportalProxy");

        deal(address(mUSD), address(boringVault), 1000e6);
        deal(address(boringVault), 1 ether);

        // Recipient and refund go back to the vault (on the destination chain at the same address).
        bytes32 vaultAsBytes32 = bytes32(uint256(uint160(address(boringVault))));

        // destinationToken is mUSD on Monad — same EVM address, padded to bytes32.
        bytes32 destinationToken = bytes32(uint256(uint160(address(mUSD))));

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        _addMPortalLeafs(leafs, mportalProxy, mUSD, MONAD_CHAIN_ID, destinationToken, vaultAsBytes32, vaultAsBytes32);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0]; // approve
        manageLeafs[1] = leafs[1]; // sendToken

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = address(mUSD);
        targets[1] = mportalProxy;

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", mportalProxy, type(uint256).max);
        targetData[1] = abi.encodeWithSignature(
            "sendToken(uint256,address,uint32,bytes32,bytes32,bytes32,bytes)",
            10e6,
            address(mUSD),
            MONAD_CHAIN_ID,
            destinationToken,
            vaultAsBytes32,
            vaultAsBytes32,
            bytes("")
        );

        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = MPortalProxy(mportalProxy).quote(MONAD_CHAIN_ID, 0); // 0 is `TokenTransfer`

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256 balanceBefore = mUSD.balanceOf(address(boringVault));
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        assertLt(mUSD.balanceOf(address(boringVault)), balanceBefore, "mUSD should have left the vault");
    }

    function testMPortalBridgeMUSDCustomAdapter() external {
        ERC20 mUSD = getERC20(sourceChain, "mUSD");
        address mportalProxy = getAddress(sourceChain, "mportalProxy");
        address bridgeAdapter = 0xfCc1d596Ad6cAb0b5394eAa447d8626813180f32;

        deal(address(mUSD), address(boringVault), 1000e6);
        deal(address(boringVault), 1 ether);

        bytes32 vaultAsBytes32 = bytes32(uint256(uint160(address(boringVault))));
        bytes32 destinationToken = bytes32(uint256(uint160(address(mUSD))));

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        _addMPortalLeafs(leafs, mportalProxy, mUSD, MONAD_CHAIN_ID, destinationToken, vaultAsBytes32, vaultAsBytes32, bridgeAdapter);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0]; // approve
        manageLeafs[1] = leafs[1]; // sendToken (custom adapter overload)

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = address(mUSD);
        targets[1] = mportalProxy;

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", mportalProxy, type(uint256).max);
        targetData[1] = abi.encodeWithSignature(
            "sendToken(uint256,address,uint32,bytes32,bytes32,bytes32,address,bytes)",
            10e6,
            address(mUSD),
            MONAD_CHAIN_ID,
            destinationToken,
            vaultAsBytes32,
            vaultAsBytes32,
            bridgeAdapter,
            bytes("")
        );

        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = MPortalProxy(mportalProxy).quote(MONAD_CHAIN_ID, 0);

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256 balanceBefore = mUSD.balanceOf(address(boringVault));
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        assertLt(mUSD.balanceOf(address(boringVault)), balanceBefore, "mUSD should have left the vault");
    }

    // Proves the bridge-fee invariant: if the strategist underpays the MPortal quote by even 1 wei,
    // the whole batched manage call reverts and no tokens leave the vault. This guarantees the
    // approve+sendToken pair cannot split — tokens can never get stuck "approved but not bridged".
    function testMPortalBridgeRevertsOnUnderpaidFee() external {
        ERC20 mUSD = getERC20(sourceChain, "mUSD");
        address mportalProxy = getAddress(sourceChain, "mportalProxy");

        deal(address(mUSD), address(boringVault), 1000e6);
        deal(address(boringVault), 1 ether);

        (bytes32[][] memory manageProofs, address[] memory targets, bytes[] memory targetData, uint256[] memory values) =
            _buildUnderpaidCalldata(mUSD, mportalProxy);

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256 mUSDBefore = mUSD.balanceOf(address(boringVault));
        uint256 nativeBefore = address(boringVault).balance;
        uint256 allowanceBefore = mUSD.allowance(address(boringVault), mportalProxy);

        vm.expectRevert();
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // Atomicity: the entire batch reverted, so neither the approve nor the transfer took effect.
        assertEq(mUSD.balanceOf(address(boringVault)), mUSDBefore, "mUSD must not leave the vault on revert");
        assertEq(address(boringVault).balance, nativeBefore, "native must not leave the vault on revert");
        assertEq(mUSD.allowance(address(boringVault), mportalProxy), allowanceBefore, "approval must roll back on revert (no orphan allowance)");
    }

    // Extracted to keep testMPortalBridgeRevertsOnUnderpaidFee under solc 0.8.21's stack-depth limit.
    function _buildUnderpaidCalldata(ERC20 mUSD, address mportalProxy)
        internal
        returns (bytes32[][] memory manageProofs, address[] memory targets, bytes[] memory targetData, uint256[] memory values)
    {
        bytes32 vaultAsBytes32 = bytes32(uint256(uint160(address(boringVault))));
        bytes32 destinationToken = bytes32(uint256(uint160(address(mUSD))));

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        _addMPortalLeafs(leafs, mportalProxy, mUSD, MONAD_CHAIN_ID, destinationToken, vaultAsBytes32, vaultAsBytes32);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        manageProofs = _getProofsUsingTree(leafs, manageTree);

        targets = new address[](2);
        targets[0] = address(mUSD);
        targets[1] = mportalProxy;

        targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", mportalProxy, type(uint256).max);
        targetData[1] = abi.encodeWithSignature(
            "sendToken(uint256,address,uint32,bytes32,bytes32,bytes32,bytes)",
            10e6,
            address(mUSD),
            MONAD_CHAIN_ID,
            destinationToken,
            vaultAsBytes32,
            vaultAsBytes32,
            bytes("")
        );

        values = new uint256[](2);
        values[0] = 0;
        values[1] = MPortalProxy(mportalProxy).quote(MONAD_CHAIN_ID, 0) - 1; // underpay by exactly 1 wei
    }

    // ========================================= NEGATIVE TESTS =========================================

    // Proves the recipient is fully pinned in the leaf: swapping it for an attacker-controlled
    // bytes32 makes proof verification fail before any state change.
    function testMPortalRevertsWrongRecipient() external {
        ERC20 mUSD = getERC20(sourceChain, "mUSD");
        address mportalProxy = getAddress(sourceChain, "mportalProxy");
        deal(address(mUSD), address(boringVault), 1000e6);
        deal(address(boringVault), 1 ether);

        bytes32 vaultAsBytes32 = bytes32(uint256(uint160(address(boringVault))));
        bytes32 attackerAsBytes32 = bytes32(uint256(uint160(address(0xdeadbeef))));

        (bytes32[][] memory manageProofs, address[] memory targets, bytes[] memory targetData, uint256[] memory values) =
            _buildCalldataWithMismatchedRecipient(mUSD, mportalProxy, vaultAsBytes32, attackerAsBytes32);

        uint256 mUSDBefore = mUSD.balanceOf(address(boringVault));
        vm.expectRevert();
        manager.manageVaultWithMerkleVerification(manageProofs, _twoDecoders(), targets, targetData, values);
        assertEq(mUSD.balanceOf(address(boringVault)), mUSDBefore, "mUSD must not leave the vault");
    }

    // Proves the full 32 bytes of recipient are pinned — not just the bottom 20. The call uses a
    // recipient with the same lower 20 bytes as the leaf's recipient but non-zero upper 12 bytes
    // (the "non-EVM shape"). Without the two-slot split in the decoder, this would pass.
    function testMPortalRevertsWrongRecipientUpperBytes() external {
        ERC20 mUSD = getERC20(sourceChain, "mUSD");
        address mportalProxy = getAddress(sourceChain, "mportalProxy");
        deal(address(mUSD), address(boringVault), 1000e6);
        deal(address(boringVault), 1 ether);

        bytes32 vaultAsBytes32 = bytes32(uint256(uint160(address(boringVault))));
        // 96 bits of junk in the upper 12 bytes, lower 20 bytes equal to the vault address.
        bytes32 vaultWithJunkUpper = bytes32((uint256(0xdeadbeefdeadbeefdeadbeef) << 160) | uint256(uint160(address(boringVault))));
        require(vaultWithJunkUpper != vaultAsBytes32, "test setup: bytes32 must differ from leaf value");

        (bytes32[][] memory manageProofs, address[] memory targets, bytes[] memory targetData, uint256[] memory values) =
            _buildCalldataWithMismatchedRecipient(mUSD, mportalProxy, vaultAsBytes32, vaultWithJunkUpper);

        uint256 mUSDBefore = mUSD.balanceOf(address(boringVault));
        vm.expectRevert();
        manager.manageVaultWithMerkleVerification(manageProofs, _twoDecoders(), targets, targetData, values);
        assertEq(mUSD.balanceOf(address(boringVault)), mUSDBefore, "mUSD must not leave the vault");
    }

    // Proves destinationChainId is pinned in the leaf: the leaf authorizes a bridge to Monad,
    // but the strategist submits a call for a different chain. Proof verification must fail.
    function testMPortalRevertsWrongDestinationChain() external {
        ERC20 mUSD = getERC20(sourceChain, "mUSD");
        address mportalProxy = getAddress(sourceChain, "mportalProxy");
        deal(address(mUSD), address(boringVault), 1000e6);
        deal(address(boringVault), 1 ether);

        (bytes32[][] memory manageProofs, address[] memory targets, bytes[] memory targetData, uint256[] memory values) =
            _buildCalldataWithMismatchedChainId(mUSD, mportalProxy, MONAD_CHAIN_ID, MONAD_CHAIN_ID + 1);

        uint256 mUSDBefore = mUSD.balanceOf(address(boringVault));
        vm.expectRevert();
        manager.manageVaultWithMerkleVerification(manageProofs, _twoDecoders(), targets, targetData, values);
        assertEq(mUSD.balanceOf(address(boringVault)), mUSDBefore, "mUSD must not leave the vault");
    }

    // Proves the decoder rejects non-empty bridgeAdapterArgs — the freeform bytes blob that
    // would otherwise smuggle behavior past the merkle sanitization.
    function testMPortalRevertsNonEmptyBridgeAdapterArgs() external {
        ERC20 mUSD = getERC20(sourceChain, "mUSD");
        address mportalProxy = getAddress(sourceChain, "mportalProxy");
        deal(address(mUSD), address(boringVault), 1000e6);
        deal(address(boringVault), 1 ether);

        (bytes32[][] memory manageProofs, address[] memory targets, bytes[] memory targetData, uint256[] memory values) =
            _buildCalldataWithBridgeArgs(mUSD, mportalProxy, hex"deadbeef");

        vm.expectRevert(MPortalDecoderAndSanitizer.MPortalDecoderAndSanitizer__NonEmptyBridgeAdapterArgs.selector);
        manager.manageVaultWithMerkleVerification(manageProofs, _twoDecoders(), targets, targetData, values);
    }

    // Proves the bridge adapter is pinned in the custom-adapter overload's leaf: swapping it
    // for any other address fails proof verification.
    function testMPortalRevertsWrongBridgeAdapterCustomOverload() external {
        ERC20 mUSD = getERC20(sourceChain, "mUSD");
        address mportalProxy = getAddress(sourceChain, "mportalProxy");
        address leafAdapter = 0xfCc1d596Ad6cAb0b5394eAa447d8626813180f32;
        address callAdapter = address(0xbaDBAdbADbaDBADBAdBaDbaDbadBAdbaDbaDbadb);
        deal(address(mUSD), address(boringVault), 1000e6);
        deal(address(boringVault), 1 ether);

        (bytes32[][] memory manageProofs, address[] memory targets, bytes[] memory targetData, uint256[] memory values) =
            _buildCalldataCustomAdapter(mUSD, mportalProxy, leafAdapter, callAdapter);

        uint256 mUSDBefore = mUSD.balanceOf(address(boringVault));
        vm.expectRevert();
        manager.manageVaultWithMerkleVerification(manageProofs, _twoDecoders(), targets, targetData, values);
        assertEq(mUSD.balanceOf(address(boringVault)), mUSDBefore, "mUSD must not leave the vault");
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _twoDecoders() internal view returns (address[] memory d) {
        d = new address[](2);
        d[0] = rawDataDecoderAndSanitizer;
        d[1] = rawDataDecoderAndSanitizer;
    }

    function _buildCalldataWithMismatchedRecipient(ERC20 mUSD, address mportalProxy, bytes32 leafRecipient, bytes32 callRecipient)
        internal
        returns (bytes32[][] memory manageProofs, address[] memory targets, bytes[] memory targetData, uint256[] memory values)
    {
        bytes32 destinationToken = bytes32(uint256(uint160(address(mUSD))));

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        _addMPortalLeafs(leafs, mportalProxy, mUSD, MONAD_CHAIN_ID, destinationToken, leafRecipient, leafRecipient);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        manageProofs = _getProofsUsingTree(leafs, manageTree);

        targets = new address[](2);
        targets[0] = address(mUSD);
        targets[1] = mportalProxy;

        targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", mportalProxy, type(uint256).max);
        targetData[1] = abi.encodeWithSignature(
            "sendToken(uint256,address,uint32,bytes32,bytes32,bytes32,bytes)",
            10e6,
            address(mUSD),
            MONAD_CHAIN_ID,
            destinationToken,
            callRecipient,
            leafRecipient, // refundAddress matches the leaf — only recipient is swapped
            bytes("")
        );

        values = new uint256[](2);
        values[1] = MPortalProxy(mportalProxy).quote(MONAD_CHAIN_ID, 0);
    }

    function _buildCalldataWithMismatchedChainId(ERC20 mUSD, address mportalProxy, uint32 leafChainId, uint32 callChainId)
        internal
        returns (bytes32[][] memory manageProofs, address[] memory targets, bytes[] memory targetData, uint256[] memory values)
    {
        bytes32 vaultAsBytes32 = bytes32(uint256(uint160(address(boringVault))));
        bytes32 destinationToken = bytes32(uint256(uint160(address(mUSD))));

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        _addMPortalLeafs(leafs, mportalProxy, mUSD, leafChainId, destinationToken, vaultAsBytes32, vaultAsBytes32);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        manageProofs = _getProofsUsingTree(leafs, manageTree);

        targets = new address[](2);
        targets[0] = address(mUSD);
        targets[1] = mportalProxy;

        targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", mportalProxy, type(uint256).max);
        targetData[1] = abi.encodeWithSignature(
            "sendToken(uint256,address,uint32,bytes32,bytes32,bytes32,bytes)",
            10e6,
            address(mUSD),
            callChainId,
            destinationToken,
            vaultAsBytes32,
            vaultAsBytes32,
            bytes("")
        );

        values = new uint256[](2);
        values[1] = MPortalProxy(mportalProxy).quote(leafChainId, 0);
    }

    function _buildCalldataWithBridgeArgs(ERC20 mUSD, address mportalProxy, bytes memory callBridgeArgs)
        internal
        returns (bytes32[][] memory manageProofs, address[] memory targets, bytes[] memory targetData, uint256[] memory values)
    {
        bytes32 vaultAsBytes32 = bytes32(uint256(uint160(address(boringVault))));
        bytes32 destinationToken = bytes32(uint256(uint160(address(mUSD))));

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        _addMPortalLeafs(leafs, mportalProxy, mUSD, MONAD_CHAIN_ID, destinationToken, vaultAsBytes32, vaultAsBytes32);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        manageProofs = _getProofsUsingTree(leafs, manageTree);

        targets = new address[](2);
        targets[0] = address(mUSD);
        targets[1] = mportalProxy;

        targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", mportalProxy, type(uint256).max);
        targetData[1] = abi.encodeWithSignature(
            "sendToken(uint256,address,uint32,bytes32,bytes32,bytes32,bytes)",
            10e6,
            address(mUSD),
            MONAD_CHAIN_ID,
            destinationToken,
            vaultAsBytes32,
            vaultAsBytes32,
            callBridgeArgs
        );

        values = new uint256[](2);
        values[1] = MPortalProxy(mportalProxy).quote(MONAD_CHAIN_ID, 0);
    }

    function _buildCalldataCustomAdapter(ERC20 mUSD, address mportalProxy, address leafAdapter, address callAdapter)
        internal
        returns (bytes32[][] memory manageProofs, address[] memory targets, bytes[] memory targetData, uint256[] memory values)
    {
        bytes32 vaultAsBytes32 = bytes32(uint256(uint160(address(boringVault))));
        bytes32 destinationToken = bytes32(uint256(uint160(address(mUSD))));

        // Isolated to keep the 8-arg _addMPortalLeafs call out of this stack frame
        // (solc 0.8.21 hits stack-too-deep otherwise).
        manageProofs = _customAdapterProofs(mUSD, mportalProxy, destinationToken, vaultAsBytes32, leafAdapter);

        targets = new address[](2);
        targets[0] = address(mUSD);
        targets[1] = mportalProxy;

        targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", mportalProxy, type(uint256).max);
        targetData[1] = abi.encodeWithSignature(
            "sendToken(uint256,address,uint32,bytes32,bytes32,bytes32,address,bytes)",
            10e6,
            address(mUSD),
            MONAD_CHAIN_ID,
            destinationToken,
            vaultAsBytes32,
            vaultAsBytes32,
            callAdapter, // adapter in calldata differs from the one pinned in the leaf
            bytes("")
        );

        values = new uint256[](2);
        values[1] = MPortalProxy(mportalProxy).quote(MONAD_CHAIN_ID, 0);
    }

    function _customAdapterProofs(ERC20 mUSD, address mportalProxy, bytes32 destinationToken, bytes32 vaultAsBytes32, address leafAdapter)
        private
        returns (bytes32[][] memory manageProofs)
    {
        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        _addMPortalLeafs(leafs, mportalProxy, mUSD, MONAD_CHAIN_ID, destinationToken, vaultAsBytes32, vaultAsBytes32, leafAdapter);
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        manageProofs = _getProofsUsingTree(leafs, manageTree);
    }

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
