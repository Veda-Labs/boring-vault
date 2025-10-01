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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateEthenaRWAMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateEthenaRWAMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0x6fDcB0654B4814c2eC1E7e9dbC4cEBf1a2038a84;
    address public rawDataDecoderAndSanitizer = 0xc2fEe7F0dBDF0F1f2eAcBC2d393e12FBf268B070;
    address public managerAddress = 0x7fDB2E3a51E5379D80137EDE02066cB3a3362961;
    address public accountantAddress = 0x98d37cFCC869F8aB6111Acd23B1d78F6DD62A915;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateStrategistMerkleRoot();
    }

    function generateStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);

        _addEthenaMintingLeafs(leafs, 0x9BE81248787c5284D1180Cd84B5ad2473d7d92D8);
        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Mainnet/EthenaRWAMerkleRoot.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
