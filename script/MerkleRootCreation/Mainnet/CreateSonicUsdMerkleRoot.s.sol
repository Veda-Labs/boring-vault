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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateSonicUsdMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */

contract CreateSonicUsdMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xd3DCe716f3eF535C5Ff8d041c1A41C3bd89b97aE;
    address public managerAddress = 0x76fda7A02B616070D3eC5902Fa3C5683AC3cB8B6;
    address public accountantAddress = 0xA76E0F54918E39A63904b51F688513043242a0BE;
    address public rawDataDecoderAndSanitizer = 0x808C101469d723E48874c9450C3C99771493057F;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateSonicUsdStrategistMerkleRoot();
    }

    function generateSonicUsdStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](1024);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](4);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        feeAssets[1] = getERC20(sourceChain, "DAI");
        feeAssets[2] = getERC20(sourceChain, "USDT");
        feeAssets[3] = getERC20(sourceChain, "USDS");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, true);

        // ========================== UniswapV3 ==========================
        // All combinations of USDC, USDT, sDAI, DAI, sUSDs, GHO, USDs
        address[] memory token0 = new address[](21);
        token0[0] = getAddress(sourceChain, "USDC");
        token0[1] = getAddress(sourceChain, "USDC");
        token0[2] = getAddress(sourceChain, "USDC");
        token0[3] = getAddress(sourceChain, "USDC");
        token0[4] = getAddress(sourceChain, "USDC");
        token0[5] = getAddress(sourceChain, "USDC");
        token0[6] = getAddress(sourceChain, "USDT");
        token0[7] = getAddress(sourceChain, "USDT");
        token0[8] = getAddress(sourceChain, "USDT");
        token0[9] = getAddress(sourceChain, "USDT");
        token0[10] = getAddress(sourceChain, "USDT");
        token0[11] = getAddress(sourceChain, "sDAI");
        token0[12] = getAddress(sourceChain, "sDAI");
        token0[13] = getAddress(sourceChain, "sDAI");
        token0[14] = getAddress(sourceChain, "DAI");
        token0[15] = getAddress(sourceChain, "DAI");
        token0[16] = getAddress(sourceChain, "sUSDs");
        token0[17] = getAddress(sourceChain, "sUSDs");
        token0[18] = getAddress(sourceChain, "GHO");
        token0[19] = getAddress(sourceChain, "USDS");
        token0[20] = getAddress(sourceChain, "USDS");

        address[] memory token1 = new address[](21);
        token1[0] = getAddress(sourceChain, "USDT");
        token1[1] = getAddress(sourceChain, "sDAI");
        token1[2] = getAddress(sourceChain, "DAI");
        token1[3] = getAddress(sourceChain, "sUSDs");
        token1[4] = getAddress(sourceChain, "GHO");
        token1[5] = getAddress(sourceChain, "USDS");
        token1[6] = getAddress(sourceChain, "sDAI");
        token1[7] = getAddress(sourceChain, "DAI");
        token1[8] = getAddress(sourceChain, "sUSDs");
        token1[9] = getAddress(sourceChain, "GHO");
        token1[10] = getAddress(sourceChain, "USDS");
        token1[11] = getAddress(sourceChain, "DAI");
        token1[12] = getAddress(sourceChain, "sUSDs");
        token1[13] = getAddress(sourceChain, "GHO");
        token1[14] = getAddress(sourceChain, "sUSDs");
        token1[15] = getAddress(sourceChain, "GHO");
        token1[16] = getAddress(sourceChain, "GHO");
        token1[17] = getAddress(sourceChain, "USDS");
        token1[18] = getAddress(sourceChain, "USDS");
        token1[19] = getAddress(sourceChain, "sUSDs");
        token1[20] = getAddress(sourceChain, "GHO");

        _addUniswapV3Leafs(leafs, token0, token1, true);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](13);
        SwapKind[] memory kind = new SwapKind[](13);
        assets[0] = getAddress(sourceChain, "USDC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "USDT");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "DAI");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "sDAI");
        kind[3] = SwapKind.BuyAndSell;
        assets[4] = getAddress(sourceChain, "sUSDs");
        kind[4] = SwapKind.BuyAndSell;
        assets[5] = getAddress(sourceChain, "GHO");
        kind[5] = SwapKind.BuyAndSell;
        assets[6] = getAddress(sourceChain, "USDS");
        kind[6] = SwapKind.BuyAndSell;
        assets[7] = getAddress(sourceChain, "MORPHO");
        kind[7] = SwapKind.Sell;
        assets[8] = getAddress(sourceChain, "FLUID");
        kind[8] = SwapKind.Sell;
        assets[9] = getAddress(sourceChain, "EUL");
        kind[9] = SwapKind.Sell;
        assets[10] = getAddress(sourceChain, "rEUL");
        kind[10] = SwapKind.Sell;
        assets[10] = getAddress(sourceChain, "frxUSD");
        kind[10] = SwapKind.BuyAndSell;
        assets[11] = getAddress(sourceChain, "sfrxUSD");
        kind[11] = SwapKind.BuyAndSell;
        assets[12] = getAddress(sourceChain, "CRVUSD");
        kind[12] = SwapKind.BuyAndSell;
        

        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Aave V3 ==========================
        // Core
        ERC20[] memory supplyAssets = new ERC20[](4);
        supplyAssets[0] = getERC20(sourceChain, "USDC");
        supplyAssets[1] = getERC20(sourceChain, "USDT");
        supplyAssets[2] = getERC20(sourceChain, "DAI");
        supplyAssets[3] = getERC20(sourceChain, "USDS");
        ERC20[] memory borrowAssets = new ERC20[](0);

        //Prime
        ERC20[] memory supplyAssetsPrime = new ERC20[](2);
        supplyAssetsPrime[0] = getERC20(sourceChain, "USDC");
        supplyAssetsPrime[1] = getERC20(sourceChain, "USDS");
        ERC20[] memory borrowAssetsPrime = new ERC20[](0);

        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);
        // Prime
        _addAaveV3PrimeLeafs(leafs, supplyAssetsPrime, borrowAssetsPrime);

        // ========================== MetaMorho  ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "steakhouseUSDC")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletUSDCcore")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletUSDCprime")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "usualBoostedUSDC")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "smokehouseUSDC")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "steakhouseUSDT"))); 
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "smokehouseUSDT"))); 

        // ========================== Morpho Rewards ==========================
        _addMorphoRewardMerkleClaimerLeafs(leafs, getAddress(sourceChain, "universalRewardsDistributor")); 

        // ========================== sDAI ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sDAI")));

        // ========================== sUSDs ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sUSDs")));

        // ========================== sUSDC ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sUSDC")));

        // ========================== sfrxUSD ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sfrxUSD")));

        // ========================== scrvUSD ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "scrvUSD")));

        // ========================== Sonic Gateway ==========================
        {
        ERC20[] memory bridgeAssets = new ERC20[](2);
        bridgeAssets[0] = getERC20(sourceChain, "USDC");
        bridgeAssets[1] = getERC20(sourceChain, "USDT");
        _addSonicGatewayLeafsEth(leafs, bridgeAssets);
        }

        // ========================== Fluid ==========================
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fUSDC"));
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fUSDT"));            
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fGHO"));            

        // ========================== Fluid Rewards ==========================

        _addFluidRewardsClaiming(leafs);

        // ========================== Fluid Dex ==========================
         {
            ERC20[] memory supplyTokens = new ERC20[](2);
            supplyTokens[0] = getERC20(sourceChain, "GHO");
            supplyTokens[1] = getERC20(sourceChain, "USDC");

            ERC20[] memory borrowTokens = new ERC20[](2);
            borrowTokens[0] = getERC20(sourceChain, "GHO");
            borrowTokens[1] = getERC20(sourceChain, "USDC");

            uint256 dexType = 4000;

            _addFluidDexLeafs(
                leafs, getAddress(sourceChain, "GHO_USDCDex_GHO_USDCDex"), dexType, supplyTokens, borrowTokens, false //no native ETH leaves
            );
        }
        
        // ========================== Odos ==========================
        // reuse same assets from 1inch array since we want those same swaps
        _addOdosSwapLeafs(leafs, assets, kind); 


        // ========================== Sparklend ==========================
        {
        ERC20[] memory supplyAssetsSparklend = new ERC20[](2);
        supplyAssetsSparklend[0] = getERC20(sourceChain, "USDC"); 
        supplyAssetsSparklend[1] = getERC20(sourceChain, "USDT"); 
        ERC20[] memory borrowAssetsSparklend = new ERC20[](0);
        _addSparkLendLeafs(leafs, supplyAssetsSparklend, borrowAssetsSparklend); 
        }

        // ========================== Euler ==========================
        {
        ERC4626[] memory depositVaults = new ERC4626[](5);      
        depositVaults[0] = ERC4626(getAddress(sourceChain, "evkeUSDC-2")); //Prime
        depositVaults[1] = ERC4626(getAddress(sourceChain, "evkeUSDT-2")); //Prime
        depositVaults[2] = ERC4626(getAddress(sourceChain, "evkeUSDC-22")); //Yield 
        depositVaults[3] = ERC4626(getAddress(sourceChain, "evkeUSDT-9")); //Yield
        depositVaults[4] = ERC4626(getAddress(sourceChain, "evkesUSDS-4")); //Yield
        
        address[] memory subaccounts = new address[](1); 
        subaccounts[0] = getAddress(sourceChain, "boringVault"); 

        _addEulerDepositLeafs(leafs,  depositVaults, subaccounts); 

        }

        // ========================== Merkl ==========================
        //claim rEUL
        { 
            _addMerklLeafs(leafs, getAddress(sourceChain, "merklDistributor"), getAddress(sourceChain, "dev1Address"));  
        }

         // ========================== Gearbox ==========================
         /**
         * USDC, USDT, GHO deposit, withdraw,  dUSDCV3, dUSDTV3, dGHOV3 deposit, withdraw, claim
         */
        _addGearboxLeafs(leafs, ERC4626(getAddress(sourceChain, "dUSDCV3")), getAddress(sourceChain, "sdUSDCV3"));
        _addGearboxLeafs(leafs, ERC4626(getAddress(sourceChain, "dUSDTV3")), getAddress(sourceChain, "sdUSDTV3"));
        _addGearboxLeafs(leafs, ERC4626(getAddress(sourceChain, "dGHOV3")), getAddress(sourceChain, "sdGHOV3"));

        // ========================== LayerZero ==========================
        //USDC, frxUSD  
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "USDC"), getAddress(sourceChain, "stargateUSDC"), layerZeroSonicMainnetEndpointId, getBytes32(sourceChain, "boringVault"));  
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "frxUSD"), getAddress(sourceChain, "frxUSDOFTAdapter"), layerZeroSonicMainnetEndpointId, getBytes32(sourceChain, "boringVault")); 
        
        
        _addCCTPBridgeLeafs(leafs, uint32(13));

        // ========================== Verify & Generate ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/SonicUsdStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
