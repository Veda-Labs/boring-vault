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
 *  source .env && forge script script/MerkleRootCreation/Monad/CreateTestMusdMerkleRoot.s.sol --rpc-url $MONAD_RPC_URL
 */
contract CreateTestMusdMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xb4563bcD3B7764CCBf497f515585f70B6C3EA5Ae;
    address public managerAddress = 0xF1645565052f14c1A5e0b05aA5020501F2e445A1;
    address public accountantAddress = 0x7382c5b8B51B8C4f127B3123C1039581BAA5A06B;
    address public rawDataDecoderAndSanitizer = 0x676b46C6E1cb6a33399036335D5518F682681d4A;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(monad);
        setAddress(false, monad, "boringVault", boringVault);
        setAddress(false, monad, "managerAddress", managerAddress);
        setAddress(false, monad, "accountantAddress", accountantAddress);
        setAddress(false, monad, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);

        // ========================== Steakhouse ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "steakhouseMUSDVault")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "steakhouseUSDCVault")));

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Monad/TestMusdMerkleRoot.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
