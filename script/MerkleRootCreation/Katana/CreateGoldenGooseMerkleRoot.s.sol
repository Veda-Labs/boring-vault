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
 *  source .env && forge script script/MerkleRootCreation/Katana/CreateGoldenGooseMerkleRoot.s.sol --rpc-url $KATANA_RPC_URL
 */
contract CreateGoldenGooseMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xef417FCE1883c6653E7dC6AF7c6F85CCDE84Aa09;
    address public managerAddress = 0x5F341B1cf8C5949d6bE144A725c22383a5D3880B;
    address public accountantAddress = 0xc873F2b7b3BA0a7faA2B56e210E3B965f2b618f5;
    address public rawDataDecoderAndSanitizer = 0x1E139A5B693bD97A489a0a492A85887499123868;
    //address public goldenGooseTeller = 0xE89fAaf3968ACa5dCB054D4a9287E54aa84F67e9;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateMerkleRoot();
    }

    function generateMerkleRoot() public {
        setSourceChainName(katana);
        setAddress(false, katana, "boringVault", boringVault);
        setAddress(false, katana, "managerAddress", managerAddress);
        setAddress(false, katana, "accountantAddress", accountantAddress);
        setAddress(false, katana, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);

        // ========================== Native Wrapping ==========================
        _addNativeLeafs(leafs);

        // ========================== Agglayer ==========================
        _addAgglayerTokenLeafs(
            leafs, getAddress(sourceChain, "agglayerBridgeKatana"), getAddress(sourceChain, "vbETH"), 20, 0
        );
        _addAgglayerTokenLeafs(
            leafs, getAddress(sourceChain, "agglayerBridgeKatana"), getAddress(sourceChain, "WSTETH"), 20, 0
        );

        // ========================== Yearn ==========================
        _addYearnLeafs(leafs, ERC4626(getAddress(sourceChain, "yvbWETH")));
        _addYearnLeafs(leafs, ERC4626(getAddress(sourceChain, "yvWSTETH")));

        // ========================== Verify & Generate ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Katana/GoldenGooseStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
