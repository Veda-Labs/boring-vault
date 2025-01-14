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
 *  source .env && forge script script/MerkleRootCreation/Sonic/CreateStakedSonicUSDMerkleRoot.s.sol:CreateStakedSonicUSDMerkleRoot --rpc-url $SONIC_MAINNET_RPC_URL
 */
contract CreateStakedSonicUSDMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;
    
    address public boringVault = 0x4D85bA8c3918359c78Ed09581E5bc7578ba932ba;
    address public managerAddress = 0x5F7f5205A3E7c63c3bd287EecBe7879687D4c698;
    address public accountantAddress = 0x13cCc810DfaA6B71957F2b87060aFE17e6EB8034;
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
        _addBalancerLeafs(leafs, getBytes32(sourceChain, "scUSD_USDC_PoolId"), getAddress(sourceChain, "scUSD_USDC_gauge")); 
        
        // ========================== Teller ==========================
        ERC20[] memory tellerAssets = new ERC20[](1); 
        tellerAssets[0] = getERC20(sourceChain, "USDC"); 
        _addTellerLeafs(leafs, getAddress(sourceChain, "scUSDTeller"), tellerAssets); 

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Sonic/StakedSonicUSDStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
         
    }
}
