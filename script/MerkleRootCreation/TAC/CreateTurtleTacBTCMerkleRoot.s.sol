// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/TAC/CreateTurtleTacBTCMerkleRoot.s.sol --rpc-url $TAC_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateTurtleTacBTCMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0x6Bf340dB729d82af1F6443A0Ea0d79647b1c3DDf;
    address public rawDataDecoderAndSanitizer = 0x5ebE12dE67970a6d3DD70d23f90EbBA4dD38726A; 
    address public managerAddress = 0x85A8821a579736e7E5e98296D34C50B77122BB5e; 
    address public accountantAddress = 0xe4858a89d5602Ad30de2018C408d33d101F53d53; 
    

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
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "cbBTC"), getAddress(sourceChain, "cbBTC"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));

        // ========================== Curve ==========================
        _addCurveLeafs(leafs, getAddress(sourceChain, "cbBTC_LBTC_Curve_Pool"), 2, getAddress(sourceChain, "cbBTC_LBTC_Curve_Gauge")); 
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "cbBTC_LBTC_Curve_Pool")); 
         
        // ========================== MetaMorpho ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "re7cbBTC")));
        
        // ========================== Euler ==========================
        ERC4626[] memory depositVaults = new ERC4626[](2);
        depositVaults[0] = ERC4626(getAddress(sourceChain, "evkecbBTC-3"));
        depositVaults[1] = ERC4626(getAddress(sourceChain, "evkecbBTC-2"));

        address[] memory subaccounts = new address[](1);
        subaccounts[0] = address(boringVault);

        _addEulerDepositLeafs(leafs, depositVaults, subaccounts);
        
        // ========================== ZeroLend ==========================
        //ERC20[] memory supplyAssets = new ERC20[](1);  //Pending Zerolend 
        //supplyAssets[0] = getAddress(sourceChain, "cbBTC"); 
        //ERC20[] memory borrowAssets = new ERC20[](1); 
        //borrowAssets[0] = getAddress(sourceChain, "cbBTC"); 
        //_addZeroLendLeafs(leafs, supplyAssets, borrowAssets);  

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/TAC/TurtleTacBTCStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

    }

}
