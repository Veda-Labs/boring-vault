// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateMultiChainTestMerkleRoot.s.sol:CreateMultiChainTestMerkleRootScript --rpc-url $MAINNET_RPC_URL
 */
contract CreateMultiChainTestMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xaA6D4Fb1FF961f8E52334f433974d40484e8be8F;
    address public rawDataDecoderAndSanitizer = 0x749E7D288071Bda6BC41C731ca360934F9513B66;
    address public managerAddress = 0x744d1f71a6d064204b4c59Cf2BDCF9De9C6c3430;
    address public accountantAddress = 0x99c836937305693A5518819ED457B0d3dfE99785;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateMultiChainTestStrategistMerkleRoot();
    }

    function generateMultiChainTestStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](512);

        // ========================== Native ==========================
        /**
         * wrap, unwrap
         */
        _addNativeLeafs(leafs);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](19);
        SwapKind[] memory kind = new SwapKind[](19);
        assets[0] = getAddress(sourceChain, "WETH");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "WEETH");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "WSTETH");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "LBTC");
        kind[3] = SwapKind.BuyAndSell;
        assets[4] = getAddress(sourceChain, "cbBTC");
        kind[4] = SwapKind.BuyAndSell;
        assets[5] = getAddress(sourceChain, "WBTC");
        kind[5] = SwapKind.BuyAndSell;
        assets[6] = getAddress(sourceChain, "SUSDE");
        kind[6] = SwapKind.BuyAndSell;
        assets[7] = getAddress(sourceChain, "eBTC");
        kind[7] = SwapKind.BuyAndSell;
        assets[8] = getAddress(sourceChain, "USD0_plus");
        kind[8] = SwapKind.BuyAndSell;
        assets[9] = getAddress(sourceChain, "sDAI");
        kind[9] = SwapKind.BuyAndSell;
        assets[10] = getAddress(sourceChain, "USDE");
        kind[10] = SwapKind.BuyAndSell;
        assets[11] = getAddress(sourceChain, "USDS");
        kind[11] = SwapKind.BuyAndSell;
        assets[12] = getAddress(sourceChain, "PYUSD");
        kind[12] = SwapKind.BuyAndSell;
        assets[13] = getAddress(sourceChain, "DAI");
        kind[13] = SwapKind.BuyAndSell;
        assets[14] = getAddress(sourceChain, "USDT");
        kind[14] = SwapKind.BuyAndSell;
        assets[15] = getAddress(sourceChain, "USDC");
        kind[15] = SwapKind.BuyAndSell;
        assets[16] = getAddress(sourceChain, "USD0");
        kind[16] = SwapKind.BuyAndSell;
        assets[17] = getAddress(sourceChain, "USR");
        kind[17] = SwapKind.BuyAndSell;
        assets[18] = getAddress(sourceChain, "wstUSR");
        kind[18] = SwapKind.BuyAndSell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "wstETH_wETH_01"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "wETH_weETH_05"));

        // ========================== Euler ==========================
        {
            ERC4626[] memory depositVaults = new ERC4626[](1); 
            depositVaults[0] = ERC4626(getAddress(sourceChain, "eulerPrimeWETH")); 
            
            address[] memory subaccounts = new address[](1); 
            subaccounts[0] = address(boringVault); 

            _addEulerDepositLeafs(leafs, depositVaults, subaccounts); 
        }

        string memory filePath = "./leafs/Mainnet/MultiChainTestMerkleRoot.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
