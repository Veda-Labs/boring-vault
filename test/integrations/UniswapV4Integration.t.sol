// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { MainnetAddresses } from "test/resources/MainnetAddresses.sol";
import { BoringVault } from "src/base/BoringVault.sol";
import { ManagerWithMerkleVerification } from "src/base/Roles/ManagerWithMerkleVerification.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";
import { FixedPointMathLib } from "@solmate/utils/FixedPointMathLib.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { ERC4626 } from "@solmate/tokens/ERC4626.sol";
import {
    UniswapV4DecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/Protocols/UniswapV4DecoderAndSanitizer.sol";
import { DecoderCustomTypes } from "src/interfaces/DecoderCustomTypes.sol";
import { Actions, Commands, TickMath, LiquidityAmounts, Constants } from "src/interfaces/UniswapV4Actions.sol";
import { RolesAuthority, Authority } from "@solmate/auth/authorities/RolesAuthority.sol";
import { MerkleTreeHelper } from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import { Test, stdStorage, StdStorage, stdError, console } from "@forge-std/Test.sol";

contract UniswapV4IntegrationTest is Test, MerkleTreeHelper {
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
        uint256 blockNumber = 21_838_936;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer =
            address(new FullUniswapV4DecoderAndSanitizer(getAddress(sourceChain, "uniV4PositionManager")));

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

    function testUniswapV4Swaps() external {
        deal(getAddress(sourceChain, "USDT"), address(boringVault), 1_000_000e6);
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e8);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "USDT");
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "USDC");
        address[] memory hooks = new address[](1);
        hooks[0] = address(0);

        _addUniswapV4Leafs(leafs, token0, token1, hooks);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        //_generateTestLeafs(leafs, manageTree);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](7);
        manageLeafs[0] = leafs[0]; //approve USDC router
        manageLeafs[1] = leafs[2]; //approve USDC permit2
        manageLeafs[2] = leafs[3]; //approve USDC permit2 router

        manageLeafs[3] = leafs[5]; //approve USDT router
        manageLeafs[4] = leafs[7]; //approve USDT permit2
        manageLeafs[5] = leafs[8]; //approve USDT permit2 router

        manageLeafs[6] = leafs[10]; //execute() V4_SWAP token0 -> token1

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](7);
        targets[0] = getAddress(sourceChain, "USDC"); //approve router
        targets[1] = getAddress(sourceChain, "USDC"); //approve permit2
        targets[2] = getAddress(sourceChain, "permit2"); //approve permit2 router

        targets[3] = getAddress(sourceChain, "USDT"); //approve
        targets[4] = getAddress(sourceChain, "USDT"); //approve
        targets[5] = getAddress(sourceChain, "permit2"); //approve permit2 router

        targets[6] = getAddress(sourceChain, "uniV4UniversalRouter");

        bytes[] memory targetData = new bytes[](7);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "uniV4UniversalRouter"), type(uint256).max
        );
        targetData[1] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max);
        targetData[2] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)",
            getAddress(sourceChain, "USDC"),
            getAddress(sourceChain, "uniV4UniversalRouter"),
            1000e8,
            block.timestamp + 1000
        );
        targetData[3] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "uniV4UniversalRouter"), type(uint256).max
        );
        targetData[4] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max);
        targetData[5] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)",
            getAddress(sourceChain, "USDT"),
            getAddress(sourceChain, "uniV4UniversalRouter"),
            type(uint160).max,
            block.timestamp + 1000
        );

        // Universal Router takes 2 params, commands and inputs.
        // Commands == V4_SWAP
        // Inputs are broken down into smaller things: Actions and Params
        // Actions help the flow of the swap, and Params are params for the actions
        // Actions.SWAP_SINGLE would have params of SwapParams, etc
        // these are then put together in inputs[0] = abi.encode(actions, params);
        // and this is used in the `execute()` function

        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);

        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_IN_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));

        DecoderCustomTypes.PoolKey memory key = DecoderCustomTypes.PoolKey(
            getAddress(sourceChain, "USDC"),
            getAddress(sourceChain, "USDT"),
            100,
            1,
            address(0) //no hook address?
        );

        uint128 amountIn = 1e8;
        uint128 minAmountOut = 0;

        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            DecoderCustomTypes.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: true, // true if we're swapping token0 for token1
                amountIn: amountIn, // amount of tokens we're swapping
                amountOutMinimum: minAmountOut, // minimum amount we expect to receive
                hookData: bytes("") // no hook data needed
            })
        );

        // Second parameter: specify input tokens for the swap
        // encode SETTLE_ALL parameters
        params[1] = abi.encode(key.currency0, amountIn);
        // Third parameter: specify output tokens from the swap
        params[2] = abi.encode(key.currency1, minAmountOut);
        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        targetData[6] = abi.encodeWithSignature("execute(bytes,bytes[],uint256)", commands, inputs, block.timestamp);

        address[] memory decodersAndSanitizers = new address[](7);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](7)
        );
    }

    function testUniswapV4SwapsToken1ForToken0() external {
        deal(getAddress(sourceChain, "USDT"), address(boringVault), 1_000_000e6);
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e8);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "USDT");
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "USDC");
        address[] memory hooks = new address[](1);
        hooks[0] = address(0);

        _addUniswapV4Leafs(leafs, token0, token1, hooks);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        //_generateTestLeafs(leafs, manageTree);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](7);
        manageLeafs[0] = leafs[0]; //approve USDC router
        manageLeafs[1] = leafs[2]; //approve USDC permit2
        manageLeafs[2] = leafs[3]; //approve USDC permit2 router

        manageLeafs[3] = leafs[5]; //approve USDT router
        manageLeafs[4] = leafs[7]; //approve USDT permit2
        manageLeafs[5] = leafs[8]; //approve USDT permit2 router

        manageLeafs[6] = leafs[11]; //execute() V4_SWAP token1 -> token0

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](7);
        targets[0] = getAddress(sourceChain, "USDC"); //approve router
        targets[1] = getAddress(sourceChain, "USDC"); //approve permit2
        targets[2] = getAddress(sourceChain, "permit2"); //approve permit2 router

        targets[3] = getAddress(sourceChain, "USDT"); //approve
        targets[4] = getAddress(sourceChain, "USDT"); //approve
        targets[5] = getAddress(sourceChain, "permit2"); //approve permit2 router

        targets[6] = getAddress(sourceChain, "uniV4UniversalRouter");

        bytes[] memory targetData = new bytes[](7);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "uniV4UniversalRouter"), type(uint256).max
        );
        targetData[1] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max);
        targetData[2] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)",
            getAddress(sourceChain, "USDC"),
            getAddress(sourceChain, "uniV4UniversalRouter"),
            1000e8,
            block.timestamp + 1000
        );
        targetData[3] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "uniV4UniversalRouter"), type(uint256).max
        );
        targetData[4] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max);
        targetData[5] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)",
            getAddress(sourceChain, "USDT"),
            getAddress(sourceChain, "uniV4UniversalRouter"),
            type(uint160).max,
            block.timestamp + 1000
        );

        // Universal Router takes 2 params, commands and inputs.
        // Commands == V4_SWAP
        // Inputs are broken down into smaller things: Actions and Params
        // Actions help the flow of the swap, and Params are params for the actions
        // Actions.SWAP_SINGLE would have params of SwapParams, etc
        // these are then put together in inputs[0] = abi.encode(actions, params);
        // and this is used in the `execute()` function

        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);

        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_IN_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));

        DecoderCustomTypes.PoolKey memory key = DecoderCustomTypes.PoolKey(
            getAddress(sourceChain, "USDC"),
            getAddress(sourceChain, "USDT"),
            100,
            1,
            address(0) //no hook address?
        );

        uint128 amountIn = 1e8;
        uint128 minAmountOut = 0;

        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            DecoderCustomTypes.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: false, // true if we're swapping token0 for token1
                amountIn: amountIn, // amount of tokens we're swapping
                amountOutMinimum: minAmountOut, // minimum amount we expect to receive
                hookData: bytes("") // no hook data needed
            })
        );

        // Second parameter: specify input tokens for the swap
        // encode SETTLE_ALL parameters
        params[1] = abi.encode(key.currency1, amountIn);
        // Third parameter: specify output tokens from the swap
        params[2] = abi.encode(key.currency0, minAmountOut);
        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        targetData[6] = abi.encodeWithSignature("execute(bytes,bytes[],uint256)", commands, inputs, block.timestamp);

        address[] memory decodersAndSanitizers = new address[](7);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](7)
        );
    }

    function testUniswapV4SwapsToken0ForToken1ExactOutput() external {
        deal(getAddress(sourceChain, "USDT"), address(boringVault), 1_000_000e6);
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e8);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "USDT");
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "USDC");
        address[] memory hooks = new address[](1);
        hooks[0] = address(0);

        _addUniswapV4Leafs(leafs, token0, token1, hooks);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        //_generateTestLeafs(leafs, manageTree);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](7);
        manageLeafs[0] = leafs[0]; //approve USDC router
        manageLeafs[1] = leafs[2]; //approve USDC permit2
        manageLeafs[2] = leafs[3]; //approve USDC permit2 router

        manageLeafs[3] = leafs[5]; //approve USDT router
        manageLeafs[4] = leafs[7]; //approve USDT permit2
        manageLeafs[5] = leafs[8]; //approve USDT permit2 router

        manageLeafs[6] = leafs[10]; //execute() V4_SWAP token1 -> token0

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](7);
        targets[0] = getAddress(sourceChain, "USDC"); //approve router
        targets[1] = getAddress(sourceChain, "USDC"); //approve permit2
        targets[2] = getAddress(sourceChain, "permit2"); //approve permit2 router

        targets[3] = getAddress(sourceChain, "USDT"); //approve
        targets[4] = getAddress(sourceChain, "USDT"); //approve
        targets[5] = getAddress(sourceChain, "permit2"); //approve permit2 router

        targets[6] = getAddress(sourceChain, "uniV4UniversalRouter");

        bytes[] memory targetData = new bytes[](7);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "uniV4UniversalRouter"), type(uint256).max
        );
        targetData[1] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max);
        targetData[2] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)",
            getAddress(sourceChain, "USDC"),
            getAddress(sourceChain, "uniV4UniversalRouter"),
            1000e8,
            block.timestamp + 1000
        );
        targetData[3] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "uniV4UniversalRouter"), type(uint256).max
        );
        targetData[4] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max);
        targetData[5] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)",
            getAddress(sourceChain, "USDT"),
            getAddress(sourceChain, "uniV4UniversalRouter"),
            type(uint160).max,
            block.timestamp + 1000
        );

        // Universal Router takes 2 params, commands and inputs.
        // Commands == V4_SWAP
        // Inputs are broken down into smaller things: Actions and Params
        // Actions help the flow of the swap, and Params are params for the actions
        // Actions.SWAP_SINGLE would have params of SwapParams, etc
        // these are then put together in inputs[0] = abi.encode(actions, params);
        // and this is used in the `execute()` function

        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);

        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_OUT_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));

        DecoderCustomTypes.PoolKey memory key = DecoderCustomTypes.PoolKey(
            getAddress(sourceChain, "USDC"),
            getAddress(sourceChain, "USDT"),
            100,
            1,
            address(0) //no hook address?
        );

        uint128 amountOut = 1e8;
        uint128 amountInMax = 100e8;

        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            DecoderCustomTypes.ExactOutputSingleParams({
                poolKey: key,
                zeroForOne: true, // true if we're swapping token0 for token1
                amountOut: amountOut, // amount of tokens we're swapping for
                amountInMaximum: amountInMax, // max amount we expect to spend
                hookData: bytes("") // no hook data needed
            })
        );

        // Second parameter: specify input tokens for the swap
        // encode SETTLE_ALL parameters
        params[1] = abi.encode(key.currency0, amountInMax);
        // Third parameter: specify output tokens from the swap
        params[2] = abi.encode(key.currency1, amountOut);
        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        targetData[6] = abi.encodeWithSignature("execute(bytes,bytes[],uint256)", commands, inputs, block.timestamp);

        address[] memory decodersAndSanitizers = new address[](7);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](7)
        );
    }

    function testUniswapV4SwapsToken1ForToken0ExactOutput() external {
        deal(getAddress(sourceChain, "USDT"), address(boringVault), 1_000_000e6);
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e8);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "USDT");
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "USDC");
        address[] memory hooks = new address[](1);
        hooks[0] = address(0);

        _addUniswapV4Leafs(leafs, token0, token1, hooks);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        //_generateTestLeafs(leafs, manageTree);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](7);
        manageLeafs[0] = leafs[0]; //approve USDC router
        manageLeafs[1] = leafs[2]; //approve USDC permit2
        manageLeafs[2] = leafs[3]; //approve USDC permit2 router

        manageLeafs[3] = leafs[5]; //approve USDT router
        manageLeafs[4] = leafs[7]; //approve USDT permit2
        manageLeafs[5] = leafs[8]; //approve USDT permit2 router

        manageLeafs[6] = leafs[11]; //execute() V4_SWAP token1 -> token0 (EXACT_OUT_SINGLE)

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](7);
        targets[0] = getAddress(sourceChain, "USDC"); //approve router
        targets[1] = getAddress(sourceChain, "USDC"); //approve permit2
        targets[2] = getAddress(sourceChain, "permit2"); //approve permit2 router

        targets[3] = getAddress(sourceChain, "USDT"); //approve
        targets[4] = getAddress(sourceChain, "USDT"); //approve
        targets[5] = getAddress(sourceChain, "permit2"); //approve permit2 router

        targets[6] = getAddress(sourceChain, "uniV4UniversalRouter");

        bytes[] memory targetData = new bytes[](7);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "uniV4UniversalRouter"), type(uint256).max
        );
        targetData[1] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max);
        targetData[2] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)",
            getAddress(sourceChain, "USDC"),
            getAddress(sourceChain, "uniV4UniversalRouter"),
            1000e8,
            block.timestamp + 1000
        );
        targetData[3] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "uniV4UniversalRouter"), type(uint256).max
        );
        targetData[4] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max);
        targetData[5] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)",
            getAddress(sourceChain, "USDT"),
            getAddress(sourceChain, "uniV4UniversalRouter"),
            type(uint160).max,
            block.timestamp + 1000
        );

        // Universal Router takes 2 params, commands and inputs.
        // Commands == V4_SWAP
        // Inputs are broken down into smaller things: Actions and Params
        // Actions help the flow of the swap, and Params are params for the actions
        // Actions.SWAP_SINGLE would have params of SwapParams, etc
        // these are then put together in inputs[0] = abi.encode(actions, params);
        // and this is used in the `execute()` function

        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);

        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_OUT_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));

        DecoderCustomTypes.PoolKey memory key = DecoderCustomTypes.PoolKey(
            getAddress(sourceChain, "USDC"),
            getAddress(sourceChain, "USDT"),
            100,
            1,
            address(0) //no hook address?
        );

        uint128 amountOut = 1e8;
        uint128 amountInMax = 100e8;

        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            DecoderCustomTypes.ExactOutputSingleParams({
                poolKey: key,
                zeroForOne: false, // true if we're swapping token0 for token1
                amountOut: amountOut, // amount of tokens we're swapping for
                amountInMaximum: amountInMax, // max amount we expect to spend
                hookData: bytes("") // no hook data needed
            })
        );

        // Second parameter: specify input tokens for the swap
        // encode SETTLE_ALL parameters
        params[1] = abi.encode(key.currency1, amountInMax);
        // Third parameter: specify output tokens from the swap
        params[2] = abi.encode(key.currency0, amountOut);
        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        targetData[6] = abi.encodeWithSignature("execute(bytes,bytes[],uint256)", commands, inputs, block.timestamp);

        address[] memory decodersAndSanitizers = new address[](7);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](7)
        );
    }

    function testUniswapV4LiquidityFunctions() external {
        deal(getAddress(sourceChain, "USDT"), address(boringVault), 1_000_000e6);
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e8);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "USDT");
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "USDC");
        address[] memory hooks = new address[](1);
        hooks[0] = address(0);

        _addUniswapV4Leafs(leafs, token0, token1, hooks);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        //_generateTestLeafs(leafs, manageTree);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](8);
        manageLeafs[0] = leafs[2]; //approve usdc permit2
        manageLeafs[1] = leafs[7]; //approve usdt permit2
        manageLeafs[2] = leafs[4]; //approve usdc permit2 for positionManager
        manageLeafs[3] = leafs[9]; //approve usdt positionManager()
        manageLeafs[4] = leafs[12]; //modifyLiquidities() mint
        manageLeafs[5] = leafs[13]; //modifyLiquidities() increase via SETTLE
        manageLeafs[6] = leafs[14]; //modifyLiquidities() decrease
        manageLeafs[7] = leafs[14]; //modifyLiquidities() collect (same leaf as decrease)

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](8);
        targets[0] = getAddress(sourceChain, "USDC"); //approve usdc permit2
        targets[1] = getAddress(sourceChain, "USDT"); //approve usdt permit2
        targets[2] = getAddress(sourceChain, "permit2"); //approve permit2 posm usdc
        targets[3] = getAddress(sourceChain, "permit2"); //approve permit2 posm usdt
        targets[4] = getAddress(sourceChain, "uniV4PositionManager"); //modifyLiquidities mint
        targets[5] = getAddress(sourceChain, "uniV4PositionManager"); //modifyLiquidities increase
        targets[6] = getAddress(sourceChain, "uniV4PositionManager"); //modifyLiquidities decrease
        targets[7] = getAddress(sourceChain, "uniV4PositionManager"); //modifyLiquidities collect

        bytes[] memory targetData = new bytes[](8);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max);
        targetData[1] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max);
        targetData[2] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)",
            getAddress(sourceChain, "USDC"),
            getAddress(sourceChain, "uniV4PositionManager"),
            type(uint160).max,
            type(uint48).max
        );
        targetData[3] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)",
            getAddress(sourceChain, "USDT"),
            getAddress(sourceChain, "uniV4PositionManager"),
            type(uint160).max,
            type(uint48).max
        );

        DecoderCustomTypes.PoolKey memory key = DecoderCustomTypes.PoolKey(
            getAddress(sourceChain, "USDC"),
            getAddress(sourceChain, "USDT"),
            100,
            1,
            address(0) //no hook address?
        );

        //actions
        bytes memory liquidityActions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));
        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(
            key,
            TickMath.minUsableTick(key.tickSpacing),
            TickMath.maxUsableTick(key.tickSpacing),
            100e6,
            type(uint128).max,
            type(uint128).max,
            address(boringVault),
            new bytes(0)
        );
        params[1] = abi.encode(key.currency0, key.currency1);

        //mint token id = 2345
        targetData[4] = abi.encodeWithSignature(
            "modifyLiquidities(bytes,uint256)", abi.encode(liquidityActions, params), block.timestamp
        );

        //increase liquidity
        liquidityActions = abi.encodePacked(uint8(Actions.INCREASE_LIQUIDITY), uint8(Actions.SETTLE_PAIR));
        params = new bytes[](2);
        params[0] = abi.encode(2345, 100e6, type(uint128).max, type(uint128).max, new bytes(0));
        params[1] = abi.encode(key.currency0, key.currency1);

        targetData[5] = abi.encodeWithSignature(
            "modifyLiquidities(bytes,uint256)", abi.encode(liquidityActions, params), block.timestamp
        );

        //decrease liquidity
        liquidityActions = abi.encodePacked(uint8(Actions.DECREASE_LIQUIDITY), uint8(Actions.TAKE_PAIR));
        params = new bytes[](2);
        params[0] = abi.encode(2345, 50e6, 0, 0, new bytes(0));
        params[1] = abi.encode(key.currency0, key.currency1, address(boringVault));

        targetData[6] = abi.encodeWithSignature(
            "modifyLiquidities(bytes,uint256)", abi.encode(liquidityActions, params), block.timestamp
        );

        //collect, no fees are collected here in the test because none have accumulated (view the logs with -vvvv to see this happening)
        // @dev collect is done by decreasing liquidity with a 0 amount, and then taking the pair
        liquidityActions = abi.encodePacked(uint8(Actions.DECREASE_LIQUIDITY), uint8(Actions.TAKE_PAIR));
        params = new bytes[](2);
        params[0] = abi.encode(
            2345,
            0, //no liquidity decrease
            0,
            0,
            new bytes(0)
        );
        //still take fees here
        params[1] = abi.encode(key.currency0, key.currency1, address(boringVault));

        targetData[7] = abi.encodeWithSignature(
            "modifyLiquidities(bytes,uint256)", abi.encode(liquidityActions, params), block.timestamp
        );

        address[] memory decodersAndSanitizers = new address[](8);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](8)
        );

        skip(1 days);

        manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[16];

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](1);
        targets[0] = getAddress(sourceChain, "uniV4PositionManager"); //modifyLiquidities

        targetData = new bytes[](1);

        // @dev docs are wrong here, we need to take pair still
        liquidityActions = abi.encodePacked(uint8(Actions.BURN_POSITION), uint8(Actions.TAKE_PAIR));
        params = new bytes[](2);
        params[0] = abi.encode(
            2345,
            0, //amount0
            0, //amount1
            new bytes(0)
        );
        //still take fees here
        params[1] = abi.encode(key.currency0, key.currency1, address(boringVault));

        targetData[0] = abi.encodeWithSignature(
            "modifyLiquidities(bytes,uint256)", abi.encode(liquidityActions, params), block.timestamp + 1
        );

        decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](1)
        );
    }

    function testUniswapV4LiquidityFunctionsCloseCurrency() external {
        deal(getAddress(sourceChain, "USDT"), address(boringVault), 1_000_000e6);
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e8);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "USDT");
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "USDC");
        address[] memory hooks = new address[](1);
        hooks[0] = address(0);

        _addUniswapV4Leafs(leafs, token0, token1, hooks);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        //_generateTestLeafs(leafs, manageTree);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](8);
        manageLeafs[0] = leafs[2]; //approve usdc permit2
        manageLeafs[1] = leafs[7]; //approve usdt permit2
        manageLeafs[2] = leafs[4]; //approve usdc permit2 for positionManager
        manageLeafs[3] = leafs[9]; //approve usdt positionManager()
        manageLeafs[4] = leafs[12]; //modifyLiquidities() mint
        manageLeafs[5] = leafs[13]; //modifyLiquidities() increase via CLOSE_CURRENCY
        manageLeafs[6] = leafs[15]; //modifyLiquidities() decrease via CLOSE_CURRENCY
        manageLeafs[7] = leafs[14]; //modifyLiquidities() collect (same leaf as decrease)

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](8);
        targets[0] = getAddress(sourceChain, "USDC"); //approve usdc permit2
        targets[1] = getAddress(sourceChain, "USDT"); //approve usdt permit2
        targets[2] = getAddress(sourceChain, "permit2"); //approve permit2 posm usdc
        targets[3] = getAddress(sourceChain, "permit2"); //approve permit2 posm usdt
        targets[4] = getAddress(sourceChain, "uniV4PositionManager"); //modifyLiquidities mint
        targets[5] = getAddress(sourceChain, "uniV4PositionManager"); //modifyLiquidities increase
        targets[6] = getAddress(sourceChain, "uniV4PositionManager"); //modifyLiquidities decrease
        targets[7] = getAddress(sourceChain, "uniV4PositionManager"); //modifyLiquidities collect

        bytes[] memory targetData = new bytes[](8);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max);
        targetData[1] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max);
        targetData[2] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)",
            getAddress(sourceChain, "USDC"),
            getAddress(sourceChain, "uniV4PositionManager"),
            type(uint160).max,
            type(uint48).max
        );
        targetData[3] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)",
            getAddress(sourceChain, "USDT"),
            getAddress(sourceChain, "uniV4PositionManager"),
            type(uint160).max,
            type(uint48).max
        );

        DecoderCustomTypes.PoolKey memory key = DecoderCustomTypes.PoolKey(
            getAddress(sourceChain, "USDC"),
            getAddress(sourceChain, "USDT"),
            100,
            1,
            address(0) //no hook address?
        );

        //actions
        bytes memory liquidityActions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));
        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(
            key,
            TickMath.minUsableTick(key.tickSpacing),
            TickMath.maxUsableTick(key.tickSpacing),
            100e6,
            type(uint128).max,
            type(uint128).max,
            address(boringVault),
            new bytes(0)
        );
        params[1] = abi.encode(key.currency0, key.currency1);

        //mint token id = 2345
        targetData[4] = abi.encodeWithSignature(
            "modifyLiquidities(bytes,uint256)", abi.encode(liquidityActions, params), block.timestamp
        );

        //increase liquidity
        liquidityActions = abi.encodePacked(
            uint8(Actions.INCREASE_LIQUIDITY), uint8(Actions.CLOSE_CURRENCY), uint8(Actions.CLOSE_CURRENCY)
        );
        params = new bytes[](3);
        params[0] = abi.encode(2345, 100e6, type(uint128).max, type(uint128).max, new bytes(0));
        params[1] = abi.encode(key.currency0);
        params[2] = abi.encode(key.currency1);

        targetData[5] = abi.encodeWithSignature(
            "modifyLiquidities(bytes,uint256)", abi.encode(liquidityActions, params), block.timestamp
        );

        //decrease liquidity
        liquidityActions = abi.encodePacked(
            uint8(Actions.DECREASE_LIQUIDITY), uint8(Actions.CLEAR_OR_TAKE), uint8(Actions.CLEAR_OR_TAKE)
        );
        params = new bytes[](3);
        params[0] = abi.encode(2345, 50e6, 0, 0, new bytes(0));
        params[1] = abi.encode(key.currency0, 0);
        params[2] = abi.encode(key.currency1, 0);

        targetData[6] = abi.encodeWithSignature(
            "modifyLiquidities(bytes,uint256)", abi.encode(liquidityActions, params), block.timestamp
        );

        //collect, no fees are collected here in the test because none have accumulated (view the logs with -vvvv to see this happening)
        // @dev collect is done by decreasing liquidity with a 0 amount, and then taking the pair
        liquidityActions = abi.encodePacked(uint8(Actions.DECREASE_LIQUIDITY), uint8(Actions.TAKE_PAIR));
        params = new bytes[](2);
        params[0] = abi.encode(
            2345,
            0, //no liquidity decrease
            0,
            0,
            new bytes(0)
        );
        //still take fees here
        params[1] = abi.encode(key.currency0, key.currency1, address(boringVault));

        targetData[7] = abi.encodeWithSignature(
            "modifyLiquidities(bytes,uint256)", abi.encode(liquidityActions, params), block.timestamp
        );

        address[] memory decodersAndSanitizers = new address[](8);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[7] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](8)
        );

        skip(1 days);

        manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[16];

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](1);
        targets[0] = getAddress(sourceChain, "uniV4PositionManager"); //modifyLiquidities

        targetData = new bytes[](1);

        // @dev docs are wrong here, we need to take pair still
        liquidityActions = abi.encodePacked(uint8(Actions.BURN_POSITION), uint8(Actions.TAKE_PAIR));
        params = new bytes[](2);
        params[0] = abi.encode(
            2345,
            0, //amount0
            0, //amount1
            new bytes(0)
        );
        //still take fees here
        params[1] = abi.encode(key.currency0, key.currency1, address(boringVault));

        targetData[0] = abi.encodeWithSignature(
            "modifyLiquidities(bytes,uint256)", abi.encode(liquidityActions, params), block.timestamp + 1
        );

        decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](1)
        );
    }

    function testUniswapV4SwapsNativeForToken1() external {
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e8);
        deal(address(boringVault), 2e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "ETH"); //should be address(0), but this is handled in MerkleTreeHelper
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "USDC");
        address[] memory hooks = new address[](1);
        hooks[0] = address(0);

        _addUniswapV4Leafs(leafs, token0, token1, hooks);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        //_generateTestLeafs(leafs, manageTree);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](4);
        manageLeafs[0] = leafs[0]; //approve USDC router
        manageLeafs[1] = leafs[2]; //approve USDC permit2
        manageLeafs[2] = leafs[3]; //approve USDC permit2 router

        manageLeafs[3] = leafs[5]; //execute() V4_SWAP

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](4);
        targets[0] = getAddress(sourceChain, "USDC"); //approve router
        targets[1] = getAddress(sourceChain, "USDC"); //approve permit2
        targets[2] = getAddress(sourceChain, "permit2"); //approve permit2 router

        targets[3] = getAddress(sourceChain, "uniV4UniversalRouter");

        bytes[] memory targetData = new bytes[](4);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "uniV4UniversalRouter"), type(uint256).max
        );
        targetData[1] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max);
        targetData[2] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)",
            getAddress(sourceChain, "USDC"),
            getAddress(sourceChain, "uniV4UniversalRouter"),
            1000e8,
            block.timestamp + 1000
        );

        // Universal Router takes 2 params, commands and inputs.
        // Commands == V4_SWAP
        // Inputs are broken down into smaller things: Actions and Params
        // Actions help the flow of the swap, and Params are params for the actions
        // Actions.SWAP_SINGLE would have params of SwapParams, etc
        // these are then put together in inputs[0] = abi.encode(actions, params);
        // and this is used in the `execute()` function

        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP), uint8(Commands.SWEEP));
        bytes[] memory inputs = new bytes[](2);

        //bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        //bytes[] memory inputs = new bytes[](1);

        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_IN_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));

        DecoderCustomTypes.PoolKey memory key = DecoderCustomTypes.PoolKey(
            address(0), //ETH
            getAddress(sourceChain, "USDC"),
            500,
            10,
            address(0) //no hook address?
        );

        uint128 amountIn = 1e18;
        uint128 minAmountOut = 0;

        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            DecoderCustomTypes.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: true, // true if we're swapping token0 for token1
                amountIn: amountIn, // amount of tokens we're swapping
                amountOutMinimum: minAmountOut, // minimum amount we expect to receive
                hookData: bytes("") // no hook data needed
            })
        );

        // Second parameter: specify input tokens for the swap
        // encode SETTLE_ALL parameters
        params[1] = abi.encode(key.currency0, amountIn);
        // Third parameter: specify output tokens from the swap
        params[2] = abi.encode(key.currency1, minAmountOut);
        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);
        inputs[1] = abi.encode(key.currency0, address(boringVault), 0);

        targetData[3] = abi.encodeWithSignature("execute(bytes,bytes[],uint256)", commands, inputs, block.timestamp);

        address[] memory decodersAndSanitizers = new address[](4);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](4);
        values[0] = 0;
        values[1] = 0;
        values[2] = 0;
        values[3] = 2e18;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        uint256 ethBal = address(boringVault).balance;
        assertEq(ethBal, 1e18);
    }

    function testUniswapV4SwapsNativeForToken1ExactOut() external {
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e8);
        deal(address(boringVault), 5e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "ETH"); //should be address(0), but this is handled in MerkleTreeHelper
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "USDC");
        address[] memory hooks = new address[](1);
        hooks[0] = address(0);

        _addUniswapV4Leafs(leafs, token0, token1, hooks);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        //_generateTestLeafs(leafs, manageTree);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](4);
        manageLeafs[0] = leafs[0]; //approve USDC router
        manageLeafs[1] = leafs[2]; //approve USDC permit2
        manageLeafs[2] = leafs[3]; //approve USDC permit2 router

        manageLeafs[3] = leafs[5]; //execute() V4_SWAP

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](4);
        targets[0] = getAddress(sourceChain, "USDC"); //approve router
        targets[1] = getAddress(sourceChain, "USDC"); //approve permit2
        targets[2] = getAddress(sourceChain, "permit2"); //approve permit2 router

        targets[3] = getAddress(sourceChain, "uniV4UniversalRouter");

        bytes[] memory targetData = new bytes[](4);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "uniV4UniversalRouter"), type(uint256).max
        );
        targetData[1] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max);
        targetData[2] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)",
            getAddress(sourceChain, "USDC"),
            getAddress(sourceChain, "uniV4UniversalRouter"),
            1000e8,
            block.timestamp + 1000
        );

        // Universal Router takes 2 params, commands and inputs.
        // Commands == V4_SWAP
        // Inputs are broken down into smaller things: Actions and Params
        // Actions help the flow of the swap, and Params are params for the actions
        // Actions.SWAP_SINGLE would have params of SwapParams, etc
        // these are then put together in inputs[0] = abi.encode(actions, params);
        // and this is used in the `execute()` function

        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP), uint8(Commands.SWEEP));
        bytes[] memory inputs = new bytes[](2);

        //bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        //bytes[] memory inputs = new bytes[](1);

        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_OUT_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));

        DecoderCustomTypes.PoolKey memory key = DecoderCustomTypes.PoolKey(
            address(0), //ETH
            getAddress(sourceChain, "USDC"),
            500,
            10,
            address(0) //no hook address?
        );

        uint128 amountOut = 10e8;
        uint128 amountInMax = 2e18;

        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            DecoderCustomTypes.ExactOutputSingleParams({
                poolKey: key,
                zeroForOne: true, // true if we're swapping token0 for token1
                amountOut: amountOut, // amount of tokens we're swapping for
                amountInMaximum: amountInMax, // max amount we expect to spend
                hookData: bytes("") // no hook data needed
            })
        );

        // Second parameter: specify input tokens for the swap
        // encode SETTLE_ALL parameters
        params[1] = abi.encode(key.currency0, amountInMax);
        // Third parameter: specify output tokens from the swap
        params[2] = abi.encode(key.currency1, amountOut);
        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);
        inputs[1] = abi.encode(key.currency0, address(boringVault), 0);

        targetData[3] = abi.encodeWithSignature("execute(bytes,bytes[],uint256)", commands, inputs, block.timestamp);

        address[] memory decodersAndSanitizers = new address[](4);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](4);
        values[0] = 0;
        values[1] = 0;
        values[2] = 0;
        values[3] = 5e18;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        uint256 ethBal = address(boringVault).balance;
        assertEq(ethBal, 4_619_890_037_295_905_924);
    }

    function testUniswapV4SwapsToken1ForNative() external {
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e8);
        deal(address(boringVault), 1_000_000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "ETH"); //should be address(0), but this is handled in MerkleTreeHelper
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "USDC");
        address[] memory hooks = new address[](1);
        hooks[0] = address(0);

        _addUniswapV4Leafs(leafs, token0, token1, hooks);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        //_generateTestLeafs(leafs, manageTree);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](4);
        manageLeafs[0] = leafs[0]; //approve USDC router
        manageLeafs[1] = leafs[2]; //approve USDC permit2
        manageLeafs[2] = leafs[3]; //approve USDC permit2 router

        manageLeafs[3] = leafs[6]; //execute() V4_SWAP

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](4);
        targets[0] = getAddress(sourceChain, "USDC"); //approve router
        targets[1] = getAddress(sourceChain, "USDC"); //approve permit2
        targets[2] = getAddress(sourceChain, "permit2"); //approve permit2 router

        targets[3] = getAddress(sourceChain, "uniV4UniversalRouter");

        bytes[] memory targetData = new bytes[](4);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "uniV4UniversalRouter"), type(uint256).max
        );
        targetData[1] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max);
        targetData[2] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)",
            getAddress(sourceChain, "USDC"),
            getAddress(sourceChain, "uniV4UniversalRouter"),
            1000e8,
            block.timestamp + 1000
        );

        // Universal Router takes 2 params, commands and inputs.
        // Commands == V4_SWAP
        // Inputs are broken down into smaller things: Actions and Params
        // Actions help the flow of the swap, and Params are params for the actions
        // Actions.SWAP_SINGLE would have params of SwapParams, etc
        // these are then put together in inputs[0] = abi.encode(actions, params);
        // and this is used in the `execute()` function

        bytes memory commands = abi.encodePacked(uint8(Commands.V4_SWAP));
        bytes[] memory inputs = new bytes[](1);

        bytes memory actions =
            abi.encodePacked(uint8(Actions.SWAP_EXACT_IN_SINGLE), uint8(Actions.SETTLE_ALL), uint8(Actions.TAKE_ALL));

        DecoderCustomTypes.PoolKey memory key = DecoderCustomTypes.PoolKey(
            address(0), //ETH
            getAddress(sourceChain, "USDC"),
            500,
            10,
            address(0) //no hook address?
        );

        uint128 amountIn = 1e8;
        uint128 minAmountOut = 0;

        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            DecoderCustomTypes.ExactInputSingleParams({
                poolKey: key,
                zeroForOne: false, // true if we're swapping token0 for token1
                amountIn: amountIn, // amount of tokens we're swapping
                amountOutMinimum: minAmountOut, // minimum amount we expect to receive
                hookData: bytes("") // no hook data needed
            })
        );

        // Second parameter: specify input tokens for the swap
        // encode SETTLE_ALL parameters
        params[1] = abi.encode(key.currency1, amountIn);
        // Third parameter: specify output tokens from the swap
        params[2] = abi.encode(key.currency0, minAmountOut);
        // Combine actions and params into inputs
        inputs[0] = abi.encode(actions, params);

        targetData[3] = abi.encodeWithSignature("execute(bytes,bytes[],uint256)", commands, inputs, block.timestamp);

        address[] memory decodersAndSanitizers = new address[](4);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;

        uint256[] memory values = new uint256[](4);
        values[0] = 0;
        values[1] = 0;
        values[2] = 0;
        values[3] = 0;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testUniswapV4LiquidityFunctionsNative() external {
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e6);
        deal(address(boringVault), 1000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "ETH");
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "USDC");
        address[] memory hooks = new address[](1);
        hooks[0] = address(0);

        _addUniswapV4Leafs(leafs, token0, token1, hooks);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        _generateTestLeafs(leafs, manageTree);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](6);
        manageLeafs[0] = leafs[2]; //approve usdc permit2
        manageLeafs[1] = leafs[4]; //approve usdc permit2 for positionManager
        manageLeafs[2] = leafs[7]; //modifyLiquidities() mint (native)
        manageLeafs[3] = leafs[8]; //modifyLiquidities() increase via SETTLE
        manageLeafs[4] = leafs[9]; //modifyLiquidities() decrease
        manageLeafs[5] = leafs[9]; //modifyLiquidities() collect (same leaf as decrease)

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](6);
        targets[0] = getAddress(sourceChain, "USDC"); //approve usdt permit2
        targets[1] = getAddress(sourceChain, "permit2"); //approve permit2 posm usdc
        targets[2] = getAddress(sourceChain, "uniV4PositionManager"); //modifyLiquidities mint
        targets[3] = getAddress(sourceChain, "uniV4PositionManager"); //modifyLiquidities increase
        targets[4] = getAddress(sourceChain, "uniV4PositionManager"); //modifyLiquidities decrease
        targets[5] = getAddress(sourceChain, "uniV4PositionManager"); //modifyLiquidities collect

        bytes[] memory targetData = new bytes[](6);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max);
        targetData[1] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)",
            getAddress(sourceChain, "USDC"),
            getAddress(sourceChain, "uniV4PositionManager"),
            type(uint160).max,
            type(uint48).max
        );

        DecoderCustomTypes.PoolKey memory key = DecoderCustomTypes.PoolKey(
            address(0), //ETH
            getAddress(sourceChain, "USDC"),
            500,
            10,
            address(0) //no hook address?
        );

        //actions
        bytes memory liquidityActions =
            abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR), uint8(Actions.SWEEP));
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            key,
            TickMath.minUsableTick(key.tickSpacing),
            TickMath.maxUsableTick(key.tickSpacing),
            1e6,
            type(uint128).max,
            type(uint128).max,
            address(boringVault),
            new bytes(0)
        );
        params[1] = abi.encode(key.currency0, key.currency1);
        params[2] = abi.encode(key.currency0, address(boringVault));

        //mint token id = 2345
        targetData[2] = abi.encodeWithSignature(
            "modifyLiquidities(bytes,uint256)", abi.encode(liquidityActions, params), block.timestamp
        );

        //increase liquidity
        liquidityActions =
            abi.encodePacked(uint8(Actions.INCREASE_LIQUIDITY), uint8(Actions.SETTLE_PAIR), uint8(Actions.SWEEP));
        params = new bytes[](3);
        params[0] = abi.encode(2345, 1e6, type(uint128).max, type(uint128).max, new bytes(0));
        params[1] = abi.encode(key.currency0, key.currency1);
        params[2] = abi.encode(key.currency0, address(boringVault));

        targetData[3] = abi.encodeWithSignature(
            "modifyLiquidities(bytes,uint256)", abi.encode(liquidityActions, params), block.timestamp
        );

        //decrease liquidity
        liquidityActions = abi.encodePacked(uint8(Actions.DECREASE_LIQUIDITY), uint8(Actions.TAKE_PAIR));
        params = new bytes[](2);
        params[0] = abi.encode(2345, 50e3, 0, 0, new bytes(0));
        params[1] = abi.encode(key.currency0, key.currency1, address(boringVault));

        targetData[4] = abi.encodeWithSignature(
            "modifyLiquidities(bytes,uint256)", abi.encode(liquidityActions, params), block.timestamp
        );

        //collect, no fees are collected here in the test because none have accumulated (view the logs with -vvvv to see this happening)
        // @dev collect is done by decreasing liquidity with a 0 amount, and then taking the pair
        liquidityActions = abi.encodePacked(uint8(Actions.DECREASE_LIQUIDITY), uint8(Actions.TAKE_PAIR));
        params = new bytes[](2);
        params[0] = abi.encode(
            2345,
            0, //no liquidity decrease
            0,
            0,
            new bytes(0)
        );
        //still take fees here
        params[1] = abi.encode(key.currency0, key.currency1, address(boringVault));

        targetData[5] = abi.encodeWithSignature(
            "modifyLiquidities(bytes,uint256)", abi.encode(liquidityActions, params), block.timestamp
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
        values[2] = 1e16;
        values[3] = 1e16;
        values[4] = 0;
        values[5] = 0;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        skip(1 days);

        manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[11];

        manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        targets = new address[](1);
        targets[0] = getAddress(sourceChain, "uniV4PositionManager"); //modifyLiquidities

        targetData = new bytes[](1);

        // @dev docs are wrong here, we need to take pair still
        liquidityActions = abi.encodePacked(uint8(Actions.BURN_POSITION), uint8(Actions.TAKE_PAIR));
        params = new bytes[](2);
        params[0] = abi.encode(
            2345,
            0, //amount0 full slippage
            0, //amount1 full slippage
            new bytes(0)
        );
        //still take fees here
        params[1] = abi.encode(key.currency0, key.currency1, address(boringVault));

        targetData[0] = abi.encodeWithSignature(
            "modifyLiquidities(bytes,uint256)", abi.encode(liquidityActions, params), block.timestamp + 1
        );

        decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](1)
        );
    }

    function testUniswapV4LiquidityFunctionsNative__Reverts() external {
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1_000_000e6);
        deal(address(boringVault), 1000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "ETH");
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "USDC");
        address[] memory hooks = new address[](1);
        hooks[0] = address(0);

        _addUniswapV4Leafs(leafs, token0, token1, hooks);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        _generateTestLeafs(leafs, manageTree);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](6);
        manageLeafs[0] = leafs[2]; //approve usdc permit2
        manageLeafs[1] = leafs[4]; //approve usdc permit2 for positionManager
        manageLeafs[2] = leafs[7]; //modifyLiquidities() mint (native)
        manageLeafs[3] = leafs[8]; //modifyLiquidities() increase via SETTLE
        manageLeafs[4] = leafs[9]; //modifyLiquidities() decrease
        manageLeafs[5] = leafs[9]; //modifyLiquidities() collect (same leaf as decrease)

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](6);
        targets[0] = getAddress(sourceChain, "USDC"); //approve usdt permit2
        targets[1] = getAddress(sourceChain, "permit2"); //approve permit2 posm usdc
        targets[2] = getAddress(sourceChain, "uniV4PositionManager"); //modifyLiquidities mint
        targets[3] = getAddress(sourceChain, "uniV4PositionManager"); //modifyLiquidities increase
        targets[4] = getAddress(sourceChain, "uniV4PositionManager"); //modifyLiquidities decrease
        targets[5] = getAddress(sourceChain, "uniV4PositionManager"); //modifyLiquidities collect

        bytes[] memory targetData = new bytes[](6);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "permit2"), type(uint256).max);
        targetData[1] = abi.encodeWithSignature(
            "approve(address,address,uint160,uint48)",
            getAddress(sourceChain, "USDC"),
            getAddress(sourceChain, "uniV4PositionManager"),
            type(uint160).max,
            type(uint48).max
        );

        DecoderCustomTypes.PoolKey memory key = DecoderCustomTypes.PoolKey(
            address(0), //ETH
            getAddress(sourceChain, "USDC"),
            500,
            10,
            address(0) //no hook address?
        );

        //actions
        bytes memory liquidityActions =
            abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR), uint8(Actions.SETTLE_PAIR));
        bytes[] memory params = new bytes[](3);
        params[0] = abi.encode(
            key,
            TickMath.minUsableTick(key.tickSpacing),
            TickMath.maxUsableTick(key.tickSpacing),
            1e6,
            type(uint128).max,
            type(uint128).max,
            address(boringVault),
            new bytes(0)
        );
        params[1] = abi.encode(key.currency0, key.currency1);
        params[2] = abi.encode(key.currency0, address(boringVault));

        //mint token id = 2345
        targetData[2] = abi.encodeWithSignature(
            "modifyLiquidities(bytes,uint256)", abi.encode(liquidityActions, params), block.timestamp
        );

        //increase liquidity
        liquidityActions =
            abi.encodePacked(uint8(Actions.INCREASE_LIQUIDITY), uint8(Actions.SETTLE_PAIR), uint8(Actions.SWEEP));
        params = new bytes[](3);
        params[0] = abi.encode(2345, 1e6, type(uint128).max, type(uint128).max, new bytes(0));
        params[1] = abi.encode(key.currency0, key.currency1);
        params[2] = abi.encode(key.currency0, address(boringVault));

        targetData[3] = abi.encodeWithSignature(
            "modifyLiquidities(bytes,uint256)", abi.encode(liquidityActions, params), block.timestamp
        );

        //decrease liquidity
        liquidityActions = abi.encodePacked(uint8(Actions.DECREASE_LIQUIDITY), uint8(Actions.TAKE_PAIR));
        params = new bytes[](2);
        params[0] = abi.encode(2345, 50e3, 0, 0, new bytes(0));
        params[1] = abi.encode(key.currency0, key.currency1, address(boringVault));

        targetData[4] = abi.encodeWithSignature(
            "modifyLiquidities(bytes,uint256)", abi.encode(liquidityActions, params), block.timestamp
        );

        //collect, no fees are collected here in the test because none have accumulated (view the logs with -vvvv to see this happening)
        // @dev collect is done by decreasing liquidity with a 0 amount, and then taking the pair
        liquidityActions = abi.encodePacked(uint8(Actions.DECREASE_LIQUIDITY), uint8(Actions.TAKE_PAIR));
        params = new bytes[](2);
        params[0] = abi.encode(
            2345,
            0, //no liquidity decrease
            0,
            0,
            new bytes(0)
        );
        //still take fees here
        params[1] = abi.encode(key.currency0, key.currency1, address(boringVault));

        targetData[5] = abi.encodeWithSignature(
            "modifyLiquidities(bytes,uint256)", abi.encode(liquidityActions, params), block.timestamp
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
        values[2] = 1e16;
        values[3] = 1e16;
        values[4] = 0;
        values[5] = 0;

        vm.expectRevert(
            abi.encodeWithSelector(UniswapV4DecoderAndSanitizer.UniswapV4DecoderAndSanitizer__MustBeSweep.selector)
        );
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

contract FullUniswapV4DecoderAndSanitizer is UniswapV4DecoderAndSanitizer {
    constructor(address _posm) UniswapV4DecoderAndSanitizer(_posm) { }
}

interface IUniswapV2Factory {
    function getPair(address token0, address token1) external view returns (address);
}
