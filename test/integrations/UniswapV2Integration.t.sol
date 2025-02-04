// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import { UniswapV2DecoderAndSanitizer } from "src/base/DecodersAndSanitizers/Protocols/UniswapV2DecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract UniswapV2IntegrationTest is Test, MerkleTreeHelper {
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
        uint256 blockNumber = 21665883;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new FullUniswapV2DecoderAndSanitizer());

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

    function testUniswapV2IntegrationLiquidityFunctionsNoETH() external {
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "WETH");
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "USDC");

        _addUniswapV2Leafs(leafs, token0, token1, false);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //string memory filePath = "testTEST.json";
        //_generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](5);
        manageLeafs[0] = leafs[0]; //tokens are sorted, so this is actually leaf 1, token1 becomes token0 during sort since USDC > WETH address
        manageLeafs[1] = leafs[1]; //approve weth 
        manageLeafs[2] = leafs[2]; //approve tokenPair
        manageLeafs[3] = leafs[7]; //addLiquidity
        manageLeafs[4] = leafs[8]; //removeLiquidity

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address tokenPair = IUniswapV2Factory(getAddress(sourceChain, "uniV2Factory")).getPair(token0[0], token1[0]); 

        address[] memory targets = new address[](5);
        targets[0] = getAddress(sourceChain, "USDC");
        targets[1] = getAddress(sourceChain, "WETH");
        targets[2] = tokenPair; 
        targets[3] = getAddress(sourceChain, "uniV2Router");
        targets[4] = getAddress(sourceChain, "uniV2Router");

        bytes[] memory targetData = new bytes[](5);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "uniV2Router"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "uniV2Router"), type(uint256).max
        );
        targetData[2] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "uniV2Router"), type(uint256).max
        );
        targetData[3] = abi.encodeWithSignature(
            "addLiquidity(address,address,uint256,uint256,uint256,uint256,address,uint256)", 
                getAddress(sourceChain, "USDC"),
                getAddress(sourceChain, "WETH"),
                100_000e8,
                1_000e18,
                0,
                0,
                getAddress(sourceChain, "boringVault"),
                block.timestamp + 1
        );
        uint256 amountLiquidity = 26539317965273; 
        targetData[4] = abi.encodeWithSignature(
            "removeLiquidity(address,address,uint256,uint256,uint256,address,uint256)", 
                getAddress(sourceChain, "USDC"),
                getAddress(sourceChain, "WETH"),
                amountLiquidity,
                0,
                0,
                getAddress(sourceChain, "boringVault"),
                block.timestamp + 1
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

    function testUniswapV2IntegrationLiquidityFunctionsWithETH() external {
        deal(address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "ETH");
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "USDC");

        _addUniswapV2Leafs(leafs, token0, token1, true);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //string memory filePath = "testTEST.json";
        //_generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](4);
        manageLeafs[0] = leafs[0]; //tokens are sorted, so this is actually leaf 1, token1 becomes token0 during sort since USDC > WETH address
        manageLeafs[1] = leafs[2]; //approve tokenPair
        manageLeafs[2] = leafs[13]; //addLiquidityETH
        manageLeafs[3] = leafs[14]; //removeLiquidityETH

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address tokenPair = IUniswapV2Factory(getAddress(sourceChain, "uniV2Factory")).getPair(token0[0], token1[0]); 

        address[] memory targets = new address[](4);
        targets[0] = getAddress(sourceChain, "USDC");
        targets[1] = tokenPair; 
        targets[2] = getAddress(sourceChain, "uniV2Router");
        targets[3] = getAddress(sourceChain, "uniV2Router");

        bytes[] memory targetData = new bytes[](4);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "uniV2Router"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "uniV2Router"), type(uint256).max
        );
        targetData[2] = abi.encodeWithSignature(
            "addLiquidityETH(address,uint256,uint256,uint256,address,uint256)", 
                getAddress(sourceChain, "USDC"),
                100_000e8,
                0,
                0,
                getAddress(sourceChain, "boringVault"),
                block.timestamp + 1
        );
        uint256 amountLiquidity = 26539317965273; 
        targetData[3] = abi.encodeWithSignature(
            "removeLiquidityETH(address,uint256,uint256,uint256,address,uint256)", 
                getAddress(sourceChain, "USDC"),
                amountLiquidity,
                0,
                0,
                getAddress(sourceChain, "boringVault"),
                block.timestamp + 1
        );

        address[] memory decodersAndSanitizers = new address[](4);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        
        uint256[] memory values = new uint256[](4); 
        values[0] = 0; 
        values[1] = 0; 
        values[2] = 1000e18; 
        values[3] = 0; 

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testUniswapV2IntegrationSwapsNoETH() external {
        deal(getAddress(sourceChain, "WETH"), address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "WETH");
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "USDC");

        _addUniswapV2Leafs(leafs, token0, token1, false);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        //string memory filePath = "testTEST.json";
        //_generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](6);
        manageLeafs[0] = leafs[0]; 
        manageLeafs[1] = leafs[1]; 
        manageLeafs[2] = leafs[3]; //swapTokensForTokens token0 -> token1 
        manageLeafs[3] = leafs[4]; //swapTokensForTokens token0 -> token1 
        manageLeafs[4] = leafs[5]; //swapTokenForExactTokens token0 -> token1 
        manageLeafs[5] = leafs[6]; //swapTokenForExactTokens token1 -> token0

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        //address tokenPair = IUniswapV2Factory(getAddress(sourceChain, "uniV2Factory")).getPair(token0[0], token1[0]); 

        address[] memory targets = new address[](6);
        targets[0] = getAddress(sourceChain, "USDC");
        targets[1] = getAddress(sourceChain, "WETH");
        targets[2] = getAddress(sourceChain, "uniV2Router");
        targets[3] = getAddress(sourceChain, "uniV2Router");
        targets[4] = getAddress(sourceChain, "uniV2Router");
        targets[5] = getAddress(sourceChain, "uniV2Router");
        
        
        address[] memory path =  new address[](2); 
        path[0] = getAddress(sourceChain, "USDC");
        path[1] = getAddress(sourceChain, "WETH");

        bytes[] memory targetData = new bytes[](6);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "uniV2Router"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "uniV2Router"), type(uint256).max
        );
        targetData[2] = abi.encodeWithSignature(
            "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)", 
                100_000e8,
                0,
                path,
                getAddress(sourceChain, "boringVault"),
                block.timestamp + 1
        );
        
        uint256 wethOut = 2112645616190283048320; 
        path[0] = getAddress(sourceChain, "WETH");
        path[1] = getAddress(sourceChain, "USDC");

        targetData[3] = abi.encodeWithSignature(
            "swapExactTokensForTokens(uint256,uint256,address[],address,uint256)", 
                wethOut,
                0,
                path,
                getAddress(sourceChain, "boringVault"),
                block.timestamp + 1
        );

        path[0] = getAddress(sourceChain, "USDC");
        path[1] = getAddress(sourceChain, "WETH");
        
        //swap USDC for exactly 
        targetData[4] = abi.encodeWithSignature(
            "swapTokensForExactTokens(uint256,uint256,address[],address,uint256)", 
                10e18,
                100_000_000e18,
                path,
                getAddress(sourceChain, "boringVault"),
                block.timestamp + 1
        );

        path[0] = getAddress(sourceChain, "WETH");
        path[1] = getAddress(sourceChain, "USDC");

        targetData[5] = abi.encodeWithSignature(
            "swapTokensForExactTokens(uint256,uint256,address[],address,uint256)", 
                100e6,
                1e18,
                path,
                getAddress(sourceChain, "boringVault"),
                block.timestamp + 1
        );

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

    function testUniswapV2IntegrationSwapsWithETH() external {
        deal(address(boringVault), 1_000e18);
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "ETH");
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "USDC");

        _addUniswapV2Leafs(leafs, token0, token1, true);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "testTEST.json";
        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](6);
        manageLeafs[0] = leafs[0]; 
        manageLeafs[1] = leafs[1]; 
        manageLeafs[2] = leafs[9]; //swapExactETHForTokens ETH -> token
        manageLeafs[3] = leafs[10]; //swapExactTokensForETH token -> ETH
        manageLeafs[4] = leafs[11]; //swapTokensForExactETH token -> ETH
        manageLeafs[5] = leafs[12]; //swapTokenForExactTokens token1 -> token0

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        //address tokenPair = IUniswapV2Factory(getAddress(sourceChain, "uniV2Factory")).getPair(token0[0], token1[0]); 

        address[] memory targets = new address[](6);
        targets[0] = getAddress(sourceChain, "USDC");
        targets[1] = getAddress(sourceChain, "WETH");
        targets[2] = getAddress(sourceChain, "uniV2Router");
        targets[3] = getAddress(sourceChain, "uniV2Router");
        targets[4] = getAddress(sourceChain, "uniV2Router");
        targets[5] = getAddress(sourceChain, "uniV2Router");
        
        
        address[] memory path =  new address[](2); 
        path[0] = getAddress(sourceChain, "WETH");
        path[1] = getAddress(sourceChain, "USDC");

        bytes[] memory targetData = new bytes[](6);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "uniV2Router"), type(uint256).max
        );
        targetData[1] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "uniV2Router"), type(uint256).max
        );
        targetData[2] = abi.encodeWithSignature(
            "swapExactETHForTokens(uint256,address[],address,uint256)",
            0,
            path,
            getAddress(sourceChain, "boringVault"),
            block.timestamp + 1
        );

        path[0] = getAddress(sourceChain, "USDC");
        path[1] = getAddress(sourceChain, "WETH");

        targetData[3] = abi.encodeWithSignature(
            "swapExactTokensForETH(uint256,uint256,address[],address,uint256)",
            100e6,
            0,
            path,
            getAddress(sourceChain, "boringVault"),
            block.timestamp + 1
        );

        targetData[4] = abi.encodeWithSignature(
            "swapTokensForExactETH(uint256,uint256,address[],address,uint256)",
            1e18,
            3000e8,
            path,
            getAddress(sourceChain, "boringVault"),
            block.timestamp + 1
        );

        path[0] = getAddress(sourceChain, "WETH");
        path[1] = getAddress(sourceChain, "USDC");

        targetData[5] = abi.encodeWithSignature(
            "swapETHForExactTokens(uint256,address[],address,uint256)",
            3000e8,
            path,
            getAddress(sourceChain, "boringVault"),
            block.timestamp + 1
        );
        
        address[] memory decodersAndSanitizers = new address[](6);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        
        uint256[] memory values = new uint256[](6); 
        values[0] = 0; 
        values[1] = 0; 
        values[2] = 10e18; 
        values[3] = 0; 
        values[4] = 0; 
        values[5] = 100e18; 

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }


    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}


contract FullUniswapV2DecoderAndSanitizer is UniswapV2DecoderAndSanitizer { }

interface IUniswapV2Factory {
    function getPair(address token0, address token1) external view returns (address); 
}
