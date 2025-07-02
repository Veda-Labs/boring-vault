// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Katana/CreateKatanaLBTCvMerkleRoot.s.sol --rpc-url $KATANA_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateKatanaLBTCvMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0x75231079973C23e9eB6180fa3D2fc21334565aB5;
    address public rawDataDecoderAndSanitizer = 0x770B3AAA48096b3fB36876b8dD55789372775bf0;
    address public managerAddress = 0x9aC5AEf62eCe812FEfb77a0d1771c9A5ce3D04E4;
    address public accountantAddress = 0x90e864A256E58DBCe034D9C43C3d8F18A00f55B6;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateStrategistMerkleRoot();
    }

    function generateStrategistMerkleRoot() public {
        setSourceChainName(katana);
        setAddress(false, katana, "boringVault", boringVault);
        setAddress(false, katana, "managerAddress", managerAddress);
        setAddress(false, katana, "accountantAddress", accountantAddress);
        setAddress(false, katana, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);


        // ========================== CCIP ==========================
        ERC20[] memory ccipBridgeAssets = new ERC20[](1);
        ccipBridgeAssets[0] = getERC20(sourceChain, "LBTC");
        ERC20[] memory ccipBridgeFeeAssets = new ERC20[](1);
        ccipBridgeFeeAssets[0] = getERC20(sourceChain, "WETH");
        _addCcipBridgeLeafs(leafs, ccipMainnetChainSelector, ccipBridgeAssets, ccipBridgeFeeAssets);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](1);
        feeAssets[0] = getERC20(sourceChain, "LBTC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Katana/KatanaLBTCvMerkleRoot.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
