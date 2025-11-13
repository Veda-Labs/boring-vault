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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateBoostedUSDCMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateBoostedUSDCMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0xDbD87325D7b1189Dcc9255c4926076fF4a96A271;
    address public rawDataDecoderAndSanitizer = ;
    address public managerAddress = 0xEd23b12e7700BeB638562A22ED65f74291901c25;
    address public accountantAddress = 0x62A88Bea6fe527b5DEfAA103A3f8b5010205aF92;

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

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](2);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        feeAssets[1] = getERC20(sourceChain, "USDT");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        // ========================== 1inch/Odos ==========================
        address[] memory assets = new address[](6);
        SwapKind[] memory kind = new SwapKind[](6);
        assets[0] = getAddress(sourceChain, "USDC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "USDT");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "SUSDE");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "SUSDS");
        kind[3] = SwapKind.BuyAndSell;
        assets[4] = getAddress(sourceChain, "USDS");
        kind[4] = SwapKind.BuyAndSell;
        assets[5] = getAddress(sourceChain, "USDE");
        kind[5] = SwapKind.BuyAndSell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);
        _addOdosSwapLeafs(leafs, assets, kind);

        // ========================== NativeWrapper ==========================
        _addNativeLeafs(leafs);

        // ========================== Aave V3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](5);
        supplyAssets[0] = getERC20(sourceChain, "USDE");
        supplyAssets[1] = getERC20(sourceChain, "SUSDE");
        supplyAssets[2] = getERC20(sourceChain, "USDC");
        supplyAssets[3] = getERC20(sourceChain, "USDT");
        supplyAssets[4] = getERC20(sourceChain, "USDS");
        ERC20[] memory borrowAssets = new ERC20[](5);
        borrowAssets[0] = getERC20(sourceChain, "USDE");
        borrowAssets[1] = getERC20(sourceChain, "SUSDE");
        borrowAssets[2] = getERC20(sourceChain, "USDC");
        borrowAssets[3] = getERC20(sourceChain, "USDT");
        borrowAssets[4] = getERC20(sourceChain, "USDS");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== Sky Money ==========================
        _addAllSkyMoneyLeafs(leafs);

        // ========================== Ethena ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "SUSDE")));
        _addEthenaSUSDeWithdrawLeafs(leafs);

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "USDT"), getAddress(sourceChain, "usdt0OFTAdapter"), layerZeroInkEndpointId, getBytes32(sourceChain, "boringVault"));

        // ========================== CCTP ==========================
        _addCCTPBridgeLeafs(leafs, cctpInkDomainId);

        // ========================== Verify ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/BoostedUSDCStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);


    }
}
