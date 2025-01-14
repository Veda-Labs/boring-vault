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
    address public rawDataDecoderAndSanitizer = 0xfc27B1CbA6F640060cCcC5E42B7828577f175D17;

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

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](4);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        feeAssets[1] = getERC20(sourceChain, "DAI");
        feeAssets[2] = getERC20(sourceChain, "USDT");
        feeAssets[3] = getERC20(sourceChain, "USDS");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets);

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
        address[] memory assets = new address[](7);
        SwapKind[] memory kind = new SwapKind[](7);
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

        // ========================== sDAI ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sDAI")));

        // ========================== sUSDs  ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sUSDs")));

         // ========================== Sonic Gateway ==========================
        ERC20[] memory bridgeAssets = new ERC20[](1); 
        bridgeAssets[0] = getERC20(sourceChain, "USDC"); 
        _addSonicGatewayLeafsEth(leafs, bridgeAssets); 

        // ========================== Verify & Generate ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/SonicUsdStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
