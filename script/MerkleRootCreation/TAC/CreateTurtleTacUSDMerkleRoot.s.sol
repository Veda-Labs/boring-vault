// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/TAC/CreateTurtleTacUSDMerkleRoot.s.sol --rpc-url $TAC_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateTurtleTacUSDMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0x699e04F98dE2Fc395a7dcBf36B48EC837A976490;
    address public rawDataDecoderAndSanitizer = 0x9Bc20d0F13E68FAD5f4eE5Dda58c391b342e65a5; 
    address public managerAddress = 0x2FA91E4eb6Ace724EfFbDD61bBC1B55EF8bD7aAc; 
    address public accountantAddress = 0x58cD5e97ffaeA62986C86ac44bB8EF7092c7ff5B;
    

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

        ManageLeaf[] memory leafs = new ManageLeaf[](8);

        // ========================== Cross Chain Layer ==========================
        string memory tvmTarget = "EQCj-sWCD3CQkYh-pWSn2ZpamhuRrSYxl7SAV4BStSM59B9E"; 
        _addTacCrossChainLeafs(leafs, getERC20(sourceChain, "USDT"), tvmTarget);

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/TAC/TurtleTacUSDStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);

    }

}
