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

contract CreateMultichainLiquidEthOperationalMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xf0bb20865277aBd641a307eCe5Ee04E79073416C;
    address public rawDataDecoderAndSanitizer = 0x8fB043d30BAf4Eba2C8f7158aCBc07ec9A53Fe85;
    address public managerAddress = 0xf9f7969C357ce6dfd7973098Ea0D57173592bCCa;
    address public accountantAddress = 0x0d05D94a5F1E76C18fbeB7A13d17C8a314088198;
    address public drone = 0x0a42b2F3a0D54157Dbd7CC346335A4F1909fc02c;

    address public itbDecoderAndSanitizer = 0xEEb53299Cb894968109dfa420D69f0C97c835211;
    address public itbReserveProtocolPositionManager = 0x778aC5d0EE062502fADaa2d300a51dE0869f7995;
    address public itbAaveLidoPositionManager = 0xC4F5Ee078a1C4DA280330546C29840d45ab32753;
    address public itbAaveLidoPositionManager2 = 0x572F323Aa330B467C356c5a30Bf9A20480F4fD52;

    address public scrollBridgeDecoderAndSanitizer = 0xA66a6B289FB5559b7e4ebf598B8e0A97C776c200;
    address public kingClaimingDecoderAndSanitizer = 0xd4067b594C6D48990BE42a559C8CfDddad4e8D6F;

    function setUp() external {}

    function run() external {
        generateLiquidEthOperationalStrategistMerkleRoot();
    }

    function generateLiquidEthOperationalStrategistMerkleRoot() public {

        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](256);
        leafIndex = 0;


        // ========================== UniswapV3 ==========================
        {
            address[] memory token0 = new address[](6);
            token0[0] = getAddress(sourceChain, "RLUSD");
            token0[1] = getAddress(sourceChain, "RLUSD");
            token0[2] = getAddress(sourceChain, "USDC");
            token0[3] = getAddress(sourceChain, "EIGEN");
            token0[4] = getAddress(sourceChain, "rEUL");
            token0[5] = getAddress(sourceChain, "MNT");

            address[] memory token1 = new address[](6);
            token1[0] = getAddress(sourceChain, "USDC");
            token1[1] = getAddress(sourceChain, "WETH");
            token1[2] = getAddress(sourceChain, "WETH");
            token1[3] = getAddress(sourceChain, "WETH");
            token1[4] = getAddress(sourceChain, "WETH");
            token1[5] = getAddress(sourceChain, "WETH");

            bool swapRouter02 = false;
            _addUniswapV3OneWaySwapLeafs(leafs, token0, token1, swapRouter02);
        }

        // ========================== Odos ==========================
        {
            address RLUSD = getAddress(sourceChain, "RLUSD");
            address USDC = getAddress(sourceChain, "USDC");
            address WETH = getAddress(sourceChain, "WETH");
            address EIGEN = getAddress(sourceChain, "EIGEN");
            address rEUL = getAddress(sourceChain, "rEUL");
            address MNT = getAddress(sourceChain, "MNT");

            _addOdosOneWaySwapLeafs(leafs, RLUSD, USDC);
            _addOdosOneWaySwapLeafs(leafs, RLUSD, WETH);
            _addOdosOneWaySwapLeafs(leafs, USDC, WETH);
            _addOdosOneWaySwapLeafs(leafs, EIGEN, WETH);
            _addOdosOneWaySwapLeafs(leafs, rEUL, WETH);
            _addOdosOneWaySwapLeafs(leafs, MNT, WETH);
        }

        // ========================== Merkl ==========================
        {
            _addMerklClaimLeaf(leafs, getAddress(sourceChain, "merklDistributor"));
        }

        // ========================== EtherFi ==========================
        {
            _addEtherFiLeafs(leafs);
        }

        // =========================== ITB =============================
        {
            setAddress(true, mainnet, "rawDataDecoderAndSanitizer", itbDecoderAndSanitizer);
            ERC20[] memory tokens = new ERC20[](7);
            tokens[0] = getERC20(sourceChain, "SFRXETH");
            tokens[1] = getERC20(sourceChain, "WSTETH");
            tokens[2] = getERC20(sourceChain, "RETH");
            tokens[3] = getERC20(sourceChain, "ETHX");
            tokens[4] = getERC20(sourceChain, "WETH");
            tokens[5] = getERC20(sourceChain, "WEETH");
            tokens[6] = getERC20(sourceChain, "WSTETH");

            _addITBPositionManagerWithdrawals(leafs, itbReserveProtocolPositionManager, tokens, "itb reserve position manager");
            _addITBPositionManagerWithdrawals(leafs, itbAaveLidoPositionManager, tokens, "itb aave position manager 1");
            _addITBPositionManagerWithdrawals(leafs, itbAaveLidoPositionManager2, tokens, "itb aave position manager 2");
            setAddress(true, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        }


        // ========================== Scroll Bridge ==========================
        {
            setAddress(true, mainnet, "rawDataDecoderAndSanitizer", scrollBridgeDecoderAndSanitizer);
            ERC20[] memory tokens = new ERC20[](1);
            tokens[0] = getERC20(sourceChain, "WETH");
            address[] memory scrollGateways = new address[](1);
            scrollGateways[0] = getAddress(scroll, "scrollWETHGateway");
            _addScrollNativeBridgeLeafs(leafs, "scroll", tokens, scrollGateways);
            setAddress(true, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        }

        // ========================== Plasma Bridging ==========================
        {
            // USDT
            _addLayerZeroLeafs(
                leafs,
                getERC20(sourceChain, "USDT"),
                getAddress(sourceChain, "usdt0OFTAdapter"),
                layerZeroPlasmaEndpointId,
                getBytes32(sourceChain, "boringVault")
            );
            // ETH
            _addLayerZeroLeafNative(
                leafs,
                getAddress(sourceChain, "stargateNative"),
                layerZeroPlasmaEndpointId,
                getBytes32(sourceChain, "boringVault")
            );
            // WEETH
            _addLayerZeroLeafs(
                leafs,
                getERC20(sourceChain, "WEETH"),
                getAddress(sourceChain, "EtherFiOFTAdapter"),
                layerZeroPlasmaEndpointId,
                getBytes32(sourceChain, "boringVault")
            );
        }

        // ========================== Drone ==========================
        {
            ERC20[] memory droneTransferTokens = new ERC20[](5);
            droneTransferTokens[0] = getERC20(sourceChain, "USDC"); 
            droneTransferTokens[1] = getERC20(sourceChain, "RLUSD");
            droneTransferTokens[2] = getERC20(sourceChain, "EIGEN");
            droneTransferTokens[3] = getERC20(sourceChain, "rEUL");
            droneTransferTokens[4] = getERC20(sourceChain, "MNT");

            _addLeafsForDroneTransfers(leafs, drone, droneTransferTokens);
            _addLeafsForDrone(leafs, drone);
        }

        // ==================== KING Claiming ========================
        setAddress(true, mainnet, "rawDataDecoderAndSanitizer", kingClaimingDecoderAndSanitizer);
        _addKingRewardsClaimingLeafs(leafs, new address[](0), getAddress(sourceChain, "boringVault"));
        setAddress(true, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        // ========================== Finalize ===================================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        string memory filePath = "./leafs/Mainnet/MultiChainLiquidEthOperationalStrategistLeafs.json";
        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function _addLeafsForDrone(ManageLeaf[] memory leafs, address _drone) internal {
        setAddress(true, mainnet, "boringVault", _drone);
        uint256 droneStartIndex = leafIndex + 1;

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](6);
        token0[0] = getAddress(sourceChain, "RLUSD");
        token0[1] = getAddress(sourceChain, "RLUSD");
        token0[2] = getAddress(sourceChain, "USDC");
        token0[3] = getAddress(sourceChain, "EIGEN");
        token0[4] = getAddress(sourceChain, "rEUL");
        token0[5] = getAddress(sourceChain, "MNT");

        address[] memory token1 = new address[](6);
        token1[0] = getAddress(sourceChain, "USDC");
        token1[1] = getAddress(sourceChain, "WETH");
        token1[2] = getAddress(sourceChain, "WETH");
        token1[3] = getAddress(sourceChain, "WETH");
        token1[4] = getAddress(sourceChain, "WETH");
        token1[5] = getAddress(sourceChain, "WETH");

        bool swapRouter02 = false;
        _addUniswapV3OneWaySwapLeafs(leafs, token0, token1, swapRouter02);

        // ========================== Odos ==========================
        {
            address RLUSD = getAddress(sourceChain, "RLUSD");
            address USDC = getAddress(sourceChain, "USDC");
            address WETH = getAddress(sourceChain, "WETH");
            address EIGEN = getAddress(sourceChain, "EIGEN");
            address rEUL = getAddress(sourceChain, "rEUL");
            address MNT = getAddress(sourceChain, "MNT");

            _addOdosOneWaySwapLeafs(leafs, RLUSD, USDC);
            _addOdosOneWaySwapLeafs(leafs, RLUSD, WETH);
            _addOdosOneWaySwapLeafs(leafs, USDC, WETH);
            _addOdosOneWaySwapLeafs(leafs, EIGEN, WETH);
            _addOdosOneWaySwapLeafs(leafs, rEUL, WETH);
            _addOdosOneWaySwapLeafs(leafs, MNT, WETH);
        }

        // ========================== Merkl ==========================
        {
            _addMerklClaimLeaf(leafs, getAddress(sourceChain, "merklDistributor"));
        }

        // ========================== EtherFi ==========================
        {
            _addEtherFiLeafs(leafs);
        }

        _createDroneLeafs(leafs, _drone, droneStartIndex, leafIndex + 1);
        setAddress(true, mainnet, "boringVault", boringVault);
    }

     function _addITBPositionManagerWithdrawals(
         ManageLeaf[] memory leafs,
         address itbPositionManager,
         ERC20[] memory tokensUsed,
         string memory itbContractName
     ) internal {

         for (uint256 i; i < tokensUsed.length; ++i) {
             // Withdraw
             leafIndex++;
             leafs[leafIndex] = ManageLeaf(
                 itbPositionManager,
                 false,
                 "withdraw(address,uint256)",
                 new address[](0),
                 string.concat("Withdraw ", tokensUsed[i].symbol(), " from the ", itbContractName, " contract"),
                 getAddress(sourceChain, "rawDataDecoderAndSanitizer")
             );
             // WithdrawAll
             leafIndex++;
             leafs[leafIndex] = ManageLeaf(
                 itbPositionManager,
                 false,
                 "withdrawAll(address)",
                 new address[](0),
                 string.concat("Withdraw all ", tokensUsed[i].symbol(), " from the ", itbContractName, " contract"),
                 getAddress(sourceChain, "rawDataDecoderAndSanitizer")
             );
         }
     }
}
