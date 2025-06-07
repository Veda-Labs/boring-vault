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
 *  source .env && forge script script/MerkleRootCreation/Bob/CreateHybridBtcMerkleRoot.s.sol --rpc-url $BOB_RPC_URL
 */

contract CreateHybridBtcMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x9998e05030Aee3Af9AD3df35A34F5C51e1628779; 
    address public managerAddress = 0x2A1512a030D6eb71A5864968d795e1b6D382735D;
    address public accountantAddress = 0x22b025037ff1F6206F41b7b28968726bDBB5E7D5;
    address public rawDataDecoderAndSanitizer = 0x782fEe69B109419B9548BB5798CB4c1a2A43D00E; 

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateStrategistLeafs();
    }

    function generateStrategistLeafs() public {
        setSourceChainName(bob);
        setAddress(false, bob, "boringVault", boringVault);
        setAddress(false, bob, "managerAddress", managerAddress);
        setAddress(false, bob, "accountantAddress", accountantAddress);
        setAddress(false, bob, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);


        // ========================== Standard Bridge ==========================
        
        ERC20[] memory localTokens = new ERC20[](2);
        localTokens[0] = getERC20(sourceChain, "WBTC");
        localTokens[1] = getERC20(sourceChain, "LBTC");

        ERC20[] memory remoteTokens = new ERC20[](2);
        remoteTokens[0] = getERC20(mainnet, "WBTC");
        remoteTokens[1] = getERC20(mainnet, "LBTC");

        _addStandardBridgeLeafs(
            leafs,
            mainnet,
            address(0),
            address(0),
            getAddress(sourceChain, "standardBridge"),
            address(0),
            localTokens,
            remoteTokens
        );

        // ========================== Verify & Generate ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Bob/HybridBTCStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
