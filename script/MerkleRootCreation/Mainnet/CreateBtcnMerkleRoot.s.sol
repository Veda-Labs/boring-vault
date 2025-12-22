// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { FixedPointMathLib } from "@solmate/utils/FixedPointMathLib.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { Strings } from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import { ERC4626 } from "@solmate/tokens/ERC4626.sol";
import { ManagerWithMerkleVerification } from "src/base/Roles/ManagerWithMerkleVerification.sol";
import { MerkleTreeHelper } from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateBtcFiMerkleRoot.s.sol:CreateBtcFiMerkleRootScript --rpc-url $MAINNET_RPC_URL
 */
contract CreateBtcnMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x62a474C3d8C20876FfBc6df95e76C29B62cC07b8;
    address public managerAddress = 0xF1cdeCf0cA06bf18feDFb3F71f2b4628967097B7;
    address public accountantAddress = 0x63Ef0a95488eB43b337cF1aA5E7b25e40698c648;

    //TODO
    address public rawDataDecoderAndSanitizer = address(0);

    function setUp() external { }

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](3);
        token0[0] = getAddress(sourceChain, "WBTC");
        token0[1] = getAddress(sourceChain, "WBTC");
        token0[2] = getAddress(sourceChain, "WBTC");

        address[] memory token1 = new address[](3);
        token1[0] = getAddress(sourceChain, "cbBTC");
        token1[1] = getAddress(sourceChain, "LBTC");
        token1[2] = getAddress(sourceChain, "BTCN");

        _addUniswapV3Leafs(leafs, token0, token1, false);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](4);
        SwapKind[] memory kind = new SwapKind[](4);
        assets[0] = getAddress(sourceChain, "WBTC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "BTCN");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "LBTC");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "cbBTC");
        kind[3] = SwapKind.BuyAndSell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Corn ==========================
        //_addBTCNLeafs(//TODO)

        // ======================== LayerZero =======================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/BtcnMerkleRoot.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
