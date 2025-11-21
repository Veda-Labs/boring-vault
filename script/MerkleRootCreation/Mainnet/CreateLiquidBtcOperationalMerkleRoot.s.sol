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

contract CreateMultichainLiquidBtcOperationalMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x5f46d540b6eD704C3c8789105F30E075AA900726;
    address public rawDataDecoderAndSanitizer = 0x74522D571f80FF8024b176d710cD963002aC4278;
    address public managerAddress = 0xaFa8c08bedB2eC1bbEb64A7fFa44c604e7cca68d;
    address public accountantAddress = 0xEa23aC6D7D11f6b181d6B98174D334478ADAe6b0;
    address public itbPositionManager = 0x7AAf9539B7359470Def1920ca41b5AAA05C13726;
    address public itbPositionManager2 = 0x11Fd9E49c41738b7500748f7B94B4DBb0E8c13d2; // Spark LBTC (PYUSD) + Aave Core Euler PYUSD Supervised Loan
    address public itbDecoderAndSanitizer = 0xEEb53299Cb894968109dfa420D69f0C97c835211;

    function setUp() external {}

    function run() external {
        generateLiquidBtcOperationalStrategistMerkleRoot();
    }

    function generateLiquidBtcOperationalStrategistMerkleRoot() public {

        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](64);
        leafIndex = 0;

        // ========================== ODOS ==========================
        {
            address[] memory token0 = new address[](3);
            token0[0] = getAddress(sourceChain, "RLUSD");
            token0[1] = getAddress(sourceChain, "PYUSD");
            token0[2] = getAddress(sourceChain, "USDC");


            address[] memory token1 = new address[](3);
            token1[0] = getAddress(sourceChain, "USDC");
            token1[1] = getAddress(sourceChain, "USDC");
            token1[2] = getAddress(sourceChain, "WBTC");

            _addOdosOneWaySwapLeafs(leafs, token0[0], token1[0]);
            _addOdosOneWaySwapLeafs(leafs, token0[1], token1[1]);
            _addOdosOneWaySwapLeafs(leafs, token0[2], token1[2]);
        }

        {
            setAddress(true, mainnet, "rawDataDecoderAndSanitizer", itbDecoderAndSanitizer);
            ERC20[] memory itbTokensUsed = new ERC20[](1);
            itbTokensUsed[0] = getERC20(sourceChain, "WBTC");
            _addITBPositionManagerWithdrawals(leafs, itbPositionManager, itbTokensUsed, "ITB Position Manager");
            _addITBPositionManagerWithdrawals(leafs, itbPositionManager2, itbTokensUsed, "ITB Position Manager 2");
            setAddress(true, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        }

        // ========================== Verify ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        string memory filePath = "./leafs/Mainnet/LiquidBtcOperationalStrategistLeafs.json";
        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

     function _addITBPositionManagerWithdrawals(
         ManageLeaf[] memory leafs,
         address itbPositionManager,
         ERC20[] memory tokensUsed,
         string memory itbContractName
     ) internal {

         for (uint256 i; i < tokensUsed.length; ++i) {
             // Withdraw
             leafIndex++;
             leafs[leafIndex] = ManageLeaf(
                 itbPositionManager,
                 false,
                 "withdraw(address,uint256)",
                 new address[](0),
                 string.concat("Withdraw ", tokensUsed[i].symbol(), " from the ", itbContractName, " contract"),
                 getAddress(sourceChain, "rawDataDecoderAndSanitizer")
             );

             // WithdrawAll
             leafIndex++;
             leafs[leafIndex] = ManageLeaf(
                 itbPositionManager,
                 false,
                 "withdrawAll(address)",
                 new address[](0),
                 string.concat("Withdraw all ", tokensUsed[i].symbol(), " from the ", itbContractName, " contract"),
                 getAddress(sourceChain, "rawDataDecoderAndSanitizer")
             );
         }
     }
}
