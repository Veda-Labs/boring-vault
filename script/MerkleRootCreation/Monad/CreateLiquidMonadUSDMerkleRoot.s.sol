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
 * liquidMonadUSD — Monad strategy root.
 *
 *  source .env && forge script script/MerkleRootCreation/Monad/CreateLiquidMonadUSDMerkleRoot.s.sol --rpc-url $MONAD_RPC_URL
 *
 * Strategy leaves:
 *   - Upshift earnAUSD ERC4626 vault
 *   - Merkl claim (AUSD compound, WMON sell-through)
 *   - WMON wrap / unwrap
 *
 * Reverse-bridge leaves (Monad → Mainnet):
 *   - AUSD via LayerZero OFT
 *   - USDC via Circle CCTP V2
 */
contract CreateLiquidMonadUSDMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = address(0);
    address public managerAddress = address(0);
    address public accountantAddress = address(0);
    address public rawDataDecoderAndSanitizer = address(0);

    function setUp() external {}

    function run() external {
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(monad);
        setAddress(false, monad, "boringVault", boringVault);
        setAddress(false, monad, "managerAddress", managerAddress);
        setAddress(false, monad, "accountantAddress", accountantAddress);
        setAddress(false, monad, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);

        // ========================== Upshift earnAUSD ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "upshiftEarnAUSDVault")));

        // ========================== Merkl rewards ==========================
        _addMerklClaimLeaf(leafs, getAddress(sourceChain, "merklDistributor"));

        // ========================== WMON wrap / unwrap ==========================
        _addNativeLeafs(leafs, getAddress(sourceChain, "WMON"));

        // ========================== LayerZero OFT — AUSD → Mainnet ==========================
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "AUSD"),
            getAddress(sourceChain, "ausdOFTAdapter"),
            layerZeroMainnetEndpointId,
            getBytes32(sourceChain, "boringVault")
        );

        // ========================== CCTP V2 — USDC → Mainnet ==========================
        _addCCTPBridgeLeafs(leafs, cctpMainnetDomainId);

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Monad/LiquidMonadUSDStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
