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
 *  source .env && forge script script/MerkleRootCreation/Sepolia/CreateTestVault0MerkleRoot.s.sol --rpc-url $SEPOLIA_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateTestVault0MerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0xd99B6d7b1dd1cFf9910021BfB8fB204ea48e57A8;
    address public rawDataDecoderAndSanitizer = 0x48283cFc1D47f8222ADB58c2778F08Ce5b1bC626;
    address public managerAddress = 0x434cb80982224342b0b6fCc7ef4E1eb9EB366526;
    address public accountantAddress = 0xD74dcFab310258e00c9661be35D2d4540beff730;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateStrategistMerkleRoot();
    }

    function generateStrategistMerkleRoot() public {
        setSourceChainName(sepolia);
        setAddress(false, sepolia, "boringVault", boringVault);
        setAddress(false, sepolia, "managerAddress", managerAddress);
        setAddress(false, sepolia, "accountantAddress", accountantAddress);
        setAddress(false, sepolia, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);

        // ========================== Aave V3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](2);
        supplyAssets[0] = getERC20(sourceChain, "USDT");
        supplyAssets[1] = getERC20(sourceChain, "USDC");
        ERC20[] memory borrowAssets = new ERC20[](2);
        borrowAssets[0] = getERC20(sourceChain, "USDT");
        borrowAssets[1] = getERC20(sourceChain, "USDC");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== Native ==========================
        _addNativeLeafs(leafs, getAddress(sourceChain, "WETH9"));

        // ========================== UNISWAP V3 ==========================
        {
            address[] memory token0 = new address[](1);
            token0[0] = getAddress(sourceChain, "USDT");

            address[] memory token1 = new address[](1);
            token1[0] = getAddress(sourceChain, "USDC");

            _addUniswapV3Leafs(leafs, token0, token1, false, true);
        }
        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Sepolia/TestVault0MerkleRoot.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
