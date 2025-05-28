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
 *  source .env && forge script script/MerkleRootCreation/Scroll/CreateLiquidBtcMerkleRoot.s.sol --rpc-url $SCROLL_RPC_URL
 */
contract CreateLiquidBtcMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x5f46d540b6eD704C3c8789105F30E075AA900726;
    address public managerAddress = 0xaFa8c08bedB2eC1bbEb64A7fFa44c604e7cca68d;
    address public accountantAddress = 0xEa23aC6D7D11f6b181d6B98174D334478ADAe6b0;
    address public rawDataDecoderAndSanitizer = 0xFDE49d6B3ae04acd8D89FD6f50B970DeB2B943D9;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(scroll);
        setAddress(false, scroll, "boringVault", boringVault);
        setAddress(false, scroll, "managerAddress", managerAddress);
        setAddress(false, scroll, "accountantAddress", accountantAddress);
        setAddress(false, scroll, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);

        // ========================== Scroll Native Bridge ==========================
        ERC20[] memory tokens = new ERC20[](1); 
        tokens[0] = getERC20(sourceChain, "WBTC"); 
        _addScrollNativeBridgeLeafs(leafs, "mainnet", tokens);  

        // ========================== Tellers & Withdraw Queues ==========================
        // deposit WBTC into eBTC, receive eBTC shares
        address eBTCTeller = 0x6Ee3aaCcf9f2321E49063C4F8da775DdBd407268; 
        ERC20[] memory tellerAssets = new ERC20[](1); 
        tellerAssets[0] = getERC20(sourceChain, "WBTC"); 
        _addTellerLeafs(leafs, eBTCTeller, tellerAssets, false, true);  
        
        //request withdraw from eBTC if needed
        address eBTCWithdrawQueue = 0x686696A3e59eE16e8A8533d84B62cfA504827135; 
        _addWithdrawQueueLeafs(leafs, eBTCWithdrawQueue, getAddress(sourceChain, "EBTC"), tellerAssets); 

        // ========================== Verify ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Scroll/LiquidBtcStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

    }
}

