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
 *  source .env && forge script script/MerkleRootCreation/Test/CreateTestSwapperMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateTestSwapperMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0xC395ef909560FFAe6c3A6e5bf05827FDb1c34f9c;
    address public rawDataDecoderAndSanitizer = 0x69e987E905B61BdEcBEFe215E5D7AE5b7011e183; 
    address public managerAddress = 0xc69bd430B6C40Da716B6DABF4BBB48EeBBcCa2a1;
    address public accountantAddress = 0xb388b9A995f80AD454fD93A0C057Aaf297A35C4d;
    

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

        ManageLeaf[] memory leafs = new ManageLeaf[](32);

        // ========================== Swapper ==========================
        address swapper = 0xaBB0d47aFc22810038B1895b738bB77115Ca306f;
        address[][] memory pairs = new address[][](2);
        pairs[0] = new address[](2);
        pairs[0][0] = getAddress(sourceChain, "WETH");
        pairs[0][1] = getAddress(sourceChain, "USDC");

        pairs[1] = new address[](2);
        pairs[1][0] = getAddress(sourceChain, "mUSD");
        pairs[1][1] = getAddress(sourceChain, "USDC");

        SwapKind[] memory kind = new SwapKind[](2);
        kind[0] = SwapKind.BuyAndSell;
        kind[1] = SwapKind.BuyAndSell;

        _addBoringSwapperLeafs(leafs, swapper, pairs, kind);

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Mainnet/TestSwapperMerkleRoot.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

    }

}
