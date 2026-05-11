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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateSentoraBTCMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateSentoraBTCMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0x7Dee0120739b7ec048B469939EFB178ADbbB19B2;
    address public rawDataDecoderAndSanitizer = 0x6AbBF63aCe627106190ca7845e5609e6AD6eB357;
    address public itbDecoderAndSanitizer = 0x2D7085602a85aFb417AE1dFcEc09C301FeC8Df36;
    address public managerAddress = 0x29AB989D159C44dCE28A722d36aE7E35b7dB9CFE;
    address public accountantAddress = 0x4Bb6C416a00561ad6657110b76552c42d55Ff1d6;

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

        ManageLeaf[] memory leafs = new ManageLeaf[](64);
        
        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](1);
        feeAssets[0] = getERC20(sourceChain, "KBTC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);
        
        // ========================== LayerZero ==========================
        // bridge USDT to Ink via USDT0
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "USDT"),
            getAddress(sourceChain, "usdt0OFTAdapter"),
            layerZeroInkEndpointId,
            getBytes32(sourceChain, "boringVault")
        );
        
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "KBTC"),
            getAddress(sourceChain, "KBTC"),
            layerZeroInkEndpointId,
            getBytes32(sourceChain, "boringVault")
        );

        // bridge USDC to Ink via CCTP
        _addCCTPBridgeLeafs(leafs, cctpInkDomainId);

        // ========================== Position Manager ==========================
        // Supplies kBTC on Morpho, borrows PYUSD, Supplies PYUSD
        {
            address pyusdMorphoPositionManager = 0xAd50F5a15F5a3Bc9DAa934915586D9b8889294AC;
            ERC20[] memory pyusdMorphoTokensUsed = new ERC20[](3);
            pyusdMorphoTokensUsed[0] = getERC20(sourceChain, "KBTC");
            pyusdMorphoTokensUsed[1] = getERC20(sourceChain, "PYUSD");
            pyusdMorphoTokensUsed[2] = getERC20(sourceChain, "MORPHO");
            _addLeafsForITBPositionManagerLocal(leafs, pyusdMorphoPositionManager, pyusdMorphoTokensUsed, "Sentora PYUSD main V2 KBTC ITB Position Manager");
        }

        // Supplies wBTC on Morpho, borrows PYUSD, supplies PYUSD
        {
            address pyusdMorphoPositionManager = 0x834957eb674eFB12f2F70fceA7A9De5AB114D4B1;
            ERC20[] memory pyusdMorphoTokensUsed = new ERC20[](3);
            pyusdMorphoTokensUsed[0] = getERC20(sourceChain, "WBTC");
            pyusdMorphoTokensUsed[1] = getERC20(sourceChain, "PYUSD");
            pyusdMorphoTokensUsed[2] = getERC20(sourceChain, "MORPHO");
            _addLeafsForITBPositionManagerLocal(leafs, pyusdMorphoPositionManager, pyusdMorphoTokensUsed, "Sentora PYUSD main V2 WBTC ITB Position Manager");
        }

        // Supplies wBTC on Morpho, borrows RLUSD, supplies RLUSD
        {
            address pyusdMorphoPositionManager = 0x817c40CFE1BB06fADbc96b3Ce3DbDc517D2b5dCE;
            ERC20[] memory pyusdMorphoTokensUsed = new ERC20[](3);
            pyusdMorphoTokensUsed[0] = getERC20(sourceChain, "WBTC");
            pyusdMorphoTokensUsed[1] = getERC20(sourceChain, "RLUSD");
            pyusdMorphoTokensUsed[2] = getERC20(sourceChain, "MORPHO");
            _addLeafsForITBPositionManagerLocal(leafs, pyusdMorphoPositionManager, pyusdMorphoTokensUsed, "Sentora RLUSD main V2 WBTC ITB Position Manager");
        }

        // ========================== 1inch ==========================
        {
            address[] memory assets = new address[](6);
            SwapKind[] memory kind = new SwapKind[](6);
            assets[0] = getAddress(sourceChain, "KBTC");
            kind[0] = SwapKind.BuyAndSell;
            assets[1] = getAddress(sourceChain, "WBTC");
            kind[1] = SwapKind.BuyAndSell;
            assets[2] = getAddress(sourceChain, "PRIME");
            kind[2] = SwapKind.BuyAndSell;
            assets[3] = getAddress(sourceChain, "PYUSD");
            kind[3] = SwapKind.BuyAndSell;
            assets[4] = getAddress(sourceChain, "RLUSD");
            kind[4] = SwapKind.BuyAndSell;
            assets[5] = getAddress(sourceChain, "MORPHO");
            kind[5] = SwapKind.Sell;

            setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", oneInchOwnedDecoderAndSanitizer);
            _addLeafsFor1InchOwnedGeneralSwapping(leafs, assets, kind);
            setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        }

        // ========================== Uniswap V3 ==========================
        // WBTC/KBTC pair
        // Pool address: 0x64869c8D4B7C5a6A2F102C9FceeA7f7De846B672
        {
            address[] memory token0 = new address[](1);
            token0[0] = getAddress(sourceChain, "WBTC");

            address[] memory token1 = new address[](1);
            token1[0] = getAddress(sourceChain, "KBTC");

            _addUniswapV3Leafs(leafs, token0, token1, true, true); // swap only, swapRouter02
        }
        
        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Mainnet/SentoraBTCStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function _addLeafsForITBPositionManagerLocal(
         ManageLeaf[] memory leafs,
         address itbPositionManager,
         ERC20[] memory tokensUsed,
         string memory itbContractName
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

         // Withdraw
         leafIndex++;
         leafs[leafIndex] = ManageLeaf(
             itbPositionManager,
             false,
             "withdraw(address,uint256)",
             new address[](0),
             string.concat("Withdraw from the ", itbContractName, " contract"),
             itbDecoderAndSanitizer
         );
         // WithdrawAll
         leafIndex++;
         leafs[leafIndex] = ManageLeaf(
             itbPositionManager,
             false,
             "withdrawAll(address)",
             new address[](0),
             string.concat("Withdraw all from the ", itbContractName, " contract"),
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
         }
     }
}
