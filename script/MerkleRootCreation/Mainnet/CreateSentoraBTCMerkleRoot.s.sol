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
    address public rawDataDecoderAndSanitizer = 0x8D2368E25f5076E31092e69026C6B5D0CE0A03dc;
    address public itbDecoderAndSanitizer = 0x2D7085602a85aFb417AE1dFcEc09C301FeC8Df36;
    address public managerAddress = 0x29AB989D159C44dCE28A722d36aE7E35b7dB9CFE;
    address public accountantAddress = 0x4Bb6C416a00561ad6657110b76552c42d55Ff1d6;

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

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        
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
            _addLeafsForITBPositionManagerLocal(leafs, pyusdMorphoPositionManager, pyusdMorphoTokensUsed, "Sentora PYUSD main V2 ITB Position Manager");
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
     }
}
