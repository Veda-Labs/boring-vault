// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";
/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateSonicBTCMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */

contract CreateSonicBTCMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xBb30e76d9Bb2CC9631F7fC5Eb8e87B5Aff32bFbd;
    address public managerAddress = 0x5dA93667DCc58b71726aFC595f116A6F166F9aeD;
    address public accountantAddress = 0xC1a2C650D2DcC8EAb3D8942477De71be52318Acb;
    address public rawDataDecoderAndSanitizer = 0xf7d5D3ba755583C8b174ADE63E8687471Ad8b20a;
    address public lbtcBridgeDecoder = 0xE9527EA95a383993b41EA7D3b0E50DDA7B13dE94; 

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

        ManageLeaf[] memory leafs = new ManageLeaf[](128);

        // ========================== UniswapV3 ==========================
        // WBTC, LBTC, EBTC
        address[] memory token0 = new address[](2);
        token0[0] = getAddress(sourceChain, "WBTC");
        token0[1] = getAddress(sourceChain, "WBTC");

        address[] memory token1 = new address[](2);
        token1[0] = getAddress(sourceChain, "LBTC");
        token1[1] = getAddress(sourceChain, "EBTC");

        _addUniswapV3Leafs(leafs, token0, token1, true);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](3);
        SwapKind[] memory kind = new SwapKind[](3);
        assets[0] = getAddress(sourceChain, "WBTC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "LBTC");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "EBTC");
        kind[2] = SwapKind.BuyAndSell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Aave V3 ==========================
        // Core
        ERC20[] memory supplyAssets = new ERC20[](3);
        supplyAssets[0] = getERC20(sourceChain, "WBTC");
        supplyAssets[1] = getERC20(sourceChain, "LBTC");
        supplyAssets[2] = getERC20(sourceChain, "EBTC");
        ERC20[] memory borrowAssets = new ERC20[](0);

        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== MetaMorho  ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletWBTCcore")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletLBTCcore")));

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "WBTC"),
            getAddress(sourceChain, "WBTCOFTAdapter"),
            layerZeroSonicMainnetEndpointId,
            getBytes32(sourceChain, "boringVault")
        );

        // ========================== CCIP ==========================
        setAddress(true, mainnet, "rawDataDecoderAndSanitizer", lbtcBridgeDecoder);
        bytes32 toChain = 0x0000000000000000000000000000000000000000000000000000000000000092; //sonic
        _addLBTCBridgeLeafs(leafs, toChain);

        // ========================== Tellers ==========================
        setAddress(true, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        {
            ERC20[] memory eBTCTellerAssets = new ERC20[](3);
            eBTCTellerAssets[0] = getERC20(sourceChain, "WBTC");
            eBTCTellerAssets[1] = getERC20(sourceChain, "LBTC");
            eBTCTellerAssets[2] = getERC20(sourceChain, "cbBTC");
            _addTellerLeafs(leafs, getAddress(sourceChain, "eBTCTeller"), eBTCTellerAssets, false, false);

            // Add withdrawal leafs eBTC for LBTC
            ERC20[] memory _eBTCWithdrawalAssets = new ERC20[](3);
            _eBTCWithdrawalAssets[0] = getERC20(sourceChain, "LBTC");
            _eBTCWithdrawalAssets[1] = getERC20(sourceChain, "WBTC");
            _eBTCWithdrawalAssets[2] = getERC20(sourceChain, "cbBTC");
            _addWithdrawQueueLeafs(leafs, getAddress(sourceChain, "eBTCOnChainQueueFast"), getAddress(sourceChain, "eBTC"), _eBTCWithdrawalAssets);
        }

        // ========================== Verify & Generate ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/SonicBTCStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
