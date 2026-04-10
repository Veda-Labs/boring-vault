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
 *  source .env && forge script script/MerkleRootCreation/Optimism/CreateEtherFiBTCMerkleRoot.s.sol --rpc-url $OPTIMISM_RPC_URL
 */
contract CreateEtherFiBTCMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x657e8C867D8B37dCC18fA4Caead9C45EB088C642;
    address public managerAddress = 0x382d0106F308864D5462332D9D3bB54a60384B70;
    address public accountantAddress = 0x1b293DC39F94157fA0D1D36d7e0090C8B8B8c13F;
    address public rawDataDecoderAndSanitizer = 0x58D28BB88400b889C4a1b754d930a743323F5Ada;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(optimism);
        setAddress(false, optimism, "boringVault", boringVault);
        setAddress(false, optimism, "managerAddress", managerAddress);
        setAddress(false, optimism, "accountantAddress", accountantAddress);
        setAddress(false, optimism, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);


        // ========================== Standard Bridge ==========================
        ERC20[] memory localTokens = new ERC20[](1);
        localTokens[0] = getERC20(sourceChain, "WBTC");

        ERC20[] memory remoteTokens = new ERC20[](1);
        remoteTokens[0] = getERC20(mainnet, "WBTC");

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


        // ========================== Verify ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Optimism/EtherFiBTCStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

    }
}

