// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/HyperEVM/CreateSubvaultLiquidUSDMerkleRoot.s.sol --rpc-url $HYPER_EVM_RPC_URL
 */
contract CreateKHypeMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = ;
    address public rawDataDecoderAndSanitizer = ;
    address public managerAddress = ;
    address public accountantAddress = ;

    function setUp() external {} /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateStrategistMerkleRoot();
    }

    function generateStrategistMerkleRoot() public {
        setSourceChainName(hyperEVM);
        setAddress(false, hyperEVM, "boringVault", boringVault);
        setAddress(false, hyperEVM, "managerAddress", managerAddress);
        setAddress(false, hyperEVM, "accountantAddress", accountantAddress);
        setAddress(false, hyperEVM, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // ========================== Native Wrapping ==========================
        _addNativeLeafs(leafs, getAddress(sourceChain, "WHYPE"));

        // ========================== Layer Zero / Stargate ==========================
        _addLayerZeroLeafs(
            leafs, 
            getERC20(sourceChain, "USDT"), 
            getAddress(sourceChain, "USDTOFTAdapter"), 
            layerZeroMainnetEndpointId, 
            getBytes32(sourceChain, "boringVault")
        );

        // ========================== CCTP ==========================
        // Bridge USDC to mainnet
        _addCCTPBridgeLeafs(leafs, cctpMainnetDomainId);

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/HyperEVM/KHypeStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
