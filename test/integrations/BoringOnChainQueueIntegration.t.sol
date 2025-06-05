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
import {TellerDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/TellerDecoderAndSanitizer.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {DelayedWithdraw} from "src/base/Roles/DelayedWithdraw.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract BoringOnChainQueueIntegration is Test, MerkleTreeHelper {
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
    uint8 public constant BURNER_ROLE = 8;

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 21580030;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new FullBoringVaultDecoder());

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(1));

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

        //eBTC roles authority

        RolesAuthority eBTCAuth =
            RolesAuthority(address(BoringVault(payable(getAddress(sourceChain, "eBTC"))).authority()));
        vm.startPrank(eBTCAuth.owner());
        eBTCAuth.setPublicCapability(
            getAddress(sourceChain, "eBTCDelayedWithdraw"), DelayedWithdraw.requestWithdraw.selector, true
        );
        //eBTCAuth.setUserRole(getAddress(sourceChain, "eBTCDelayedWithdraw"), BURNER_ROLE, true);
        vm.stopPrank();
    }

    function testBoringOnChainQueueWithdraw() external {
        deal(getAddress(sourceChain, "eBTC"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "WBTC"), address(boringVault), 100e8);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory assets = new ERC20[](1);
        assets[0] = getERC20(sourceChain, "WBTC");
        _addTellerLeafs(leafs, getAddress(sourceChain, "eBTCTeller"), assets, false, true);
        _addWithdrawQueueLeafs(
            leafs, getAddress(sourceChain, "eBTCOnChainQueue"), getAddress(sourceChain, "eBTC"), assets
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](4);
        manageLeafs[0] = leafs[0]; //approve
        manageLeafs[1] = leafs[3]; //deposit
        manageLeafs[2] = leafs[4]; //approve queue
        manageLeafs[3] = leafs[5]; //withdraw w/ queue

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](4);
        targets[0] = getAddress(sourceChain, "WBTC");
        targets[1] = getAddress(sourceChain, "eBTCTeller");
        targets[2] = getAddress(sourceChain, "eBTC");
        targets[3] = getAddress(sourceChain, "eBTCOnChainQueue");

        bytes[] memory targetData = new bytes[](4);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "eBTC"), type(uint256).max);
        targetData[1] =
            abi.encodeWithSignature("deposit(address,uint256,uint256)", getAddress(sourceChain, "WBTC"), 100e8, 0);
        targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "eBTCOnChainQueue"), type(uint256).max
        );
        targetData[3] = abi.encodeWithSignature(
            "requestOnChainWithdraw(address,uint128,uint16,uint24)",
            getAddress(sourceChain, "WBTC"),
            uint128(100e8),
            uint16(100),
            uint24(2592000)
        );

        address[] memory decodersAndSanitizers = new address[](4);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](4);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testBoringOnChainQueueCancel() external {
        //deal(getAddress(sourceChain, "eBTC"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "WBTC"), address(boringVault), 100e8);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory assets = new ERC20[](1);
        assets[0] = getERC20(sourceChain, "WBTC");
        _addTellerLeafs(leafs, getAddress(sourceChain, "eBTCTeller"), assets, false, true);
        _addWithdrawQueueLeafs(
            leafs, getAddress(sourceChain, "eBTCOnChainQueue"), getAddress(sourceChain, "eBTC"), assets
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](5);
        manageLeafs[0] = leafs[0]; //approve
        manageLeafs[1] = leafs[3]; //deposit
        manageLeafs[2] = leafs[4]; //approve queue
        manageLeafs[3] = leafs[5]; //withdraw w/ queue
        manageLeafs[4] = leafs[6]; //cancel request

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](5);
        targets[0] = getAddress(sourceChain, "WBTC");
        targets[1] = getAddress(sourceChain, "eBTCTeller");
        targets[2] = getAddress(sourceChain, "eBTC");
        targets[3] = getAddress(sourceChain, "eBTCOnChainQueue");
        targets[4] = getAddress(sourceChain, "eBTCOnChainQueue");

        bytes[] memory targetData = new bytes[](5);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "eBTC"), type(uint256).max);
        targetData[1] =
            abi.encodeWithSignature("deposit(address,uint256,uint256)", getAddress(sourceChain, "WBTC"), 100e8, 0);
        targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "eBTCOnChainQueue"), type(uint256).max
        );
        targetData[3] = abi.encodeWithSignature(
            "requestOnChainWithdraw(address,uint128,uint16,uint24)",
            getAddress(sourceChain, "WBTC"),
            uint128(9970000000),
            uint16(100),
            uint24(2592000)
        );
        
        //uint96 nonce = vm.getNonce(address(boringVault));         

        DecoderCustomTypes.OnChainWithdraw memory request = DecoderCustomTypes.OnChainWithdraw(
            1,
            address(boringVault),
            getAddress(sourceChain, "WBTC"),
            uint128(9970000000),
            uint128(9870300000),
            uint40(1736342615),
            uint24(43200),
            uint24(2592000)
        ); 

        targetData[4] = abi.encodeWithSignature(
            "cancelOnChainWithdraw((uint96,address,address,uint128,uint128,uint40,uint24,uint24))",
            request
        );

        address[] memory decodersAndSanitizers = new address[](5);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](5);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        uint256 eBTCSharesAmount = getERC20(sourceChain, "eBTC").balanceOf(address(boringVault)); 
        assertEq(eBTCSharesAmount, 9970000000); 
    }

    function testBoringOnChainQueueReplace() external {
        //deal(getAddress(sourceChain, "eBTC"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "WBTC"), address(boringVault), 100e8);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory assets = new ERC20[](1);
        assets[0] = getERC20(sourceChain, "WBTC");
        _addTellerLeafs(leafs, getAddress(sourceChain, "eBTCTeller"), assets, false, true);
        _addWithdrawQueueLeafs(
            leafs, getAddress(sourceChain, "eBTCOnChainQueue"), getAddress(sourceChain, "eBTC"), assets
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](5);
        manageLeafs[0] = leafs[0]; //approve
        manageLeafs[1] = leafs[3]; //deposit
        manageLeafs[2] = leafs[4]; //approve queue
        manageLeafs[3] = leafs[5]; //withdraw w/ queue
        manageLeafs[4] = leafs[7]; //cancel request

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](5);
        targets[0] = getAddress(sourceChain, "WBTC");
        targets[1] = getAddress(sourceChain, "eBTCTeller");
        targets[2] = getAddress(sourceChain, "eBTC");
        targets[3] = getAddress(sourceChain, "eBTCOnChainQueue");
        targets[4] = getAddress(sourceChain, "eBTCOnChainQueue");

        bytes[] memory targetData = new bytes[](5);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "eBTC"), type(uint256).max);
        targetData[1] =
            abi.encodeWithSignature("deposit(address,uint256,uint256)", getAddress(sourceChain, "WBTC"), 100e8, 0);
        targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "eBTCOnChainQueue"), type(uint256).max
        );
        targetData[3] = abi.encodeWithSignature(
            "requestOnChainWithdraw(address,uint128,uint16,uint24)",
            getAddress(sourceChain, "WBTC"),
            uint128(9970000000),
            uint16(100),
            uint24(2592000)
        );
        
        //uint96 nonce = vm.getNonce(address(boringVault));         

        DecoderCustomTypes.OnChainWithdraw memory request = DecoderCustomTypes.OnChainWithdraw(
            1,
            address(boringVault),
            getAddress(sourceChain, "WBTC"),
            uint128(9970000000),
            uint128(9870300000),
            uint40(1736342615),
            uint24(43200),
            uint24(2592000)
        ); 

        targetData[4] = abi.encodeWithSignature(
            "replaceOnChainWithdraw((uint96,address,address,uint128,uint128,uint40,uint24,uint24),uint16,uint24)",
            request,
            uint16(100),
            uint24(2592000)
        );

        address[] memory decodersAndSanitizers = new address[](5);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](5);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        uint256 eBTCSharesAmount = getERC20(sourceChain, "eBTC").balanceOf(address(boringVault)); 
        assertEq(eBTCSharesAmount, 0); 
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

contract FullBoringVaultDecoder is TellerDecoderAndSanitizer {}
