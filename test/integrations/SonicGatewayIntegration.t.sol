// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {SonicGatewayDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/SonicGatewayDecoderAndSanitizer.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract SonicGatewayIntegration is Test, MerkleTreeHelper {
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

    function setUpSonic() internal {
        setSourceChainName("sonicMainnet");
        // Setup forked environment.
        string memory rpcKey = "SONIC_MAINNET_RPC_URL";
        uint256 blockNumber = 2350914;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new FullSonicGatewayDecoderAndSanitizer());

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

    function setUpMainnet() internal {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 21572390;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new FullSonicGatewayDecoderAndSanitizer());

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

    //test bridge eth -> sonic
    function testSonicGatewayDeposits() external {
        setUpMainnet();

        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e6);

        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        ERC20[] memory bridgeAssets = new ERC20[](1);
        bridgeAssets[0] = getERC20(sourceChain, "USDC");
        _addSonicGatewayLeafsEth(leafs, bridgeAssets);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0]; //approve
        manageLeafs[1] = leafs[1]; //deposit

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "USDC");
        targets[1] = getAddress(sourceChain, "sonicGateway");

        //uid can be any number of the depositors choosing? I believe in their SDK they might simply pick a random number, these don't appear to be incrementing with any kind of pattern afaict
        //the only condition is that it hasn't been used before
        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "sonicGateway"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "deposit(uint96,address,uint256)", 1234123412342314556, getAddress(sourceChain, "USDC"), 100e6
        );

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    //test bridge sonic l2 -> eth mainnet
    function testSonicGatewaySonicWitdraw() external {
        setUpSonic();
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e6);

        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        address[] memory mainnetAssets = new address[](1);
        address[] memory sonicAssets = new address[](1);
        mainnetAssets[0] = getAddress(mainnet, "USDC"); //NOTE: this needs to be mainnet USDC
        sonicAssets[0] = getAddress(sonicMainnet, "USDC");
        _addSonicGatewayLeafsSonic(leafs, mainnetAssets, sonicAssets);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[0]; //approve circle adapter
        manageLeafs[1] = leafs[1]; //approve sonic gateway
        manageLeafs[2] = leafs[2]; //withdraw

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](3);
        targets[0] = getAddress(sourceChain, "USDC");
        targets[1] = getAddress(sourceChain, "USDC");
        targets[2] = getAddress(sourceChain, "sonicGateway");

        //uid can be any number of the depositors choosing? I believe in their SDK they might simply pick a random number, these don't appear to be incrementing with any kind of pattern afaict
        //the only condition is that it hasn't been used before
        bytes[] memory targetData = new bytes[](3);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "circleTokenAdapter"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "sonicGateway"), type(uint256).max
        );
        targetData[2] = abi.encodeWithSignature(
            "withdraw(uint96,address,uint256)", 1234123412342314556, getAddress(mainnet, "USDC"), 100e6
        );

        address[] memory decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](3);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testSonicGatewayDepositCancel() external {
        setUpMainnet();

        MockProofVerifier mockVerifier = new MockProofVerifier();
        vm.store(
            getAddress(sourceChain, "sonicGateway"),
            bytes32(uint256(9)), // proofVerifier slot
            bytes32(uint256(uint160(address(mockVerifier))))
        );
        bytes memory proof = "";

        uint256 depositId = 917551056842671309452305380979543736893630245704;
        bytes32 mappingSlot = bytes32(uint256(7));
        bytes32 depositSlot = keccak256(abi.encode(depositId, mappingSlot));
        // Calculate the hash that should be stored
        bytes32 depositHash = keccak256(abi.encode(address(boringVault), getAddress(sourceChain, "USDC"), 100e6));
        // Store the hash directly in the mapping
        vm.store(getAddress(sourceChain, "sonicGateway"), depositSlot, depositHash);

        // Set deadState directly
        bytes32 slot = bytes32(uint256(11)); // deadState is declared after several other state variables
        vm.store(
            getAddress(sourceChain, "sonicGateway"),
            slot,
            bytes32(uint256(1)) // Any non-zero value will work
        );

        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e6);

        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        ERC20[] memory bridgeAssets = new ERC20[](1);
        bridgeAssets[0] = getERC20(sourceChain, "USDC");
        _addSonicGatewayLeafsEth(leafs, bridgeAssets);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0]; //approve
        manageLeafs[1] = leafs[3]; //cancel

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "USDC");
        targets[1] = getAddress(sourceChain, "sonicGateway");

        //uid can be any number of the depositors choosing? I believe in their SDK they might simply pick a random number, these don't appear to be incrementing with any kind of pattern afaict
        //the only condition is that it hasn't been used before
        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "sonicGateway"), type(uint256).max
        );
        //id needs to be L2 id, we're going from deposit to
        targetData[1] = abi.encodeWithSignature(
            "cancelDepositWhileDead(uint256,address,uint256,bytes)",
            depositId,
            getAddress(sourceChain, "USDC"),
            100e6,
            proof
        );

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testClaimSonicToEth() external {
        setUpMainnet();

        MockProofVerifier mockVerifier = new MockProofVerifier();
        vm.store(
            getAddress(sourceChain, "sonicGateway"),
            bytes32(uint256(9)), // proofVerifier slot
            bytes32(uint256(uint160(address(mockVerifier))))
        );
        bytes memory proof = "";

        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        ERC20[] memory bridgeAssets = new ERC20[](1);
        bridgeAssets[0] = getERC20(sourceChain, "USDC");
        _addSonicGatewayLeafsEth(leafs, bridgeAssets);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[2]; //claim

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "sonicGateway");

        uint256 depositId = 10169420;
        bytes[] memory targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature(
            "claim(uint256,address,uint256,bytes)", depositId, getAddress(sourceChain, "USDC"), 100e6, proof
        );

        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](1);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        uint256 bal = getERC20(sourceChain, "USDC").balanceOf(address(boringVault));
        assertEq(bal, 100e6);
    }

    function testClaimETHToSonic() external {
        setUpSonic();

        MockProofVerifier mockVerifier = new MockProofVerifier();
        vm.store(
            getAddress(sourceChain, "sonicGateway"),
            bytes32(uint256(3)), // proofVerifier slot
            bytes32(uint256(uint160(address(mockVerifier))))
        );
        bytes memory proof = "";

        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        address[] memory mainnetAssets = new address[](1);
        address[] memory sonicAssets = new address[](1);
        mainnetAssets[0] = getAddress(mainnet, "USDC"); //NOTE: this needs to be mainnet USDC
        sonicAssets[0] = getAddress(sonicMainnet, "USDC");
        _addSonicGatewayLeafsSonic(leafs, mainnetAssets, sonicAssets);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[3]; //claim

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "sonicGateway");

        //uid can be any number of the depositors choosing? I believe in their SDK they might simply pick a random number, these don't appear to be incrementing with any kind of pattern afaict
        //the only condition is that it hasn't been used before
        //NOTE: address of token here is mainnet address
        bytes[] memory targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature(
            "claim(uint256,address,uint256,bytes)", 1234123412342314556, getAddress(mainnet, "USDC"), 100e6, proof
        );

        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](1);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        uint256 bal = getERC20(sourceChain, "USDC").balanceOf(address(boringVault));
        assertEq(bal, 100e6);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

contract FullSonicGatewayDecoderAndSanitizer is SonicGatewayDecoderAndSanitizer {}

contract MockProofVerifier {
    function verifyProof(address target, bytes32 slot, bytes32 value, bytes32 stateRoot, bytes calldata proof)
        external
        pure
    {
        // Always verify for testing
        target;
        slot;
        value;
        stateRoot;
        proof;
        return;
    }
}
