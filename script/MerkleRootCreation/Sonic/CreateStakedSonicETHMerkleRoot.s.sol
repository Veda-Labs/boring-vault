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
    address public rawDataDecoderAndSanitizer = 0x8A6790A3665167f3bCdfB9A3EECE92F9443c106c; 
    
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

        ManageLeaf[] memory leafs = new ManageLeaf[](16);

        // ========================== Beets ==========================
        _addBalancerLeafs(leafs, getBytes32(sourceChain, "scETH_WETH_PoolId"), address(0)); //address(0) indicates no gauge for staking 
        
        // ========================== Teller ==========================
        ERC20[] memory tellerAssets = new ERC20[](1);  
        tellerAssets[0] = getERC20(sourceChain, "WETH"); 
        _addTellerLeafs(leafs, getAddress(sourceChain, "scETHTeller"), tellerAssets); 

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Sonic/StakedSonicETHStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
         
    }
}
