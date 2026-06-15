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
 * liquidMonadUSD — Mainnet bridging root.
 *
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateLiquidMonadUSDMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 *
 * Bridge leaves:
 *   - AUSD → Monad via LayerZero OFT
 *   - USDC → Monad via Circle CCTP V2
 */
contract CreateLiquidMonadUSDMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x525D01dBb0004565C80bF60E269122759672dAD2;
    address public managerAddress = 0x71F38f6e336791893916EDC50CE7292240D7b46d;
    address public accountantAddress = 0xBa814af88A9279386896E3aCFA685BFA7f093d14;
    address public rawDataDecoderAndSanitizer = 0xDd1169376E8fD99a7141043646cf903A7f4676A2;

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

        // ========================== LayerZero OFT — AUSD → Monad ==========================
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "AUSD"),
            getAddress(sourceChain, "ausdOFTAdapter"),
            layerZeroMonadEndpointId,
            getBytes32(sourceChain, "boringVault")
        );

        // ========================== CCTP V2 — USDC → Monad ==========================
        _addCCTPBridgeLeafs(leafs, cctpMonadDomainId);

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/LiquidMonadUSDStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
