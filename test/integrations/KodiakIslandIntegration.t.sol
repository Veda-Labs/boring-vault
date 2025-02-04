// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {KodiakIslandDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/KodiakIslandDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract KodiakIslandIntegrationTest is Test, MerkleTreeHelper {
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
        setSourceChainName("bartio");
        // Setup forked environment.
        string memory rpcKey = "BARTIO_RPC_URL";
        uint256 blockNumber = 9832868;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(
            new KodiakDecoderAndSanitizer()
        );

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

    function testKodiakIslandIntegrationTokenLiquidity() external {
        deal(getAddress(sourceChain, "WBERA"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "YEET"), address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        address[] memory islands = new address[](1); 
        islands[0] = getAddress(sourceChain, "kodiak_island_WBERA_YEET_1%"); 

        _addKodiakIslandLeafs(leafs, islands);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](5);
        manageLeafs[0] = leafs[0]; //approve token0
        manageLeafs[1] = leafs[1]; //approve token1
        manageLeafs[2] = leafs[2]; //approve island (tokenPair)
        manageLeafs[3] = leafs[3]; //removeLiquidity (tokens)
        manageLeafs[4] = leafs[5]; //removeLiquidity (tokens)

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](5);
        targets[0] = getAddress(sourceChain, "WBERA");
        targets[1] = getAddress(sourceChain, "YEET");
        targets[2] = getAddress(sourceChain, "kodiak_island_WBERA_YEET_1%"); //island is tokenPair
        targets[3] = getAddress(sourceChain, "kodiakIslandRouterNew");
        targets[4] = getAddress(sourceChain, "kodiakIslandRouterNew");

        bytes[] memory targetData = new bytes[](5);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "kodiakIslandRouterNew"), type(uint256).max);
        targetData[1] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "kodiakIslandRouterNew"), type(uint256).max);
        targetData[2] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "kodiakIslandRouterNew"), type(uint256).max);
        targetData[3] =
            abi.encodeWithSignature(
                "addLiquidity(address,uint256,uint256,uint256,uint256,uint256,address)", 
                getAddress(sourceChain, "kodiak_island_WBERA_YEET_1%"),
                100e18, 
                1000e18,
                0, 
                0,
                0, 
                getAddress(sourceChain, "boringVault")
            ); 
        uint256 liquidity = 32290217619646538319; 
        targetData[4] =
            abi.encodeWithSignature(
                "removeLiquidity(address,uint256,uint256,uint256,address)", 
                getAddress(sourceChain, "kodiak_island_WBERA_YEET_1%"), 
                liquidity, 
                0,
                0,
                getAddress(sourceChain, "boringVault")
            ); 

        address[] memory decodersAndSanitizers = new address[](5);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](5);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testKodiakIslandIntegrationNativeLiquidity() external {
        deal(address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "YEET"), address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        address[] memory islands = new address[](1); 
        islands[0] = getAddress(sourceChain, "kodiak_island_WBERA_YEET_1%"); 

        _addKodiakIslandLeafs(leafs, islands);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](4);
        manageLeafs[0] = leafs[1]; //approve token1
        manageLeafs[1] = leafs[2]; //approve island (tokenPair)
        manageLeafs[2] = leafs[4]; //addLiquidityNative (tokens)
        manageLeafs[3] = leafs[6]; //removeLiquidityNative (tokens)

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](4);
        targets[0] = getAddress(sourceChain, "YEET");
        targets[1] = getAddress(sourceChain, "kodiak_island_WBERA_YEET_1%"); //island is tokenPair
        targets[2] = getAddress(sourceChain, "kodiakIslandRouterNew");
        targets[3] = getAddress(sourceChain, "kodiakIslandRouterNew");

        bytes[] memory targetData = new bytes[](4);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "kodiakIslandRouterNew"), type(uint256).max);
        targetData[1] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "kodiakIslandRouterNew"), type(uint256).max);
        targetData[2] =
            abi.encodeWithSignature(
                "addLiquidityNative(address,uint256,uint256,uint256,uint256,uint256,address)", 
                getAddress(sourceChain, "kodiak_island_WBERA_YEET_1%"),
                100e18, 
                1000e18,
                0, 
                0,
                0, 
                getAddress(sourceChain, "boringVault")
            ); 
        uint256 liquidity = 32290217619646538319; 
        targetData[3] =
            abi.encodeWithSignature(
                "removeLiquidityNative(address,uint256,uint256,uint256,address)",
                getAddress(sourceChain, "kodiak_island_WBERA_YEET_1%"), 
                liquidity, 
                0,
                0,
                getAddress(sourceChain, "boringVault")
            ); 

        address[] memory decodersAndSanitizers = new address[](4);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](4);
        values[0] = 0; 
        values[1] = 0; 
        values[2] = 100e18; 
        values[3] = 0; 

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}


contract KodiakDecoderAndSanitizer is KodiakIslandDecoderAndSanitizer {}
