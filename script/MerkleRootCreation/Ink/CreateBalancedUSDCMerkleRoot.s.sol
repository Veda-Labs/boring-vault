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
 *  source .env && forge script script/MerkleRootCreation/Ink/CreateBalancedUSDCMerkleRoot.s.sol --rpc-url $INK_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateBalancedUSDCMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0xcaae49fb7f74cCFBE8A05E6104b01c097a78789f;
    address public rawDataDecoderAndSanitizer = 0x5901da9Ca757Bf6ce3e232024840D32e0bfbc692;
    address public managerAddress = 0xA0e501F98A1B5d3d8e6Ffd161c76f92570E42931;
    address public accountantAddress = 0x727929AF06Fa4f6E96cbC3fF7F4b60A65E168e23;

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

        string memory filePath = "./leafs/Ink/BalancedUSDCStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
