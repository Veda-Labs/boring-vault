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
 *  source .env && forge script script/MerkleRootCreation/Plasma/CreateWhopUSDMerkleRoot.s.sol --rpc-url $PLASMA_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateWhopUSDMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0xd447b8776cEd03C4Cb40C7F6515dA89d90f6648A;
    address public rawDataDecoderAndSanitizer = 0xEBbFFb805750661a39367276f4B8fEb486d7eCce;
    address public managerAddress = 0xB7E9CD6bF9De2807B15a472B6398282Afc5E8b3f;
    address public accountantAddress = 0x0cBBb8A916A4F9bc735f6D39c8f685E6eD597CaC;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateStrategistMerkleRoot();
    }

    function generateStrategistMerkleRoot() public {
        setSourceChainName(plasma);
        setAddress(false, plasma, "boringVault", boringVault);
        setAddress(false, plasma, "managerAddress", managerAddress);
        setAddress(false, plasma, "accountantAddress", accountantAddress);
        setAddress(false, plasma, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);

        // ========================== Aave V3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](1);
        supplyAssets[0] = getERC20(sourceChain, "USDT0");
        ERC20[] memory borrowAssets = new ERC20[](0);
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "wXPL");
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "USDT0");
        _addUniswapV3OneWaySwapLeafs(leafs, token0, token1, true);

        // ========================== GlueX / RedSnwapper ==========================
        address[] memory tokens = new address[](2);
        SwapKind[] memory kind = new SwapKind[](2);
        tokens[0] = getAddress(sourceChain, "USDT0");
        kind[0] = SwapKind.BuyAndSell;
        tokens[1] = getAddress(sourceChain, "wXPL");
        kind[1] = SwapKind.Sell;
        _addGlueXLeafs(leafs, tokens, kind);
        _addSnwapLeafs(leafs, tokens, kind);


        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Plasma/WhopUSDMerkleRoot.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
