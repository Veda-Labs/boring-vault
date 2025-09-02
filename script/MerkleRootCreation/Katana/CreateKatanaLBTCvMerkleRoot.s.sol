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
 *  source .env && forge script script/MerkleRootCreation/Katana/CreateKatanaLBTCvMerkleRoot.s.sol --rpc-url $KATANA_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateKatanaLBTCvMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0x75231079973C23e9eB6180fa3D2fc21334565aB5;
    address public rawDataDecoderAndSanitizer = 0x635a196D276Ed85eaA9A878D508D497bc740865E;
    address public managerAddress = 0x9aC5AEf62eCe812FEfb77a0d1771c9A5ce3D04E4;
    address public accountantAddress = 0x90e864A256E58DBCe034D9C43C3d8F18A00f55B6;

    function setUp() external {} /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateStrategistMerkleRoot();
    }

    function generateStrategistMerkleRoot() public {
        setSourceChainName(katana);
        setAddress(false, katana, "boringVault", boringVault);
        setAddress(false, katana, "managerAddress", managerAddress);
        setAddress(false, katana, "accountantAddress", accountantAddress);
        setAddress(false, katana, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        // ========================== LBTC Bridge Wrapper ==========================
        // To Mainnet
        _addLBTCBridgeLeafs(leafs, 0x0000000000000000000000000000000000000000000000000000000000000001);  

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](1);
        feeAssets[0] = getERC20(sourceChain, "LBTC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        // ========================== Morpho Blue ==========================
        _addMorphoBlueSupplyLeafs(leafs, getBytes32(sourceChain, "LBTC_vbWBTC_915")); 

        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "LBTC_vbWBTC_915")); 

        // ========================== MetaMorhpo ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletWBTC")));  

        // ========================== Agglayer ==========================
        _addAgglayerTokenLeafs(
            leafs,
            getAddress(sourceChain, "agglayerBridgeKatana"), //bridge
            getAddress(sourceChain, "vbWBTC"), //bridge token
            20, //from chain
            0 //to chain
        );

        // ========================== Sushi ==========================
        address[] memory token0 = new address[](3);
        token0[0] = getAddress(sourceChain, "LBTC");
        token0[1] = getAddress(sourceChain, "WBTC");
        token0[2] = getAddress(sourceChain, "LBTC");

        address[] memory token1 = new address[](3);
        token1[0] = getAddress(sourceChain, "BTCK");
        token1[1] = getAddress(sourceChain, "BTCK");
        token1[2] = getAddress(sourceChain, "WBTC");

        _addUniswapV3Leafs(leafs, token0, token1, false);
            
        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Katana/KatanaLBTCvMerkleRoot.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
