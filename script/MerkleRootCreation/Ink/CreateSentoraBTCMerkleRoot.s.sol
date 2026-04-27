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
 *  source .env && forge script script/MerkleRootCreation/Ink/CreateSentoraBTCMerkleRoot.s.sol --rpc-url $INK_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateSentoraBTCMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0x7Dee0120739b7ec048B469939EFB178ADbbB19B2;
    address public rawDataDecoderAndSanitizer = 0x8D2368E25f5076E31092e69026C6B5D0CE0A03dc;
    address public itbDecoderAndSanitizer = 0x51cDDE815429fb7Bce964601774018eA0Cc119f7;
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
        setSourceChainName(ink);
        setAddress(false, ink, "boringVault", boringVault);
        setAddress(false, ink, "managerAddress", managerAddress);
        setAddress(false, ink, "accountantAddress", accountantAddress);
        setAddress(false, ink, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](1);
        feeAssets[0] = getERC20(sourceChain, "KBTC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);
        
        // ========================== Aave V3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](1);
        supplyAssets[0] = getERC20(sourceChain, "KBTC");
        ERC20[] memory borrowAssets = new ERC20[](0);
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== Position Manager ==========================
        // KBTC Tydro
        {
            address kbtcTydroPositionManager = 0xBAd85E5F3a14b25C84422E3Acbd3b0aa3E8eEb00;
            ERC20[] memory kbtcTydroTokensUsed = new ERC20[](1);
            kbtcTydroTokensUsed[0] = getERC20(sourceChain, "KBTC");
            _addLeafsForITBPositionManagerLocal(leafs, kbtcTydroPositionManager, kbtcTydroTokensUsed, "Tydro KBTC ITB Position Manager");
        }
        
        // bridge KBTC to Mainnet via LayerZero
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "KBTC"),
            getAddress(sourceChain, "KBTC"),
            layerZeroMainnetEndpointId,
            getBytes32(sourceChain, "boringVault")
        );
        
        // bridge USDT to Mainnet via USDT0
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "USDT"),
            getAddress(sourceChain, "usdt0OFTAdapter"),
            layerZeroMainnetEndpointId,
            getBytes32(sourceChain, "boringVault")
        );

        // bridge USDC to Mainnet via CCTP
        _addCCTPBridgeLeafs(leafs, cctpMainnetDomainId);
       

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Ink/SentoraBTCStrategistLeafs.json";

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