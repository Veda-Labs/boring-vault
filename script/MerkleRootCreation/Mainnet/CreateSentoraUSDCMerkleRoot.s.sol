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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateSentoraUSDCMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateSentoraUSDCMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0x9761DDF8e79930b334f1Be1BD93aBE3695061CcA;
    address public rawDataDecoderAndSanitizer = 0x5fFc5881EFce9a75e5654FC815EcaD03695EFf36;
    address public itbDecoderAndSanitizer = 0x2D7085602a85aFb417AE1dFcEc09C301FeC8Df36;
    address public managerAddress = 0x38Fe609799ED585e9154c92D1D801B461F538753;
    address public accountantAddress = 0x427a3c091F09fa6212d177060bb7456Abf538b22;

    address public odosOwnedDecoderAndSanitizer = 0x6149c711434C54A48D757078EfbE0E2B2FE2cF6a;
    address public oneInchOwnedDecoderAndSanitizer = 0x42842201E199E6328ADBB98e7C2CbE77561FAC88;

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

        ManageLeaf[] memory leafs = new ManageLeaf[](128);
        
        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](1);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        // ========================== 1inch/Odos ==========================
        address[] memory assets = new address[](4);
        SwapKind[] memory kind = new SwapKind[](4);
        assets[0] = getAddress(sourceChain, "USDC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "USDT");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "PYUSD");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "RLUSD");
        kind[3] = SwapKind.BuyAndSell;

        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", oneInchOwnedDecoderAndSanitizer);
        _addLeafsFor1InchOwnedGeneralSwapping(leafs, assets, kind);
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", odosOwnedDecoderAndSanitizer);
        _addOdosOwnedSwapLeafs(leafs, assets, kind);
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        // ========================== LayerZero ==========================
        // bridge USDT to Ink via USDT0
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "USDT"),
            getAddress(sourceChain, "usdt0OFTAdapter"),
            layerZeroInkEndpointId,
            getBytes32(sourceChain, "boringVault")
        );

        // bridge USDC to Ink via CCTP
        _addCCTPBridgeLeafs(leafs, cctpInkDomainId);

        // ========================== Syrup ==========================

        {
            address[] memory syrupTokens = new address[](2);
            syrupTokens[0] = getAddress(sourceChain, "USDC");
            syrupTokens[1] = getAddress(sourceChain, "USDT");
            _addAllSyrupLeafs(leafs, syrupTokens);
        }

        // ========================== Position Manager ==========================
            // aave PYUSD
        {
            address aavePYUSDPositionManager = 0xb0463294137E42Ca84dD837bC9135292EC97F270;
            ERC20[] memory aavePYUSDTokensUsed = new ERC20[](1);
            aavePYUSDTokensUsed[0] = getERC20(sourceChain, "PYUSD");
            address[] memory aavePYUSDAdditionalExecutors = new address[](0);
            _addLeafsForITBPositionManager(leafs, aavePYUSDPositionManager, aavePYUSDTokensUsed, "Aave PYUSD ITB Position Manager", aavePYUSDAdditionalExecutors);
        }
        {
            // aave RLUSD
            address aaveRLUSDPositionManager = 0x89dfbb43dd50954a3CCe48b611E4ED231579224e;
            ERC20[] memory aaveRLUSDTokensUsed = new ERC20[](1);
            aaveRLUSDTokensUsed[0] = getERC20(sourceChain, "RLUSD");
            address[] memory aaveRLUSDAdditionalExecutors = new address[](0);
            _addLeafsForITBPositionManager(leafs, aaveRLUSDPositionManager, aaveRLUSDTokensUsed, "Aave RLUSD ITB Position Manager", aaveRLUSDAdditionalExecutors);
        }
        {
            // Euler RLUSD
            address eulerRLUSDPositionManager = 0x4D6376DdDD67Af6f9aD40225eC566212F85B5A16;
            ERC20[] memory eulerRLUSDTokensUsed = new ERC20[](1);
            eulerRLUSDTokensUsed[0] = getERC20(sourceChain, "RLUSD");
            address[] memory eulerRLUSDAdditionalExecutors = new address[](0);
            _addLeafsForITBPositionManager(leafs, eulerRLUSDPositionManager, eulerRLUSDTokensUsed, "Euler RLUSD ITB Position Manager", eulerRLUSDAdditionalExecutors);
        }
        {
            // Morpho PYUSD
            address morphoPYUSDPositionManager = 0xC5e0E2Bd8B8663c621b5051d863D072295dA9720;
            ERC20[] memory morphoPYUSDTokensUsed = new ERC20[](1);
            morphoPYUSDTokensUsed[0] = getERC20(sourceChain, "PYUSD");
            address[] memory morphoPYUSDAdditionalExecutors = new address[](1);
            morphoPYUSDAdditionalExecutors[0] = 0x49fAEBD1caed2488398E80fBB9D1dfCB8b502bDc;
            _addLeafsForITBPositionManager(leafs, morphoPYUSDPositionManager, morphoPYUSDTokensUsed, "Morpho PYUSD ITB Position Manager", morphoPYUSDAdditionalExecutors);
        }
        {
            // Euler PYUSD
            address eulerPYUSDPositionManager = 0xba4970b839678168340f823EF8f255832AB18C12;
            ERC20[] memory eulerPYUSDTokensUsed = new ERC20[](1);
            eulerPYUSDTokensUsed[0] = getERC20(sourceChain, "PYUSD");
            address[] memory eulerPYUSDAdditionalExecutors = new address[](0);
            _addLeafsForITBPositionManager(leafs, eulerPYUSDPositionManager, eulerPYUSDTokensUsed, "Euler PYUSD ITB Position Manager", eulerPYUSDAdditionalExecutors);
        
        }     
        {
            // Euler USDC
            address eulerUSDCPositionManager = 0xB134641B80982bEd7cDbb307E56E55ABBC8b3197;
            ERC20[] memory eulerUSDCTokensUsed = new ERC20[](1);
            eulerUSDCTokensUsed[0] = getERC20(sourceChain, "USDC");
            address[] memory eulerUSDCAdditionalExecutors = new address[](0);
            _addLeafsForITBPositionManager(leafs, eulerUSDCPositionManager, eulerUSDCTokensUsed, "Euler USDC ITB Position Manager", eulerUSDCAdditionalExecutors);
        }
        {
            address curvePYUSD_USDCPositionManager = 0xb11eD12e302815c8C5F12A3a1a93EBD7BD730A21;
            ERC20[] memory curveTokensUsed = new ERC20[](2);
            curveTokensUsed[0] = getERC20(sourceChain, "PYUSD");
            curveTokensUsed[1] = getERC20(sourceChain, "USDC");
            address[] memory curvePYUSD_USDCAdditionalExecutors = new address[](0);
            _addLeafsForITBPositionManager(leafs, curvePYUSD_USDCPositionManager, curveTokensUsed, "Curve PYUSD/USDC ITB Position Manager", curvePYUSD_USDCAdditionalExecutors);
        }
        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Mainnet/SentoraUSDCStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function _addLeafsForITBPositionManager(
         ManageLeaf[] memory leafs,
         address itbPositionManager,
         ERC20[] memory tokensUsed,
         string memory itbContractName,
         address[] memory additionalExecutors
     ) internal {
         // acceptOwnership
         leafIndex++;
         leafs[leafIndex] = ManageLeaf(
             itbPositionManager,
             false,
             "acceptOwnership()",
             new address[](0),
             string.concat("Accept ownership of the ", itbContractName, " contract"),
             itbDecoderAndSanitizer
         );
 
         // removeExecutor
         leafIndex++;
         leafs[leafIndex] = ManageLeaf(
             itbPositionManager,
             false,
             "removeExecutor(address)",
             new address[](0),
             string.concat("Remove executor from the ", itbContractName, " contract"),
             itbDecoderAndSanitizer
         );
 
         for (uint256 i; i < tokensUsed.length; ++i) {
             // Transfer
             leafIndex++;
             leafs[leafIndex] = ManageLeaf(
                 address(tokensUsed[i]),
                 false,
                 "transfer(address,uint256)",
                 new address[](1),
                 string.concat("Transfer ", tokensUsed[i].symbol(), " to the ", itbContractName, " contract"),
                 itbDecoderAndSanitizer
             );
             leafs[leafIndex].argumentAddresses[0] = itbPositionManager;
             // Withdraw
             leafIndex++;
             leafs[leafIndex] = ManageLeaf(
                 itbPositionManager,
                 false,
                 "withdraw(address,uint256)",
                 new address[](0),
                 string.concat("Withdraw ", tokensUsed[i].symbol(), " from the ", itbContractName, " contract"),
                 itbDecoderAndSanitizer
             );
             // WithdrawAll
             leafIndex++;
             leafs[leafIndex] = ManageLeaf(
                 itbPositionManager,
                 false,
                 "withdrawAll(address)",
                 new address[](0),
                 string.concat("Withdraw all ", tokensUsed[i].symbol(), " from the ", itbContractName, " contract"),
                 itbDecoderAndSanitizer
             );
         }

         for (uint256 i; i < additionalExecutors.length; ++i) {
             // AddExecutor
             leafIndex++;
             leafs[leafIndex] = ManageLeaf(
                 itbPositionManager,
                 false,
                 "addExecutor(address)",
                 new address[](1),
                 string.concat("Add executor to the ", itbContractName, " contract"),
                 itbDecoderAndSanitizer
             );
             leafs[leafIndex].argumentAddresses[0] = additionalExecutors[i];
         }
     }
}
