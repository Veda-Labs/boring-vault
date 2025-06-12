// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Flare/CreateUltraUsdMerkleRoot.s.sol --rpc-url $FLARE_RPC_URL --gas-limit 1000000000000000000000000
 */
contract CreateUltraUSDMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    // "AccountantWithRateProviders": "0x95fE19b324bE69250138FE8EE50356e9f6d17Cfe",
    // "BoringOnChainQueue": "0x83fc67984DEA64Af56b37b77fB03E1fEb10b92Bb",
    // "BoringVault": "0xbc0f3B23930fff9f4894914bD745ABAbA9588265",
    // "Lens": "0x5232bc0F5999f8dA604c42E1748A13a170F94A1B",
    // "ManagerWithMerkleVerification": "0x4f81c27e750A453d6206C2d10548d6566F60886C",
    // "Pauser": "0x1e02C841aE94d552025F6Da0bb65642C409921d1",
    // "QueueSolver": "0x1F34B98dBAf1300716aE470215c34aCf2131BFfb",
    // "RolesAuthority": "0x3E6D22a67b9728A0866D69EFa16c2e20E60A8451",
    // "TellerWithMultiAssetSupport": "0xc8c58d1567e1db8c02542e6df5241A0d71f91Fe2",
    // "Timelock": "0x68E0a14EAD593E757EE04d520E71F8263fb34c40"
    //standard
    address public boringVault = 0xbc0f3B23930fff9f4894914bD745ABAbA9588265;
    address public rawDataDecoderAndSanitizer = 0x5521408dDeC0DceAE907807545BE02a5A3E5d542;
    address public managerAddress = 0x4f81c27e750A453d6206C2d10548d6566F60886C;
    address public accountantAddress = 0x95fE19b324bE69250138FE8EE50356e9f6d17Cfe; 
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

        ManageLeaf[] memory leafs = new ManageLeaf[](128);

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

        // ========================== Kinetic ==================================
        ERC20[] memory collateralAssets = new ERC20[](2);
        address[] memory cTokens = new address[](2);

        collateralAssets[0] = ERC20(getAddress(sourceChain, "USDT0"));
        collateralAssets[1] = ERC20(getAddress(sourceChain, "USDC"));

        cTokens[0] = getAddress(sourceChain, "kUSDT0");
        cTokens[1] = getAddress(sourceChain, "kUSDC");
        address unitroller = getAddress(sourceChain, "kineticUnitroller");
        _addCompoundV2Leafs(leafs, collateralAssets, cTokens, unitroller);

        // ========================== Verify and Generate =======================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Flare/UltraUsdStrategistLeafs.json";

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
