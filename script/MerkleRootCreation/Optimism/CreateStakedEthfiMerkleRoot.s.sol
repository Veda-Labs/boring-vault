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
 *  source .env && forge script script/MerkleRootCreation/Optimism/CreateStakedEthfiMerkleRoot.s.sol --rpc-url $OPTIMISM_RPC_URL
 */
contract CreateStakedEthfiMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x86B5780b606940Eb59A062aA85a07959518c0161;
    address public managerAddress = 0x66aae0ee1f68c658401c7d8D6E417202A99545d7;
    address public accountantAddress = 0x05A1552c5e18F5A0BB9571b5F2D6a4765ebdA32b;
    address public rawDataDecoderAndSanitizer = 0x58D28BB88400b889C4a1b754d930a743323F5Ada;


    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateStakedEthfiStrategistMerkleRoot();
    }

    function generateStakedEthfiStrategistMerkleRoot() public {
        setSourceChainName(optimism);
        setAddress(false, optimism, "boringVault", boringVault);
        setAddress(false, optimism, "managerAddress", managerAddress);
        setAddress(false, optimism, "accountantAddress", accountantAddress);
        setAddress(false, optimism, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);

        // // ========================== Layerzero ==========================
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "ETHFI"),
            getAddress(sourceChain, "ETHFI"),
            layerZeroMainnetEndpointId,
            getBytes32(sourceChain, "boringVault")
        );

        // ========================== Verify ==========================
        
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);
        
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Optimism/StakedETHFIStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
