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
import {FluidDexDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/FluidDexDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FluidDexFullDecoderAndSanitizer is FluidDexDecoderAndSanitizer, BaseDecoderAndSanitizer {

}

contract FluidDexIntegrationTest is Test, MerkleTreeHelper {
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

    function _setUpOldBlock() internal {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 23641760;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new FluidDexFullDecoderAndSanitizer());

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

    function _setUpNewBlock() internal {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 21820055;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new FluidDexFullDecoderAndSanitizer());

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

    function testFluidDexIntegrationFluidT1() public {
        _setUpOldBlock();
        deal(getAddress(sourceChain, "WSTUSR"), address(boringVault), 100e18);
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 10);//give some dust to payback borrow
        ERC20[] memory supplyTokens = new ERC20[](1);
        supplyTokens[0] = getERC20(sourceChain, "WSTUSR");
        ERC20[] memory borrowTokens = new ERC20[](1);
        borrowTokens[0] = getERC20(sourceChain, "USDC");
        uint256 dexType = 1000;
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addFluidDexLeafs(leafs, getAddress(sourceChain, "wstUSR-USDC"), dexType, supplyTokens, borrowTokens, false);
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);
        ManageLeaf[] memory manageLeafs = new ManageLeaf[](6);
        manageLeafs[0] = leafs[0]; //approval supply
        manageLeafs[1] = leafs[1]; //approval borrow
        manageLeafs[2] = leafs[2]; 
        manageLeafs[3] = leafs[2]; 
        manageLeafs[4] = leafs[2]; 
        manageLeafs[5] = leafs[2]; 

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](6);
        targets[0] = getAddress(sourceChain, "WSTUSR"); //approve supply
        targets[1] = getAddress(sourceChain, "USDC"); //aprove borrow for repay
        targets[2] = getAddress(sourceChain, "wstUSR-USDC"); //operate() deposit Collateral wstUSR
        targets[3] = getAddress(sourceChain, "wstUSR-USDC"); //operate() borrow USDC
        targets[4] = getAddress(sourceChain, "wstUSR-USDC"); //operate() payback USDC
        targets[5] = getAddress(sourceChain, "wstUSR-USDC"); //operate() withdraw wstUSR

        bytes[] memory targetData = new bytes[](6);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "wstUSR-USDC"), 1000e18);
        targetData[1] = abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "wstUSR-USDC"), 1000e18);
        targetData[2] = abi.encodeWithSignature("operate(uint256,int256,int256,address)", 0, 90e18, 0, getAddress(sourceChain, "boringVault"));
        targetData[3] = abi.encodeWithSignature("operate(uint256,int256,int256,address)", 8574, 0, 9e6, getAddress(sourceChain, "boringVault"));
        targetData[4] = abi.encodeWithSignature("operate(uint256,int256,int256,address)", 8574, 0, type(int256).min, getAddress(sourceChain, "boringVault"));
        targetData[5] = abi.encodeWithSignature("operate(uint256,int256,int256,address)", 8574, type(int256).min, 0, getAddress(sourceChain, "boringVault"));

        uint256[] memory values = new uint256[](6);
        address[] memory decodersAndSanitizers = new address[](6);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testFluidDexIntegration() public {
        _setUpOldBlock(); 

        deal(getAddress(sourceChain, "WBTC"), address(boringVault), 100e18);
        deal(getAddress(sourceChain, "cbBTC"), address(boringVault), 100e18);

        ERC20[] memory supplyTokens = new ERC20[](2);
        supplyTokens[0] = getERC20(sourceChain, "WBTC");
        supplyTokens[1] = getERC20(sourceChain, "cbBTC");

        ERC20[] memory borrowTokens = new ERC20[](1);
        borrowTokens[0] = getERC20(sourceChain, "USDT");

        uint256 dexType = 2000;

        //3 approvals, 1 leaf for `operate()`, 1 leaf for `operatePerfect()`
        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addFluidDexLeafs(leafs, getAddress(sourceChain, "wBTC-cbBTCDex-USDT"), dexType, supplyTokens, borrowTokens, false); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](11);
        manageLeafs[0] = leafs[0]; //approval supply
        manageLeafs[1] = leafs[1]; //approval borrow0
        manageLeafs[2] = leafs[2]; //approval borrow1
        manageLeafs[3] = leafs[3]; //operate() deposit params
        manageLeafs[4] = leafs[3]; //operate() borrow params
        manageLeafs[5] = leafs[3]; //operate() payback params
        manageLeafs[6] = leafs[3]; //operate() withdraw params
        manageLeafs[7] = leafs[4]; //operatePerfect() deposit params
        manageLeafs[8] = leafs[4]; //operatePerfect() borrow params
        manageLeafs[9] = leafs[4]; //operatePerfect() payback params
        manageLeafs[10] = leafs[4]; //operatePerfect() withdraw params (use type(int256).min for max withdraw)

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        //tree setup complete
        //
        //setup boring vault tx data

        //this is what will be minted after we deposit
        uint256 nftId = 2795;
        uint256 nftPerfectId = 2796;

        //deal some dust to payback borrow
        //deal(getAddress(sourceChain, "USDC"), address(boringVault), 10e18); //I know USDC and USDT don't have 18decimals
        //deal(getAddress(sourceChain, "USDT"), address(boringVault), 10e18);

        address[] memory targets = new address[](11);
        targets[0] = getAddress(sourceChain, "WBTC");
        targets[1] = getAddress(sourceChain, "cbBTC");
        targets[2] = getAddress(sourceChain, "USDT");
        targets[3] = getAddress(sourceChain, "wBTC-cbBTCDex-USDT");
        targets[4] = getAddress(sourceChain, "wBTC-cbBTCDex-USDT");
        targets[5] = getAddress(sourceChain, "wBTC-cbBTCDex-USDT");
        targets[6] = getAddress(sourceChain, "wBTC-cbBTCDex-USDT");
        targets[7] = getAddress(sourceChain, "wBTC-cbBTCDex-USDT");
        targets[8] = getAddress(sourceChain, "wBTC-cbBTCDex-USDT");
        targets[9] = getAddress(sourceChain, "wBTC-cbBTCDex-USDT");
        targets[10] = getAddress(sourceChain, "wBTC-cbBTCDex-USDT");

        bytes[] memory targetData = new bytes[](11);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "wBTC-cbBTCDex-USDT"), 1000e18);
        targetData[1] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "wBTC-cbBTCDex-USDT"), 1000e18);
        targetData[2] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "wBTC-cbBTCDex-USDT"), 1000e18);
        //deposit
        targetData[3] = abi.encodeWithSignature(
            "operate(uint256,int256,int256,int256,int256,address)",
            0,
            10e8,
            10e8,
            10,
            0,
            getAddress(sourceChain, "boringVault")
        );
        //borrow
        targetData[4] = abi.encodeWithSignature(
            "operate(uint256,int256,int256,int256,int256,address)",
            nftId,
            0,
            0,
            0,
            1e6,
            getAddress(sourceChain, "boringVault")
        );
        //payback
        targetData[5] = abi.encodeWithSignature(
            "operate(uint256,int256,int256,int256,int256,address)",
            nftId,
            0,
            0,
            0,
            -1e5,
            getAddress(sourceChain, "boringVault")
        );
        //withdraw
        targetData[6] = abi.encodeWithSignature(
            "operate(uint256,int256,int256,int256,int256,address)",
            nftId,
            -10e7,
            -10e7,
            -100000e18,
            0,
            getAddress(sourceChain, "boringVault")
        );
        //deposit perfect
        targetData[7] = abi.encodeWithSignature(
            "operatePerfect(uint256,int256,int256,int256,int256,address)",
            0,
            1e18,
            1e18,
            1e18,
            0,
            getAddress(sourceChain, "boringVault")
        );
        //borrow perfect
        targetData[8] = abi.encodeWithSignature(
            "operatePerfect(uint256,int256,int256,int256,int256,address)",
            nftPerfectId,
            0,
            0,
            0,
            1e6,
            getAddress(sourceChain, "boringVault")
        );
        //payback perfect
        targetData[9] = abi.encodeWithSignature(
            "operatePerfect(uint256,int256,int256,int256,int256,address)",
            nftPerfectId,
            0,
            0,
            0,
            -1e5,
            getAddress(sourceChain, "boringVault")
        );
        //withdraw perfect
        targetData[10] = abi.encodeWithSignature(
            "operatePerfect(uint256,int256,int256,int256,int256,address)",
            nftPerfectId,
            -1e17,
            -1e5,
            -1e5,
            0,
            getAddress(sourceChain, "boringVault")
        );
        uint256[] memory values = new uint256[](11);
        address[] memory decodersAndSanitizers = new address[](11);
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
        decodersAndSanitizers[10] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }


    function testFluidDexIntegrationNative() public {
        _setUpNewBlock(); 

        deal(getAddress(sourceChain, "WEETH"), address(boringVault), 100e18);
        deal(address(boringVault), 100e18);

        ERC20[] memory supplyTokens = new ERC20[](2);
        supplyTokens[0] = getERC20(sourceChain, "WEETH");
        supplyTokens[1] = getERC20(sourceChain, "ETH");

        ERC20[] memory borrowTokens = new ERC20[](1);
        borrowTokens[0] = getERC20(sourceChain, "WSTETH");

        uint256 dexType = 2000;

        //3 approvals, 1 leaf for `operate()`, 1 leaf for `operatePerfect()`
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addFluidDexLeafs(leafs, getAddress(sourceChain, "weETH_ETHDex_wstETH"), dexType, supplyTokens, borrowTokens, true);


        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);   

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](4);
        manageLeafs[0] = leafs[0]; //approval supply
        manageLeafs[1] = leafs[1]; //approval borrow
        manageLeafs[2] = leafs[2]; //operate() deposit params
        manageLeafs[3] = leafs[4]; //operate() deposit params Native

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        //tree setup complete
        //
        //setup boring vault tx data

        //this is what will be minted after we deposit
        //uint256 nftId = 2795;
        //uint256 nftPerfectId = 2796;

        //deal some dust to payback borrow
        //deal(getAddress(sourceChain, "USDC"), address(boringVault), 10e18); //I know USDC and USDT don't have 18decimals
        //deal(getAddress(sourceChain, "USDT"), address(boringVault), 10e18);

        address[] memory targets = new address[](4);
        targets[0] = getAddress(sourceChain, "WEETH");
        targets[1] = getAddress(sourceChain, "WSTETH");
        targets[2] = getAddress(sourceChain, "weETH_ETHDex_wstETH");
        targets[3] = getAddress(sourceChain, "weETH_ETHDex_wstETH");

        bytes[] memory targetData = new bytes[](4);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "weETH_ETHDex_wstETH"), 1000e18);
        targetData[1] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "weETH_ETHDex_wstETH"), 1000e18);
        //deposit
        targetData[2] = abi.encodeWithSignature(
            "operate(uint256,int256,int256,int256,int256,address)",
            0,
            0.01e18,
            0,
            1,
            0,
            getAddress(sourceChain, "boringVault")
        );
        targetData[3] = abi.encodeWithSignature(
            "operate(uint256,int256,int256,int256,int256,address)",
            0,
            0.01e18,
            0,
            1,
            0,
            getAddress(sourceChain, "boringVault")
        );

        uint256[] memory values = new uint256[](4);
        values[0] = 0; 
        values[1] = 0; 
        values[2] = 0; 
        values[3] = 0.01e18; 

        address[] memory decodersAndSanitizers = new address[](4);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
