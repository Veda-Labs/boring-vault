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
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Scroll/CreateStakedEthFiMerkleRoot.s.sol --rpc-url $SCROLL_RPC_URL
 */
contract CreateStakedEthFiMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x86B5780b606940Eb59A062aA85a07959518c0161;
    address public managerAddress = 0x66aae0ee1f68c658401c7d8D6E417202A99545d7;
    address public accountantAddress = 0x05A1552c5e18F5A0BB9571b5F2D6a4765ebdA32b;
    address public rawDataDecoderAndSanitizer = 0xf6cF44791ee924597f8D1EFf98562435aFae29B8;


    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateStakedEthfiStrategistMerkleRoot();
    }

    function generateStakedEthfiStrategistMerkleRoot() public {
        setSourceChainName(scroll);
        setAddress(false, scroll, "boringVault", boringVault);
        setAddress(false, scroll, "managerAddress", managerAddress);
        setAddress(false, scroll, "accountantAddress", accountantAddress);
        setAddress(false, scroll, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);

        // // ========================== Layerzero ==========================
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "ETHFI"),
            getAddress(sourceChain, "ETHFIOFTAdapter"),
            layerZeroMainnetEndpointId,
            getBytes32(sourceChain, "boringVault")
        );

        // ========================== Verify ==========================
        
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Scroll/StakedETHFIStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
