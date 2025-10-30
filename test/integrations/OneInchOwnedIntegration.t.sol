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
import {OneInchOwnedDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/OneInchOwnedDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract OneInchOwnedIntegrationTest is Test, MerkleTreeHelper {
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
    address public constant OLD_ONE_INCH_EXECUTOR_MAINNET = 0x5141B82f5fFDa4c6fE1E372978F1C5427640a190;
    address public constant NEW_ONE_INCH_EXECUTOR_MAINNET = 0x8C864D0c8E476Bf9eb9d620C10E1296fb0E2F940;

    function _setUpSpecificBlock__WETHSwap(address _oneInchExecutor, uint256 _blockNumber) internal {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = _blockNumber;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new FullOneInchOwnedDecoderAndSanitizer(address(this), _oneInchExecutor));

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

    function testOneInchSwapERC20__OldExecutor() external {
        _setUpSpecificBlock__WETHSwap(OLD_ONE_INCH_EXECUTOR_MAINNET, 23591300); 

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 2_000e18);
        
        address[] memory tokens = new address[](2);   
        SwapKind[] memory kind = new SwapKind[](2); 
        tokens[0] = getAddress(sourceChain, "WETH"); 
        kind[0] = SwapKind.BuyAndSell; 
        tokens[1] = getAddress(sourceChain, "WEETH"); 
        kind[1] = SwapKind.BuyAndSell; 
       
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addLeafsFor1InchOwnedGeneralSwapping(leafs, tokens, kind);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0]; //approve weth
        manageLeafs[1] = leafs[1]; //swap() weth -> weeth

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "WETH"); //approve
        targets[1] = getAddress(sourceChain, "aggregationRouterV5"); //swap

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "aggregationRouterV5"), type(uint256).max
        );
        
        DecoderCustomTypes.SwapDescription memory swapTokenInfo = DecoderCustomTypes.SwapDescription({
            srcToken: getAddress(sourceChain, "WETH"),
            dstToken: getAddress(sourceChain, "WEETH"),
            srcReceiver: payable(OLD_ONE_INCH_EXECUTOR_MAINNET),
            dstReceiver: payable(address(boringVault)),
            amount: 2000000000000000000000,
            minReturnAmount: 1853168613540785108260,
            flags: 4
        });

        bytes memory data = hex"00000000000000000000000000000000000000029700026900021f00001a0020d6bdbf78c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200a0c9e75c480000000000001e0012020000000000000000000000000000000000000001d700013b0000ff00004f02a00000000000000000000000000000000000000000000000000000000000000001ee63c1e501202a6012894ae5c288ea824cbc8a9bfb26a49b93c02aaa39b223fe8d0a0e5c4f27ead9083c756cc25100db74dfdd3bb46be8ce6c33dc9d82777bcfc3ded5c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200443df0212400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000014101c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200042e1a7d4d0000000000000000000000000000000000000000000000000000000000000000416086f874212335af27c41cdb855c2255543d1499ce00242668dfaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000005141b82f5ffda4c6fe1e372978f1c5427640a19000a0f2fa6b66cd5fe23c85820f7b72d0926fc9b05b43e359b7ee0000000000000000000000000000000000000000000000647873ed1122954ca0000000000000000000043784c68b019880a06c4eca27cd5fe23c85820f7b72d0926fc9b05b43e359b7ee1111111254eeb25477b68fb85ed929f73a960582";

        targetData[1] = abi.encodeWithSignature(
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)", OLD_ONE_INCH_EXECUTOR_MAINNET, swapTokenInfo, "", data
        );
        
        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testOneInchSwapERC20__NewExecutor() external {
        _setUpSpecificBlock__WETHSwap(NEW_ONE_INCH_EXECUTOR_MAINNET, 23671018); 

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 2_000e18);
        
        address[] memory tokens = new address[](2);   
        SwapKind[] memory kind = new SwapKind[](2); 
        tokens[0] = getAddress(sourceChain, "WETH"); 
        kind[0] = SwapKind.BuyAndSell; 
        tokens[1] = getAddress(sourceChain, "WEETH"); 
        kind[1] = SwapKind.BuyAndSell; 
       
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addLeafsFor1InchOwnedGeneralSwapping(leafs, tokens, kind);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0]; //approve weth
        manageLeafs[1] = leafs[1]; //swap() weth -> weeth

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = getAddress(sourceChain, "WETH"); //approve
        targets[1] = getAddress(sourceChain, "aggregationRouterV5"); //swap

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "aggregationRouterV5"), type(uint256).max
        );
        
        DecoderCustomTypes.SwapDescription memory swapTokenInfo = DecoderCustomTypes.SwapDescription({
            srcToken: getAddress(sourceChain, "WETH"),
            dstToken: getAddress(sourceChain, "WEETH"),
            srcReceiver: payable(NEW_ONE_INCH_EXECUTOR_MAINNET),
            dstReceiver: payable(address(boringVault)),
            amount: 2000000000000000000000,
            minReturnAmount: 1852129623269144641715,
            flags: 4
        });

        bytes memory data = hex"0000000000000000000000000000000000000002520002240001da00001a0020d6bdbf78c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200a0c9e75c4800000000000000000000000000000029000000090000000000000000000000000000000000000000000001880000ec0000b05100db74dfdd3bb46be8ce6c33dc9d82777bcfc3ded5c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200443df0212400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000014101c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200042e1a7d4d0000000000000000000000000000000000000000000000000000000000000000416086f874212335af27c41cdb855c2255543d1499ce00242668dfaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000008c864d0c8e476bf9eb9d620c10e1296fb0e2f94000a0f2fa6b66cd5fe23c85820f7b72d0926fc9b05b43e359b7ee0000000000000000000000000000000000000000000000646a08526a24695c2e00000000000000000003ea6740d11d1f80a06c4eca27cd5fe23c85820f7b72d0926fc9b05b43e359b7ee1111111254eeb25477b68fb85ed929f73a960582";

        targetData[1] = abi.encodeWithSignature(
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)", NEW_ONE_INCH_EXECUTOR_MAINNET, swapTokenInfo, "", data
        );
        
        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](2);

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testOneInchSwapERC20__Reverts() external {
        _setUpSpecificBlock__WETHSwap(NEW_ONE_INCH_EXECUTOR_MAINNET, 23671018); 

        deal(getAddress(sourceChain, "WETH"), address(boringVault), 2_000e18);
        
        address[] memory tokens = new address[](2);   
        SwapKind[] memory kind = new SwapKind[](2); 
        tokens[0] = getAddress(sourceChain, "WETH"); 
        kind[0] = SwapKind.BuyAndSell; 
        tokens[1] = getAddress(sourceChain, "WEETH"); 
        kind[1] = SwapKind.BuyAndSell; 
       
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        _addLeafsFor1InchOwnedGeneralSwapping(leafs, tokens, kind);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //_generateTestLeafs(leafs, manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](3);
        manageLeafs[0] = leafs[0]; //approve weth
        manageLeafs[1] = leafs[1]; //swap() weth -> weeth
        manageLeafs[2] = leafs[2]; //swap() weth -> weeth

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](3);
        targets[0] = getAddress(sourceChain, "WETH"); //approve
        targets[1] = getAddress(sourceChain, "aggregationRouterV5"); //swap
        targets[2] = getAddress(sourceChain, "aggregationRouterV5"); //swap

        bytes[] memory targetData = new bytes[](3);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "aggregationRouterV5"), type(uint256).max
        );
        
        // wrong executor here
        DecoderCustomTypes.SwapDescription memory swapTokenInfo = DecoderCustomTypes.SwapDescription({
            srcToken: getAddress(sourceChain, "WETH"),
            dstToken: getAddress(sourceChain, "WEETH"),
            srcReceiver: payable(OLD_ONE_INCH_EXECUTOR_MAINNET),
            dstReceiver: payable(address(boringVault)),
            amount: 2000000000000000000000,
            minReturnAmount: 1852129623269144641715,
            flags: 4
        });

        bytes memory data = hex"0000000000000000000000000000000000000002520002240001da00001a0020d6bdbf78c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200a0c9e75c4800000000000000000000000000000029000000090000000000000000000000000000000000000000000001880000ec0000b05100db74dfdd3bb46be8ce6c33dc9d82777bcfc3ded5c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200443df0212400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000014101c02aaa39b223fe8d0a0e5c4f27ead9083c756cc200042e1a7d4d0000000000000000000000000000000000000000000000000000000000000000416086f874212335af27c41cdb855c2255543d1499ce00242668dfaa0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000008c864d0c8e476bf9eb9d620c10e1296fb0e2f94000a0f2fa6b66cd5fe23c85820f7b72d0926fc9b05b43e359b7ee0000000000000000000000000000000000000000000000646a08526a24695c2e00000000000000000003ea6740d11d1f80a06c4eca27cd5fe23c85820f7b72d0926fc9b05b43e359b7ee1111111254eeb25477b68fb85ed929f73a960582";

        // right executor here
        targetData[1] = abi.encodeWithSignature(
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)", NEW_ONE_INCH_EXECUTOR_MAINNET, swapTokenInfo, "", data
        );

        address[] memory decodersAndSanitizers = new address[](3);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](3);

        vm.expectRevert(
            OneInchOwnedDecoderAndSanitizer.OneInchDecoderAndSanitizer__InvalidExecutor.selector
        ); 
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        // right executor here
        swapTokenInfo = DecoderCustomTypes.SwapDescription({
            srcToken: getAddress(sourceChain, "WETH"),
            dstToken: getAddress(sourceChain, "WEETH"),
            srcReceiver: payable(NEW_ONE_INCH_EXECUTOR_MAINNET),
            dstReceiver: payable(address(boringVault)),
            amount: 2000000000000000000000,
            minReturnAmount: 1852129623269144641715,
            flags: 4
        });
        
        // wrong executor here
        targetData[2] = abi.encodeWithSignature(
            "swap(address,(address,address,address,address,uint256,uint256,uint256),bytes,bytes)", OLD_ONE_INCH_EXECUTOR_MAINNET, swapTokenInfo, "", data
        );

        vm.expectRevert(
            OneInchOwnedDecoderAndSanitizer.OneInchDecoderAndSanitizer__InvalidExecutor.selector
        ); 

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    event OneInchExecutorSet(address oneInchExecutor);
    function testDecoderSetExecutor() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 22140604;

        _startFork(rpcKey, blockNumber);

        OneInchOwnedDecoderAndSanitizer decoder = new FullOneInchOwnedDecoderAndSanitizer(address(this), getAddress(sourceChain, "oneInchExecutor"));
        vm.expectEmit(true, true, true, true);
        emit OneInchExecutorSet(getAddress(sourceChain, "oneInchExecutor"));
        decoder.setOneInchExecutor(getAddress(sourceChain, "oneInchExecutor"));
        assertEq(decoder.oneInchExecutor(), getAddress(sourceChain, "oneInchExecutor"));
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

contract FullOneInchOwnedDecoderAndSanitizer is BaseDecoderAndSanitizer, OneInchOwnedDecoderAndSanitizer {
    constructor(address _owner, address _oneInchExecutor) OneInchOwnedDecoderAndSanitizer(_owner, _oneInchExecutor){}
}
