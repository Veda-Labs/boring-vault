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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateCapBTCvMerkleRoot.s.sol:CreateCapBTCvMerkleRootScript --rpc-url $MAINNET_RPC_URL
 */
contract CreateCapBTCvMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xE26c57F9C23F2F385BdB98886EC4E598f7F5a44c;
    address public managerAddress = 0x001ca40a376cF779AcdA318fa0Df504a95F0C4be;
    address public accountantAddress = 0x157aD71dB4696f0a53B8b82fc4F9Ba479c9aD21E;
    address public rawDataDecoderAndSanitizer = 0x6E1fB5711C3A9a2b2f0c810Ff9541452eE0CEc3c;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        // ========================== Symbiotic Vault ==========================
        address[] memory vaults = new address[](1);
        vaults[0] = getAddress(sourceChain, "CapSymbiotic");
        ERC20[] memory vault_assets = new ERC20[](1);
        vault_assets[0] = ERC20(getAddress(sourceChain, "LBTC"));

        address[] memory rewards = new address[](0);
        _addSymbioticVaultLeafs(leafs, vaults, vault_assets, rewards);

        // ========================== BTCb ==========================
        _addBTCbLeafs(leafs);

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/CapBTCvStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
