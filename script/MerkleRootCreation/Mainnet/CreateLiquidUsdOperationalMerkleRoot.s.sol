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

contract CreateLiquidUsdOperationalMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0x08c6F91e2B681FaF5e17227F2a44C307b3C1364C;
    address public rawDataDecoderAndSanitizer = 0xB781C6Ab69B63A10B05D120Bcbe40C58D1b0Bc2e;
    address public managerAddress = 0x7b57Ad1A0AA89583130aCfAD024241170D24C13C;
    address public accountantAddress = 0xc315D6e14DDCDC7407784e2Caf815d131Bc1D3E7;
    address public drone = 0x3683fc2792F676BBAbc1B5555dE0DfAFee546e9a;
    address public drone1 = 0x08777996b26bD82aD038Bca80De5B8dEA742370f; 

    //one offs
    address public symbioticDecoderAndSanitizer = 0xdaEfE2146908BAd73A1C45f75eB2B8E46935c781;
    address public pancakeSwapDataDecoderAndSanitizer = 0xfdC73Fc6B60e4959b71969165876213918A443Cd;
    address public aaveV3DecoderAndSanitizer = 0x159Af850c18a83B67aeEB9597409f6C4Aa07ACb3;
    address public scrollBridgeDecoderAndSanitizer = 0xA66a6B289FB5559b7e4ebf598B8e0A97C776c200; 

    function setUp() external {}

    function run() external {
        generateLiquidUsdOperationalStrategistMerkleRoot();
    }

    function generateLiquidUsdOperationalStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // ========================== Aave V3 ==========================
        {
            setAddress(true, mainnet, "rawDataDecoderAndSanitizer", aaveV3DecoderAndSanitizer);
            ERC20[] memory supplyAssets = new ERC20[](2);
            supplyAssets[0] = getERC20(sourceChain, "USDC");
            supplyAssets[1] = getERC20(sourceChain, "USDT");
            ERC20[] memory borrowAssets = new ERC20[](0);
            _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);
            _addAaveV3RepayLeafs("Aave V3", getAddress(mainnet, "v3Pool"), leafs, supplyAssets);
            setAddress(true, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        }

        // ========================== MorphoBlue ==========================
        {
            _addMorphoBlueRepayLeafs(leafs, 0xdc5333039bcf15f1237133f74d5806675d83d9cf19cfd4cfdd9be674842651bf);
            _addMorphoBlueRepayLeafs(leafs, 0xcec858380cba2d9ca710fce3ce864d74c3f620d53826f69d08508902e09be86f);
            _addMorphoBlueRepayLeafs(leafs, 0x8e6aeb10c401de3279ac79b4b2ea15fc94b7d9cfc098d6c2a1ff7b2b26d9d02c);
            _addMorphoBlueRepayLeafs(leafs, 0x1247f1c237eceae0602eab1470a5061a6dd8f734ba88c7cdc5d6109fb0026b28);
            _addMorphoBlueRepayLeafs(leafs, 0xdb760246f6859780f6c1b272d47a8f64710777121118e56e0cdb4b8b744a3094);
            _addMorphoBlueRepayLeafs(leafs, 0xc581c5f70bd1afa283eed57d1418c6432cbff1d862f94eaf58fdd4e46afbb67f);
            _addMorphoBlueRepayLeafs(leafs, 0xfd8493f09eb6203615221378d89f53fcd92ff4f7d62cca87eece9a2fff59e86f);
            _addMorphoBlueRepayLeafs(leafs, 0x7dde86a1e94561d9690ec678db673c1a6396365f7d1d65e129c5fff0990ff758);
            _addMorphoBlueRepayLeafs(leafs, 0xf9acc677910cc17f650416a22e2a14d5da7ccb9626db18f1bf94efe64f92b372);
            _addMorphoBlueRepayLeafs(leafs, 0x42dcfb38bb98767afb6e38ccf90d59d0d3f0aa216beb3a234f12850323d17536);
            _addMorphoBlueRepayLeafs(leafs, 0x39d11026eae1c6ec02aa4c0910778664089cdd97c3fd23f68f7cd05e2e95af48);
            _addMorphoBlueRepayLeafs(leafs, 0xe7e9694b754c4d4f7e21faf7223f6fa71abaeb10296a4c43a54a7977149687d2);
            _addMorphoBlueRepayLeafs(leafs, 0xb323495f7e4148be5643a4ea4a8221eef163e4bccfdedc2a6f4696baacbc86cc);
            _addMorphoBlueRepayLeafs(leafs, getBytes32(sourceChain, "eUSDePT_05_28_25_USDC_915"));
            _addMorphoBlueRepayLeafs(leafs, getBytes32(sourceChain, "eUSDePT_05_28_25_DAI_915"));
            _addMorphoBlueRepayLeafs(leafs, getBytes32(sourceChain, "syrupUSDC_USDC_915"));
            _addMorphoBlueRepayLeafs(leafs, getBytes32(sourceChain, "sUSDePT_07_30_25_DAI_915"));
            _addMorphoBlueRepayLeafs(leafs, getBytes32(sourceChain, "sUSDePT_07_30_25_USDC_915"));
        }

        // ========================== Layer Zero Bridging ==========================
        // Flare
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "USDC"),
            getAddress(sourceChain, "stargateUSDC"),
            layerZeroFlareEndpointId,
            getBytes32(sourceChain, "boringVault")
        );
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "USDT"),
            getAddress(sourceChain, "usdt0OFTAdapter"),
            layerZeroFlareEndpointId,
            getBytes32(sourceChain, "boringVault")
        );
       // Scroll
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "USDC"),
            getAddress(sourceChain, "stargateUSDC"),
            layerZeroScrollEndpointId,
            getBytes32(sourceChain, "boringVault")
        );

        // ========================== Scroll Bridge ==========================
        {
            setAddress(true, mainnet, "rawDataDecoderAndSanitizer", scrollBridgeDecoderAndSanitizer);
            ERC20[] memory tokens = new ERC20[](3);
            tokens[0] = getERC20(sourceChain, "USDC");
            tokens[1] = getERC20(sourceChain, "USDT");
            tokens[2] = getERC20(sourceChain, "DAI");
            address[] memory scrollGateways = new address[](3);
            scrollGateways[0] = getAddress(scroll, "scrollUSDCGateway");
            scrollGateways[1] = getAddress(scroll, "scrollUSDTGateway");
            scrollGateways[2] = getAddress(scroll, "scrollDAIGateway");
            _addScrollNativeBridgeLeafs(leafs, "scroll", tokens, scrollGateways);
            setAddress(true, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        }

        // ========================== Merkl ==========================
        {
            _addMerklLeafs(leafs, getAddress(sourceChain, "merklDistributor"), getAddress(sourceChain, "dev1Address")); 
        }

        // ========================== Drone Transfers ==========================
        {
            ERC20[] memory localTokens = new ERC20[](2);
            localTokens[0] = getERC20("mainnet", "USDT");
            localTokens[1] = getERC20("mainnet", "USDC");

            _addLeafsForDroneTransfers(leafs, drone, localTokens);
            _addLeafsForDroneTransfers(leafs, drone1, localTokens);
        }

        // ========================== Drones Setup ===============================
        _addLeafsForDrone(leafs);
        _addLeafsForDroneOne(leafs);

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Mainnet/LiquidUsdOperationalStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function _addLeafsForDrone(ManageLeaf[] memory leafs) internal {
        setAddress(true, mainnet, "boringVault", drone);
        uint256 droneStartIndex = leafIndex + 1;

        // ========================== Aave V3 ==========================
        {
            setAddress(true, mainnet, "rawDataDecoderAndSanitizer", aaveV3DecoderAndSanitizer);
            ERC20[] memory supplyAssets = new ERC20[](2);
            supplyAssets[0] = getERC20(sourceChain, "USDC");
            supplyAssets[1] = getERC20(sourceChain, "USDT");
            ERC20[] memory borrowAssets = new ERC20[](0);
            _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);
            _addAaveV3RepayLeafs("Aave V3", getAddress(mainnet, "v3Pool"), leafs, supplyAssets);
            setAddress(true, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        }

        // ========================== MorphoBlue ==========================
        {
            _addMorphoBlueRepayLeafs(leafs, 0xdc5333039bcf15f1237133f74d5806675d83d9cf19cfd4cfdd9be674842651bf);
            _addMorphoBlueRepayLeafs(leafs, 0xcec858380cba2d9ca710fce3ce864d74c3f620d53826f69d08508902e09be86f);
            _addMorphoBlueRepayLeafs(leafs, 0x8e6aeb10c401de3279ac79b4b2ea15fc94b7d9cfc098d6c2a1ff7b2b26d9d02c);
            _addMorphoBlueRepayLeafs(leafs, 0x1247f1c237eceae0602eab1470a5061a6dd8f734ba88c7cdc5d6109fb0026b28);
            _addMorphoBlueRepayLeafs(leafs, 0xdb760246f6859780f6c1b272d47a8f64710777121118e56e0cdb4b8b744a3094);
            _addMorphoBlueRepayLeafs(leafs, 0xc581c5f70bd1afa283eed57d1418c6432cbff1d862f94eaf58fdd4e46afbb67f);
            _addMorphoBlueRepayLeafs(leafs, 0xfd8493f09eb6203615221378d89f53fcd92ff4f7d62cca87eece9a2fff59e86f);
            _addMorphoBlueRepayLeafs(leafs, 0x7dde86a1e94561d9690ec678db673c1a6396365f7d1d65e129c5fff0990ff758);
            _addMorphoBlueRepayLeafs(leafs, 0xf9acc677910cc17f650416a22e2a14d5da7ccb9626db18f1bf94efe64f92b372);
            _addMorphoBlueRepayLeafs(leafs, 0x42dcfb38bb98767afb6e38ccf90d59d0d3f0aa216beb3a234f12850323d17536);
            _addMorphoBlueRepayLeafs(leafs, 0x39d11026eae1c6ec02aa4c0910778664089cdd97c3fd23f68f7cd05e2e95af48);
            _addMorphoBlueRepayLeafs(leafs, 0xe7e9694b754c4d4f7e21faf7223f6fa71abaeb10296a4c43a54a7977149687d2);
            _addMorphoBlueRepayLeafs(leafs, 0xb323495f7e4148be5643a4ea4a8221eef163e4bccfdedc2a6f4696baacbc86cc);
            _addMorphoBlueRepayLeafs(leafs, getBytes32(sourceChain, "eUSDePT_05_28_25_USDC_915"));
            _addMorphoBlueRepayLeafs(leafs, getBytes32(sourceChain, "eUSDePT_05_28_25_DAI_915"));
            _addMorphoBlueRepayLeafs(leafs, getBytes32(sourceChain, "syrupUSDC_USDC_915"));
            _addMorphoBlueRepayLeafs(leafs, getBytes32(sourceChain, "sUSDePT_07_30_25_DAI_915"));
            _addMorphoBlueRepayLeafs(leafs, getBytes32(sourceChain, "sUSDePT_07_30_25_USDC_915"));
        }

        // ========================== Merkl ==========================
        {
            _addMerklLeafs(leafs, getAddress(sourceChain, "merklDistributor"), getAddress(sourceChain, "dev1Address")); 
        }

        _createDroneLeafs(leafs, drone, droneStartIndex, leafIndex + 1);
        setAddress(true, mainnet, "boringVault", boringVault);
    }

    function _addLeafsForDroneOne(ManageLeaf[] memory leafs) internal {
        setAddress(true, mainnet, "boringVault", drone1);
        uint256 drone1StartIndex = leafIndex + 1;

        //NOTE: ensure this is drone1 address
        _createDroneLeafs(leafs, drone1, drone1StartIndex, leafIndex + 1);
        setAddress(true, mainnet, "boringVault", boringVault);
    }

}
