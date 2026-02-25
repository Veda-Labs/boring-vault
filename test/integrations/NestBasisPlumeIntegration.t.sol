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
import {AtomicQueue} from "src/archive/atomic-queue/AtomicQueue.sol";
import {NestBasisPlumeDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/NestBasisPlumeDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract NestBasisPlumeIntegrationTest is Test, MerkleTreeHelper {
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

    // Plume addresses
    address public predicateProxy;
    address public nBASISTeller;
    address public atomicQueue = 0x228C44Bb4885C6633F4b6C83f14622f37D5112E5;
    ERC20 public nativeUSDC;
    ERC20 public nBASIS;
    ERC20 public pUSD;

    function setUp() external {
        setSourceChainName(plume);
        string memory rpcKey = "PLUME_RPC_URL";
        uint256 blockNumber = 51924034;
        _startFork(rpcKey, blockNumber);

        // Deploy BoringVault at the approved depositor address for nBASIS (not yet deployed on-chain)
        address targetAddr = 0x08c6F91e2B681FaF5e17227F2a44C307b3C1364C;
        deployCodeTo(
            "BoringVault.sol:BoringVault",
            abi.encode(address(this), "EtherFi Liquid USD V0.0", "liquidUSD", uint8(18)),
            targetAddr
        );
        boringVault = BoringVault(payable(targetAddr));

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);

        // Plume has no Balancer vault, use address(1) as placeholder
        manager = new ManagerWithMerkleVerification(address(this), address(boringVault), address(1));

        rawDataDecoderAndSanitizer = address(new NestBasisPlumeDecoderAndSanitizer());

        setAddress(false, plume, "boringVault", address(boringVault));
        setAddress(false, plume, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, plume, "manager", address(manager));
        setAddress(false, plume, "managerAddress", address(manager));
        setAddress(false, plume, "accountantAddress", address(1));

        manager.setAuthority(rolesAuthority);

        // Setup roles authority
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

        // Cache addresses
        predicateProxy = getAddress(plume, "nBASISPredicateProxy");
        nBASISTeller = getAddress(plume, "nBASISTeller");
        nativeUSDC = getERC20(plume, "nativeUSDC");
        pUSD = ERC20(0xdddD73F5Df1F0DC31373357beAC77545dC5A6f3F);
        nBASIS = getERC20(plume, "nBASIS");
    }

    function testPredicateProxyDeposit() external {
        // Give the boring vault some native USDC to deposit
        deal(address(nativeUSDC), address(boringVault), 1_000e6);

        // Build leafs: approve USDC to predicate proxy + deposit
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addPredicateProxyDepositLeafs(leafs, predicateProxy, nativeUSDC, address(boringVault), nBASISTeller);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = address(nativeUSDC);
        targets[1] = predicateProxy;

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", predicateProxy, type(uint256).max);
        // Predicate compliance proof
        address[] memory signerAddresses = new address[](1);
        signerAddresses[0] = 0x5f936C12E43181662e85814b0cFd10334A33E5A1;

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = hex"7b368ae3e0a6508c69f051b777f2c837c9ca6247eac9cf97b4d5de6cf3e6f9ea67253d8f70db2a7c4df2b8a0ec506e3756678b03f2e3f1cef055d8ff078e04431c";

        DecoderCustomTypes.PredicateMessage memory predicateMessage = DecoderCustomTypes.PredicateMessage({
            taskId: "0bb95ac6-ed8c-4d00-bd54-d3a4cf956412",
            expireByBlockNumber: 1771987594,
            signerAddresses: signerAddresses,
            signatures: signatures
        });

        targetData[1] = abi.encodeWithSignature(
            "deposit(address,uint256,uint256,address,address,(string,uint256,address[],bytes[]))",
            address(nativeUSDC),
            1_000e6,
            0,
            address(boringVault),
            nBASISTeller,
            predicateMessage
        );

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testPredicateProxyDepositPUSD() external {
        // Give the boring vault some pUSD to deposit
        deal(address(pUSD), address(boringVault), 1_000e6);

        // Build leafs: approve pUSD to predicate proxy + deposit
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addPredicateProxyDepositLeafs(leafs, predicateProxy, pUSD, address(boringVault), nBASISTeller);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = address(pUSD);
        targets[1] = predicateProxy;

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", predicateProxy, type(uint256).max);

        // Predicate compliance proof
        address[] memory signerAddresses = new address[](1);
        signerAddresses[0] = 0x5f936C12E43181662e85814b0cFd10334A33E5A1;

        bytes[] memory signatures = new bytes[](1);
        signatures[0] = hex"7b368ae3e0a6508c69f051b777f2c837c9ca6247eac9cf97b4d5de6cf3e6f9ea67253d8f70db2a7c4df2b8a0ec506e3756678b03f2e3f1cef055d8ff078e04431c";

        DecoderCustomTypes.PredicateMessage memory predicateMessage = DecoderCustomTypes.PredicateMessage({
            taskId: "0bb95ac6-ed8c-4d00-bd54-d3a4cf956412",
            expireByBlockNumber: 1771987594,
            signerAddresses: signerAddresses,
            signatures: signatures
        });

        targetData[1] = abi.encodeWithSignature(
            "deposit(address,uint256,uint256,address,address,(string,uint256,address[],bytes[]))",
            address(pUSD),
            1_000e6,
            0,
            address(boringVault),
            nBASISTeller,
            predicateMessage
        );

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testAtomicQueueWithdrawal() external {
        // Give the boring vault some nBASIS tokens
        deal(address(nBASIS), address(boringVault), 100e18);

        // Build leafs: approve nBASIS to atomic queue + updateAtomicRequest
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addAtomicQueueLeafs(leafs, atomicQueue, nBASIS, nativeUSDC);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = address(nBASIS);
        targets[1] = atomicQueue;

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", atomicQueue, type(uint256).max);

        AtomicQueue.AtomicRequest memory request = AtomicQueue.AtomicRequest({
            deadline: uint64(block.timestamp + 1 days),
            atomicPrice: uint88(1e6), // 1 USDC per nBASIS (6 decimals)
            offerAmount: uint96(10e18),
            inSolve: false
        });
        targetData[1] = abi.encodeWithSignature(
            "updateAtomicRequest(address,address,(uint64,uint88,uint96,bool))", nBASIS, nativeUSDC, request
        );

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testFullMerkleTreeVerification() external {
        // Build the complete merkle tree matching what the MerkleRoot script generates
        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // Fee claiming
        ERC20[] memory feeAssets = new ERC20[](1);
        feeAssets[0] = nativeUSDC;
        _addLeafsForFeeClaiming(leafs, getAddress(plume, "accountantAddress"), feeAssets, true);

        // PredicateProxy deposit
        _addPredicateProxyDepositLeafs(leafs, predicateProxy, nativeUSDC, address(boringVault), nBASISTeller);

        // AtomicQueue withdrawal
        _addAtomicQueueLeafs(leafs, atomicQueue, nBASIS, nativeUSDC);

        // Verify all leafs can be decoded by the decoder
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        // Generate tree and set root
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
