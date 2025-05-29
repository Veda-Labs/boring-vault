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
 *  source .env && forge script script/MerkleRootCreation/Corn/CreateLiquidBTCMerkleRoot.s.sol:CreateLiquidBTCMerkleRoot --rpc-url $CORN_MAIZENET_RPC_URL
 */
contract CreateLiquidBTCMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address boringVault = 0x5f46d540b6eD704C3c8789105F30E075AA900726;
    address managerAddress = 0xaFa8c08bedB2eC1bbEb64A7fFa44c604e7cca68d;
    address accountantAddress = 0xEa23aC6D7D11f6b181d6B98174D334478ADAe6b0;
    address rawDataDecoderAndSanitizer = 0x1c0243F818c2af828938d703476D53448E93dD9D;
    

    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateLiquidBTCMerkleRoot();
    }

    function generateLiquidBTCMerkleRoot() public {
        setSourceChainName(corn);
        setAddress(false, corn, "boringVault", boringVault);
        setAddress(false, corn, "managerAddress", managerAddress);
        setAddress(false, corn, "accountantAddress", accountantAddress);
        setAddress(false, corn, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // ========================== LayerZero ==========================
       
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "WBTCN"), getAddress(sourceChain, "WBTCN_OFT"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault")
        );
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "LBTC"), getAddress(sourceChain, "LBTC_OFT"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault")
        );

        // ========================== Native Wrapping ==========================
        
        _addNativeLeafs(leafs, getAddress(sourceChain, "WBTCN"));

        // ========================== UniswapV3 ==========================
        
        address[] memory token0 = new address[](1);   
        token0[0] = getAddress(sourceChain, "WBTCN");  

        address[] memory token1 = new address[](1);   
        token1[0] = getAddress(sourceChain, "LBTC");  

        _addUniswapV3Leafs(leafs, token0, token1, false); 


        // ========================== Tellers ==========================
        {
        ERC20[] memory tellerAssets = new ERC20[](3); 
        tellerAssets[0] = getERC20(sourceChain, "WBTCN");  
        tellerAssets[1] = getERC20(sourceChain, "LBTC");  
        tellerAssets[2] = getERC20(sourceChain, "EBTC");
        address liquidBTCTeller = 0x9E88C603307fdC33aA5F26E38b6f6aeF3eE92d48;  

        _addTellerLeafs(leafs, liquidBTCTeller, tellerAssets, false, false); //no native deposit, no bulk deposit/withdraw
        
        
        // ========================== Withdraw Queues ==========================
        address withdrawQueue = 0x77A2fd42F8769d8063F2E75061FC200014E41Edf;
        _addWithdrawQueueLeafs(leafs, withdrawQueue, getAddress(sourceChain, "boringVault"), tellerAssets); 

        }

        
        // ========================== Morpho ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "smokehouseBTCN")));  

         // ========================== MorphoBlue ==========================
       

        _addMorphoBlueCollateralLeafs(leafs, getBytes32(sourceChain, "WBTCN_USDT0_915"));


        // ========================== Verify ==========================
        
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Corn/LiquidBTCStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
