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
 *  source .env && forge script script/MerkleRootCreation/Plasma/CreateLiquidUSDOperationalMerkleRoot.s.sol --rpc-url $PLASMA_RPC_URL --gas-limit 1000000000000000000
 */

contract CreateLiquidUSDMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0x08c6F91e2B681FaF5e17227F2a44C307b3C1364C;
    address public rawDataDecoderAndSanitizer = 0x180e32788541663FbA09D022A439215d0243fd8d;
    address public managerAddress = 0x7b57Ad1A0AA89583130aCfAD024241170D24C13C;
    address public accountantAddress = 0xc315D6e14DDCDC7407784e2Caf815d131Bc1D3E7;

    function setUp() external {}

    function run() external {
        generateStrategistMerkleRoot();
    }

    function generateStrategistMerkleRoot() public {
        setSourceChainName(plasma);
        setAddress(false, plasma, "boringVault", boringVault);
        setAddress(false, plasma, "managerAddress", managerAddress);
        setAddress(false, plasma, "accountantAddress", accountantAddress);
        setAddress(false, plasma, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // // ========================== Aave V3 ==========================
        {
            ERC20[] memory supplyAssets = new ERC20[](3);
            supplyAssets[0] = getERC20(sourceChain, "USDE");
            supplyAssets[1] = getERC20(sourceChain, "SUSDE");
            supplyAssets[2] = getERC20(sourceChain, "USDT0");
            _addAaveV3EOALeafs("Aave V3", getAddress(sourceChain, "v3Pool"), leafs, supplyAssets);
        }

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "USDT0"), getAddress(sourceChain, "USDT0_OFT"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));

        // ========================== Native ==========================
        _addNativeLeafs(leafs, getAddress(sourceChain, "wXPL"));

        // ========================== Merkl ==========================
        _addMerklLeafs(
            leafs,
            getAddress(sourceChain, "merklDistributor"),
            getAddress(sourceChain, "etherfiOpsAddress")
        );

        // ====================== UniswapV3/OKU ==========================
        {
            address[] memory token0 = new address[](2);
            token0[0] = getAddress(sourceChain, "wXPL");
            address[] memory token1 = new address[](2);
            token1[0] = getAddress(sourceChain, "USDT0");

            bool swapRouter02 = true;
            _addUniswapV3OneWaySwapLeafs(leafs, token0, token1, swapRouter02);
        }

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Plasma/LiquidUSDMerkleRoot.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

}
