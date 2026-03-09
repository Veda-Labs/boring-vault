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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateLiquidBeraEthMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */
contract CreateLiquidBeraEthMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x83599937c2C9bEA0E0E8ac096c6f32e86486b410;
    address public managerAddress = 0x62b283d4FeFB2a120e1120dba9f83bE6CA41bCD7;
    address public accountantAddress = 0x04B8136820598A4e50bEe21b8b6a23fE25Df9Bd8;
    address public rawDataDecoderAndSanitizer = 0xf2842b0a7e26B5A40132DCeC8118a24851e05048;
    address public liquidEthTeller = 0x9AA79C84b79816ab920bBcE20f8f74557B514734;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateLiquidBeraEthStrategistMerkleRoot();
    }

    function generateLiquidBeraEthStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, mainnet, "liquidEthTeller", liquidEthTeller);

        ManageLeaf[] memory leafs = new ManageLeaf[](128);

        ERC20[] memory eEthAssets = new ERC20[](3);
        eEthAssets[0] = getERC20(sourceChain, "EETH");
        eEthAssets[1] = getERC20(sourceChain, "WEETH");
        eEthAssets[2] = getERC20(sourceChain, "WETH");

        _addTellerLeafs(leafs, getAddress(sourceChain, "liquidEthTeller"), eEthAssets, false, true);

        // ========================== Swaps ==========================
        address[] memory assets = new address[](5);
        SwapKind[] memory kind = new SwapKind[](5);
        assets[0] = getAddress(sourceChain, "WETH");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "WEETH");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "EETH");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "STETH");
        kind[3] = SwapKind.BuyAndSell;
        assets[4] = getAddress(sourceChain, "WSTETH");
        kind[4] = SwapKind.BuyAndSell;

        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);
        _addOdosSwapLeafs(leafs, assets, kind);

        // ========================== Lido ==========================
        _addLidoLeafs(leafs);

        // ========================== EtherFi ==========================
        /**
         * stake, unstake, wrap, unwrap
         */
        _addEtherFiLeafs(leafs);

        // ========================== Native ==========================
        /**
         * wrap, unwrap
         */
        _addNativeLeafs(leafs);

        // ========================== Royco ==========================
        {
            bytes32 wethMarketHash = 0x0484203315d701daff0d6dbdd55c49c3f220c3c7b917892bed1badb8fdc0182e;
            address roycoFrontEndFeeRecipientTemp = 0x303907c6991B9058AB4aBd18B9c57B611FB81103; //this is what is used when there is no fee, I think, but waiting on confirmation from royco team on if they need us to use something specific
            _addRoycoWeirollLeafs(leafs, getERC20(sourceChain, "WETH"), wethMarketHash, roycoFrontEndFeeRecipientTemp);

            bytes32 weethMarketHash = 0xff0182973d5f1e9a64392c413caaa75f364f24632a7de0fdd1a31fe30517fdd2;
            _addRoycoWeirollLeafs(leafs, getERC20(sourceChain, "WEETH"), weethMarketHash, roycoFrontEndFeeRecipientTemp);
        }

        // ========================== LayerZero ==========================
        _addLayerZeroLeafNative(
            leafs,
            getAddress(sourceChain, "stargateNative"),
            layerZeroBerachainEndpointId,
            getBytes32(sourceChain, "boringVault")
        );
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "WEETH"),
            getAddress(sourceChain, "EtherFiOFTAdapter"),
            layerZeroBerachainEndpointId,
            getBytes32(sourceChain, "boringVault")
        );

        // ========================== Fee Claiming ==========================
        /**
         * Claim fees in WETH, WEETH, EETH, STETH, WSTETH
         */
        ERC20[] memory feeAssets = new ERC20[](5);
        feeAssets[0] = getERC20(sourceChain, "WETH");
        feeAssets[1] = getERC20(sourceChain, "WEETH");
        feeAssets[2] = getERC20(sourceChain, "EETH");
        feeAssets[3] = getERC20(sourceChain, "STETH");
        feeAssets[4] = getERC20(sourceChain, "WSTETH");
        _addLeafsForFeeClaiming(leafs, accountantAddress, feeAssets, false);

        //Verify

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/LiquidBeraEthStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
