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

contract CreateLiquidUsdOperationalMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0x08c6F91e2B681FaF5e17227F2a44C307b3C1364C;
    address public rawDataDecoderAndSanitizer = 0x330f85CD9C04236145C8cB9531112Ced3E8D9fDD;
    address public managerAddress = 0xcFF411d5C54FE0583A984beE1eF43a4776854B9A;
    address public accountantAddress = 0xc315D6e14DDCDC7407784e2Caf815d131Bc1D3E7; 
    address public drone = 0x3683fc2792F676BBAbc1B5555dE0DfAFee546e9a; 


    function setUp() external {}

    function run() external {
        generateLiquidUsdStrategistMerkleRoot();
    }

    function generateLiquidUsdStrategistMerkleRoot() public {
        setSourceChainName(flare);
        setAddress(false, flare, "boringVault", boringVault);
        setAddress(false, flare, "managerAddress", managerAddress);
        setAddress(false, flare, "accountantAddress", accountantAddress);
        setAddress(false, flare, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        // ========================== SparkDEX ===============================
        {
            address[] memory token0 = new address[](4);
            token0[0] = getAddress(sourceChain, "WFLR");
            token0[1] = getAddress(sourceChain, "WFLR");
            token0[2] = getAddress(sourceChain, "USDC");
            token0[3] = getAddress(sourceChain, "USDT0");

            address[] memory token1 = new address[](4);
            token1[0] = getAddress(sourceChain, "USDT0");
            token1[1] = getAddress(sourceChain, "USDC");
            token1[2] = getAddress(sourceChain, "USDT0");
            token1[3] = getAddress(sourceChain, "USDC");

            bool swapRouter02 = false;
            _addUniswapV3OneWaySwapLeafs(leafs, token0, token1, swapRouter02);
        }

        // ========================== LayerZero ===============================
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "USDC"), getAddress(sourceChain, "USDC_OFT_stargate"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault")); 
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "USDT0"), getAddress(sourceChain, "USDT0_OFT"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault")); 

        // ========================== Drone Transfer ===============================
        {
            ERC20[] memory localTokens = new ERC20[](3);
            localTokens[0] = getERC20(sourceChain, "USDC");
            localTokens[1] = getERC20(sourceChain, "USDT0");
            localTokens[2] = getERC20(sourceChain, "WFLR");

            _addLeafsForDroneTransfers(leafs, drone, localTokens);
        }

        // ========================== Native Leafs ===============================
        _addNativeLeafs(leafs, getAddress(sourceChain, "WFLR"));

        // ========================== rFLR Rewards ===============================
        _addrFLRLeafs(leafs, getAddress(sourceChain, "rFLR"));

        // ========================== Drone Setup ===============================
        _addLeafsForDrone(leafs);

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Flare/LiquidUsdOperationalStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function _addLeafsForDrone(ManageLeaf[] memory leafs) internal {
        setAddress(true, flare, "boringVault", drone);
        uint256 droneStartIndex = leafIndex + 1;

        // ========================== SparkDEX ===============================
        {
            address[] memory token0 = new address[](4);
            token0[0] = getAddress(sourceChain, "WFLR");
            token0[1] = getAddress(sourceChain, "WFLR");
            token0[2] = getAddress(sourceChain, "USDC");
            token0[3] = getAddress(sourceChain, "USDT0");

            address[] memory token1 = new address[](4);
            token1[0] = getAddress(sourceChain, "USDT0");
            token1[1] = getAddress(sourceChain, "USDC");
            token1[2] = getAddress(sourceChain, "USDT0");
            token1[3] = getAddress(sourceChain, "USDC");

            bool swapRouter02 = false;
            _addUniswapV3OneWaySwapLeafs(leafs, token0, token1, swapRouter02);
        }

        // ========================== LayerZero ===============================
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "USDC"), getAddress(sourceChain, "USDC_OFT_stargate"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "USDT0"), getAddress(sourceChain, "USDT0_OFT"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));

        // ========================== Native Leafs ===============================
        _addNativeLeafs(leafs, getAddress(sourceChain, "WFLR"));

        // ========================== rFLR Rewards ===============================
        _addrFLRLeafs(leafs, getAddress(sourceChain, "rFLR"));

        _createDroneLeafs(leafs, drone, droneStartIndex, leafIndex + 1);
        setAddress(true, mainnet, "boringVault", boringVault);
    }

}
