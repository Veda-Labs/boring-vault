// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Sonic/CreateSonicBTCMerkleRoot.s.sol:CreateSonicBTCMerkleRoot --rpc-url $SONIC_MAINNET_RPC_URL
 */
contract CreateSonicBTCMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xBb30e76d9Bb2CC9631F7fC5Eb8e87B5Aff32bFbd;
    address public managerAddress = 0x5dA93667DCc58b71726aFC595f116A6F166F9aeD; 
    address public accountantAddress = 0xC1a2C650D2DcC8EAb3D8942477De71be52318Acb;
    address public rawDataDecoderAndSanitizer = 0xE9527EA95a383993b41EA7D3b0E50DDA7B13dE94; 

    function setUp() external {}

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

        ManageLeaf[] memory leafs = new ManageLeaf[](16);

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "WBTC"), getAddress(sourceChain, "WBTC"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault")
        ); 
        
        // ========================== CCIP ==========================
        bytes32 toChain = 0x0000000000000000000000000000000000000000000000000000000000000001; //mainnet
        _addLBTCBridgeLeafs(leafs, toChain);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](3);
        feeAssets[0] = getERC20(sourceChain, "LBTC");
        feeAssets[1] = getERC20(sourceChain, "WBTC");
        feeAssets[2] = getERC20(sourceChain, "EBTC");

        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, true); //add yield claiming

        // ========================== Verify  ==========================
        
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Sonic/SonicBTCStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
