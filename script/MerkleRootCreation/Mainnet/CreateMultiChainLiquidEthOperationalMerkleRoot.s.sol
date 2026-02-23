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

// source .env && forge script script/MerkleRootCreation/Mainnet/CreateMultiChainLiquidEthOperationalMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL --gas-limit 100000000000000000

contract CreateMultichainLiquidEthOperationalMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xf0bb20865277aBd641a307eCe5Ee04E79073416C;
    address public rawDataDecoderAndSanitizer = 0x8fB043d30BAf4Eba2C8f7158aCBc07ec9A53Fe85;
    address public capDecoderAndSanitizer = 0xE0e86bf98dAA0D2b408Cb038E94bCB9B7864309C;
    address public managerAddress = 0xf9f7969C357ce6dfd7973098Ea0D57173592bCCa;
    address public accountantAddress = 0x0d05D94a5F1E76C18fbeB7A13d17C8a314088198;
    address public drone = 0x0a42b2F3a0D54157Dbd7CC346335A4F1909fc02c;

    address public itbReserveProtocolPositionManager = 0x778aC5d0EE062502fADaa2d300a51dE0869f7995;
    address public itbPositionManager2 = 0xA40aFb15275A94F64aF37C0cEaAaA45Cb568A361;
    address public itbPositionManager3 = 0x2A601FC6C0Cb854fDA82715E49Ab04C5340A0396;

    // The cork decoder and sanitizer relaxes restrictions around which tokens can be withdrawn
    address public itbCorkDecoderAndSanitizer = 0x457Cce6Ec3fEb282952a7e50a1Bc727Ca235Eb0a;

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
            address[] memory token0 = new address[](3);
            token0[0] = getAddress(sourceChain, "EIGEN");
            token0[1] = getAddress(sourceChain, "rEUL");
            token0[2] = getAddress(sourceChain, "MNT");

            address[] memory token1 = new address[](3);
            token1[0] = getAddress(sourceChain, "WETH");
            token1[1] = getAddress(sourceChain, "WETH");
            token1[2] = getAddress(sourceChain, "WETH");

            bool swapRouter02 = false;
            _addUniswapV3OneWaySwapLeafs(leafs, token0, token1, swapRouter02);
        }

        // ========================== Odos ==========================
        {
            address WETH = getAddress(sourceChain, "WETH");
            address EIGEN = getAddress(sourceChain, "EIGEN");
            address rEUL = getAddress(sourceChain, "rEUL");
            address MNT = getAddress(sourceChain, "MNT");
            address EUL = getAddress(sourceChain, "EUL");
            address axlSAGA = getAddress(sourceChain, "axlSAGA");
            address PENDLE = getAddress(sourceChain, "PENDLE");

            _addOdosOneWaySwapLeafs(leafs, EIGEN, WETH);
            _addOdosOneWaySwapLeafs(leafs, rEUL, WETH);
            _addOdosOneWaySwapLeafs(leafs, MNT, WETH);
            _addOdosOneWaySwapLeafs(leafs, EUL, WETH);
            _addOdosOneWaySwapLeafs(leafs, axlSAGA, WETH);
            _addOdosOneWaySwapLeafs(leafs, PENDLE, WETH);
        }

        // ========================== Merkl ==========================
        {
            _addMerklClaimLeaf(leafs, getAddress(sourceChain, "merklDistributor"));
        }

        // ========================== EtherFi ==========================
        {
            _addEtherFiLeafs(leafs);
        }

        // ========================== Native ==========================
        _addNativeLeafs(leafs);

        // =========================== ITB =============================
        {
            setAddress(true, mainnet, "rawDataDecoderAndSanitizer", itbCorkDecoderAndSanitizer);
            ERC20[] memory tokens = new ERC20[](9);
            tokens[0] = getERC20(sourceChain, "SFRXETH");
            tokens[1] = getERC20(sourceChain, "WSTETH");
            tokens[2] = getERC20(sourceChain, "RETH");
            tokens[3] = getERC20(sourceChain, "ETHX");
            tokens[4] = getERC20(sourceChain, "WETH");
            tokens[5] = getERC20(sourceChain, "WEETH");
            tokens[6] = getERC20(sourceChain, "WSTETH");
            tokens[7] = getERC20(sourceChain, "RLUSD");
            tokens[8] = getERC20(sourceChain, "PYUSD");

            _addITBPositionManagerWithdrawals(leafs, itbReserveProtocolPositionManager, tokens, "itb reserve position manager");
            _addITBPositionManagerWithdrawals(leafs, itbPositionManager2, tokens, "itb position manager 2");
            _addITBPositionManagerWithdrawals(leafs, itbPositionManager3, tokens, "itb position manager 3");
            setAddress(true, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
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
        // ========================== Fee Claiming ==========================
        {
            ERC20[] memory feeAssets = new ERC20[](2);
            feeAssets[0] = getERC20(sourceChain, "WEETH");
            feeAssets[1] = getERC20(sourceChain, "WETH");
            _addLeafsForFeeClaiming(
                leafs,
                getAddress(sourceChain, "accountantAddress"),
                feeAssets, false);
        }

        // ========================= AAVE ===============================
        {
            ERC20[] memory supplyAssets = new ERC20[](2);
            supplyAssets[0] = getERC20(sourceChain, "WEETH");
            supplyAssets[1] = getERC20(sourceChain, "WETH");
            _addAaveV3EOALeafs("Aave V3", getAddress(sourceChain, "v3Pool"), leafs, supplyAssets);
        }

      // ========================== Plasma Bridging ==========================
        // USDT
        {
            _addLayerZeroLeafs(
                leafs,
                getERC20(sourceChain, "USDT"),
                getAddress(sourceChain, "usdt0OFTAdapter"),
                layerZeroPlasmaEndpointId,
                getBytes32(sourceChain, "boringVault")
            );
        }

        // ========================== LayerZero WEETH =========================

        {
            _addLayerZeroLeafs(
                leafs,
                getERC20(sourceChain, "WEETH"),
                getAddress(sourceChain, "EtherFiOFTAdapter"),
                layerZeroPlasmaEndpointId,
                getBytes32(sourceChain, "boringVault")
            );

                _addLayerZeroLeafs(
                    leafs,
                    getERC20(sourceChain, "WEETH"),
                    getAddress(sourceChain, "EtherFiOFTAdapter"),
                    layerZeroScrollEndpointId,
                    getBytes32(sourceChain, "boringVault")
                );
        }

        // ========================== Cap =======================================
        {
            setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", capDecoderAndSanitizer);
            address[] memory capDepositAssets = new address[](3);
            capDepositAssets[0] = getAddress(sourceChain, "USDC");
            capDepositAssets[1] = getAddress(sourceChain, "USDT");
            capDepositAssets[2] = getAddress(sourceChain, "PYUSD");
            _addCapWithdrawLeafs(leafs, capDepositAssets);
            setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
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
        address[] memory token0 = new address[](3);
        token0[0] = getAddress(sourceChain, "EIGEN");
        token0[1] = getAddress(sourceChain, "rEUL");
        token0[2] = getAddress(sourceChain, "MNT");

        address[] memory token1 = new address[](3);
        token1[0] = getAddress(sourceChain, "WETH");
        token1[1] = getAddress(sourceChain, "WETH");
        token1[2] = getAddress(sourceChain, "WETH");

        bool swapRouter02 = false;
        _addUniswapV3OneWaySwapLeafs(leafs, token0, token1, swapRouter02);

        // ========================== Odos ==========================
        {
            address WETH = getAddress(sourceChain, "WETH");
            address EIGEN = getAddress(sourceChain, "EIGEN");
            address rEUL = getAddress(sourceChain, "rEUL");
            address MNT = getAddress(sourceChain, "MNT");

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

        // ========================== Native ==========================
        _addNativeLeafs(leafs);


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
