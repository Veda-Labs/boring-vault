// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { FixedPointMathLib } from "@solmate/utils/FixedPointMathLib.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { Strings } from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import { ERC4626 } from "@solmate/tokens/ERC4626.sol";
import { MerkleTreeHelper } from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateTurtleTacETHMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateTurtleTacETHMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0x294eecec65A0142e84AEdfD8eB2FBEA8c9a9fbad;
    address public rawDataDecoderAndSanitizer = 0x678Ff354a12a6fC0b9D357647879F32df45f5177;
    address public managerAddress = 0x401C29bafA0A205a0dAb316Dc6136A18023eF08A;
    address public accountantAddress = 0x1683870f3347F2837865C5D161079Dc3fDbf1087;

    function setUp() external { }

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateStrategistMerkleRoot();
    }

    function generateStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](3);
        SwapKind[] memory kind = new SwapKind[](3);
        assets[0] = getAddress(sourceChain, "WETH");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "STETH");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "WSTETH");
        kind[2] = SwapKind.BuyAndSell;

        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Odos ==========================
        _addOdosSwapLeafs(leafs, assets, kind);

        // ========================== Native Leafs ==========================
        _addNativeLeafs(leafs);

        // ========================== Lido ==========================
        _addLidoLeafs(leafs);

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "WSTETH"),
            getAddress(sourceChain, "WSTETHOFTAdapterTAC"),
            layerZeroTACEndpointId,
            getBytes32(sourceChain, "boringVault")
        );
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "WETH"),
            getAddress(sourceChain, "WETHOFTAdapterTAC"),
            layerZeroTACEndpointId,
            getBytes32(sourceChain, "boringVault")
        );

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Mainnet/TurtleTacETHStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
