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
 *  source .env && forge script script/MerkleRootCreation/Corn/CreateStakedBTCNMerkleRoot.s.sol:CreateStakedBTCNMerkleRoot --rpc-url $CORN_MAIZENET_RPC_URL
 */
contract CreateStakedBTCNMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address boringVault = 0x5E272ca4bD94e57Ec5C51D26703621Ccac1A7089;
    address managerAddress = 0x5239158272D1f626aF9ef3353489D3Cb68439D66;
    address accountantAddress = 0x9A22F5dC4Ec86184D4771E620eb75D52E7b9E043;
    address rawDataDecoderAndSanitizer = 0xCAc92301f96e3b6554EF11366482f464c6f87cFB;

    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(corn);
        setAddress(false, corn, "boringVault", boringVault);
        setAddress(false, corn, "managerAddress", managerAddress);
        setAddress(false, corn, "accountantAddress", accountantAddress);
        setAddress(false, corn, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](16);

        // ========================== Curve ==========================
        _addCurveLeafs(
            leafs,
            getAddress(sourceChain, "curve_pool_LBTC_WBTCN"),
            2,
            getAddress(sourceChain, "curve_gauge_LBTC_WBTCN")
        );

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "WBTCN"), getAddress(sourceChain, "WBTCN_OFT"), layerZeroMainnetEndpointId
        );
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "LBTC"), getAddress(sourceChain, "LBTC_OFT"), layerZeroMainnetEndpointId
        );

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Corn/sBTCNStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
