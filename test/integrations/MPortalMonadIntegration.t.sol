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
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

interface MPortalProxy {
    function quote(uint32 destination, uint8 bridgeOperationType) external returns (uint256);
}

// forge test --match-path "test/integrations/MPortalMonadIntegration.t.sol" -vvvv --skip "script/*" --skip "test/integrations/SymbioticIntegration.t.sol" --skip "test/integrations/SymbioticVaultIntegration.t.sol"
contract MPortalMonadIntegrationTest is Test, MerkleTreeHelper {
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

    // Ethereum mainnet chain ID used by MPortal as destination.
    uint32 public constant MAINNET_CHAIN_ID = 1;

    function setUp() external {
        setSourceChainName("monad");
        string memory rpcKey = "MONAD_RPC_URL";
        uint256 blockNumber = 74_290_598;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 6);

        // The local manager uses Balancer vault as its flash-loan source. Monad has no Balancer
        // deployment, but this test doesn't exercise flash loans, so the address only needs to be
        // a stable role assignment target — mainnet's value is reused for parity with the existing test.
        manager = new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress("mainnet", "vault"));

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

        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);
    }

    function testMPortalBridgeMUSDFromMonad() external {
        ERC20 mUSD = getERC20(sourceChain, "mUSD");
        address mportalProxy = getAddress(sourceChain, "mportalProxy");

        deal(address(mUSD), address(boringVault), 1000e6);
        deal(address(boringVault), 100 ether); // Monad->mainnet quote is ~8 MON; leave headroom.

        // Recipient and refund go back to the vault (on mainnet at the same address).
        bytes32 vaultAsBytes32 = bytes32(uint256(uint160(address(boringVault))));

        // destinationToken is mUSD on mainnet — same EVM address, padded to bytes32.
        bytes32 destinationToken = bytes32(uint256(uint160(address(mUSD))));

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        _addMPortalLeafs(leafs, mportalProxy, mUSD, MAINNET_CHAIN_ID, destinationToken, vaultAsBytes32, vaultAsBytes32);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0]; // approve
        manageLeafs[1] = leafs[1]; // sendToken (default adapter)

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
            MAINNET_CHAIN_ID,
            destinationToken,
            vaultAsBytes32,
            vaultAsBytes32,
            bytes("")
        );

        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = MPortalProxy(mportalProxy).quote(MAINNET_CHAIN_ID, 0); // 0 is `TokenTransfer`

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256 balanceBefore = mUSD.balanceOf(address(boringVault));
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        assertLt(mUSD.balanceOf(address(boringVault)), balanceBefore, "mUSD should have left the vault");
    }

    function testMPortalBridgeMUSDFromMonadCustomAdapter() external {
        ERC20 mUSD = getERC20(sourceChain, "mUSD");
        address mportalProxy = getAddress(sourceChain, "mportalProxy");
        address bridgeAdapter = 0xfCc1d596Ad6cAb0b5394eAa447d8626813180f32;

        deal(address(mUSD), address(boringVault), 1000e6);
        deal(address(boringVault), 100 ether); // Monad->mainnet quote is ~8 MON; leave headroom.

        bytes32 vaultAsBytes32 = bytes32(uint256(uint160(address(boringVault))));
        bytes32 destinationToken = bytes32(uint256(uint160(address(mUSD))));

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        _addMPortalLeafs(leafs, mportalProxy, mUSD, MAINNET_CHAIN_ID, destinationToken, vaultAsBytes32, vaultAsBytes32, bridgeAdapter);

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
            MAINNET_CHAIN_ID,
            destinationToken,
            vaultAsBytes32,
            vaultAsBytes32,
            bridgeAdapter,
            bytes("")
        );

        uint256[] memory values = new uint256[](2);
        values[0] = 0;
        values[1] = MPortalProxy(mportalProxy).quote(MAINNET_CHAIN_ID, 0);

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256 balanceBefore = mUSD.balanceOf(address(boringVault));
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        assertLt(mUSD.balanceOf(address(boringVault)), balanceBefore, "mUSD should have left the vault");
    }

    // Proves the bridge-fee invariant on the Monad->mainnet leg: if the strategist underpays the
    // MPortal quote by even 1 wei, the whole batched manage call reverts and no tokens leave
    // the vault. Mirrors the mainnet-side test so both directions enforce the same atomicity.
    function testMPortalBridgeFromMonadRevertsOnUnderpaidFee() external {
        ERC20 mUSD = getERC20(sourceChain, "mUSD");
        address mportalProxy = getAddress(sourceChain, "mportalProxy");

        deal(address(mUSD), address(boringVault), 1000e6);
        deal(address(boringVault), 100 ether);

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

    // Extracted to keep testMPortalBridgeFromMonadRevertsOnUnderpaidFee under solc 0.8.21's stack-depth limit.
    function _buildUnderpaidCalldata(ERC20 mUSD, address mportalProxy)
        internal
        returns (bytes32[][] memory manageProofs, address[] memory targets, bytes[] memory targetData, uint256[] memory values)
    {
        bytes32 vaultAsBytes32 = bytes32(uint256(uint160(address(boringVault))));
        bytes32 destinationToken = bytes32(uint256(uint160(address(mUSD))));

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        _addMPortalLeafs(leafs, mportalProxy, mUSD, MAINNET_CHAIN_ID, destinationToken, vaultAsBytes32, vaultAsBytes32);

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
            MAINNET_CHAIN_ID,
            destinationToken,
            vaultAsBytes32,
            vaultAsBytes32,
            bytes("")
        );

        values = new uint256[](2);
        values[0] = 0;
        values[1] = MPortalProxy(mportalProxy).quote(MAINNET_CHAIN_ID, 0) - 1; // underpay by exactly 1 wei
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
