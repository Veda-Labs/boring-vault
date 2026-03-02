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
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

interface ITBPositionManager {
    function executors(address) external view returns (bool);
    function addExecutor(address) external;
    function owner() external view returns (address);
}

contract ITBBasePositionAddExecutorIntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    // Real sentoraUSDC on-chain contracts
    BoringVault public boringVault = BoringVault(payable(0x9761DDF8e79930b334f1Be1BD93aBE3695061CcA));
    ManagerWithMerkleVerification public manager =
        ManagerWithMerkleVerification(0x38Fe609799ED585e9154c92D1D801B461F538753);
    address public itbDecoderAndSanitizer = 0x2D7085602a85aFb417AE1dFcEc09C301FeC8Df36;
    ITBPositionManager public morphoPYUSDPositionManager =
        ITBPositionManager(0xC5e0E2Bd8B8663c621b5051d863D072295dA9720);

    address public executor = address(0xCAFE);

    function setUp() external {
        setSourceChainName("mainnet");
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 24570777;

        _startFork(rpcKey, blockNumber);

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", itbDecoderAndSanitizer);
    }

    function testAddExecutor() external {
        ManageLeaf[] memory leafs = new ManageLeaf[](8);

        // addExecutor leaf
        unchecked { leafIndex++; }
        leafs[leafIndex] = ManageLeaf(
            address(morphoPYUSDPositionManager),
            false,
            "addExecutor(address)",
            new address[](1),
            "Add executor to Morpho PYUSD ITB Position Manager",
            itbDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = executor;

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        // Set the manage root as the strategist (owner of manager)
        address managerOwner = manager.owner();
        vm.prank(managerOwner);
        manager.setManageRoot(managerOwner, manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = address(morphoPYUSDPositionManager);

        bytes[] memory targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature("addExecutor(address)", executor);

        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = itbDecoderAndSanitizer;

        uint256[] memory values = new uint256[](1);

        vm.prank(managerOwner);
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        assertTrue(morphoPYUSDPositionManager.executors(executor), "Executor should have been added");
    }

    function testAddExecutorRevertsWithWrongAddress() external {
        leafIndex = type(uint256).max;
        ManageLeaf[] memory leafs = new ManageLeaf[](8);

        // addExecutor leaf - only allows `executor` address
        unchecked { leafIndex++; }
        leafs[leafIndex] = ManageLeaf(
            address(morphoPYUSDPositionManager),
            false,
            "addExecutor(address)",
            new address[](1),
            "Add executor to Morpho PYUSD ITB Position Manager",
            itbDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = executor;

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        address managerOwner = manager.owner();
        vm.prank(managerOwner);
        manager.setManageRoot(managerOwner, manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0];
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = address(morphoPYUSDPositionManager);

        // Use a different address than what was approved in the merkle tree
        address wrongExecutor = address(0xDEAD);
        bytes[] memory targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature("addExecutor(address)", wrongExecutor);

        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = itbDecoderAndSanitizer;

        uint256[] memory values = new uint256[](1);

        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector,
                targets[0],
                targetData[0],
                uint256(0)
            )
        );
        vm.prank(managerOwner);
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
