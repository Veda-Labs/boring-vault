// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateLombardMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */
contract CreateSonicLBTCvMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x309f25d839A2fe225E80210e110C99150Db98AAF;
    address public rawDataDecoderAndSanitizer = 0x163a296D62CbF170Fc29Fd76798AA95e534de782;
    address public managerAddress = 0x9D828035dd3C95452D4124870C110E7866ea6bb7;
    address public accountantAddress = 0x0639e239E417Ab9D1f0f926Fd738a012153930A7;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateSonicLBTCvStrategistMerkleRoot();
    }

    function generateSonicLBTCvStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        leafIndex = type(uint256).max;

        ManageLeaf[] memory leafs = new ManageLeaf[](32);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](2);
        feeAssets[0] = getERC20(sourceChain, "LBTC");
        feeAssets[1] = getERC20(sourceChain, "eBTC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, true);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](3);
        SwapKind[] memory kind = new SwapKind[](3);
        assets[0] = getAddress(sourceChain, "LBTC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "eBTC");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "scBTC");
        kind[2] = SwapKind.BuyAndSell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== BoringVaults ==========================
        {
            ERC20[] memory eBTCTellerAssets = new ERC20[](1);
            eBTCTellerAssets[0] = getERC20(sourceChain, "LBTC");
            address eBTCTeller = 0x458797A320e6313c980C2bC7D270466A6288A8bB;
            _addTellerLeafs(leafs, eBTCTeller, eBTCTellerAssets, false);

            ERC20[] memory sonicBTCTellerAssets = new ERC20[](2); 
            sonicBTCTellerAssets[0] = getERC20(sourceChain, "LBTC"); 
            sonicBTCTellerAssets[1] = getERC20(sourceChain, "eBTC");
            address sonicBTCTeller = 0xAce7DEFe3b94554f0704d8d00F69F273A0cFf079;
            _addTellerLeafs(leafs, sonicBTCTeller, sonicBTCTellerAssets, false);
        }

        // ========================== LayerZero ==========================
        address LBTCSonicOFTAdapter = 0xcFEAc622BC6464acC759ACd9741a6D78F8b0d3Cd;
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "LBTC"), LBTCSonicOFTAdapter, layerZeroSonicMainnetEndpointId
        );

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Mainnet/SonicLBTCvStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
