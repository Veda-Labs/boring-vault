// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateTacTestMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateTacTestMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0x00007EDa736C6CdF973BDefF2191bbCfE6175db7;
    address public rawDataDecoderAndSanitizer = 0x17D6eDA406b8D2D0DC4a68a4656c3091E3467386;
    address public managerAddress = 0x999999e868Fb298c6EDbf0060f7cE077f01ad782; 
    address public accountantAddress = 0x5555559e499d2107aBb035a5feA1235b7f942E6D;
    

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

        ManageLeaf[] memory leafs = new ManageLeaf[](8);


        // ========================== 1inch ==========================
        // address[] memory assets = new address[](9);
        // SwapKind[] memory kind = new SwapKind[](9);
        // assets[0] = getAddress(sourceChain, "USDC");
        // kind[0] = SwapKind.BuyAndSell;
        // assets[1] = getAddress(sourceChain, "USDT");
        // kind[1] = SwapKind.BuyAndSell;
        // assets[2] = getAddress(sourceChain, "DAI");
        // kind[2] = SwapKind.BuyAndSell;
        // assets[3] = getAddress(sourceChain, "sUSDS");
        // kind[3] = SwapKind.BuyAndSell;
        // assets[4] = getAddress(sourceChain, "USDS");
        // kind[4] = SwapKind.BuyAndSell;
        // assets[5] = getAddress(sourceChain, "WETH");
        // kind[5] = SwapKind.BuyAndSell;
        // assets[6] = getAddress(sourceChain, "WSTETH");
        // kind[6] = SwapKind.BuyAndSell;
        // assets[7] = getAddress(sourceChain, "LBTC");
        // kind[7] = SwapKind.BuyAndSell;
        // assets[8] = getAddress(sourceChain, "cbBTC");
        // kind[8] = SwapKind.BuyAndSell;

        // _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // // ========================== Odos ==========================
        // _addOdosSwapLeafs(leafs, assets, kind);  

        // // ========================== Sky Money ==========================
        // _addAllSkyMoneyLeafs(leafs);  

        // // ========================== sUSDs ==========================
        // _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "sUSDs")));

        // // ========================== Aave ==========================
        // ERC20[] memory supplyAssets = new ERC20[](1);
        // supplyAssets[0] = getERC20(sourceChain, "USDT");

        // ERC20[] memory borrowAssets = new ERC20[](1);
        // borrowAssets[0] = getERC20(sourceChain, "USDC");

        // _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== LayerZero ==========================
        // tacUSD test
        //_addLayerZeroLeafs(leafs, getERC20(sourceChain, "USDT"), getAddress(sourceChain, ""), layerZeroTONEndpointId, getBytes32(sourceChain, "boringVault"));
        // tacETH test
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "WSTETH"), getAddress(sourceChain, "WSTETHOFTAdapterTAC"), layerZeroTACEndpointId, getBytes32(sourceChain, "boringVault")); 
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "WETH"), getAddress(sourceChain, "WETHOFTAdapterTAC"), layerZeroTACEndpointId, getBytes32(sourceChain, "boringVault")); 
        // tacBTC test
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "cbBTC"), getAddress(sourceChain, "CBBTCOFTAdapterTAC"), layerZeroTACEndpointId, getBytes32(sourceChain, "boringVault")); 
        // tacLBTCv test
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "LBTC"), getAddress(sourceChain, "LBTCOFTAdapterTAC"), layerZeroTACEndpointId, getBytes32(sourceChain, "boringVault")); 

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);
        console.log("leafs length: %s", leafs.length);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Mainnet/TacTestStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

    }

}
