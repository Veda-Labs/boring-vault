// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/TAC/CreateTurtleTacETHMerkleRoot.s.sol --rpc-url $TAC_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateTurtleTacETHMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0x294eecec65A0142e84AEdfD8eB2FBEA8c9a9fbad; 
    address public rawDataDecoderAndSanitizer = 0x9Bc20d0F13E68FAD5f4eE5Dda58c391b342e65a5;
    address public managerAddress = 0x401C29bafA0A205a0dAb316Dc6136A18023eF08A; 
    address public accountantAddress = 0x1683870f3347F2837865C5D161079Dc3fDbf1087;
    

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateStrategistMerkleRoot();
    }

    function generateStrategistMerkleRoot() public {
        setSourceChainName(tac);
        setAddress(false, tac, "boringVault", boringVault);
        setAddress(false, tac, "managerAddress", managerAddress);
        setAddress(false, tac, "accountantAddress", accountantAddress);
        setAddress(false, tac, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "WETH"), getAddress(sourceChain, "WETH"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "WSTETH"), getAddress(sourceChain, "WSTETH"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/TAC/TurtleTacETHStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

    }

}
