// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 * liquidMonadETH — Mainnet bridging root.
 *
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateLiquidMonadETHMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 *
 * Bridge leaves:
 *   - WETH   → Monad via Wormhole NTT MultiToken Executor
 *   - wstETH → Monad via Chainlink CCIP
 */
contract CreateLiquidMonadETHMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = address(0);
    address public managerAddress = address(0);
    address public accountantAddress = address(0);
    address public rawDataDecoderAndSanitizer = address(0);

    // Chainlink CCIP chain selector for Monad. A literal `0` will revert at encode time,
    // forcing the gap to be filled before broadcasting.
    uint64 public constant ccipMonadChainSelector = 0;

    function setUp() external {}

    function run() external {
        generateStrategistMerkleRoot();
    }

    function generateStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);

        // ========================== CCIP — wstETH → Monad ==========================
        ERC20[] memory ccipBridgeAssets = new ERC20[](1);
        ccipBridgeAssets[0] = getERC20(sourceChain, "WSTETH");
        ERC20[] memory ccipFeeTokens = new ERC20[](2);
        ccipFeeTokens[0] = getERC20(sourceChain, "LINK");
        ccipFeeTokens[1] = getERC20(sourceChain, "WETH");
        _addCcipBridgeLeafs(leafs, ccipMonadChainSelector, ccipBridgeAssets, ccipFeeTokens);

        // ========================== Wormhole NTT — WETH → Monad ==========================
        _addWormholeNTTExecutorMultiTokenBridgeLeafs(
            leafs,
            getAddress(sourceChain, "wormholeMultiTokenExecutor"),
            getAddress(sourceChain, "wormholeMultiTokenNtt"),
            getERC20(sourceChain, "WETH"),
            uint16(wormholeMonadChainId)
        );

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/LiquidMonadETHStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
