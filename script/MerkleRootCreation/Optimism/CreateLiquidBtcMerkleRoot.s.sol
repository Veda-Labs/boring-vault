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
 *  source .env && forge script script/MerkleRootCreation/Optimism/CreateLiquidBtcMerkleRoot.s.sol --rpc-url $OPTIMISM_RPC_URL
 */
contract CreateLiquidBtcMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x5f46d540b6eD704C3c8789105F30E075AA900726;
    address public managerAddress = 0xaFa8c08bedB2eC1bbEb64A7fFa44c604e7cca68d;
    address public accountantAddress = 0xEa23aC6D7D11f6b181d6B98174D334478ADAe6b0;
    address public rawDataDecoderAndSanitizer = 0x58D28BB88400b889C4a1b754d930a743323F5Ada;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(optimism);
        setAddress(false, optimism, "boringVault", boringVault);
        setAddress(false, optimism, "managerAddress", managerAddress);
        setAddress(false, optimism, "accountantAddress", accountantAddress);
        setAddress(false, optimism, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);

        // ========================== Tellers & Withdraw Queues ==========================
        // deposit WBTC into eBTC, receive eBTC shares
        address eBTCTeller = 0x6Ee3aaCcf9f2321E49063C4F8da775DdBd407268; 
        address[] memory depositAssets = new address[](1); 
        depositAssets[0] = getAddress(sourceChain, "WBTC"); 

        address[] memory feeAssets = new address[](1); 
        feeAssets[0] = getAddress(sourceChain, "ETH"); 

        _addCrossChainTellerLeafs(leafs, eBTCTeller, depositAssets, feeAssets, abi.encode(layerZeroMainnetEndpointId)); 
        

        // Fee Claiming 
        ERC20[] memory claimingAssets = new ERC20[](1);
        claimingAssets[0] = getERC20(sourceChain, "WBTC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), claimingAssets, false);

        // ========================== Verify ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Optimism/LiquidBtcStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

    }
}

