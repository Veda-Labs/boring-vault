// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Sonic/CreateStakedSonicETHMerkleRoot.s.sol:CreateStakedSonicETHMerkleRoot --rpc-url $SONIC_MAINNET_RPC_URL
 */
contract CreateStakedSonicETHMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x455d5f11Fea33A8fa9D3e285930b478B6bF85265;
    address public managerAddress = 0xB77F31E02797724021F822181dff29F966A7B2cb;
    address public accountantAddress = 0x61bE1eC20dfE0197c27B80bA0f7fcdb1a6B236E2;
    address public rawDataDecoderAndSanitizer = 0x594c769681dAdA8E39C630550e03012d11E88234;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(sonicMainnet);
        setAddress(false, sonicMainnet, "boringVault", boringVault);
        setAddress(false, sonicMainnet, "managerAddress", managerAddress);
        setAddress(false, sonicMainnet, "accountantAddress", accountantAddress);
        setAddress(false, sonicMainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](128);

        // ========================== Beets ==========================
        _addBalancerLeafs(leafs, getBytes32(sourceChain, "scETH_WETH_PoolId"), getAddress(sourceChain, "scETH_WETH_gauge")); 

        // ========================== Teller ==========================
        ERC20[] memory tellerAssets = new ERC20[](1);
        tellerAssets[0] = getERC20(sourceChain, "WETH");
        _addTellerLeafs(leafs, getAddress(sourceChain, "scETHTeller"), tellerAssets, false);

        // ========================== Silo ==========================
        
        _addSiloV2Leafs(leafs, getAddress(sourceChain, "silo_S_ETH_config")); 
        _addSiloV2Leafs(leafs, getAddress(sourceChain, "silo_ETH_wstkscETH_config")); 

        // ========================== Curve =========================
        
        _addCurveLeafs(leafs, getAddress(sourceChain, "curve_WETH_scETH_pool"), 2, getAddress(sourceChain, "curve_WETH_scETH_gauge")); 
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "curve_WETH_scETH_pool")); 

        // ========================== Euler =========================
        
        ERC4626[] memory depositVaults = new ERC4626[](2);
        depositVaults[0] = ERC4626(getAddress(sourceChain, "euler_scETH_MEV")); 
        depositVaults[1] = ERC4626(getAddress(sourceChain, "euler_WETH_MEV")); 

        address[] memory subaccounts = new address[](1);
        subaccounts[0] = address(boringVault);

        _addEulerDepositLeafs(leafs, depositVaults, subaccounts);
       
        // ========================== Verify =========================
         
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Sonic/StakedSonicETHStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
