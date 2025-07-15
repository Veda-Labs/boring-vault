// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/TAC/CreateTacTONMerkleRoot.s.sol --rpc-url $TAC_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateTacTONMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = ;
    address public rawDataDecoderAndSanitizer = ;
    address public managerAddress = ; 
    address public accountantAddress = ;
    

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
        _addLayerZeroBridgeLeafs(leafs, getERC20(sourceChain, "LBTC"), getAddress(sourceChain, "LBTCOFTAdapter"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));  
        _addLayerZeroBridgeLeafs(leafs, getERC20(sourceChain, "cbBTC"), getAddress(sourceChain, "cbBTC"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));  

        // ========================== Curve ==========================
        _addCurveLeafs(leafs, getAddress(sourceChain, "cbBTC_LBTC_Curve_Pool"), 2, getAddress(sourceChain, "cbBTC_LBTC_Curve_Gauge")); 
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "cbBTC_LBTC_Curve_Pool")); 

        // ========================== Euler ==========================
        ERC4626[] memory depositVaults = new ERC4626[](2);
        depositVaults[0] = ERC4626(getAddress(sourceChain, "evkeTON-1"));
        depositVaults[1] = ERC4626(getAddress(sourceChain, "evketsTON-1"));

        address[] memory subaccounts = new address[](1);
        subaccounts[0] = address(boringVault);

        _addEulerDepositLeafs(leafs, depositVaults, subaccounts);

        // ========================== Morpho ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "re7TON")));

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/TAC/TurtleTacBTCStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

    }

}
