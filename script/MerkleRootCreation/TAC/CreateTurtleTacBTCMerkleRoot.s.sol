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
 *  source .env && forge script script/MerkleRootCreation/TAC/CreateTurtleTacBTCMerkleRoot.s.sol --rpc-url $TAC_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateTurtleTacBTCMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0x6Bf340dB729d82af1F6443A0Ea0d79647b1c3DDf;
    address public rawDataDecoderAndSanitizer = 0x9Bc20d0F13E68FAD5f4eE5Dda58c391b342e65a5; 
    address public managerAddress = 0x85A8821a579736e7E5e98296D34C50B77122BB5e; 
    address public accountantAddress = 0xe4858a89d5602Ad30de2018C408d33d101F53d53; 
    

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateStrategistMerkleRoot();
    }

    function generateStrategistMerkleRoot() public {
        setSourceChainName(tac);
        setAddress(false, tac, "boringVault", boringVault);
        setAddress(false, tac, "managerAddress", managerAddress);
        setAddress(false, tac, "accountantAddress", accountantAddress);
        setAddress(false, tac, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "cbBTC"), getAddress(sourceChain, "cbBTC"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/TAC/TurtleTacBTCStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

    }

}
