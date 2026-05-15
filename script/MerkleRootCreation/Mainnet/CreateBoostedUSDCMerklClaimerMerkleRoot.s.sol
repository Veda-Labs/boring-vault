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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateBoostedUSDCMerklClaimerMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateBoostedUSDCMerklClaimerMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0xDbD87325D7b1189Dcc9255c4926076fF4a96A271;
    address public rawDataDecoderAndSanitizer = 0xB44B0976dBE7b958Ef451ab102d47452aB3cB29B;
    address public managerAddress = 0xEd23b12e7700BeB638562A22ED65f74291901c25;
    address public accountantAddress = 0x62A88Bea6fe527b5DEfAA103A3f8b5010205aF92;

    address public odosOwnedDecoderAndSanitizer = 0x6149c711434C54A48D757078EfbE0E2B2FE2cF6a;
    address public oneInchOwnedDecoderAndSanitizer = 0x42842201E199E6328ADBB98e7C2CbE77561FAC88;

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

        ManageLeaf[] memory leafs = new ManageLeaf[](2);

        // ========================== Merkl Claim ==========================
        _addMerklClaimLeaf(
            leafs, getAddress(sourceChain, "merklDistributor")
        );

        // ========================== Verify ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/BoostedUSDCMerklClaimerLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
