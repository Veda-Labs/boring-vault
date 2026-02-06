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
 *  source .env && forge script script/MerkleRootCreation/Plasma/CreateP1USDMerkleRoot.s.sol --rpc-url $PLASMA_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateP1USDMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0x1cF1c71440eBd9Cc998Ce0B1B25CcEf275c53d77;
    address public rawDataDecoderAndSanitizer = 0xC270A0EB853Fc04CeB7c6a819172059fb8Fd1331;
    address public managerAddress = 0xF1b3aD534CAc8B1369C9Bc1a20AF88c7Fe4c9Fa7;
    address public accountantAddress = 0xE40d00FfB5089042014b12b87B09D6880ccd9029;

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

        // ========================== Merkl ==========================
        _addMerklLeafs(
            leafs,
            getAddress(sourceChain, "merklDistributor"),
            getAddress(sourceChain, "dev1Address")
        );


        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Plasma/P1USDMerkleRoot.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
