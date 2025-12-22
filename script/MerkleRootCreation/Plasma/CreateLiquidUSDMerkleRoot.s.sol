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

contract CreateLiquidUSDMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0x08c6F91e2B681FaF5e17227F2a44C307b3C1364C;
    address public rawDataDecoderAndSanitizer = 0x180e32788541663FbA09D022A439215d0243fd8d;
    address public managerAddress = 0x7b57Ad1A0AA89583130aCfAD024241170D24C13C;
    address public accountantAddress = 0xc315D6e14DDCDC7407784e2Caf815d131Bc1D3E7;

    function setUp() external { }

    function run() external {
        generateStrategistMerkleRoot();
    }

    function generateStrategistMerkleRoot() public {
        setSourceChainName(plasma);
        setAddress(false, plasma, "boringVault", boringVault);
        setAddress(false, plasma, "managerAddress", managerAddress);
        setAddress(false, plasma, "accountantAddress", accountantAddress);
        setAddress(false, plasma, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        // ========================== Fluid ==========================
        ERC20[] memory supplyTokens = new ERC20[](1);
        supplyTokens[0] = getERC20(sourceChain, "wstUSR");

        ERC20[] memory borrowTokens = new ERC20[](1);
        borrowTokens[0] = getERC20(sourceChain, "USDT0");
        _addFluidDexLeafs(
            leafs, getAddress(sourceChain, "Vaultt1_Wstusr_Usdt0"), 1000, supplyTokens, borrowTokens, false
        );

        // ========================== Aave V3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](3);
        supplyAssets[0] = getERC20(sourceChain, "USDE");
        supplyAssets[1] = getERC20(sourceChain, "SUSDE");
        supplyAssets[2] = getERC20(sourceChain, "USDT0");
        ERC20[] memory borrowAssets = new ERC20[](2);
        borrowAssets[0] = getERC20(sourceChain, "USDE");
        borrowAssets[1] = getERC20(sourceChain, "USDT0");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "USDT0"),
            getAddress(sourceChain, "USDT0_OFT"),
            layerZeroMainnetEndpointId,
            getBytes32(sourceChain, "boringVault")
        );
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "SUSDE"),
            getAddress(sourceChain, "SUSDE"),
            layerZeroMainnetEndpointId,
            getBytes32(sourceChain, "boringVault")
        );
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "USDE"),
            getAddress(sourceChain, "USDE"),
            layerZeroMainnetEndpointId,
            getBytes32(sourceChain, "boringVault")
        );
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "wstUSR"),
            getAddress(sourceChain, "wstUSR"),
            layerZeroMainnetEndpointId,
            getBytes32(sourceChain, "boringVault")
        );

        // ========================== Native ==========================
        _addNativeLeafs(leafs, getAddress(sourceChain, "wXPL"));

        // ========================== Merkl ==========================
        _addMerklLeafs(leafs, getAddress(sourceChain, "merklDistributor"), getAddress(sourceChain, "dev1Address"));

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Plasma/LiquidUSDMerkleRoot.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
