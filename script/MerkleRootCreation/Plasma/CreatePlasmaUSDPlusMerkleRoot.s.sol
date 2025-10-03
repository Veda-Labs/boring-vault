// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Plasma/CreatePlasmaUSDPlusMerkleRoot.s.sol --rpc-url $PLASMA_RPC_URL --gas-limit 1000000000000000000
 */
contract CreatePlasmaUSDPlusMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0x9e424A3F0C92289251B1F42c4F55d0E8FeE16d6E;
    address public rawDataDecoderAndSanitizer = ;
    address public managerAddress = 0x1587D3B0C8Eb509977fAF0439474c58a0E557A65;
    address public accountantAddress = 0xca9c2ae69E6cd74368916ca995f01c3703b25A9E;
    address public drone = ;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateStrategistMerkleRoot();
    }

    function generateStrategistMerkleRoot() public {
        setSourceChainName(plasma);
        setAddress(false, plasma, "boringVault", boringVault);
        setAddress(false, plasma, "managerAddress", managerAddress);
        setAddress(false, plasma, "accountantAddress", accountantAddress);
        setAddress(false, plasma, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // ========================== LayerZero to Mainnet ==========================
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "USDT0"),
            getAddress(sourceChain, "USDT0_OFT"),
            layerZeroMainnetEndpointId,
            getBytes32(sourceChain, "boringVault")
        );
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "USDe"),
            getAddress(sourceChain, "USDe"),
            layerZeroMainnetEndpointId,
            getBytes32(sourceChain, "boringVault")
        );
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "SUSDE"),
            getAddress(sourceChain, "SUSDE"),
            layerZeroMainnetEndpointId,
            getBytes32(sourceChain, "boringVault")
        );

        // ========================== Aave V3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](5);
        supplyAssets[0] = getERC20(sourceChain, "USDT0");
        supplyAssets[1] = getERC20(sourceChain, "USDe");
        supplyAssets[2] = getERC20(sourceChain, "SUSDE");
        supplyAssets[3] = getERC20(sourceChain, "pendle_pt_USDe_01_15_26");
        supplyAssets[4] = getERC20(sourceChain, "pendle_pt_sUSDe_01_15_26");
        ERC20[] memory borrowAssets = new ERC20[](2);
        borrowAssets[0] = getERC20(sourceChain, "USDT0");
        borrowAssets[1] = getERC20(sourceChain, "SUSDE");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== Pendle ==========================
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_market_USDe_01_15_26"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_market_sUSDe_01_15_26"), true);

        // ========================== Balancer V3 ==========================
        _addBalancerV3Leafs(
            leafs,
            getAddress(sourceChain, "balancerV3waPlaUSDe-waPlaUSDT0"),
            true,
            address(0)
        );
        _addBalancerV3Leafs(
            leafs,
            getAddress(sourceChain, "balancerV3sUSDe-waPlaUSDT0"),
            true,
            address(0)
        );
        _addBalancerV3SwapLeafs(leafs, getAddress(sourceChain, "balancerV3waPlaUSDe-waPlaUSDT0"), false);
        _addBalancerV3SwapLeafs(leafs, getAddress(sourceChain, "balancerV3sUSDe-waPlaUSDT0"), false);
        _addBalancerV3SwapLeafs(leafs, getAddress(sourceChain, "balancerV3WXPL-USDT0"), true);

        // ========================== Curve swapping ==========================
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "USDe_USDT0_Curve_Pool"));
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "sUSDe_USDT0_Curve_Pool"));

        // ========================== Uniswap V3 ==========================
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "wXPL");
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "USDT0");
        _addUniswapV3Leafs(leafs, token0, token1, true, true);

        // ========================== Merkl ==========================
        _addMerklLeafs(
            leafs,
            getAddress(sourceChain, "merklDistributor"),
            getAddress(sourceChain, "dev1Address")
        );

        // DRONE LEAFS
        // ========================== Drone Setup ===============================
        {
            ERC20[] memory localTokens = new ERC20[](4);   
            localTokens[0] = getERC20(sourceChain, "USDe"); 
            localTokens[1] = getERC20(sourceChain, "SUSDE");
            localTokens[2] = getERC20(sourceChain, "USDT0");
            localTokens[3] = getERC20(sourceChain, "wXPL");

            _addLeafsForDroneTransfers(leafs, drone, localTokens);
            _addLeafsForDrone(leafs);
        }

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Plasma/PlasmaUSDPlusMerkleRoot.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function _addLeafsForDrone(ManageLeaf[] memory leafs) internal {
        setAddress(true, plasma, "boringVault", drone);
        uint256 droneStartIndex = leafIndex + 1;

        // ========================== Aave V3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](5);
        supplyAssets[0] = getERC20(sourceChain, "USDT0");
        supplyAssets[1] = getERC20(sourceChain, "USDe");
        supplyAssets[2] = getERC20(sourceChain, "SUSDE");
        supplyAssets[3] = getERC20(sourceChain, "pendle_pt_USDe_01_15_26");
        supplyAssets[4] = getERC20(sourceChain, "pendle_pt_sUSDe_01_15_26");
        ERC20[] memory borrowAssets = new ERC20[](2);
        borrowAssets[0] = getERC20(sourceChain, "USDT0");
        borrowAssets[1] = getERC20(sourceChain, "SUSDE");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== Uniswap V3 ==========================
        address[] memory token0 = new address[](1);
        token0[0] = getAddress(sourceChain, "wXPL");
        address[] memory token1 = new address[](1);
        token1[0] = getAddress(sourceChain, "USDT0");
        _addUniswapV3Leafs(leafs, token0, token1, true, true);

        // ========================== Merkl ==========================
        _addMerklLeafs(
            leafs,
            getAddress(sourceChain, "merklDistributor"),
            getAddress(sourceChain, "dev1Address")
        );

        _createDroneLeafs(leafs, drone, droneStartIndex, leafIndex + 1);
        setAddress(true, plasma, "boringVault", boringVault);
    }
}
