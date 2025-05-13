// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Flare/CreateLiquidUsdMerkleRoot.s.sol --rpc-url $FLARE_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateLiquidUsdMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0x08c6F91e2B681FaF5e17227F2a44C307b3C1364C;
    address public rawDataDecoderAndSanitizer = 0xb697Ac7D75cF5CDA76b273a5465e0253a70d09a2;
    address public managerAddress = 0xcFF411d5C54FE0583A984beE1eF43a4776854B9A;
    address public accountantAddress = 0xc315D6e14DDCDC7407784e2Caf815d131Bc1D3E7; 
    address public drone = 0x3683fc2792F676BBAbc1B5555dE0DfAFee546e9a; 


    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateLiquidUsdStrategistMerkleRoot();
        // generateMiniLiquidUsdStrategistMerkleRoot();
    }

    function generateLiquidUsdStrategistMerkleRoot() public {
        setSourceChainName(flare);
        setAddress(false, flare, "boringVault", boringVault);
        setAddress(false, flare, "managerAddress", managerAddress);
        setAddress(false, flare, "accountantAddress", accountantAddress);
        setAddress(false, flare, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        // ========================== SparkDEX ===============================
        address[] memory token0 = new address[](3);
        token0[0] = getAddress(sourceChain, "USDC");
        token0[1] = getAddress(sourceChain, "USDC");
        token0[2] = getAddress(sourceChain, "USDT0");

        address[] memory token1 = new address[](3);
        token1[0] = getAddress(sourceChain, "USDT0");
        token1[1] = getAddress(sourceChain, "WFLR");
        token1[2] = getAddress(sourceChain, "WFLR");
          
        _addUniswapV3Leafs(leafs, token0, token1, false); //uses regular swapRouter, not 02

        // ========================== LayerZero ===============================
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "USDC"), getAddress(sourceChain, "USDC_OFT_stargate"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault")); 
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "USDT0"), getAddress(sourceChain, "USDT0_OFT"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault")); 

        // ========================== Drone Transfer ===============================
        ERC20[] memory localTokens = new ERC20[](3);   
        localTokens[0] = getERC20(sourceChain, "USDC"); 
        localTokens[1] = getERC20(sourceChain, "USDT0"); 
        localTokens[2] = getERC20(sourceChain, "WFLR"); 

        _addLeafsForDroneTransfers(leafs, drone, localTokens);

        // ========================== Native Leafs ===============================
        _addNativeLeafs(leafs, getAddress(sourceChain, "WFLR")); 

        // ========================== Drone Setup ===============================
        _addLeafsForDrone(leafs);

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Flare/LiquidUsdStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function _addLeafsForDrone(ManageLeaf[] memory leafs) internal {
        setAddress(true, flare, "boringVault", drone);
        uint256 droneStartIndex = leafIndex + 1;

        // ========================== SparkDEX ===============================
        address[] memory token0 = new address[](3);
        token0[0] = getAddress(sourceChain, "USDC");
        token0[1] = getAddress(sourceChain, "USDC");
        token0[2] = getAddress(sourceChain, "USDT0");

        address[] memory token1 = new address[](3);
        token1[0] = getAddress(sourceChain, "USDT0");
        token1[1] = getAddress(sourceChain, "WFLR");
        token1[2] = getAddress(sourceChain, "WFLR");

        _addUniswapV3Leafs(leafs, token0, token1, false); //uses regular swapRouter, not 02
        // ========================== LayerZero ===============================
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "USDC"), getAddress(sourceChain, "USDC_OFT_stargate"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault")); 
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "USDT0"), getAddress(sourceChain, "USDT0_OFT"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault")); 

        // ========================== Native Leafs ===============================
        _addNativeLeafs(leafs, getAddress(sourceChain, "WFLR")); 


        _createDroneLeafs(leafs, drone, droneStartIndex, leafIndex + 1);
        setAddress(true, mainnet, "boringVault", boringVault);
    }

}
