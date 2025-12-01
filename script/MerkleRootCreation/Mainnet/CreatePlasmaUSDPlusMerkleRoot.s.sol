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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreatePlasmaUSDPlusMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL --gas-limit 1000000000000000000
 */
contract CreatePlasmaUSDPlusMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0x9e424A3F0C92289251B1F42c4F55d0E8FeE16d6E;
    address public rawDataDecoderAndSanitizer = 0x7b60Bc246fc291eE6c6F8750aAc31efd786d0241;
    address public managerAddress = 0x1587D3B0C8Eb509977fAF0439474c58a0E557A65;
    address public accountantAddress = 0xca9c2ae69E6cd74368916ca995f01c3703b25A9E;

    function setUp() external {}

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

        // ========================== SUSDE ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "SUSDE")));
        _addEthenaSUSDeWithdrawLeafs(leafs);

        // ========================== Ethena RWA Teller ==========================
        ERC20[] memory tellerAssets = new ERC20[](2);
        tellerAssets[0] = getERC20(sourceChain, "USDE");
        tellerAssets[1] = getERC20(sourceChain, "USDT");
        _addTellerLeafs(leafs, getAddress(sourceChain, "ethenaRWATeller"), tellerAssets, false, true);

        // ========================== LayerZero to Plasma ==========================
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "USDT"),
            getAddress(sourceChain, "usdt0OFTAdapter"),
            layerZeroPlasmaEndpointId,
            getBytes32(sourceChain, "boringVault")
        );
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "USDE"),
            getAddress(sourceChain, "USDEOFTAdapter"),
            layerZeroPlasmaEndpointId,
            getBytes32(sourceChain, "boringVault")
        );
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "SUSDE"),
            getAddress(sourceChain, "SUSDEOFTAdapter"),
            layerZeroPlasmaEndpointId,
            getBytes32(sourceChain, "boringVault")
        );

        // =========================== Odos ==========================
        {
            address[] memory assets = new address[](3);
            SwapKind[] memory kind = new SwapKind[](3);
            assets[0] = getAddress(sourceChain, "USDE");
            kind[0] = SwapKind.BuyAndSell;
            assets[1] = getAddress(sourceChain, "USDT");
            kind[1] = SwapKind.BuyAndSell;
            assets[2] = getAddress(sourceChain, "SUSDE");
            kind[2] = SwapKind.BuyAndSell;

            _addOdosSwapLeafs(leafs, assets, kind);

            // =========================== 1Inch ==========================
            _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);
        }

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Mainnet/PlasmaUSDPlusMerkleRoot.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
