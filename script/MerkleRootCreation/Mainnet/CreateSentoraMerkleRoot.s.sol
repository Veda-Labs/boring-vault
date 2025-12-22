// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { FixedPointMathLib } from "@solmate/utils/FixedPointMathLib.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { Strings } from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import { ERC4626 } from "@solmate/tokens/ERC4626.sol";
import { MerkleTreeHelper } from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateSentoraMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */
contract CreateSentoraMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x13Cc1b39cb259BA10cd174EAe42012e698ed7c51;
    address public managerAddress = 0xdd5C7C5206558e4eA66a58592fEaE13424ED6F07;
    address public accountantAddress = 0x42135D908efa4E6aFd7E9B73D5A1bA55955F93fA;
    address public rawDataDecoderAndSanitizer = 0xBf6199F596D7296875Faa175Ed02Dc3940C1682E;

    function setUp() external { }

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

        // ========================== Odos/1inch ==========================
        address[] memory assets = new address[](2);
        assets[0] = getAddress(sourceChain, "LBTC");
        assets[1] = getAddress(sourceChain, "WBTC");
        SwapKind[] memory kind = new SwapKind[](2);
        kind[0] = SwapKind.BuyAndSell;
        kind[1] = SwapKind.BuyAndSell;
        _addOdosSwapLeafs(leafs, assets, kind);
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== ITB Position Manager ==========================
        ERC20[] memory itbTokensUsed = new ERC20[](1);
        itbTokensUsed[0] = getERC20(sourceChain, "LBTC");
        address itbPositionManager = 0x701D7Fc25577602dc77280108a8cef0B72b8F8A7;
        _addLeafsForITBPositionManager(leafs, itbPositionManager, itbTokensUsed, "LBTC > USDC > RLUSD Supervised Loan");
        itbPositionManager = 0x9B6a57Fda106eff13ffE4ea4Ef2783C547f75cd7;
        _addLeafsForITBPositionManager(leafs, itbPositionManager, itbTokensUsed, "LBTC > RLUSD > RLUSD Supervised Loan");
        itbPositionManager = 0x284D3b0eF51F0A6432948A9cCbCb5cAF30d6EE96;
        _addLeafsForITBPositionManager(leafs, itbPositionManager, itbTokensUsed, "LBTC > PYUSD > RLUSD Supervised Loan");

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Mainnet/SentoraStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function _addLeafsForITBPositionManager(
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
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );

        // Withdraw
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "withdraw(address,uint256)",
            new address[](0),
            string.concat("Withdraw from the ", itbContractName, " contract"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
        );
        // WithdrawAll
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "withdrawAll(address)",
            new address[](0),
            string.concat("Withdraw all from the ", itbContractName, " contract"),
            getAddress(sourceChain, "rawDataDecoderAndSanitizer")
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
                getAddress(sourceChain, "rawDataDecoderAndSanitizer")
            );
            leafs[leafIndex].argumentAddresses[0] = itbPositionManager;
        }
    }
}
