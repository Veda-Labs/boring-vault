// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/** //TODO
 *  source .env && forge script script/MerkleRootCreation/{chain}/.s.sol:{contractName} --rpc-url ${chain_rpc}
 */
contract CreateMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = address(0);
    address public managerAddress = address(0);
    address public accountantAddress = address(0);
    address public rawDataDecoderAndSanitizer = address(0);

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {

        // ========================== Setup ==========================
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);

        // ======================== Verification & File Generation =======================
        
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);
        
        //TODO
        string memory filePath = "./leafs/Mainnet/.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
