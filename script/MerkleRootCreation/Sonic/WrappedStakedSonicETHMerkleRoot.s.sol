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
 *  source .env && forge script script/MerkleRootCreation/Sonic/WrappedStakedSonicETHMerkleRoot.s.sol:CreateWrappedStakedSonicETHMerkleRoot --rpc-url $SONIC_MAINNET_RPC_URL
 */
contract CreateWrappedStakedSonicETHMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x500DC884E986dc9eD99C2833F5210825e15e28FD;
    address public managerAddress = 0x463cE91DeaeD808E6ACd540a351207f81B9A4a99;
    address public accountantAddress = 0x9B3e937f0f3AA0E60b5E4Cd70d44340A7eb24265;
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

        ManageLeaf[] memory leafs = new ManageLeaf[](8);

        //1) Deposit/Withdraw into stkscETH Teller
        //2) Claim Yield from stkscETH (in scUSD)

        // ========================== Teller ==========================
        ERC20[] memory tellerAssets = new ERC20[](1);
        tellerAssets[0] = getERC20(sourceChain, "scETH");
        _addTellerLeafs(leafs, getAddress(sourceChain, "stkscETHTeller"), tellerAssets);

        // ========================== Fee Claiming ==========================
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "stkscETHAccountant"), tellerAssets, true);

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Sonic/WrappedStakedSonicUSDStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
