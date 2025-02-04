// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {SiloDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/SiloDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract SiloFinanceIntegrationTest is Test, MerkleTreeHelper {
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
        setSourceChainName("sonicMainnet");
        // Setup forked environment.
        string memory rpcKey = "SONIC_MAINNET_RPC_URL";
        uint256 blockNumber = 4154346;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(
            new FullSiloDecoderAndSanitizer()
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

    function testSiloIntegrationERC4626Functions() external {
        deal(getAddress(sourceChain, "wS"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "stS"), address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](64); //24 leaves per silo v2 market
        _addSiloV2Leafs(leafs, getAddress(sourceChain, "silo_stS_wS_config"));  

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //string memory filePath = "./testTEST.json";
        //_generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](10);
        manageLeafs[0] = leafs[0]; //approve stS
        manageLeafs[1] = leafs[17]; //approve wS
        manageLeafs[2] = leafs[1]; //deposit stS
        manageLeafs[3] = leafs[2]; //withdraw stS
        manageLeafs[4] = leafs[3]; //mint stS
        manageLeafs[5] = leafs[4]; //redeem stS
        manageLeafs[6] = leafs[18]; //deposit wS
        manageLeafs[7] = leafs[19]; //withdraw wS
        manageLeafs[8] = leafs[20]; //mint wS
        manageLeafs[9] = leafs[21]; //redeem wS

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        (address silo0, address silo1) = ISiloConfig(getAddress(sourceChain, "silo_stS_wS_config")).getSilos(); 

        address[] memory targets = new address[](10);
        targets[0] = getAddress(sourceChain, "stS");
        targets[1] = getAddress(sourceChain, "wS");
        targets[2] = silo0; 
        targets[3] = silo0;   
        targets[4] = silo0;  
        targets[5] = silo0;   
        targets[6] = silo1;  
        targets[7] = silo1;  
        targets[8] = silo1;  
        targets[9] = silo1;  

        bytes[] memory targetData = new bytes[](10);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", silo0, type(uint256).max);
        targetData[1] =
            abi.encodeWithSignature("approve(address,uint256)", silo1, type(uint256).max);
        targetData[2] =
            abi.encodeWithSignature("deposit(uint256,address)", 100e18, getAddress(sourceChain, "boringVault"));
        targetData[3] =
            abi.encodeWithSignature("withdraw(uint256,address,address)", 10e18, getAddress(sourceChain, "boringVault"), getAddress(sourceChain, "boringVault"));
        targetData[4] =
            abi.encodeWithSignature("mint(uint256,address)", 10e18, getAddress(sourceChain, "boringVault"));
        targetData[5] =
            abi.encodeWithSignature("redeem(uint256,address,address)", 1e18, getAddress(sourceChain, "boringVault"), getAddress(sourceChain, "boringVault"));
        targetData[6] =
            abi.encodeWithSignature("deposit(uint256,address)", 100e18, getAddress(sourceChain, "boringVault"));
        targetData[7] =
            abi.encodeWithSignature("withdraw(uint256,address,address)", 10e18, getAddress(sourceChain, "boringVault"), getAddress(sourceChain, "boringVault"));
        targetData[8] =
            abi.encodeWithSignature("mint(uint256,address)", 10e18, getAddress(sourceChain, "boringVault"));
        targetData[9] =
            abi.encodeWithSignature("redeem(uint256,address,address)", 1e18, getAddress(sourceChain, "boringVault"), getAddress(sourceChain, "boringVault"));

        address[] memory decodersAndSanitizers = new address[](10);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[8] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[9] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](10);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testSiloIntegrationISiloFunctions() external {
        deal(getAddress(sourceChain, "wS"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "stS"), address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](64); //17 leaves per silo v2 market
        _addSiloV2Leafs(leafs, getAddress(sourceChain, "silo_stS_wS_config"));  

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //string memory filePath = "./testTEST.json";
        //_generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](10);
        manageLeafs[0] = leafs[0]; //approve stS
        manageLeafs[1] = leafs[17]; //approve wS
        manageLeafs[2] = leafs[5]; //deposit stS
        manageLeafs[3] = leafs[6]; //mint stS
        manageLeafs[4] = leafs[7]; //withdraw stS
        manageLeafs[5] = leafs[8]; //redeem stS
        manageLeafs[6] = leafs[22]; //deposit wS
        manageLeafs[7] = leafs[23]; //withdraw wS
        manageLeafs[8] = leafs[24]; //mint wS
        manageLeafs[9] = leafs[25]; //redeem wS

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        (address silo0, address silo1) = ISiloConfig(getAddress(sourceChain, "silo_stS_wS_config")).getSilos(); 

        address[] memory targets = new address[](10);
        targets[0] = getAddress(sourceChain, "stS");
        targets[1] = getAddress(sourceChain, "wS");
        targets[2] = silo0; 
        targets[3] = silo0;   
        targets[4] = silo0;  
        targets[5] = silo0;   
        targets[6] = silo1;  
        targets[7] = silo1;  
        targets[8] = silo1;  
        targets[9] = silo1;  

        bytes[] memory targetData = new bytes[](10);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", silo0, type(uint256).max);
        targetData[1] =
            abi.encodeWithSignature("approve(address,uint256)", silo1, type(uint256).max);
        targetData[2] =
            abi.encodeWithSignature("deposit(uint256,address,uint8)", 100e18, getAddress(sourceChain, "boringVault"), 0);
        targetData[3] =
            abi.encodeWithSignature("mint(uint256,address,uint8)", 10e18, getAddress(sourceChain, "boringVault"), 0);
        targetData[4] =
            abi.encodeWithSignature("withdraw(uint256,address,address,uint8)", 10e18, getAddress(sourceChain, "boringVault"), getAddress(sourceChain, "boringVault"), 0);
        targetData[5] =
            abi.encodeWithSignature("redeem(uint256,address,address,uint8)", 1e18, getAddress(sourceChain, "boringVault"), getAddress(sourceChain, "boringVault"), 0);
        targetData[6] =
            abi.encodeWithSignature("deposit(uint256,address,uint8)", 100e18, getAddress(sourceChain, "boringVault"), 0);
        targetData[7] =
            abi.encodeWithSignature("mint(uint256,address,uint8)", 10e18, getAddress(sourceChain, "boringVault"), 0);
        targetData[8] =
            abi.encodeWithSignature("withdraw(uint256,address,address,uint8)", 10e18, getAddress(sourceChain, "boringVault"), getAddress(sourceChain, "boringVault"), 0);
        targetData[9] =
            abi.encodeWithSignature("redeem(uint256,address,address,uint8)", 1e18, getAddress(sourceChain, "boringVault"), getAddress(sourceChain, "boringVault"), 0);

        address[] memory decodersAndSanitizers = new address[](10);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[8] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[9] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](10);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testSiloIntegrationBorrowOtherSilo() external {
        deal(getAddress(sourceChain, "wS"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "stS"), address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](64); //17 leaves per silo v2 market
        _addSiloV2Leafs(leafs, getAddress(sourceChain, "silo_stS_wS_config"));  

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //string memory filePath = "./testTEST.json";
        //_generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](7);
        manageLeafs[0] = leafs[0]; //approve stS
        manageLeafs[1] = leafs[17]; //approve wS
        manageLeafs[2] = leafs[5]; //deposit stS
        manageLeafs[3] = leafs[26]; //borrow wS (NOTE: borrow is for opposite asset, if wanting to borrow the same asset as depositing, borrowSame must be used instead)
        manageLeafs[4] = leafs[27]; //borrowShares wS 
        manageLeafs[5] = leafs[29]; //repay wS 
        manageLeafs[6] = leafs[30]; //repayShares wS

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        (address silo0, address silo1) = ISiloConfig(getAddress(sourceChain, "silo_stS_wS_config")).getSilos(); 

        address[] memory targets = new address[](7);
        targets[0] = getAddress(sourceChain, "stS");
        targets[1] = getAddress(sourceChain, "wS");
        targets[2] = silo0; 
        targets[3] = silo1;   
        targets[4] = silo1;   
        targets[5] = silo1;   
        targets[6] = silo1;   

        bytes[] memory targetData = new bytes[](7);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", silo0, type(uint256).max);
        targetData[1] =
            abi.encodeWithSignature("approve(address,uint256)", silo1, type(uint256).max);
        targetData[2] =
            abi.encodeWithSignature("deposit(uint256,address,uint8)", 1000e18, getAddress(sourceChain, "boringVault"), 1);
        targetData[3] =
            abi.encodeWithSignature("borrow(uint256,address,address)", 10e6, getAddress(sourceChain, "boringVault"), getAddress(sourceChain, "boringVault"));
        targetData[4] =
            abi.encodeWithSignature("borrowShares(uint256,address,address)", 10e6, getAddress(sourceChain, "boringVault"), getAddress(sourceChain, "boringVault"));
        targetData[5] =
            abi.encodeWithSignature("repay(uint256,address)", 10e6, getAddress(sourceChain, "boringVault"));
        targetData[6] =
            abi.encodeWithSignature("repayShares(uint256,address)", 10e6, getAddress(sourceChain, "boringVault"));
        

        address[] memory decodersAndSanitizers = new address[](7);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](7);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testSiloIntegrationBorrowSameSilo() external {
        deal(getAddress(sourceChain, "wS"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "stS"), address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](64); //17 leaves per silo v2 market
        _addSiloV2Leafs(leafs, getAddress(sourceChain, "silo_stS_wS_config"));  

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./testTEST.json";
        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](6);
        manageLeafs[0] = leafs[0]; //approve stS
        manageLeafs[1] = leafs[17]; //approve wS
        manageLeafs[2] = leafs[5]; //deposit stS
        manageLeafs[3] = leafs[11]; //borrowSame stS
        manageLeafs[4] = leafs[12]; //repay stS
        manageLeafs[5] = leafs[13]; //repayShares stS

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        (address silo0, address silo1) = ISiloConfig(getAddress(sourceChain, "silo_stS_wS_config")).getSilos(); 

        address[] memory targets = new address[](6);
        targets[0] = getAddress(sourceChain, "stS");
        targets[1] = getAddress(sourceChain, "wS");
        targets[2] = silo0; 
        targets[3] = silo0;   
        targets[4] = silo0;   
        targets[5] = silo0;   

        bytes[] memory targetData = new bytes[](6);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", silo0, type(uint256).max);
        targetData[1] =
            abi.encodeWithSignature("approve(address,uint256)", silo1, type(uint256).max);
        targetData[2] =
            abi.encodeWithSignature("deposit(uint256,address,uint8)", 1000e18, getAddress(sourceChain, "boringVault"), 1);
        targetData[3] =
            abi.encodeWithSignature("borrowSameAsset(uint256,address,address)", 10e18, getAddress(sourceChain, "boringVault"), getAddress(sourceChain, "boringVault"));
        targetData[4] =
            abi.encodeWithSignature("repay(uint256,address)", 10e6, getAddress(sourceChain, "boringVault"));
        targetData[5] =
            abi.encodeWithSignature("repayShares(uint256,address)", 10e4, getAddress(sourceChain, "boringVault"));

        address[] memory decodersAndSanitizers = new address[](6);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](6);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testSiloIntegrationHelpers() external {
        deal(getAddress(sourceChain, "wS"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "stS"), address(boringVault), 1_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](64); //17 leaves per silo v2 market
        _addSiloV2Leafs(leafs, getAddress(sourceChain, "silo_stS_wS_config"));  

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./testTEST.json";
        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](6);
        manageLeafs[0] = leafs[0]; //approve stS
        manageLeafs[1] = leafs[17]; //approve wS
        manageLeafs[2] = leafs[5]; //deposit stS
        manageLeafs[3] = leafs[14]; //transitionCollateral
        manageLeafs[4] = leafs[32]; //switchCollateralToThisSilo
        manageLeafs[5] = leafs[33]; //accrueInterest

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        (address silo0, address silo1) = ISiloConfig(getAddress(sourceChain, "silo_stS_wS_config")).getSilos(); 

        address[] memory targets = new address[](6);
        targets[0] = getAddress(sourceChain, "stS");
        targets[1] = getAddress(sourceChain, "wS");
        targets[2] = silo0; 
        targets[3] = silo0;   
        targets[4] = silo1;   
        targets[5] = silo1;   

        bytes[] memory targetData = new bytes[](6);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", silo0, type(uint256).max);
        targetData[1] =
            abi.encodeWithSignature("approve(address,uint256)", silo1, type(uint256).max);
        targetData[2] =
            abi.encodeWithSignature("deposit(uint256,address,uint8)", 1000e18, getAddress(sourceChain, "boringVault"), 0);
        targetData[3] =
            abi.encodeWithSignature("transitionCollateral(uint256,address,uint8)", 100e18, getAddress(sourceChain, "boringVault"), 0); 
        targetData[4] =
            abi.encodeWithSignature("switchCollateralToThisSilo()");
        targetData[5] =
            abi.encodeWithSignature("accrueInterest()");

        address[] memory decodersAndSanitizers = new address[](6);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](6);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }


    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

contract FullSiloDecoderAndSanitizer is SiloDecoderAndSanitizer {}

interface ISiloConfig {
    function getSilos() external view returns (address,address); 
}
