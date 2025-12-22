// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { FixedPointMathLib } from "@solmate/utils/FixedPointMathLib.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { Strings } from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import { ERC4626 } from "@solmate/tokens/ERC4626.sol";
import { ManagerWithMerkleVerification } from "src/base/Roles/ManagerWithMerkleVerification.sol";
import { MerkleTreeHelper } from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Sonic/CreateSonicETHMerkleRoot.s.sol:CreateSonicETHMerkleRoot --rpc-url $SONIC_MAINNET_RPC_URL
 */
contract CreateSonicETHMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x3bcE5CB273F0F148010BbEa2470e7b5df84C7812;
    address public managerAddress = 0x6830046d872604E92f9F95F225fF63f2300bc1e9;
    address public accountantAddress = 0x3a592F9Ea2463379c4154d03461A73c484993668;
    address public rawDataDecoderAndSanitizer = 0x053a492062317086D643fa33A3323206Da9FF64D;

    function setUp() external { }

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(sonicMainnet);
        setAddress(false, sonicMainnet, "boringVault", boringVault);
        setAddress(false, sonicMainnet, "managerAddress", managerAddress);
        setAddress(false, sonicMainnet, "accountantAddress", accountantAddress);
        setAddress(false, sonicMainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](128);

        // ========================== SonicGateway ==========================
        address[] memory mainnetAssets = new address[](1);
        address[] memory sonicAssets = new address[](1);
        mainnetAssets[0] = getAddress(mainnet, "WETH"); //NOTE: this needs to be mainnet WETH
        sonicAssets[0] = getAddress(sonicMainnet, "WETH");
        _addSonicGatewayLeafsSonic(leafs, mainnetAssets, sonicAssets);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](1);
        feeAssets[0] = getERC20(sourceChain, "WETH");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, true); //add yield claiming

        // ========================== AaveV3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](1);
        supplyAssets[0] = getERC20(sourceChain, "WETH");
        ERC20[] memory borrowAssets = new ERC20[](0);
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== SiloV2 ==========================
        _addSiloV2Leafs(leafs, getAddress(sourceChain, "silo_S_ETH_config"));
        _addSiloV2Leafs(leafs, getAddress(sourceChain, "silo_ETH_wstkscETH_config"));

        // ========================== Verify ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Sonic/SonicETHStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
