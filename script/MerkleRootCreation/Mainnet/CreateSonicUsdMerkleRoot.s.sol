// SPDX-License-Identifier: UNLICENSED
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
    address public rawDataDecoderAndSanitizer = 0x215dAfCAD04C59a9d8F48a8Ae1ea8f5a053309FD;


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

        ManageLeaf[] memory leafs = new ManageLeaf[](128);

        // ========================== UniswapV3 ==========================
        // USDC, USDT, sDAI, DAI, sUSDs, GHO
        address[] memory token0 = new address[](6);
        token0[0] = getAddress(sourceChain, "USDC");
        token0[1] = getAddress(sourceChain, "USDT");
        token0[2] = getAddress(sourceChain, "sDAI");
        token0[3] = getAddress(sourceChain, "USDC");
        token0[4] = getAddress(sourceChain, "USDC");
        token0[5] = getAddress(sourceChain, "USDT");

        address[] memory token1 = new address[](6);
        token1[0] = getAddress(sourceChain, "DAI");
        token1[1] = getAddress(sourceChain, "DAI");
        token1[2] = getAddress(sourceChain, "USDT");
        token1[3] = getAddress(sourceChain, "USDT");
        token1[4] = getAddress(sourceChain, "GHO");
        token1[5] = getAddress(sourceChain, "GHO");

        
        // ========================== 1inch ==========================
        address[] memory assets = new address[](6);
        SwapKind[] memory kind = new SwapKind[](6);
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

        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Aave V3 ==========================
        // Core
        ERC20[] memory supplyAssets = new ERC20[](2);
        supplyAssets[0] = getERC20(sourceChain, "USDC");
        supplyAssets[1] = getERC20(sourceChain, "USDT");
        ERC20[] memory borrowAssets = new ERC20[](2);
        borrowAssets[0] = getERC20(sourceChain, "USDC");
        borrowAssets[1] = getERC20(sourceChain, "USDT");

        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets); 
        // Prime
        _addAaveV3PrimeLeafs(leafs, supplyAssets, borrowAssets); 
        
        // ========================== MetaMorho  ==========================
         _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "steakhouseUSDC")));
         _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletUSDCcore")));

        // ========================== sDAI ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sDAI")));   

        // ========================== sUSDs  ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sUSDs")));   

        // ========================== Verify & Generate ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/SonicUsdStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
        
    }

}

