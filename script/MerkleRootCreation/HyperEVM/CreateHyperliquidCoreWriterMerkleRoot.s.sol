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
 *  source .env && forge script script/MerkleRootCreation/HyperEVM/CreateHyperliquidCoreWriterMerkleRoot.s.sol --rpc-url $HYPER_EVM_RPC_URL
 */
contract CreateHyperliquidCoreWriterMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    // ========================== HyperCore Tester Vault Addresses ==========================
    address public boringVault = 0xDBb925377aA9d66c1a7E33282932c3A8F264B876;
    address public managerAddress = 0x95271861969755d700a2aF8A71E10f0F1FF95ECC;
    address public accountantAddress = 0x71D7aC5a462bE93f2D4Bd53ABD18750C1bD9e5A5;
    // TODO: Update with actual deployed decoder address before generating final merkle root
    address public rawDataDecoderAndSanitizer = 0x351C889cA39Af07101bFA22eAb6C47c3C7d8a725;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateHyperliquidCoreWriterMerkleRoot();
    }

    function generateHyperliquidCoreWriterMerkleRoot() public {
        setSourceChainName(hyperEVM);
        setAddress(false, hyperEVM, "boringVault", boringVault);
        setAddress(false, hyperEVM, "managerAddress", managerAddress);
        setAddress(false, hyperEVM, "accountantAddress", accountantAddress);
        setAddress(false, hyperEVM, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](512);

        // ========================== Define Allowed Perp Assets ==========================
        // BTC=0, ETH=1 (see HyperliquidAssetIds.sol for full list)
        uint32[] memory perpAssets = new uint32[](4);
        perpAssets[0] = 0; // BTC
        perpAssets[1] = 1; // ETH
        perpAssets[2] = 159; // Hype (perp)
        perpAssets[3] = 10107;// hype spot

        // ========================== Define Allowed Recipients ==========================
        address[] memory spotSendRecipients = new address[](1);
        spotSendRecipients[0] = boringVault; // Allow sending back to self

        // ========================== Define Allowed Spot Tokens ==========================
        // USDC=0, UBTC=197, UETH=221 (for spot sends on HyperCore)
        uint64[] memory spotTokens = new uint64[](5);
        spotTokens[0] = 0;   // USDC
        spotTokens[1] = 197; // UBTC
        spotTokens[2] = 221; // UETH
        spotTokens[3] = 150; // HYPE
        spotTokens[4] = 107; // HYPE

        // ========================== Define Allowed Vaults ==========================
        address[] memory vaults = new address[](0); // No vault transfers by default

        // ========================== Define Allowed Validators ==========================
        address[] memory validators = new address[](0); // No staking by default

        // ========================== CoreWriter Leafs ==========================
        _addAllCoreWriterLeafs(
            leafs,
            perpAssets,
            spotSendRecipients,
            spotTokens,
            vaults,
            validators
        );

        // ========================== USDC Bridging (HyperEVM -> HyperCore) ==========================
        // Bridge native USDC from HyperEVM to HyperCore via CoreDepositWallet
        _addCoreWriterUsdcDepositLeafs(leafs);

        // ========================== Token Bridging (HyperCore -> HyperEVM) ==========================
        // Allow bridging tokens back from HyperCore to the vault on HyperEVM
        address[] memory bridgeDestinations = new address[](1);
        bridgeDestinations[0] = boringVault;
        address[] memory bridgeSubAccounts = new address[](1);
        bridgeSubAccounts[0] = address(0); // Main account
        _addCoreWriterSendAssetLeafs(leafs, bridgeDestinations, bridgeSubAccounts);

        // ========================== Add API Wallets ==============================

        address[] memory apiWallets = new address[](2);
        apiWallets[0] = 0x996213ed4099707059b8b5d7489ffF23dAC9770d;
        apiWallets[1] = 0x60084013A39eeE05c71Efca92F7BA47884a98EDA;
        _addCoreWriterAddApiWalletLeafs(leafs, apiWallets);

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/HyperEVM/HyperliquidCoreWriterLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
