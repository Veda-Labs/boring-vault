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

// source .env && forge script script/MerkleRootCreation/Mainnet/CreateLiquidBtcOperationalMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL

contract CreateMultichainLiquidBtcOperationalMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x5f46d540b6eD704C3c8789105F30E075AA900726;
    address public rawDataDecoderAndSanitizer = 0x74522D571f80FF8024b176d710cD963002aC4278;
    address public managerAddress = 0xaFa8c08bedB2eC1bbEb64A7fFa44c604e7cca68d;
    address public accountantAddress = 0xEa23aC6D7D11f6b181d6B98174D334478ADAe6b0;
    address public itbPositionManager = 0x7AAf9539B7359470Def1920ca41b5AAA05C13726;
    address public itbPositionManager2 = 0x11Fd9E49c41738b7500748f7B94B4DBb0E8c13d2; // Spark LBTC (PYUSD) + Aave Core Euler PYUSD Supervised Loan
    address public capDecoderAndSanitizer = 0xE0e86bf98dAA0D2b408Cb038E94bCB9B7864309C;
    address public itbDecoderAndSanitizer = 0xEEb53299Cb894968109dfa420D69f0C97c835211;

    //one offs
    address public odosOwnedDecoderAndSanitizer = 0x6149c711434C54A48D757078EfbE0E2B2FE2cF6a;

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

        // ========================== Teller ==========================
        {
            ERC20[] memory eBTCTellerAssets = new ERC20[](3);
            eBTCTellerAssets[0] = getERC20(sourceChain, "WBTC");
            eBTCTellerAssets[1] = getERC20(sourceChain, "LBTC");
            eBTCTellerAssets[2] = getERC20(sourceChain, "cbBTC");
            _addTellerLeafs(leafs, getAddress(sourceChain, "eBTCTeller"), eBTCTellerAssets, false, true);
        }

        // ========================== ITB =============================
        {
            setAddress(true, mainnet, "rawDataDecoderAndSanitizer", itbDecoderAndSanitizer);
            ERC20[] memory itbTokensUsed = new ERC20[](1);
            itbTokensUsed[0] = getERC20(sourceChain, "WBTC");
            _addITBPositionManagerWithdrawals(leafs, itbPositionManager, itbTokensUsed, "ITB Position Manager");
            _addITBPositionManagerWithdrawals(leafs, itbPositionManager2, itbTokensUsed, "ITB Position Manager 2");
            setAddress(true, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        }

        // ========================== Aave ===========================
        {
            ERC20[] memory assets = new ERC20[](5);
            assets[0] = getERC20(sourceChain, "WBTC");
            assets[1] = getERC20(sourceChain, "EBTC");
            assets[2] = getERC20(sourceChain, "LBTC");
            assets[3] = getERC20(sourceChain, "USDT");
            assets[4] = getERC20(sourceChain, "USDC");
            _addAaveV3EOALeafs("Aave V3", getAddress(sourceChain, "v3Pool"), leafs, assets);
        }

        // ========================== CAP ==========================
        {
            setAddress(true, mainnet, "rawDataDecoderAndSanitizer", capDecoderAndSanitizer);
            address[] memory capDepositAssets = new address[](2);
            capDepositAssets[0] = getAddress(sourceChain, "USDT");
            capDepositAssets[1] = getAddress(sourceChain, "USDC");
            _addCapWithdrawLeafs(leafs, capDepositAssets);
            setAddress(true, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        }

        // =================== Ether.fi  Swapper ====================
        {
            setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", odosOwnedDecoderAndSanitizer);
            // USDT
            _addEtherfiOneWaySwapperLeafs(leafs, getAddress(sourceChain, "USDT"), getAddress(sourceChain, "USDC"));
            _addEtherfiOneWaySwapperLeafs(leafs, getAddress(sourceChain, "USDT"), getAddress(sourceChain, "PYUSD"));
            _addEtherfiOneWaySwapperLeafs(leafs, getAddress(sourceChain, "USDT"), getAddress(sourceChain, "RLUSD"));
            // USDC
            _addEtherfiOneWaySwapperLeafs(leafs, getAddress(sourceChain, "USDC"), getAddress(sourceChain, "USDT"));
            _addEtherfiOneWaySwapperLeafs(leafs, getAddress(sourceChain, "USDC"), getAddress(sourceChain, "PYUSD"));
            _addEtherfiOneWaySwapperLeafs(leafs, getAddress(sourceChain, "USDC"), getAddress(sourceChain, "RLUSD"));
            // PYUSD
            _addEtherfiOneWaySwapperLeafs(leafs, getAddress(sourceChain, "PYUSD"), getAddress(sourceChain, "USDC"));
            _addEtherfiOneWaySwapperLeafs(leafs, getAddress(sourceChain, "PYUSD"), getAddress(sourceChain, "USDT"));
            _addEtherfiOneWaySwapperLeafs(leafs, getAddress(sourceChain, "PYUSD"), getAddress(sourceChain, "RLUSD"));
            // RLUSD
            _addEtherfiOneWaySwapperLeafs(leafs, getAddress(sourceChain, "RLUSD"), getAddress(sourceChain, "USDC"));
            _addEtherfiOneWaySwapperLeafs(leafs, getAddress(sourceChain, "RLUSD"), getAddress(sourceChain, "USDT"));
            _addEtherfiOneWaySwapperLeafs(leafs, getAddress(sourceChain, "RLUSD"), getAddress(sourceChain, "PYUSD"));
            setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        }


        // ========================== Fee Claiming ===========================
        {
            ERC20[] memory feeAssets = new ERC20[](3);
            feeAssets[0] = getERC20(sourceChain, "WBTC");
            feeAssets[1] = getERC20(sourceChain, "LBTC");
            feeAssets[2] = getERC20(sourceChain, "cbBTC");
            _addLeafsForFeeClaiming(
                leafs,
                getAddress(sourceChain, "accountantAddress"),
                feeAssets,
                false
            );
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
