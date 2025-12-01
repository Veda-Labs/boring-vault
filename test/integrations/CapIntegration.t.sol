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
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {CapDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/CapDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract CapIntegrationTest is Test, MerkleTreeHelper {
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
        uint256 blockNumber = 23809760;

        _startFork(rpcKey, blockNumber);

        leafIndex = 0;

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new CapDecoderAndSanitizer());

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

    function testCapIntegration() external {
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1000 * 1e6);

        address[] memory capDepositAssets = new address[](1);
        capDepositAssets[0] = getAddress(sourceChain, "USDC");

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addCapLeafs(leafs, capDepositAssets);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](8);
        manageLeafs[0] = leafs[1]; // approve USDC
        manageLeafs[1] = leafs[2]; // mint cUSD with USDC
        manageLeafs[2] = leafs[3]; // burn cUSD for USDC
        manageLeafs[3] = leafs[4]; // approve stcUSD to stake cUSD
        manageLeafs[4] = leafs[5]; // stake cUSD for stcUSD (ERC4626 deposit)
        manageLeafs[5] = leafs[6]; // stake cUSD for stcUSD (ERC4626 mint)
        manageLeafs[6] = leafs[7]; // unstake stcUSD for cUSD (ERC4626 withdraw)
        manageLeafs[7] = leafs[8]; // unstake stcUSD for cUSD (ERC4626 redeem)

        (bytes32[][] memory manageProofs) = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](8);
        targets[0] = getAddress(sourceChain, "USDC");
        targets[1] = getAddress(sourceChain, "cUSD");
        targets[2] = getAddress(sourceChain, "cUSD");
        targets[3] = getAddress(sourceChain, "cUSD");
        targets[4] = getAddress(sourceChain, "stcUSD");
        targets[5] = getAddress(sourceChain, "stcUSD");
        targets[6] = getAddress(sourceChain, "stcUSD");
        targets[7] = getAddress(sourceChain, "stcUSD");

        bytes[] memory targetData = new bytes[](8);
        targetData[0] = abi.encodeWithSelector(
            ERC20.approve.selector, getAddress(sourceChain, "cUSD"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSelector(
            bytes4(keccak256("mint(address,uint256,uint256,address,uint256)")), 
            getAddress(sourceChain, "USDC"),
            500 * 1e6,
            400 * 1e18,
            address(boringVault),
            block.timestamp + 100
        );
        targetData[2] = abi.encodeWithSelector(
            bytes4(keccak256("burn(address,uint256,uint256,address,uint256)")), 
            getAddress(sourceChain, "USDC"),
            10 * 1e18,
            9 * 1e6,
            address(boringVault),
            block.timestamp + 100
        );
        targetData[3] = abi.encodeWithSelector(
            ERC20.approve.selector, getAddress(sourceChain, "stcUSD"), type(uint256).max
        );
        targetData[4] = abi.encodeWithSelector(
            bytes4(keccak256("deposit(uint256,address)")),
            30 * 1e18,
            address(boringVault)
        );
        targetData[5] = abi.encodeWithSelector(
            bytes4(keccak256("mint(uint256,address)")),
            30 * 1e18,
            address(boringVault)
        );
        targetData[6] = abi.encodeWithSelector(
            bytes4(keccak256("withdraw(uint256,address,address)")),
            10 * 1e18,
            address(boringVault),
            address(boringVault)
        );
        targetData[7] = abi.encodeWithSelector(
            bytes4(keccak256("redeem(uint256,address,address)")),
            10 * 1e18,
            address(boringVault),
            address(boringVault)
        );

        uint256[] memory values = new uint256[](8);

        address[] memory decodersAndSanitizers = new address[](8);
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
