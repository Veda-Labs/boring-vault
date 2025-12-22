// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Corn/CreateStakedBTCNMerkleRoot.s.sol:CreateStakedBTCNMerkleRoot --rpc-url $CORN_MAIZENET_RPC_URL
 */
contract CreateStakedBTCNMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address boringVault = 0x5E272ca4bD94e57Ec5C51D26703621Ccac1A7089;
    address managerAddress = 0x5239158272D1f626aF9ef3353489D3Cb68439D66;
    address accountantAddress = 0x9A22F5dC4Ec86184D4771E620eb75D52E7b9E043;
    address rawDataDecoderAndSanitizer = 0x43916c5e3efD4763D719EBd0690DC78aC5cB10C3;

    //one offs
    address camelotDecoderAndSanitizer = 0x3FD48BE8d8fB633696AcB6dBE70166c81e869320;

    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(corn);
        setAddress(false, corn, "boringVault", boringVault);
        setAddress(false, corn, "managerAddress", managerAddress);
        setAddress(false, corn, "accountantAddress", accountantAddress);
        setAddress(false, corn, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // ========================== Curve LP ==========================

        _addCurveLeafs(
            leafs,
            getAddress(sourceChain, "curve_pool_LBTC_WBTCN"),
            2,
            getAddress(sourceChain, "curve_gauge_LBTC_WBTCN")
        );

        _addCurveLeafs(
            leafs,
            getAddress(sourceChain, "curve_pool_LBTC_WBTCN_2"),
            2,
            getAddress(sourceChain, "curve_gauge_LBTC_WBTCN_2")
        );

        _addCurveLeafs(
            leafs,
            getAddress(sourceChain, "curve_pool_LBTC_WBTCN_EBTC"),
            3,
            getAddress(sourceChain, "curve_gauge_LBTC_WBTCN_EBTC")
        );

        // ========================== Curve Swaps  ==========================

        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "curve_pool_LBTC_WBTCN"));
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "curve_pool_LBTC_WBTCN_2"));
        _addLeafsForCurveSwapping3Pool(leafs, getAddress(sourceChain, "curve_pool_LBTC_WBTCN_EBTC"));

        // ========================== LayerZero ==========================

        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "WBTCN"),
            getAddress(sourceChain, "WBTCN_OFT"),
            layerZeroMainnetEndpointId,
            getBytes32(sourceChain, "boringVault")
        );
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "LBTC"),
            getAddress(sourceChain, "LBTC_OFT"),
            layerZeroMainnetEndpointId,
            getBytes32(sourceChain, "boringVault")
        );

        // ========================== Native Wrapping ==========================

        _addNativeLeafs(leafs, getAddress(sourceChain, "WBTCN"));

        // ========================== Zerolend ==========================

        ERC20[] memory supplyAssets = new ERC20[](3);
        supplyAssets[0] = getERC20(sourceChain, "EBTC");
        supplyAssets[1] = getERC20(sourceChain, "LBTC");
        supplyAssets[2] = getERC20(sourceChain, "WBTCN");

        ERC20[] memory borrowAssets = new ERC20[](3);
        borrowAssets[0] = getERC20(sourceChain, "EBTC");
        borrowAssets[1] = getERC20(sourceChain, "LBTC");
        borrowAssets[2] = getERC20(sourceChain, "WBTCN");

        _addZerolendLeafs(leafs, supplyAssets, borrowAssets);

        // ========================== UniswapV3 ==========================

        address[] memory token0 = new address[](2);
        token0[0] = getAddress(sourceChain, "WBTCN");
        token0[1] = getAddress(sourceChain, "WBTCN");

        address[] memory token1 = new address[](2);
        token1[0] = getAddress(sourceChain, "LBTC");
        token1[1] = getAddress(sourceChain, "EBTC");

        _addUniswapV3Leafs(leafs, token0, token1, false, true); //add all leafs, use swapRouter02 params

        // ========================== Tellers ==========================
        {
            //deposit into EBTC
            ERC20[] memory tellerAssets = new ERC20[](3);
            tellerAssets[0] = getERC20(sourceChain, "WBTCN");
            tellerAssets[1] = getERC20(sourceChain, "LBTC");
            tellerAssets[2] = getERC20(sourceChain, "EBTC");

            _addTellerLeafs(leafs, getAddress(sourceChain, "eBTCTeller"), tellerAssets, false, false); //no native deposit, no bulk deposit/withdraw

            // ========================== Withdraw Queues ==========================

            _addWithdrawQueueLeafs(
                leafs, getAddress(sourceChain, "eBTCOnChainQueueFast"), getAddress(sourceChain, "EBTC"), tellerAssets
            );
        }

        // ========================== CamelotV3 ==========================

        setAddress(true, corn, "rawDataDecoderAndSanitizer", camelotDecoderAndSanitizer);

        address[] memory camelotToken0 = new address[](1);
        camelotToken0[0] = getAddress(sourceChain, "WBTCN");

        address[] memory camelotToken1 = new address[](1);
        camelotToken1[0] = getAddress(sourceChain, "LBTC");

        _addCamelotV3Leafs(leafs, camelotToken0, camelotToken1);

        setAddress(true, corn, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        // ========================== Morpho ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "smokehouseBTCN")));

        // ========================== Morpho Blue ==========================
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "WBTCN_IDLE_915"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "WBTCN_LBTC_915"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "USDT0_IDLE_915"));
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "WBTCN_USDT0_915"));

        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "WBTCN_IDLE_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "WBTCN_LBTC_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "USDT0_IDLE_915"));
        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "WBTCN_USDT0_915"));

        // ========================== Verify ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Corn/sBTCNStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
