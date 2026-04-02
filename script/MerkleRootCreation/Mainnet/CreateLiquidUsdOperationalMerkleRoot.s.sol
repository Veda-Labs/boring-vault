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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateLiquidUsdOperationalMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */

contract CreateLiquidUsdOperationalMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0x08c6F91e2B681FaF5e17227F2a44C307b3C1364C;
    address public rawDataDecoderAndSanitizer = 0xB781C6Ab69B63A10B05D120Bcbe40C58D1b0Bc2e;
    address public scrollBridgeDecoderAndSanitizer = 0xA66a6B289FB5559b7e4ebf598B8e0A97C776c200;
    address public capDecoderAndSanitizer = 0xE0e86bf98dAA0D2b408Cb038E94bCB9B7864309C;
    address public managerAddress = 0x7b57Ad1A0AA89583130aCfAD024241170D24C13C;
    address public accountantAddress = 0xc315D6e14DDCDC7407784e2Caf815d131Bc1D3E7;
    address public drone = 0x3683fc2792F676BBAbc1B5555dE0DfAFee546e9a;
    address public drone1 = 0x08777996b26bD82aD038Bca80De5B8dEA742370f; 

    //one offs
    address public symbioticDecoderAndSanitizer = 0xdaEfE2146908BAd73A1C45f75eB2B8E46935c781;
    address public pancakeSwapDataDecoderAndSanitizer = 0xfdC73Fc6B60e4959b71969165876213918A443Cd;
    address public aaveV3DecoderAndSanitizer = 0x159Af850c18a83B67aeEB9597409f6C4Aa07ACb3;
    address public cctpDecoderAndSanitizer = 0xEEb53299Cb894968109dfa420D69f0C97c835211;
    address public standardBridgeDecoderAndSanitizer = 0xC48cA54b9F3f8Fc7E5347DE55879851178B485e8;

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
        leafIndex = 0;

        // ========================== Merkl ==========================
        {
            _addMerklLeafs(leafs, getAddress(sourceChain, "merklDistributor"), getAddress(sourceChain, "etherfiOpsAddress")); 
        }

        // ========================== Aave V3 ==========================
        {
            setAddress(true, mainnet, "rawDataDecoderAndSanitizer", aaveV3DecoderAndSanitizer);
            ERC20[] memory assets = new ERC20[](2);
            assets[0] = getERC20(sourceChain, "USDC");
            assets[1] = getERC20(sourceChain, "USDT");
            _addAaveV3EOALeafs("Aave V3", getAddress(mainnet, "v3Pool"), leafs, assets);
            setAddress(true, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        }

        // ========================== Drone Transfers ==========================
        {
            ERC20[] memory localTokens = new ERC20[](2);
            localTokens[0] = getERC20("mainnet", "USDT");
            localTokens[1] = getERC20("mainnet", "USDC");

            _addLeafsForDroneTransfers(leafs, drone, localTokens);
            _addLeafsForDroneTransfers(leafs, drone1, localTokens);
        }

        // ========================== Fee Claiming ==========================
        {
            ERC20[] memory feeAssets = new ERC20[](2);
            feeAssets[0] = getERC20(sourceChain, "USDC");
            feeAssets[1] = getERC20(sourceChain, "USDT");
            _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);
        }

        // ========================= Scroll Native Bridge ==========================
        {
            setAddress(true, mainnet, "rawDataDecoderAndSanitizer", scrollBridgeDecoderAndSanitizer);
            ERC20[] memory tokens = new ERC20[](2);
            tokens[0] = getERC20(sourceChain, "USDC");
            tokens[1] = getERC20(sourceChain, "USDT");
            address[] memory scrollGateways = new address[](2);
            scrollGateways[0] = getAddress(scroll, "scrollUSDCGateway");
            scrollGateways[1] = getAddress(scroll, "scrollUSDTGateway");
            _addScrollNativeBridgeLeafs(leafs, "scroll", tokens, scrollGateways);
            setAddress(true, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        }

        // ========================== Standard Bridge to Optimism ==========================
        {
            setAddress(true, mainnet, "rawDataDecoderAndSanitizer", standardBridgeDecoderAndSanitizer);
            ERC20[] memory localTokens = new ERC20[](2);
            localTokens[0] = getERC20(sourceChain, "USDC");
            localTokens[1] = getERC20(sourceChain, "USDT");
            ERC20[] memory remoteTokens = new ERC20[](2);
            remoteTokens[0] = getERC20(optimism, "USDC");
            remoteTokens[1] = getERC20(optimism, "USDT");
            _addStandardBridgeLeafs(
                leafs,
                optimism,
                getAddress(optimism, "crossDomainMessenger"),
                getAddress(sourceChain, "optimismResolvedDelegate"),
                getAddress(sourceChain, "optimismStandardBridge"),
                getAddress(sourceChain, "optimismPortal"),
                localTokens,
                remoteTokens
            );
        }

        // ========================== CCTP Bridge ==========================
        setAddress(true, mainnet, "rawDataDecoderAndSanitizer", cctpDecoderAndSanitizer);
        _addCCTPBridgeLeafs(leafs, cctpOptimismDomainId);

        // ========================== CAP ==========================
        {
            setAddress(true, mainnet, "rawDataDecoderAndSanitizer", capDecoderAndSanitizer);
            address[] memory capDepositAssets = new address[](2);
            capDepositAssets[0] = getAddress(sourceChain, "USDT");
            capDepositAssets[1] = getAddress(sourceChain, "USDC");
            _addCapWithdrawLeafs(leafs, capDepositAssets);
            setAddress(true, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
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
            ERC20[] memory assets = new ERC20[](2);
            assets[0] = getERC20(sourceChain, "USDC");
            assets[1] = getERC20(sourceChain, "USDT");
            _addAaveV3EOALeafs("Aave V3", getAddress(mainnet, "v3Pool"), leafs, assets);
            setAddress(true, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        }

        // ========================== Merkl ==========================
        {
            _addMerklLeafs(leafs, getAddress(sourceChain, "merklDistributor"), getAddress(sourceChain, "etherfiOpsAddress")); 
        }

        _createDroneLeafs(leafs, drone, droneStartIndex, leafIndex + 1);
        setAddress(true, mainnet, "boringVault", boringVault);
    }

    function _addLeafsForDroneOne(ManageLeaf[] memory leafs) internal {
        setAddress(true, mainnet, "boringVault", drone1);
        uint256 drone1StartIndex = leafIndex + 1;

        // ========================== Aave V3 ==========================
        {
            setAddress(true, mainnet, "rawDataDecoderAndSanitizer", aaveV3DecoderAndSanitizer);
            ERC20[] memory assets = new ERC20[](2);
            assets[0] = getERC20(sourceChain, "USDC");
            assets[1] = getERC20(sourceChain, "USDT");
            _addAaveV3EOALeafs("Aave V3", getAddress(mainnet, "v3Pool"), leafs, assets);
            setAddress(true, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        }

        // ========================== Merkl ==========================
        {
            _addMerklLeafs(leafs, getAddress(sourceChain, "merklDistributor"), getAddress(sourceChain, "etherfiOpsAddress"));
        }

        //NOTE: ensure this is drone1 address
        _createDroneLeafs(leafs, drone1, drone1StartIndex, leafIndex + 1);
        setAddress(true, mainnet, "boringVault", boringVault);
    }

}
