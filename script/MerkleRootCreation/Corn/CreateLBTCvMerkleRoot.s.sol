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
 *  source .env && forge script script/MerkleRootCreation/Corn/CreateLBTCvMerkleRoot.s.sol:CreateLBTCvMerkleRoot --rpc-url $CORN_MAIZENET_RPC_URL */
contract CreateLBTCvMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;
    
    address boringVault = 0x5401b8620E5FB570064CA9114fd1e135fd77D57c; 
    address managerAddress = 0xcf38e37872748E3b66741A42560672A6cef75e9B;
    address accountantAddress = 0x28634D0c5edC67CF2450E74deA49B90a4FF93dCE; 
    address rawDataDecoderAndSanitizer = 0x284b1B0Cc7C430e3F1eb11A37836fe61157c19CD; 

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
        _addCurveLeafs(leafs, getAddress(sourceChain, "curve_pool_LBTC_WBTCN"), 2, getAddress(sourceChain, "curve_gauge_LBTC_WBTCN")); 

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "WBTCN"), getAddress(sourceChain, "WBTCN_OFT"), layerZeroMainnetEndpointId
        );
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "LBTC"), getAddress(sourceChain, "LBTC_OFT"), layerZeroMainnetEndpointId
        ); 

        // ========================== Native Wrapping ==========================
        _addNativeLeafs(leafs, getAddress(sourceChain, "WBTCN")); 



        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Corn/LBTCvStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
             
    }

}
