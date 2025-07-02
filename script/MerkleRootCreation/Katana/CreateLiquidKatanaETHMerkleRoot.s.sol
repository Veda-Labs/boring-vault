// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Katana/CreateLiquidKatanaETHMerkleRoot.s.sol --rpc-url $KATANA_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateLiquidKatanaETHMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0x69d210d3b60E939BFA6E87cCcC4fAb7e8F44C16B;
    address public rawDataDecoderAndSanitizer = 0x770B3AAA48096b3fB36876b8dD55789372775bf0;
    address public managerAddress = 0x51CdEcC111c21BED72Ab99f415Bab6d35984BfEB;
    address public accountantAddress = 0xFCb9a6bF02C43f9E38Bb102fd960Cc1e738e787d;

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

        ManageLeaf[] memory leafs = new ManageLeaf[](16);


        // ========================== NativeWrapper ==========================
        _addNativeLeafs(leafs);

        // ========================== Agglayer ==========================
        _addAgglayerTokenLeafs(
            leafs,
            getAddress(sourceChain, "agglayerBridgeKatana"),
            getAddress(sourceChain, "vbETH"),
            20,
            0
        );
        _addAgglayerTokenLeafs(
            leafs,
            getAddress(sourceChain, "agglayerBridgeKatana"),
            getAddress(sourceChain, "WEETH"),
            20,
            0
        );

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](2);
        feeAssets[0] = getERC20(sourceChain, "WETH");
        feeAssets[1] = getERC20(sourceChain, "WEETH");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);


        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Katana/LiquidKatanaETHMerkleRoot.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
