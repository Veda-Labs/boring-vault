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
 *  source .env && forge script script/MerkleRootCreation/Ink/CreateBoostedUSDCMerkleRoot.s.sol --rpc-url $INK_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateBoostedUSDCMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0xf52E683b521D38A319C1c4EbC73cF9a07781e181;
    address public rawDataDecoderAndSanitizer = ;
    address public managerAddress = 0xf2b2CC21BAA4f7641270634e860d1050B5b232a0;
    address public accountantAddress = 0xF525ef91438c2ba2cff6acF87a57Fa0FCaa4E06C;

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

        ManageLeaf[] memory leafs = new ManageLeaf[](128);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](2);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        feeAssets[1] = getERC20(sourceChain, "USDT");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        // ========================== NativeWrapper ==========================
        _addNativeLeafs(leafs);

        // ========================== Aave V3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](2);
        supplyAssets[0] = getERC20(sourceChain, "USDC");
        supplyAssets[1] = getERC20(sourceChain, "USDT");
        ERC20[] memory borrowAssets = new ERC20[](2);
        borrowAssets[0] = getERC20(sourceChain, "USDC");
        borrowAssets[1] = getERC20(sourceChain, "USDT");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "USDT"), getAddress(sourceChain, "usdt0OFTAdapter"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));

        // ========================== CCTP ==========================
        _addCCTPBridgeLeafs(leafs, cctpMainnetDomainId);

        // ========================== Verify ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Ink/BoostedUSDCStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}