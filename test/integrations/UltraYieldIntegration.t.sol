// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {UltraYieldDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/UltraYieldDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract UltraYieldIntegrationTest is Test, MerkleTreeHelper {
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
        setSourceChainName("sepolia");
        // Setup forked environment.
        string memory rpcKey = "SEPOLIA_RPC_URL";
        uint256 blockNumber = 8314708;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "balancerVault"));

        rawDataDecoderAndSanitizer = address(new FullUltraYieldDecoderAndSanitizer());

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
        rolesAuthority.setUserRole(getAddress(sourceChain, "balancerVault"), BALANCER_VAULT_ROLE, true);

        // Allow the boring vault to receive ETH.
        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);
    }

    function testUltraYieldIntegration() external {
        deal(getAddress(sourceChain, "WETH9"), address(boringVault), 1_000e18);

        // prank into owner address to grant operator role to this contract
        vm.prank(0xE665CEf14cB016b37014D0BDEAB4A693c3F46Cc0);
        IUltraYield(getAddress(sourceChain, "UltraYieldWETH")).updateRole(
            keccak256("OPERATOR_ROLE"), address(this), true
        );

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addUltraYieldLeafs(leafs, getAddress(sourceChain, "UltraYieldWETH"));

        //string memory filePath = "./TestTEST.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs0 = new ManageLeaf[](5); // skip the 4626 leafs other than approve
        manageLeafs0[0] = leafs[0]; //approve vault to spend asset
        manageLeafs0[1] = leafs[5]; //deposit using non-4626 function
        manageLeafs0[2] = leafs[9]; //approve vault to spend itself
        manageLeafs0[3] = leafs[10]; //requestRedeem
        manageLeafs0[4] = leafs[7]; //mint using non-4626 function


        ManageLeaf[] memory manageLeafs1 = new ManageLeaf[](2);
        manageLeafs1[0] = leafs[6]; //withdraw using non-4626 function
        manageLeafs1[1] = leafs[8]; //redeem using non-4626 function

        (bytes32[][] memory manageProofs0) = _getProofsUsingTree(manageLeafs0, manageTree);
        (bytes32[][] memory manageProofs1) = _getProofsUsingTree(manageLeafs1, manageTree);

        address[] memory targets0 = new address[](5);
        targets0[0] = getAddress(sourceChain, "WETH9");
        targets0[1] = getAddress(sourceChain, "UltraYieldWETH");
        targets0[2] = getAddress(sourceChain, "UltraYieldWETH");
        targets0[3] = getAddress(sourceChain, "UltraYieldWETH");
        targets0[4] = getAddress(sourceChain, "UltraYieldWETH");

        address[] memory targets1 = new address[](2);
        targets1[0] = getAddress(sourceChain, "UltraYieldWETH");
        targets1[1] = getAddress(sourceChain, "UltraYieldWETH");

        bytes[] memory targetData0 = new bytes[](5);
        targetData0[0] =
            abi.encodeWithSelector(ERC20.approve.selector, getAddress(sourceChain, "UltraYieldWETH"), type(uint256).max);
        targetData0[1] =
            abi.encodeWithSignature("deposit(uint256)", 500e18);
        targetData0[2] =
            abi.encodeWithSelector(ERC20.approve.selector, getAddress(sourceChain, "UltraYieldWETH"), type(uint256).max);
        targetData0[3] =
            abi.encodeWithSignature("requestRedeem(uint256)", 200e18);
        targetData0[4] =
            abi.encodeWithSignature("mint(uint256)", 100e18);

        bytes[] memory targetData1 = new bytes[](2);
        targetData1[0] = abi.encodeWithSignature("withdraw(uint256)", 100e18);
        targetData1[1] = abi.encodeWithSignature("redeem(uint256)", 100e18);

        uint256[] memory values0 = new uint256[](5);
        uint256[] memory values1 = new uint256[](2);

        address[] memory decodersAndSanitizers0 = new address[](5);
        for (uint256 i = 0; i < decodersAndSanitizers0.length; i++) {
            decodersAndSanitizers0[i] = rawDataDecoderAndSanitizer;
        }

        address[] memory decodersAndSanitizers1 = new address[](2);
        for (uint256 i = 0; i < decodersAndSanitizers1.length; i++) {
            decodersAndSanitizers1[i] = rawDataDecoderAndSanitizer;
        }

        manager.manageVaultWithMerkleVerification(manageProofs0, decodersAndSanitizers0, targets0, targetData0, values0);
        assertEq(
            ERC20(getAddress(sourceChain, "UltraYieldWETH")).balanceOf(address(boringVault)), 400e18, "Not managed as intended"
        );
        assertEq(
            ERC20(getAddress(sourceChain, "WETH9")).balanceOf(address(boringVault)), 400e18, "Not managed as intended"
        );
        // fulfill redeem request
        IUltraYield(getAddress(sourceChain, "UltraYieldWETH")).fulfillRedeem(200e18, address(boringVault));

        manager.manageVaultWithMerkleVerification(manageProofs1, decodersAndSanitizers1, targets1, targetData1, values1);

        assertEq(
            ERC20(getAddress(sourceChain, "UltraYieldWETH")).balanceOf(address(boringVault)), 400e18, "Not managed as intended"
        );
        assertEq(
            ERC20(getAddress(sourceChain, "WETH9")).balanceOf(address(boringVault)), 600e18, "Not managed as intended"
        );
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

interface IUltraYield {
    function updateRole(
        bytes32 role,
        address account,
        bool approved
    ) external;

    function fulfillRedeem(uint256 shares, address controller) external;
}

contract FullUltraYieldDecoderAndSanitizer is UltraYieldDecoderAndSanitizer {}