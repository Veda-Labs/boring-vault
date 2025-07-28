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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateTacLBTCvMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateTacLBTCvMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0xD86fC1CaA0a5B82cC16B16B70DFC59F6f034C348;
    address public rawDataDecoderAndSanitizer = 0xc52220989809D748a958798ca8FEf7CaF88022b4;
    address public managerAddress = 0x1F95Ae26c62D24c3a5E118922Fe2ddc3B433331D; 
    address public accountantAddress = 0xB4703f17e3212E9959cC560e0592837292b14ECE;

    address public oftDecoderAndSanitizer = 0x678Ff354a12a6fC0b9D357647879F32df45f5177;     

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

        ManageLeaf[] memory leafs = new ManageLeaf[](32);

        // ========================== UniswapV3 ==========================
        // LBTC, cbBTC
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "LBTC");

        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "cbBTC");

        _addUniswapV3Leafs(leafs, token0, token1, false);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](2);
        SwapKind[] memory kind = new SwapKind[](2);
        assets[0] = getAddress(sourceChain, "LBTC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "cbBTC");
        kind[1] = SwapKind.BuyAndSell;

        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Odos ==========================
        _addOdosSwapLeafs(leafs, assets, kind);

        // ========================== LayerZero ==========================
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", oftDecoderAndSanitizer);
         _addLayerZeroLeafs(leafs, getERC20(sourceChain, "LBTC"), getAddress(sourceChain, "LBTCOFTAdapterTAC"), layerZeroTACEndpointId, getBytes32(sourceChain, "boringVault"));

        // ========================== BoringVaults ==========================
        //ERC20[] memory tellerAssets = new ERC20[](2);
        //tellerAssets[0] = getERC20(sourceChain, "LBTC");
        //tellerAssets[1] = getERC20(sourceChain, "cbBTC");
        //address LBTCvTeller = 0x4E8f5128F473C6948127f9Cbca474a6700F99bab;
        //_addTellerLeafs(leafs, LBTCvTeller, tellerAssets, false, true);

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Mainnet/TacLBTCvStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

    }

}
