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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateStableDemoRoot.s.sol --rpc-url $MAINNET_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateStableDemoMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0x573dD6B134eC83673ff3f2319079B247355Eb05f;
    address public rawDataDecoderAndSanitizer = 0x0acCa7989219eB630a5dAf8929f6081D345d38Fa;
    address public managerAddress = 0x6d06d40e117DbEd4740216BD4F30973d59004C22;
    address public accountantAddress = 0x6Ca2620dbbB6ebE23837bB67E45b8c29d5BeC5FB;

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

        ManageLeaf[] memory leafs = new ManageLeaf[](128);

        // ========================== Aave V3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](4);
        supplyAssets[0] = getERC20(sourceChain, "USDT");
        supplyAssets[1] = getERC20(sourceChain, "USDC");
        supplyAssets[2] = getERC20(sourceChain, "USDE");
        supplyAssets[3] = getERC20(sourceChain, "SUSDE");
        ERC20[] memory borrowAssets = new ERC20[](4);
        borrowAssets[0] = getERC20(sourceChain, "USDT");
        borrowAssets[1] = getERC20(sourceChain, "USDC");
        borrowAssets[2] = getERC20(sourceChain, "USDE");
        borrowAssets[3] = getERC20(sourceChain, "SUSDE");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== Morpho ==========================
        _addMorphoBlueSupplyLeafs(leafs, 0xdc5333039bcf15f1237133f74d5806675d83d9cf19cfd4cfdd9be674842651bf);
        _addMorphoBlueCollateralLeafs(leafs, 0xdc5333039bcf15f1237133f74d5806675d83d9cf19cfd4cfdd9be674842651bf);
        
        _addMorphoBlueSupplyLeafs(leafs, 0x85c7f4374f3a403b36d54cc284983b2b02bbd8581ee0f3c36494447b87d9fcab);
        _addMorphoBlueCollateralLeafs(leafs, 0x85c7f4374f3a403b36d54cc284983b2b02bbd8581ee0f3c36494447b87d9fcab);

        _addMorphoBlueSupplyLeafs(leafs, 0x8e7cc042d739a365c43d0a52d5f24160fa7ae9b7e7c9a479bd02a56041d4cf77);
        _addMorphoBlueCollateralLeafs(leafs, 0x8e7cc042d739a365c43d0a52d5f24160fa7ae9b7e7c9a479bd02a56041d4cf77);

        _addMorphoBlueSupplyLeafs(leafs, 0xcec858380cba2d9ca710fce3ce864d74c3f620d53826f69d08508902e09be86f);
        _addMorphoBlueCollateralLeafs(leafs, 0xcec858380cba2d9ca710fce3ce864d74c3f620d53826f69d08508902e09be86f);

        // ========================== Morpho Rewards ==========================
        _addMorphoRewardMerkleClaimerLeafs(leafs, getAddress(sourceChain, "universalRewardsDistributor"));

        // ========================== Meta Morpho ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "smokehouseUSDT"))); 
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "smokehouseUSDC"))); 
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletUSDCcore")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "steakhouseUSDC")));
        

        // ========================== 1inch ==========================
        address[] memory assets = new address[](5);
        SwapKind[] memory kind = new SwapKind[](5);
        assets[0] = getAddress(sourceChain, "USDT");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "USDC");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "USDE");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "SUSDE");
        kind[3] = SwapKind.BuyAndSell;
        assets[4] = getAddress(sourceChain, "USR");
        kind[4] = SwapKind.BuyAndSell;

        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Mainnet/StableDemoStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}