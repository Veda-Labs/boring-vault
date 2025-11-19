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

contract CreateLiquidETHOperationalMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xf0bb20865277aBd641a307eCe5Ee04E79073416C;
    address public rawDataDecoderAndSanitizer = 0x6727a35867EDCdDE01B92F5104D09D4561A4C2D9;
    address public managerAddress = 0xf9f7969C357ce6dfd7973098Ea0D57173592bCCa;
    address public accountantAddress = 0x0d05D94a5F1E76C18fbeB7A13d17C8a314088198;
    address public drone = 0x7c391d7856fcbC4Fd3a3C3CD8787c7eBF85934aF;

    function setUp() external {}

    function run() external {
        generateLiquidEthOperationalStrategistMerkleRoot();
    }

    function generateLiquidEthOperationalStrategistMerkleRoot() public {

        setSourceChainName(scroll);
        setAddress(false, scroll, "boringVault", boringVault);
        setAddress(false, scroll, "managerAddress", managerAddress);
        setAddress(false, scroll, "accountantAddress", accountantAddress);
        setAddress(false, scroll, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);

        // ========================== Native Leafs==========================
        _addNativeLeafs(leafs);

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "WEETH"), getAddress(sourceChain, "WEETH"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));   

        // ========================== Scroll Native Bridge ==========================
        {
            ERC20[] memory tokens = new ERC20[](1);
            tokens[0] = getERC20(sourceChain, "WETH");
            address[] memory scrollGateways = new address[](0); // no gateways needed from Scroll
            _addScrollNativeBridgeLeafs(leafs, "mainnet", tokens, scrollGateways);
        }

        // ========================== Fee Claiming ==========================
        {
            ERC20[] memory feeAssets = new ERC20[](2);
            feeAssets[0] = getERC20(sourceChain, "WETH");
            feeAssets[1] = getERC20(sourceChain, "WEETH");
            _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);
        }

        // ========================== Finalize ===================================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        string memory filePath = "./leafs/Scroll/LiquidETHOperationalStrategistLeafs.json";
        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

}
