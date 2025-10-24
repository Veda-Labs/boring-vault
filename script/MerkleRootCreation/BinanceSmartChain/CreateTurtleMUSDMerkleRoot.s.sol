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
 *  source .env && forge script script/MerkleRootCreation/BinanceSmartChain/CreateTurtleMUSDMerkleRoot.s.sol:CreateTurtleMUSDMerkleRoot --rpc-url $BNB_RPC_URL
 */
contract CreateTurtleMUSDMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x8c76940cC63a09F9CaB9ff35e09BC9f9715c05aa;
    address public managerAddress = 0x9EF3F2dB577000E3Cf420777FC64A2087856C720;
    address public accountantAddress = 0x210DcD63F4dCE1F5A502a3fDf5663A75255663eD;
    address public rawDataDecoderAndSanitizer = 0xab7d3d3b990751a4DB70B165f23187BaB77c8AAf;

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
        token0[0] = getAddress(sourceChain, "USDT");

        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "mUSD");

        _addPancakeSwapV3Leafs(leafs, token0, token1);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](3);
        SwapKind[] memory kind = new SwapKind[](3);
        assets[0] = getAddress(sourceChain, "USDT");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "mUSD");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "EUL");
        kind[2] = SwapKind.Sell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Odos ==========================
        _addOdosSwapLeafs(leafs, assets, kind);

        // ========================== Euler ==========================
        ERC4626[] memory depositVaults = new ERC4626[](2);
        depositVaults[0] = ERC4626(getAddress(sourceChain, "euler-emUSD-1"));
        depositVaults[1] = ERC4626(getAddress(sourceChain, "euler-eUSDT-3"));

        address[] memory subaccounts = new address[](1);
        subaccounts[0] = address(boringVault);

        _addEulerDepositLeafs(leafs, depositVaults, subaccounts);

        _addrEULWrappingLeafs(leafs);

        // ========================== Merkl ==========================
        _addMerklLeafs(leafs, getAddress(sourceChain, "merklDistributor"), getAddress(sourceChain, "dev1Address"));

        // ========================== Native Leafs ==========================
        _addNativeLeafs(leafs, getAddress(sourceChain, "WBNB"));

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](2);
        feeAssets[0] = getERC20(sourceChain, "USDT");
        feeAssets[1] = getERC20(sourceChain, "mUSD");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleMusdMarket"), true);

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/BinanceSmartChain/TurtleMUSDMerkleRoot.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
