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
 *  source .env && forge script script/MerkleRootCreation/Scroll/CreateLiquidUsdOperationalMerkleRoot.s.sol --rpc-url $SCROLL_RPC_URL
 */
contract CreateLiquidUsdOperationalMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0x08c6F91e2B681FaF5e17227F2a44C307b3C1364C;
    address public managerAddress = 0xcFF411d5C54FE0583A984beE1eF43a4776854B9A;
    address public accountantAddress = 0xc315D6e14DDCDC7407784e2Caf815d131Bc1D3E7;
    address public rawDataDecoderAndSanitizer = 0xf6cF44791ee924597f8D1EFf98562435aFae29B8;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateLiquidUsdOperationalStrategistMerkleRoot();
    }

    function generateLiquidUsdOperationalStrategistMerkleRoot() public {
        setSourceChainName(scroll);
        setAddress(false, scroll, "boringVault", boringVault);
        setAddress(false, scroll, "managerAddress", managerAddress);
        setAddress(false, scroll, "accountantAddress", accountantAddress);
        setAddress(false, scroll, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);

                // Fee Claiming 
        ERC20[] memory feeAssets = new ERC20[](2);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        feeAssets[1] = getERC20(sourceChain, "USDT");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);   

        // ========================== Scroll Native Bridge ==========================
        ERC20[] memory tokens = new ERC20[](2); 
        tokens[0] = getERC20(sourceChain, "USDC"); 
        tokens[1] = getERC20(sourceChain, "USDT"); 
        address[] memory scrollGateways = new address[](2);
        scrollGateways[0] = getAddress(scroll, "scrollUSDCGateway");
        scrollGateways[1] = getAddress(scroll, "scrollUSDTGateway");
        _addScrollNativeBridgeLeafs(leafs, "mainnet", tokens, scrollGateways);  

        // ========================== Verify ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Scroll/LiquidUsdOperationalStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

    }
}

