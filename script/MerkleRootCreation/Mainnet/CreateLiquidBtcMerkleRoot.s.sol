// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateLiquidBtcMerkleRoot.s.sol:CreateLiquidBtcMerkleRoot --rpc-url $MAINNET_RPC_URL
 */
contract CreateLiquidBtcMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;
    
    address public boringVault = 0x5f46d540b6eD704C3c8789105F30E075AA900726;
    address public managerAddress = 0xaFa8c08bedB2eC1bbEb64A7fFa44c604e7cca68d;
    address public accountantAddress = 0xEa23aC6D7D11f6b181d6B98174D334478ADAe6b0;
    address public rawDataDecoderAndSanitizer = 0x0e9fa7311b5EEb6466cd8eb524Dbd96ab4289213; 
    
    function setUp() external {}

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

        ManageLeaf[] memory leafs = new ManageLeaf[](512);

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](15);
        token0[0] = getAddress(sourceChain, "WBTC");
        token0[1] = getAddress(sourceChain, "WBTC");
        token0[2] = getAddress(sourceChain, "LBTC");

        token0[3] = getAddress(sourceChain, "USDC"); 
        token0[4] = getAddress(sourceChain, "USDT"); 

        token0[5] = getAddress(sourceChain, "WBTC"); 
        token0[6] = getAddress(sourceChain, "cbBTC"); 
        token0[7] = getAddress(sourceChain, "LBTC"); 

        token0[8] = getAddress(sourceChain, "WBTC"); 
        token0[9] = getAddress(sourceChain, "cbBTC"); 
        token0[10] = getAddress(sourceChain, "LBTC"); 

        token0[11] = getAddress(sourceChain, "USD0"); 
        token0[12] = getAddress(sourceChain, "SUSDE"); 
        token0[13] = getAddress(sourceChain, "USDE"); 

        token0[14] = getAddress(sourceChain, "WBTC"); 

        address[] memory token1 = new address[](15);
        token1[0] = getAddress(sourceChain, "LBTC");
        token1[1] = getAddress(sourceChain, "cbBTC");
        token1[2] = getAddress(sourceChain, "cbBTC");

        token1[3] = getAddress(sourceChain, "USDT"); 
        token1[4] = getAddress(sourceChain, "USD0_plus"); 

        token1[5] = getAddress(sourceChain, "USDC"); 
        token1[6] = getAddress(sourceChain, "USDC"); 
        token1[7] = getAddress(sourceChain, "USDC"); 

        token1[8] = getAddress(sourceChain, "USDT"); 
        token1[9] = getAddress(sourceChain, "USDT"); 
        token1[10] = getAddress(sourceChain, "USDT"); 

        token1[11] = getAddress(sourceChain, "USDT"); 
        token1[12] = getAddress(sourceChain, "USDT"); 
        token1[13] = getAddress(sourceChain, "USDT"); 

        token1[14] = getAddress(sourceChain, "eBTC"); 

        _addUniswapV3Leafs(leafs, token0, token1, false);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](10);
        SwapKind[] memory kind = new SwapKind[](10);
        assets[0] = getAddress(sourceChain, "WBTC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "LBTC");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "cbBTC");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "USDC");
        kind[3] = SwapKind.BuyAndSell;
        assets[4] = getAddress(sourceChain, "USDT");
        kind[4] = SwapKind.BuyAndSell;
        assets[5] = getAddress(sourceChain, "USD0");
        kind[5] = SwapKind.BuyAndSell;
        assets[6] = getAddress(sourceChain, "USD0_plus");
        kind[6] = SwapKind.BuyAndSell;
        assets[7] = getAddress(sourceChain, "SUSDE");
        kind[7] = SwapKind.BuyAndSell;
        assets[8] = getAddress(sourceChain, "USDE");
        kind[8] = SwapKind.BuyAndSell;
        assets[9] = getAddress(sourceChain, "eBTC");
        kind[9] = SwapKind.BuyAndSell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);
        
        // ========================== Aave ==========================
        ERC20[] memory supplyAssets = new ERC20[](3); 
        supplyAssets[0] = getERC20(sourceChain, "WBTC");  
        supplyAssets[1] = getERC20(sourceChain, "LBTC");  
        supplyAssets[2] = getERC20(sourceChain, "cbBTC");  

        ERC20[] memory borrowAssets = new ERC20[](3); 
        borrowAssets[0] = getERC20(sourceChain, "USDC"); 
        borrowAssets[1] = getERC20(sourceChain, "USDT"); 
        borrowAssets[2] = getERC20(sourceChain, "WBTC"); 

        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);  

        // ========================== MetaMorpho ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "usualBoostedUSDC")));
        
        // ========================== Pendle ==========================
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USD0++_market_01_29_25"), true); 
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_USD0++_market_06_25_25"), true); 

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/LiquidBtcStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
         
    }
}
