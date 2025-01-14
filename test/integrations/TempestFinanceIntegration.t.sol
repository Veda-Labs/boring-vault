// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {TempestDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/TempestDecoderAndSanitizer.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol"; 
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract TempestFinance is Test, MerkleTreeHelper {
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

    function _setUpMainnet() internal {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 21616028;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(
            new FullTempestDecoderAndSanitizer(address(boringVault)));

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

    function _setUpScroll() internal {
        setSourceChainName("scroll");
        // Setup forked environment.
        string memory rpcKey = "SCROLL_RPC_URL";
        uint256 blockNumber = 12670140;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(
            new FullTempestDecoderAndSanitizer(address(boringVault)));

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

    function testTempestIntegrationLST() external {
        _setUpMainnet(); 

        deal(getAddress(sourceChain, "RSWETH"), address(boringVault), 100e18);
        deal(address(boringVault), 100e18);  

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory assets = new ERC20[](2); 
        assets[0] = getERC20(sourceChain, "RSWETH"); 
        assets[1] = getERC20(sourceChain, "ETH"); 
        _addTempestLSTLeafs(leafs, getAddress(sourceChain, "tempest_ETH_rswETH_vault"), assets);  

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](4);
        manageLeafs[0] = leafs[0]; //approve
        manageLeafs[1] = leafs[2]; //deposit 
        manageLeafs[2] = leafs[3]; //withdraw
        manageLeafs[3] = leafs[4]; //redeem

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](4);
        targets[0] = getAddress(sourceChain, "RSWETH");
        targets[1] = getAddress(sourceChain, "tempest_ETH_rswETH_vault");
        targets[2] = getAddress(sourceChain, "tempest_ETH_rswETH_vault");
        targets[3] = getAddress(sourceChain, "tempest_ETH_rswETH_vault");

        bytes[] memory targetData = new bytes[](4);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "tempest_ETH_rswETH_vault"), type(uint256).max);
        targetData[1] =
            abi.encodeWithSignature("deposit(uint256,address,bytes)", 10e18, getAddress(sourceChain, "boringVault"), "");
        targetData[2] =
            abi.encodeWithSignature("withdraw(uint256,address,address,bytes)", 5e18, getAddress(sourceChain, "boringVault"), getAddress(sourceChain, "boringVault"), "");  
        targetData[3] =
            abi.encodeWithSignature("redeem(uint256,address,address,bytes)", 1e18, getAddress(sourceChain, "boringVault"), getAddress(sourceChain, "boringVault"), "");  

        address[] memory decodersAndSanitizers = new address[](4);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](4);
        values[0] = 0; 
        values[1] = 10e18; 
        values[2] = 0; 
        values[3] = 0; 

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testTempestIntegrationRebalancingVaultSingle() external {
        _setUpScroll(); 

        deal(getAddress(sourceChain, "WEETH"), address(boringVault), 100e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        ERC20[] memory assets = new ERC20[](2); 
        assets[0] = getERC20(sourceChain, "WEETH"); 
        assets[1] = getERC20(sourceChain, "WSTETH"); 
        _addTempestRebalancingLeafs(leafs, getAddress(sourceChain, "tempest_weETH_wstETH_vault"), assets);  

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[0]; //approve
        manageLeafs[1] = leafs[1]; //approve
        manageLeafs[2] = leafs[2]; //deposit single (no eth)

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](3);
        targets[0] = getAddress(sourceChain, "WEETH");
        targets[1] = getAddress(sourceChain, "WSTETH");
        targets[2] = getAddress(sourceChain, "tempest_weETH_wstETH_vault");

        bytes[] memory targetData = new bytes[](3);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "tempest_weETH_wstETH_vault"), type(uint256).max);
        targetData[1] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "tempest_weETH_wstETH_vault"), type(uint256).max);
        targetData[2] =
            abi.encodeWithSignature("deposit(uint256,address,bool)", 10e18, getAddress(sourceChain, "boringVault"), false);

        address[] memory decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](3);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        //END DEPOSIT
        //to get around JIT liquidity safety checks, we must ff a few blocks
        skip(10); 

        //arrays are same size, we can simply reassign
        
        manageLeafs[0] = leafs[6]; //withdraw
        manageLeafs[1] = leafs[7]; //redeem
        manageLeafs[2] = leafs[8]; //withdrawWithoutSwap

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets[0] = getAddress(sourceChain, "tempest_weETH_wstETH_vault");
        targets[1] = getAddress(sourceChain, "tempest_weETH_wstETH_vault");
        targets[2] = getAddress(sourceChain, "tempest_weETH_wstETH_vault");

        targetData[0] =
            abi.encodeWithSignature("withdraw(uint256,address,address,uint256,bool)", 1e18, getAddress(sourceChain, "boringVault"), getAddress(sourceChain, "boringVault"), 10, true);  
        targetData[1] =
            abi.encodeWithSignature("redeem(uint256,address,address,uint256,bool)", 1e18, getAddress(sourceChain, "boringVault"), getAddress(sourceChain, "boringVault"), 0, false);  
        targetData[2] =
            abi.encodeWithSignature("redeemWithoutSwap(uint256,address,address,bool)", 1e18, getAddress(sourceChain, "boringVault"), getAddress(sourceChain, "boringVault"), 0, false);  
        //d&s and values are same    
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testTempestIntegrationRebalancingVaultMulti() external {
        _setUpScroll(); 

        deal(getAddress(sourceChain, "WEETH"), address(boringVault), 100e18);
        deal(getAddress(sourceChain, "WSTETH"), address(boringVault), 100e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        ERC20[] memory assets = new ERC20[](2); 
        assets[0] = getERC20(sourceChain, "WEETH"); 
        assets[1] = getERC20(sourceChain, "WSTETH"); 
        _addTempestRebalancingLeafs(leafs, getAddress(sourceChain, "tempest_weETH_wstETH_vault"), assets);  

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[0]; //approve
        manageLeafs[1] = leafs[1]; //approve
        manageLeafs[2] = leafs[4]; //deposit multi (no eth)

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](3);
        targets[0] = getAddress(sourceChain, "WEETH");
        targets[1] = getAddress(sourceChain, "WSTETH");
        targets[2] = getAddress(sourceChain, "tempest_weETH_wstETH_vault");

        // can use FE to determine amounts or call calculateAmount1ForAmount0() or calculateAmount0ForAmount1() on vault contract
        uint256[] memory amounts = new uint256[](2); 
        amounts[0] = 10e18; 
        amounts[1] = 2.820608e18; 

        bytes[] memory targetData = new bytes[](3);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "tempest_weETH_wstETH_vault"), type(uint256).max);
        targetData[1] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "tempest_weETH_wstETH_vault"), type(uint256).max);
        targetData[2] =
            abi.encodeWithSignature("deposits(uint256[],address,bool)", amounts, getAddress(sourceChain, "boringVault"), false);

        address[] memory decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](3);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        //END DEPOSIT
        //to get around JIT liquidity safety checks, we must ff a few blocks
        skip(10); 

        //arrays are same size, we can simply reassign
        
        manageLeafs[0] = leafs[6]; //withdraw
        manageLeafs[1] = leafs[7]; //redeem
        manageLeafs[2] = leafs[8]; //withdrawWithoutSwap

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets[0] = getAddress(sourceChain, "tempest_weETH_wstETH_vault");
        targets[1] = getAddress(sourceChain, "tempest_weETH_wstETH_vault");
        targets[2] = getAddress(sourceChain, "tempest_weETH_wstETH_vault");

        targetData[0] =
            abi.encodeWithSignature("withdraw(uint256,address,address,uint256,bool)", 1e18, getAddress(sourceChain, "boringVault"), getAddress(sourceChain, "boringVault"), 10, true);  
        targetData[1] =
            abi.encodeWithSignature("redeem(uint256,address,address,uint256,bool)", 1e18, getAddress(sourceChain, "boringVault"), getAddress(sourceChain, "boringVault"), 0, false);  
        targetData[2] =
            abi.encodeWithSignature("redeemWithoutSwap(uint256,address,address,bool)", 1e18, getAddress(sourceChain, "boringVault"), getAddress(sourceChain, "boringVault"), 0, false);  
        //d&s and values are same    
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}


contract FullTempestDecoderAndSanitizer is TempestDecoderAndSanitizer {
    constructor(address _boringVault) BaseDecoderAndSanitizer(_boringVault){}
}
