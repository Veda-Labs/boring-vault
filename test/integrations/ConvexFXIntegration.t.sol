// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { MainnetAddresses } from "test/resources/MainnetAddresses.sol";
import { BoringVault } from "src/base/BoringVault.sol";
import { ManagerWithMerkleVerification } from "src/base/Roles/ManagerWithMerkleVerification.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";
import { FixedPointMathLib } from "@solmate/utils/FixedPointMathLib.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { ERC4626 } from "@solmate/tokens/ERC4626.sol";
import { BaseDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import { ConvexFXDecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/ConvexFXDecoderAndSanitizer.sol";
import { DecoderCustomTypes } from "src/interfaces/DecoderCustomTypes.sol";
import { RolesAuthority, Authority } from "@solmate/auth/authorities/RolesAuthority.sol";
import { MerkleTreeHelper } from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import { Test, stdStorage, StdStorage, stdError, console } from "@forge-std/Test.sol";

contract ConvexFXIntegrationTest is Test, MerkleTreeHelper {
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

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 21_923_998;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer =
            address(new FullConvexDecoderAndSanitizer(getAddress(sourceChain, "convexFXPoolRegistry")));

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
    }

    function testConvexFXIntegration() external {
        // We need a 2 step flow here where the vault is first created, then whitelisted. Annoying, but they use `create` and not `create2` so we cannot reliably premine an address
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addConvexFXBoosterLeafs(
            leafs,
            getAddress(sourceChain, "convexFX_gauge_USDC_fxUSD"), //convex gauge (from FE) !(not the curve gauge)!
            getAddress(sourceChain, "convexFX_lp_USDC_fxUSD") //curve lp (from convex or curve FE)
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0]; //createVault

        (bytes32[][] memory manageProofs) = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "convexFXBooster"); //createVault

        bytes[] memory targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature("createVault(uint256)", 32);

        uint256[] memory values = new uint256[](1);

        address[] memory decodersAndSanitizers = new address[](1);
        for (uint256 i = 0; i < decodersAndSanitizers.length; i++) {
            decodersAndSanitizers[i] = rawDataDecoderAndSanitizer;
        }

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        address expectedVaultAddress = 0x9B8cd3346bA58D92D0601558D9F01c2C0C80B6ae;

        //now vault has been created, we need to add leaves
        _addConvexFXVaultLeafs(leafs, expectedVaultAddress);

        manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        //deal LP token
        deal(getAddress(sourceChain, "convexFX_lp_USDC_fxUSD"), address(boringVault), 100e18);
        deal(getAddress(sourceChain, "USDC"), address(expectedVaultAddress), 100e8);

        manageLeafs = new ManageLeaf[](5);
        manageLeafs[0] = leafs[1]; //approve
        manageLeafs[1] = leafs[2]; //deposit
        manageLeafs[2] = leafs[3]; //withdraw
        manageLeafs[3] = leafs[4]; //getReward
        manageLeafs[4] = leafs[5]; //transferTokens

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](5);
        targets[0] = getAddress(sourceChain, "convexFX_lp_USDC_fxUSD"); //approve lp
        targets[1] = expectedVaultAddress; //deposit lp
        targets[2] = expectedVaultAddress; //withdraw lp
        targets[3] = expectedVaultAddress; //getReward
        targets[4] = expectedVaultAddress; //transferTokens

        targetData = new bytes[](5);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", expectedVaultAddress, type(uint256).max);
        targetData[1] = abi.encodeWithSignature("deposit(uint256,bool)", 10e18, false);
        targetData[2] = abi.encodeWithSignature("withdraw(uint256)", 5e18);
        targetData[3] = abi.encodeWithSignature("getReward(bool)", true);

        address[] memory tokens = new address[](1);
        tokens[0] = getAddress(sourceChain, "USDC");

        targetData[4] = abi.encodeWithSignature("transferTokens(address[])", tokens);

        values = new uint256[](5);

        decodersAndSanitizers = new address[](5);
        for (uint256 i = 0; i < decodersAndSanitizers.length; i++) {
            decodersAndSanitizers[i] = rawDataDecoderAndSanitizer;
        }

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

contract FullConvexDecoderAndSanitizer is ConvexFXDecoderAndSanitizer {
    constructor(address _poolRegistry) ConvexFXDecoderAndSanitizer(_poolRegistry) { }
}
