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
import {OdosOwnedDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OdosOwnedDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract OdosOwnedIntegrationTest is Test, MerkleTreeHelper {
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
    address public constant OLD_ODOS_EXECUTOR_MAINNET = 0xd768d1Fe6Ef1449A54F9409400fe9d0E4954ea3F;
    address public constant OLD_ODOS_EXECUTOR_SONIC_1 = 0xB28Ca7e465C452cE4252598e0Bc96Aeba553CF82;
    address public constant OLD_ODOS_EXECUTOR_SONIC_2 = 0xECDfcB1dD81d07c3551CbA94023EE443450353E1;
    address public constant OLD_ODOS_EXECUTOR_BASE = 0x52bB904473E0aDC699c7B103962D35a0F53D9E1e;

    function _setUpSpecificBlock__USDCSwap() internal {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 22140604;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new FullOdosOwnedDecoderAndSanitizer(address(this), getAddress(sourceChain, "odosRouterV2"), OLD_ODOS_EXECUTOR_MAINNET));

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
    }

    function _setUpSpecificBlock__WETHSwap() internal {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 22140604;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new FullOdosOwnedDecoderAndSanitizer(address(this), getAddress(sourceChain, "odosRouterV2"), OLD_ODOS_EXECUTOR_MAINNET));

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
    }

    function _setUpSpecificBlock_SonicWETHSwap() internal {
        setSourceChainName("sonicMainnet");
        // Setup forked environment.
        string memory rpcKey = "SONIC_MAINNET_RPC_URL";
        uint256 blockNumber = 11169032; 

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new FullOdosOwnedDecoderAndSanitizer(address(this), getAddress(sourceChain, "odosRouterV2"), OLD_ODOS_EXECUTOR_SONIC_1));

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
    }

    function _setUpSpecificBlock_SonicWETHSwap2() internal {
        setSourceChainName("sonicMainnet");
        // Setup forked environment.
        string memory rpcKey = "SONIC_MAINNET_RPC_URL";
        uint256 blockNumber = 16175047; 

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new FullOdosOwnedDecoderAndSanitizer(address(this), getAddress(sourceChain, "odosRouterV2"), OLD_ODOS_EXECUTOR_SONIC_2));

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
    }

    function _setUpSpecificBlock_Base() internal {
        setSourceChainName("base");
        // Setup forked environment.
        string memory rpcKey = "BASE_RPC_URL";
        uint256 blockNumber = 27469585; 

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new FullOdosOwnedDecoderAndSanitizer(address(this), getAddress(sourceChain, "odosRouterV2"), OLD_ODOS_EXECUTOR_BASE));

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
    }

    function testOdosSwapERC20() external {
        _setUpSpecificBlock__USDCSwap(); 

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e18);
        
        address[] memory tokens = new address[](3);   
        SwapKind[] memory kind = new SwapKind[](3); 
        tokens[0] = getAddress(sourceChain, "USDC"); 
        kind[0] = SwapKind.BuyAndSell; 
        tokens[1] = getAddress(sourceChain, "WETH"); 
        kind[1] = SwapKind.BuyAndSell; 
        tokens[2] = getAddress(sourceChain, "USDT"); 
        kind[2] = SwapKind.BuyAndSell; 
       
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addOdosOwnedSwapLeafs(leafs, tokens, kind);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[0]; //approve usdc
        manageLeafs[1] = leafs[1]; //swap() usdc -> weth
        manageLeafs[2] = leafs[2]; //swapCompact() usdc -> weth

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](3);
        targets[0] = getAddress(sourceChain, "USDC"); //approve
        targets[1] = getAddress(sourceChain, "odosRouterV2"); //approve
        targets[2] = getAddress(sourceChain, "odosRouterV2"); //approve

        bytes[] memory targetData = new bytes[](3);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "odosRouterV2"), type(uint256).max
        );
        
        DecoderCustomTypes.swapTokenInfo memory swapTokenInfo = DecoderCustomTypes.swapTokenInfo({
            inputToken: getAddress(sourceChain, "USDC"),
            inputAmount: 100000000,
            inputReceiver: OLD_ODOS_EXECUTOR_MAINNET,
            outputToken: getAddress(sourceChain, "WETH"),
            outputQuote: 44870662095406488,
            outputMin: 44770662095406488,
            outputReceiver: address(boringVault)
        }); 

        bytes memory pathDefinition = hex"010203000d0101010201ff00000000000000000000000000000000000000000088e6a0c2ddd26feeb64f039a2c41296fcb3f5640a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000"; 

        targetData[1] = abi.encodeWithSignature(
            "swap((address,uint256,address,address,uint256,uint256,address),bytes,address,uint32)", swapTokenInfo, pathDefinition, OLD_ODOS_EXECUTOR_MAINNET, 0
        );
        
        // @dev NOTE: this is swapCompact ABI-encoded. This tx data was retrieved directly from the Odos API. After assembling the tx, the output from the /assemble endpoint will return the following data in the data field. This includes everything needed for swapping. Submit the entire tx data as the targetData. Note that is already includes the function signature, etc.  
        targetData[2] = hex"83bd37f90001a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480001c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20405f5e10007a25b351495b2c8028f5c0001d768d1Fe6Ef1449A54F9409400fe9d0E4954ea3F000000015615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f0000000003010204001201010201000001ab000004b500000000020d0001030201ff000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb486f40d4a6237c257fff2db00fa0510deeecd303ebcba27c8e7115b4eb50aa14999bc0866674a96ecb00000000"; 

        address[] memory decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](3);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testOdosSwapERC20__Reverts() external {
        _setUpSpecificBlock__USDCSwap(); 

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e18);
        
        address[] memory tokens = new address[](3);   
        SwapKind[] memory kind = new SwapKind[](3); 
        tokens[0] = getAddress(sourceChain, "USDC"); 
        kind[0] = SwapKind.BuyAndSell; 
        tokens[1] = getAddress(sourceChain, "WETH"); 
        kind[1] = SwapKind.BuyAndSell; 
        tokens[2] = getAddress(sourceChain, "USDT"); 
        kind[2] = SwapKind.BuyAndSell; 
       
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addOdosOwnedSwapLeafs(leafs, tokens, kind);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[0]; //approve usdc
        manageLeafs[1] = leafs[1]; //swap() usdc -> weth
        manageLeafs[2] = leafs[2]; //swapCompact() usdc -> weth

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](3);
        targets[0] = getAddress(sourceChain, "USDC"); //approve
        targets[1] = getAddress(sourceChain, "odosRouterV2"); //approve
        targets[2] = getAddress(sourceChain, "odosRouterV2"); //approve

        bytes[] memory targetData = new bytes[](3);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "odosRouterV2"), type(uint256).max
        );
        
        //include wrong output token 
        DecoderCustomTypes.swapTokenInfo memory swapTokenInfo = DecoderCustomTypes.swapTokenInfo({
            inputToken: getAddress(sourceChain, "USDC"),
            inputAmount: 100000000,
            inputReceiver: OLD_ODOS_EXECUTOR_MAINNET,
            outputToken: getAddress(sourceChain, "USDT"),
            outputQuote: 44870662095406488,
            outputMin: 44770662095406488,
            outputReceiver: address(boringVault)
        }); 

        bytes memory pathDefinition = hex"010203000d0101010201ff00000000000000000000000000000000000000000088e6a0c2ddd26feeb64f039a2c41296fcb3f5640a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000"; 

        targetData[1] = abi.encodeWithSignature(
            "swap((address,uint256,address,address,uint256,uint256,address),bytes,address,uint32)", swapTokenInfo, pathDefinition, OLD_ODOS_EXECUTOR_MAINNET, 0
        );
        
        // @dev NOTE: this is swapCompact ABI-encoded. This tx data was retrieved directly from the Odos API. After assembling the tx, the output from the /assemble endpoint will return the following data in the data field. This includes everything needed for swapping. Submit the entire tx data as the targetData. Note that is already includes the function signature, etc.  
        targetData[2] = hex"83bd37f90001a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480001c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20405f5e10007a25b351495b2c8028f5c0001d768d1Fe6Ef1449A54F9409400fe9d0E4954ea3F000000015615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f0000000003010204001201010201000001ab000004b500000000020d0001030201ff000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb486f40d4a6237c257fff2db00fa0510deeecd303ebcba27c8e7115b4eb50aa14999bc0866674a96ecb00000000"; 

        address[] memory decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](3);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector, 
                targets[1], 
                targetData[1], 
                0
            )
        ); 
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
        
        //correct output token
        swapTokenInfo = DecoderCustomTypes.swapTokenInfo({
            inputToken: getAddress(sourceChain, "USDC"),
            inputAmount: 100000000,
            inputReceiver: OLD_ODOS_EXECUTOR_MAINNET,
            outputToken: getAddress(sourceChain, "WETH"),
            outputQuote: 44870662095406488,
            outputMin: 44770662095406488,
            outputReceiver: address(boringVault)
        }); 

        targetData[1] = abi.encodeWithSignature(
            "swap((address,uint256,address,address,uint256,uint256,address),bytes,address,uint32)", swapTokenInfo, pathDefinition, OLD_ODOS_EXECUTOR_MAINNET, 0
        );

        targetData[2] = hex"83bd37f90001a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480001dac17f958d2ee523a2206206994597c13d831ec70405f5e1000405f695c5028f5c0001d768d1Fe6Ef1449A54F9409400fe9d0E4954ea3F000131373595F40Ea48a7aAb6CBCB0d377C6066E2dCA00015615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f0000000003010203005701010001020180000060ff0000000000000000000000000000000031373595f40ea48a7aab6cbcb0d377c6066e2dcaa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000000000000000000000000000"; 

        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector, 
                targets[2], 
                targetData[2], 
                0
            )
        ); 

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

    }

    event OdosExecutorSet(address odosExecutor);
    function testDecoderSetExecutor() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 22140604;

        _startFork(rpcKey, blockNumber);

        OdosOwnedDecoderAndSanitizer decoder = new FullOdosOwnedDecoderAndSanitizer(address(this), getAddress(sourceChain, "odosRouterV2"), OLD_ODOS_EXECUTOR_MAINNET);
        vm.expectEmit(true, true, true, true);
        emit OdosExecutorSet(getAddress(sourceChain, "odosExecutor"));
        decoder.setOdosExecutor(getAddress(sourceChain, "odosExecutor"));
        assertEq(decoder.odosExecutor(), getAddress(sourceChain, "odosExecutor"));
    }

    //function testOdosSwapERC20__WETH() external {
    //    _setUpSpecificBlock__WETHSwap(); 

    //    deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);
    //    deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e18);
    //    
    //    address[] memory tokens = new address[](3);   
    //    SwapKind[] memory kind = new SwapKind[](3); 
    //    tokens[0] = getAddress(sourceChain, "USDC"); 
    //    kind[0] = SwapKind.BuyAndSell; 
    //    tokens[1] = getAddress(sourceChain, "WETH"); 
    //    kind[1] = SwapKind.BuyAndSell; 
    //    tokens[2] = getAddress(sourceChain, "USDT"); 
    //    kind[2] = SwapKind.BuyAndSell; 
    //   
    //    ManageLeaf[] memory leafs = new ManageLeaf[](16);
    //    _addOdosOwnedSwapLeafs(leafs, tokens, kind);

    //    bytes32[][] memory manageTree = _generateMerkleTree(leafs);

    //    //_generateTestLeafs(leafs, manageTree);

    //    manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

    //    ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
    //    manageLeafs[0] = leafs[5]; //approve weth
    //    manageLeafs[1] = leafs[8]; //swap() weth -> usdt
    //    manageLeafs[2] = leafs[9]; //swapCompact() weth -> usdt

    //    bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

    //    address[] memory targets = new address[](3);
    //    targets[0] = getAddress(sourceChain, "WETH"); //approve
    //    targets[1] = getAddress(sourceChain, "odosRouterV2"); //approve
    //    targets[2] = getAddress(sourceChain, "odosRouterV2"); //approve

    //    bytes[] memory targetData = new bytes[](3);
    //    targetData[0] = abi.encodeWithSignature(
    //        "approve(address,uint256)", getAddress(sourceChain, "odosRouterV2"), type(uint256).max
    //    );
    //    
    //    DecoderCustomTypes.swapTokenInfo memory swapTokenInfo = DecoderCustomTypes.swapTokenInfo({
    //        inputToken: getAddress(sourceChain, "WETH"),
    //        inputAmount: 1e18,
    //        inputReceiver: OLD_ODOS_EXECUTOR_MAINNET,
    //        outputToken: getAddress(sourceChain, "USDT"),
    //        outputQuote: 1,
    //        outputMin: 1,
    //        outputReceiver: address(boringVault)
    //    }); 

    //    bytes memory pathDefinition = hex"01020300510101010201077e6297b36a5670ff00000000000000000000000000352b186090068eb35d532428676ce510e17ab581c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000000000"; 

    //    targetData[1] = abi.encodeWithSignature(
    //        "swap((address,uint256,address,address,uint256,uint256,address),bytes,address,uint32)", swapTokenInfo, pathDefinition, OLD_ODOS_EXECUTOR_MAINNET, 0
    //    );
    //    
    //    // @dev NOTE: this is swapCompact ABI-encoded. This tx data was retrieved directly from the Odos API. After assembling the tx, the output from the /assemble endpoint will return the following data in the data field. This includes everything needed for swapping. Submit the entire tx data as the targetData. Note that is already includes the function signature, etc.  
    //    targetData[2] = hex"83bd37f90001c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20001dac17f958d2ee523a2206206994597c13d831ec7080de0b6b3a7640000048350be22028f5c0001d768d1Fe6Ef1449A54F9409400fe9d0E4954ea3F000000015615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f0000000003010203000d0101010201ff000000000000000000000000000000000000000000c7bbec68d12a0d1830360f8ec58fa599ba1b0e9bc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2000000000000000000000000000000000000000000000000"; 

    //    address[] memory decodersAndSanitizers = new address[](3);
    //    decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
    //    decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
    //    decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

    //    uint256[] memory values = new uint256[](3);

    //    manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    //}

    function testOdosSwapERC20_Sonic() external {
        _setUpSpecificBlock_SonicWETHSwap(); 

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);
        
        address[] memory tokens = new address[](3);   
        SwapKind[] memory kind = new SwapKind[](3); 
        tokens[0] = getAddress(sourceChain, "USDC"); 
        kind[0] = SwapKind.BuyAndSell; 
        tokens[1] = getAddress(sourceChain, "WETH"); 
        kind[1] = SwapKind.BuyAndSell; 
        tokens[2] = getAddress(sourceChain, "USDT"); 
        kind[2] = SwapKind.BuyAndSell; 
       
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addOdosOwnedSwapLeafs(leafs, tokens, kind);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[9]; //approve weth
        manageLeafs[1] = leafs[3]; //swap() weth -> usdc
        manageLeafs[2] = leafs[4]; //swapCompact() weth -> usdc

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](3);
        targets[0] = getAddress(sourceChain, "WETH"); //approve
        targets[1] = getAddress(sourceChain, "odosRouterV2"); //approve
        targets[2] = getAddress(sourceChain, "odosRouterV2"); //approve

        bytes[] memory targetData = new bytes[](3);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "odosRouterV2"), type(uint256).max
        );
        
        DecoderCustomTypes.swapTokenInfo memory swapTokenInfo = DecoderCustomTypes.swapTokenInfo({
            inputToken: getAddress(sourceChain, "WETH"),
            inputAmount: 1e18,
            inputReceiver: OLD_ODOS_EXECUTOR_SONIC_1,
            outputToken: getAddress(sourceChain, "USDC"),
            outputQuote: 2239355834,
            outputMin: 2229355834,
            outputReceiver: address(boringVault)
        }); 
    
        //much longer path
        bytes memory pathDefinition = hex"04030a0102aa88cc0301000101020014012433768406010003020001a686fe0f06020104020001c5dfced4060201050200015b3a9e66060201060200000702010207eceabd67b0f236fe57f61e619d91e4b223eb75d20002000000000000000000bc02060201080901ff000000000000000000000000000000000000000000000f4dd4c3ccb1729f099b79d83540049758a5e9ff50c42deacd8fc9773493ed674b675be577f2634bb6d9b069f6b96a507243d501d1a23b3fccfc85d36fb30f3fcb864d49cdff15061ed5c6adfee40b40cfd41df89d060b72ebdd50d65f9021e4457c477efe809a1d337bdfc98b77a1067e3819f66d8ad23f29219dd400f2bf60e5a23d13be72b486d40388945c4b7d607aaf7b5cde9f09b5f03cf3b5c923aeea039e2fb66102314ce7b64ce5ce3e5183bc94ad38000000000000000000000000"; 

        targetData[1] = abi.encodeWithSignature(
            "swap((address,uint256,address,address,uint256,uint256,address),bytes,address,uint32)", swapTokenInfo, pathDefinition, OLD_ODOS_EXECUTOR_SONIC_1, 0
        );
        
        // @dev NOTE: this is swapCompact ABI-encoded. This tx data was retrieved directly from the Odos API. After assembling the tx, the output from the /assemble endpoint will return the following data in the data field. This includes everything needed for swapping. Submit the entire tx data as the targetData. Note that is already includes the function signature, etc.  
        targetData[2] = hex"83bd37f9000150c42deacd8fc9773493ed674b675be577f2634b000129219dd400f2bf60e5a23d13be72b486d4038894080de0b6b3a7640000048579dbba028f5c0001B28Ca7e465C452cE4252598e0Bc96Aeba553CF82000000015615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f0000000006020307017015f2b506010001020001e6f4da260602010302000006020104020002060201050601ff000000000000000000000000000000000000000000000000b6d9b069f6b96a507243d501d1a23b3fccfc85d350c42deacd8fc9773493ed674b675be577f2634b6fb30f3fcb864d49cdff15061ed5c6adfee40b40cfd41df89d060b72ebdd50d65f9021e4457c477e9f46dd8f2a4016c26c1cf1f4ef90e5e1928d756b039e2fb66102314ce7b64ce5ce3e5183bc94ad380000000000000000"; 

        address[] memory decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](3);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);


        uint256 usdcBal = getERC20(sourceChain, "USDC").balanceOf(address(boringVault)); 
        assertGt(usdcBal, 0); 
    }

    function testOdosSwapERC20_Sonic2() external {
        _setUpSpecificBlock_SonicWETHSwap2(); 

        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000e18);
        
        address[] memory tokens = new address[](3);   
        SwapKind[] memory kind = new SwapKind[](3); 
        tokens[0] = getAddress(sourceChain, "USDC"); 
        kind[0] = SwapKind.BuyAndSell; 
        tokens[1] = getAddress(sourceChain, "WETH"); 
        kind[1] = SwapKind.BuyAndSell; 
        tokens[2] = getAddress(sourceChain, "USDT"); 
        kind[2] = SwapKind.BuyAndSell; 
       
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addOdosOwnedSwapLeafs(leafs, tokens, kind);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0]; //approve usdc
        manageLeafs[1] = leafs[2]; //swapCompact() usdc -> weth

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "USDC"); //approve
        targets[1] = getAddress(sourceChain, "odosRouterV2"); //approve

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "odosRouterV2"), type(uint256).max
        );
        
        
        // @dev NOTE: this is swapCompact ABI-encoded. This tx data was retrieved directly from the Odos API. After assembling the tx, the output from the /assemble endpoint will return the following data in the data field. This includes everything needed for swapping. Submit the entire tx data as the targetData. Note that is already includes the function signature, etc.  
        targetData[1] = hex"83bd37f9000129219dd400f2bf60e5a23d13be72b486d4038894000150c42deacd8fc9773493ed674b675be577f2634b0405f5e10007b0b44379e0fb18028f5c0001ECDfcB1dD81d07c3551CbA94023EE443450353E1000000015615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f0000000006030205000701000102cd4d2b142235d5650ffa6a38787ed0b7d7a51c0c000000000000000000000037020700000203e7734b495a552ab6f4c78406e672cca7175181e10002000000000000000000c500060101040301ff00000000000000000029219dd400f2bf60e5a23d13be72b486d4038894d3dce716f3ef535c5ff8d041c1a41c3bd89b97ae3bce5cb273f0f148010bbea2470e7b5df84c7812c291ca0a0a0e793dc6a0442a34e1607ce190538900000000000000000000000000000000"; 

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);


        uint256 usdcBal = getERC20(sourceChain, "WETH").balanceOf(address(boringVault)); 
        assertGt(usdcBal, 0); 
    }


    function testOdosSwapERC20_BASE() external {
        _setUpSpecificBlock_Base(); 

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);
        
        address[] memory tokens = new address[](3);   
        SwapKind[] memory kind = new SwapKind[](3); 
        tokens[0] = getAddress(sourceChain, "USDC"); 
        kind[0] = SwapKind.BuyAndSell; 
        tokens[1] = getAddress(sourceChain, "WETH"); 
        kind[1] = SwapKind.BuyAndSell; 
        tokens[2] = getAddress(sourceChain, "USDT"); 
        kind[2] = SwapKind.BuyAndSell; 
       
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addOdosOwnedSwapLeafs(leafs, tokens, kind);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[9]; //approve weth
        manageLeafs[1] = leafs[3]; //swap() weth -> usdc
        manageLeafs[2] = leafs[4]; //swapCompact() weth -> usdc

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](3);
        targets[0] = getAddress(sourceChain, "WETH"); //approve
        targets[1] = getAddress(sourceChain, "odosRouterV2"); //approve
        targets[2] = getAddress(sourceChain, "odosRouterV2"); //approve

        bytes[] memory targetData = new bytes[](3);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "odosRouterV2"), type(uint256).max
        );
        
        DecoderCustomTypes.swapTokenInfo memory swapTokenInfo = DecoderCustomTypes.swapTokenInfo({
            inputToken: getAddress(sourceChain, "WETH"),
            inputAmount: 1e18,
            inputReceiver: OLD_ODOS_EXECUTOR_BASE,
            outputToken: getAddress(sourceChain, "USDC"),
            outputQuote: 1946173011,
            outputMin: 1936173011,
            outputReceiver: address(boringVault)
        }); 
    
        bytes memory pathDefinition = hex"03030a0103fcdcbb080101010201013e6c3b8808010103020101076bcb6308010104020101cb39039308010105020100080200060201051b856727440101070800080ddf4afeb2b60e0004340101010908007ffffff5ff000000000000000000b4cb800910b228ed3d0834cf79d697127bbb00e54200000000000000000000000000000000000006482fe995c4a52bc79271ab29a53591363ee30a8974cb6260be6f31965c239df6d6ef2ac2b5d4f02072ab388e2e2f6facef59e3c3fa2c4e29011c2d38f6c0a374a483101e04ef5f7ac9bd15d9142bac95bb8b2da5db110ad625270061e81987ce342677c3d9aaec86b65d86f6a7b5b1b0c42ffa531710b6ca616535324976f8dbcef19df0705b95ace86ebb48000000000000000000000000";

        targetData[1] = abi.encodeWithSignature(
            "swap((address,uint256,address,address,uint256,uint256,address),bytes,address,uint32)", swapTokenInfo, pathDefinition, OLD_ODOS_EXECUTOR_BASE, 0
        );
        
        // @dev NOTE: this is swapCompact ABI-encoded. This tx data was retrieved directly from the Odos API. After assembling the tx, the output from the /assemble endpoint will return the following data in the data field. This includes everything needed for swapping. Submit the entire tx data as the targetData. Note that is already includes the function signature, etc.  
        targetData[2] = hex"83bd37f900020004080de0b6b3a7640000047402f962028f5c000152bB904473E0aDC699c7B103962D35a0F53D9E1e000000015615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f00000000210b08230119117af704010001016c6263030201010102010501012939ba0802010302010100bb254a340201010402017fffffef0104440252080201050201010098f2df08020106020101086d470d0802010702010102b990c60802010802010111432a8b08020109020101a1c30be90802010a020101738ba3020802010b02010103f8008a340300010c02017ffffe8b010757bcb60803000d0201012e8b6e150803000e02010104bc85c40804000f02010118210c75080400100201012accc672080400110201010775c59a08050012020101de5d323108060013020100080700140201079ee8714c440201151600080ddf4afeb2b60e0006340201011716007ffffff50d07fe6f5c440201181900080de0893b049c5e800c340201011a19007ffffffb0a0802011b1c00080802011d1e000e0802011f200103f9d83bec0902012122010001f400000a00020902012122010001f300000a00ff000000000000c868fcf8af03a2306c6b37db23b5a25b38b27eb942000000000000000000000000000000000000061db0d0cb84914d09a92ba11d122bab732ac35fe0df033790907c60c9b81ae355f76f74f52f92114ab4cb800910b228ed3d0834cf79d697127bbb00e5fcd3960075c00af339a4e26afc76b949e5ff06ec482fe995c4a52bc79271ab29a53591363ee30a8974cb6260be6f31965c239df6d6ef2ac2b5d4f020b775272e537cc670c65dc852908ad47015244eaf72ab388e2e2f6facef59e3c3fa2c4e29011c2d38b2cc224c1c9fee385f8ad6a55b4d94e92359dc59ff615535e281b96022f1423c89a83744fbf3dc27e58b73ff901325b8b2056b29712c50237242f520b78daa6d74fe0e23e5c95446cfadbadc63205cfc8912bd00a81b85d5618c1965f2a5ccdc034195b626f859da14329022dba1b87dd1998f18e3b222fec211e1f853a898bd1302385ccde55f33a8c4b3f3f4dfb8647c3ef75c5a71b7b0ee9240bdccce86974d69971ccd4a636c403a3c1b00c85e99bb9b56065d4e504eb4c526995e0cc7a6e327fda75d8b52b5bb8b2da5db110ad625270061e81987ce342677c3d9aaec86b65d86f6a7b5b1b0c42ffa531710b6ca616535324976f8dbcef19df0705b95ace86ebb48d44c8a74b4c61aca153fb35f63d58af87fb3340db79dd08ea68a908a97220c76d19a6aa9cbde43762153484894dfd38d7af28de7a6d10de3b007a06be5b5f522e98b5a2baae212d4da66b865b781db97940181a94a35a4569e4529a3cdfb74e38fd98631b94b22332abf5f89877a14cc88f2abc48c34b3dfcbb7c0000ab88b473b1f5afd9ef808440eed33bf00af44843f5207dcc574add652b695d9fb15006960a3e35cc302bfa44cb288bc5a4f316fdb1adb420000000000000000000000000000000000000000833589fcd6edb6e08f4c7c32d4f71b54bda02913000000000000000000000000000000000000000000000000"; 

        address[] memory decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](3);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        uint256 usdcBal = getERC20(sourceChain, "USDC").balanceOf(address(boringVault)); 
        assertGt(usdcBal, 0); 
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

contract FullOdosOwnedDecoderAndSanitizer is BaseDecoderAndSanitizer, OdosOwnedDecoderAndSanitizer {
    constructor(address _owner, address _odosRouter, address _odosExecutor) OdosOwnedDecoderAndSanitizer(_owner, _odosRouter, _odosExecutor){}
}
