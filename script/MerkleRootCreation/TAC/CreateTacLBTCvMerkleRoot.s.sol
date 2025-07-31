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
 *  source .env && forge script script/MerkleRootCreation/TAC/CreateTacLBTCvMerkleRoot.s.sol --rpc-url $TAC_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateTacLBTCvMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0xD86fC1CaA0a5B82cC16B16B70DFC59F6f034C348;
    address public rawDataDecoderAndSanitizer = 0x5ebE12dE67970a6d3DD70d23f90EbBA4dD38726A; 
    address public managerAddress = 0x1F95Ae26c62D24c3a5E118922Fe2ddc3B433331D; 
    address public accountantAddress = 0xB4703f17e3212E9959cC560e0592837292b14ECE; 
    

    function setUp() external {}

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

        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "LBTC"), getAddress(sourceChain, "LBTCOFTAdapter"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "cbBTC"), getAddress(sourceChain, "cbBTC"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));

        // ========================== Curve ==========================
        _addCurveLeafs(leafs, getAddress(sourceChain, "cbBTC_LBTC_Curve_Pool"), 2, getAddress(sourceChain, "cbBTC_LBTC_Curve_Gauge"));
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "cbBTC_LBTC_Curve_Pool"));

        // ========================== MetaMorpho ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "re7LBTC")));

        // ========================== Euler ==========================
        ERC4626[] memory depositVaults = new ERC4626[](1);
        depositVaults[0] = ERC4626(getAddress(sourceChain, "evkeLBTC-1"));

        address[] memory subaccounts = new address[](1);
        subaccounts[0] = address(boringVault);

        _addEulerDepositLeafs(leafs, depositVaults, subaccounts);

        // ========================== ZeroLend ==========================
        //ERC20[] memory supplyAssets = new ERC20[](1);  //Pending Zerolend
        //supplyAssets[0] = getAddress(sourceChain, "LBTC");
        //ERC20[] memory borrowAssets = new ERC20[](1);
        //borrowAssets[0] = getAddress(sourceChain, "LBTC");
        //_addZerolendLeafs(leafs, supplyAssets, borrowAssets);

        // ========================== Curve ==========================
        _addCurveLeafs(leafs, getAddress(sourceChain, "cbBTC_LBTC_Curve_Pool"), 2, getAddress(sourceChain, "cbBTC_LBTC_Curve_Gauge")); 
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "cbBTC_LBTC_Curve_Pool")); 

        // ========================== MetaMorpho ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "re7LBTC")));

        // ========================== Euler ==========================
        ERC4626[] memory depositVaults = new ERC4626[](1);
        depositVaults[0] = ERC4626(getAddress(sourceChain, "evkeLBTC-1"));

        address[] memory subaccounts = new address[](1);
        subaccounts[0] = address(boringVault);

        _addEulerDepositLeafs(leafs, depositVaults, subaccounts);

        // ========================== ZeroLend ==========================
        //ERC20[] memory supplyAssets = new ERC20[](1);  //Pending Zerolend 
        //supplyAssets[0] = getAddress(sourceChain, "LBTC"); 
        //ERC20[] memory borrowAssets = new ERC20[](1); 
        //borrowAssets[0] = getAddress(sourceChain, "LBTC"); 
        //_addZerolendLeafs(leafs, supplyAssets, borrowAssets);  

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/TAC/TacLBTCvStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
