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

    // ========================== Configuration ==========================
    // Update these addresses for your deployment
    address public boringVault = address(0); // TODO: Set your boring vault address
    address public rawDataDecoderAndSanitizer = address(0); // TODO: Set your decoder address
    address public managerAddress = address(0); // TODO: Set your manager address
    address public accountantAddress = address(0); // TODO: Set your accountant address

    // CoreWriter system contract on HyperEVM
    address public constant CORE_WRITER = 0x3333333333333333333333333333333333333333;
    address public constant HYPE_BRIDGE = 0x2222222222222222222222222222222222222222;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateHyperliquidStrategistMerkleRoot();
    }

    function generateHyperliquidStrategistMerkleRoot() public {
        setSourceChainName(hyperEVM);
        setAddress(false, hyperEVM, "boringVault", boringVault);
        setAddress(false, hyperEVM, "managerAddress", managerAddress);
        setAddress(false, hyperEVM, "accountantAddress", accountantAddress);
        setAddress(false, hyperEVM, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, hyperEVM, "coreWriter", CORE_WRITER);
        setAddress(false, hyperEVM, "hypeBridge", HYPE_BRIDGE);

        ManageLeaf[] memory leafs = new ManageLeaf[](512);

        // ========================== Define Allowed Perp Assets ==========================
        // See HyperliquidAssetIds.sol for full list
        // Common perps: BTC=0, ETH=1, SOL=5, HYPE=163
        uint32[] memory perpAssets = new uint32[](4);
        perpAssets[0] = 0;   // BTC
        perpAssets[1] = 1;   // ETH
        perpAssets[2] = 5;   // SOL
        perpAssets[3] = 163; // HYPE

        // ========================== Define Allowed Recipients ==========================
        address[] memory spotSendRecipients = new address[](1);
        spotSendRecipients[0] = boringVault; // Allow sending back to self

        // ========================== Define Allowed Spot Tokens ==========================
        // See HyperliquidAssetIds.sol for full list
        // Common spot tokens: USDC=0, HYPE=122
        uint64[] memory spotTokens = new uint64[](2);
        spotTokens[0] = 0;   // USDC
        spotTokens[1] = 122; // HYPE

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

        // ========================== Fee Claiming ==========================
        // Add fee claiming if needed
        // ERC20[] memory feeAssets = new ERC20[](1);
        // feeAssets[0] = getERC20(sourceChain, "USDC");
        // _addLeafsForFeeClaiming(leafs, accountantAddress, feeAssets, false);

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/HyperEVM/HyperliquidCoreWriterStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
