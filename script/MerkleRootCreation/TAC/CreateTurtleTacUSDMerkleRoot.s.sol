// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { FixedPointMathLib } from "@solmate/utils/FixedPointMathLib.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { Strings } from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import { ERC4626 } from "@solmate/tokens/ERC4626.sol";
import { MerkleTreeHelper } from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/TAC/CreateTurtleTacUSDMerkleRoot.s.sol --rpc-url $TAC_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateTurtleTacUSDMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0x699e04F98dE2Fc395a7dcBf36B48EC837A976490;
    address public rawDataDecoderAndSanitizer = 0x5ebE12dE67970a6d3DD70d23f90EbBA4dD38726A;
    address public managerAddress = 0x2FA91E4eb6Ace724EfFbDD61bBC1B55EF8bD7aAc;
    address public accountantAddress = 0x58cD5e97ffaeA62986C86ac44bB8EF7092c7ff5B;

    function setUp() external { }

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateStrategistMerkleRoot();
    }

    function generateStrategistMerkleRoot() public {
        setSourceChainName(tac);
        setAddress(false, tac, "boringVault", boringVault);
        setAddress(false, tac, "managerAddress", managerAddress);
        setAddress(false, tac, "accountantAddress", accountantAddress);
        setAddress(false, tac, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);

        // ========================== Cross Chain Layer ==========================
        string memory tvmTarget = "EQBc4bruxc39m7qOItgoOU634GGFs-W8KT0cKQce591I-HFe";
        _addTacCrossChainLeafs(leafs, getERC20(sourceChain, "USDT"), tvmTarget);

        // ========================== Morpho ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "edgeUSDT")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "re7USDT")));

        // ========================== Euler ==========================
        ERC4626[] memory depositVaults = new ERC4626[](1);
        depositVaults[0] = ERC4626(getAddress(sourceChain, "evkeUSDT-2"));

        address[] memory subaccounts = new address[](1);
        subaccounts[0] = address(boringVault);

        _addEulerDepositLeafs(leafs, depositVaults, subaccounts);

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/TAC/TurtleTacUSDStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
