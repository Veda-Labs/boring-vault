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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateSonicEthMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */

contract CreateSonicEthMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x3bcE5CB273F0F148010BbEa2470e7b5df84C7812;
    address public managerAddress = 0x6830046d872604E92f9F95F225fF63f2300bc1e9;
    address public accountantAddress = 0x3a592F9Ea2463379c4154d03461A73c484993668;
    address public rawDataDecoderAndSanitizer = 0x74Bd1a5153Db3FE3a437dE0B7C74a088d447F9ab;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateSonicEthStrategistMerkleRoot();
    }

    function generateSonicEthStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](3);
        feeAssets[0] = getERC20(sourceChain, "WETH");
        feeAssets[1] = getERC20(sourceChain, "WEETH");
        feeAssets[2] = getERC20(sourceChain, "WSTETH");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, true);

        // ========================== UniswapV3 ==========================
        // WETH, WEETH, wstETH
        address[] memory token0 = new address[](3);
        token0[0] = getAddress(sourceChain, "WETH");
        token0[1] = getAddress(sourceChain, "WETH");
        token0[2] = getAddress(sourceChain, "WEETH");

        address[] memory token1 = new address[](3);
        token1[0] = getAddress(sourceChain, "WEETH");
        token1[1] = getAddress(sourceChain, "WSTETH");
        token1[2] = getAddress(sourceChain, "WSTETH");

        _addUniswapV3Leafs(leafs, token0, token1, true);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](4);
        SwapKind[] memory kind = new SwapKind[](4);
        assets[0] = getAddress(sourceChain, "WETH");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "WEETH");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "WSTETH");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "MORPHO");
        kind[3] = SwapKind.Sell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Odos ==========================
        _addOdosSwapLeafs(leafs, assets, kind); 
            
        // ========================== Aave V3 ==========================
        // Core
        ERC20[] memory supplyAssets = new ERC20[](3);
        supplyAssets[0] = getERC20(sourceChain, "WETH");
        supplyAssets[1] = getERC20(sourceChain, "WEETH");
        supplyAssets[2] = getERC20(sourceChain, "WSTETH");
        ERC20[] memory borrowAssets = new ERC20[](0);

        // Prime
        ERC20[] memory supplyAssetsPrime = new ERC20[](2);
        supplyAssetsPrime[0] = getERC20(sourceChain, "WETH");
        supplyAssetsPrime[1] = getERC20(sourceChain, "WSTETH");
        ERC20[] memory borrowAssetsPrime = new ERC20[](0);

        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);
        _addAaveV3PrimeLeafs(leafs, supplyAssetsPrime, borrowAssetsPrime);

        // ========================== MetaMorho  ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletWETHPrime")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletWETHCore")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "mevCapitalwWeth")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "steakhouseETH")));

        // ========================== Morpho Rewards ==========================
        _addMorphoRewardMerkleClaimerLeafs(leafs, getAddress(sourceChain, "universalRewardsDistributor")); 

        // ========================== Lido (stETH, wstETH) ==========================
        _addLidoLeafs(leafs);

        // ========================== Etherfi (eETh, weETH) ==========================
        _addEtherFiLeafs(leafs);

        // ========================== Native ==========================
        _addNativeLeafs(leafs);

        // ========================== Sonic Gateway ==========================
        ERC20[] memory bridgeAssets = new ERC20[](1);
        bridgeAssets[0] = getERC20(sourceChain, "WETH");
        _addSonicGatewayLeafsEth(leafs, bridgeAssets);

        // ========================== Gearbox ==========================
        _addGearboxLeafs(leafs, ERC4626(getAddress(sourceChain, "dWETHV3")), getAddress(sourceChain, "sdWETHV3")); 
        _addGearboxLeafs(leafs, ERC4626(getAddress(sourceChain, "dWSTETHV3")), address(0)); //no staking address for wstETH

        // ========================== Euler ==========================
        {
        ERC4626[] memory depositVaults = new ERC4626[](1);      
        depositVaults[0] = ERC4626(getAddress(sourceChain, "evkeWETH-2")); //Prime
        
        address[] memory subaccounts = new address[](1); 
        subaccounts[0] = getAddress(sourceChain, "boringVault"); 

        _addEulerDepositLeafs(leafs,  depositVaults, subaccounts); 

        }
        
        // ========================== Verify & Generate ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/SonicEthStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
