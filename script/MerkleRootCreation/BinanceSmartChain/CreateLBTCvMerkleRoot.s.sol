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
 *  source .env && forge script script/MerkleRootCreation/BinanceSmartChain/CreateLBTCvMerkleRoot.s.sol:CreateLBTCvMerkleRoot --rpc-url $BNB_RPC_URL
 */
contract CreateLBTCvMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x5401b8620E5FB570064CA9114fd1e135fd77D57c;
    address public managerAddress = 0xcf38e37872748E3b66741A42560672A6cef75e9B;
    address public accountantAddress = 0x28634D0c5edC67CF2450E74deA49B90a4FF93dCE;
    address public rawDataDecoderAndSanitizer = 0xBd0d8ff2e5DdeAE97D95f194B9dC02cE24A95C77;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(bsc);
        setAddress(false, bsc, "boringVault", boringVault);
        setAddress(false, bsc, "managerAddress", managerAddress);
        setAddress(false, bsc, "accountantAddress", accountantAddress);
        setAddress(false, bsc, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](128);

        // ========================== PancakeSwapV3 ==========================
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "LBTC");

        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "BTCB");

        _addPancakeSwapV3Leafs(leafs, token0, token1);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](4);
        SwapKind[] memory kind = new SwapKind[](4);
        assets[0] = getAddress(sourceChain, "WBTC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "LBTC");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "BTCB");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "WBNB");
        kind[3] = SwapKind.BuyAndSell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Odos ==========================
        _addOdosSwapLeafs(leafs, assets, kind); 

        // ========================== Native Leafs ==========================
        _addNativeLeafs(leafs, getAddress(sourceChain, "WBNB")); 

        // ========================== LBTC Bridge Wrapper ==========================
        _addLBTCBridgeLeafs(leafs, 0x0000000000000000000000000000000000000000000000000000000000002105);  
        _addLBTCBridgeLeafs(leafs, 0x0000000000000000000000000000000000000000000000000000000000000001);  

        // ==========================  Fee Claiming ==========================

        ERC20[] memory feeAssets = new ERC20[](2);
        feeAssets[0] = getERC20(sourceChain, "BTCB");
        feeAssets[1] = getERC20(sourceChain, "LBTC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/BinanceSmartChain/LBTCvStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
