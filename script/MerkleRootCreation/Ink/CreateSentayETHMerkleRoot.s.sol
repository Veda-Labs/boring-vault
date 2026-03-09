// SPDX-License-Identifier: SEL-1.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Ink/CreateSentayETHMerkleRoot.s.sol --rpc-url $INK_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateSentayETHMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xf15351A0d66743E09457C45EaE88dF34FcEe8CB7;
    address public managerAddress = 0xA44Ce1EAb82f99B3dc530734b9DcEaf14E7F2Af7;
    address public accountantAddress = 0xE803d9283450189f168c825AC462dfe035345114;
    address public rawDataDecoderAndSanitizer = 0x1f7dbFA46d7d150AEF6D3c8044C5c32aC71c0b6f;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateStrategistMerkleRoot();
    }

    function generateStrategistMerkleRoot() public {
        setSourceChainName(ink);
        setAddress(false, ink, "boringVault", boringVault);
        setAddress(false, ink, "managerAddress", managerAddress);
        setAddress(false, ink, "accountantAddress", accountantAddress);
        setAddress(false, ink, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);

        // ========================== Native ==========================
        _addNativeLeafs(leafs);

        {
            ERC20[] memory localTokens = new ERC20[](0);
            ERC20[] memory remoteTokens = new ERC20[](0);
            _addStandardBridgeLeafs(
                leafs,
                mainnet,
                address(0),
                address(0),
                getAddress(sourceChain, "standardBridge"),
                address(0),
                localTokens,
                remoteTokens
            );
        }

        // ========================== LayerZero ==========================

        _addLayerZeroLeafs(
            leafs,
            ERC20(getAddress(sourceChain, "WEETH")),
            getAddress(sourceChain, "WEETH"),
            layerZeroMainnetEndpointId,
            getBytes32(sourceChain, "boringVault")
        );

        // ========================== Verification ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Ink/SentayETHStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
