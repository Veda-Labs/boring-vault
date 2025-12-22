// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { FixedPointMathLib } from "@solmate/utils/FixedPointMathLib.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { Strings } from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import { ERC4626 } from "@solmate/tokens/ERC4626.sol";
import { ManagerWithMerkleVerification } from "src/base/Roles/ManagerWithMerkleVerification.sol";
import { MerkleTreeHelper } from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateLiquidBeraBtcMerkleRoot.s.sol:CreateLiquidBeraBtcMerkleRoot --rpc-url $MAINNET_RPC_URL
 */
contract CreateLiquidBeraBtcMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xC673ef7791724f0dcca38adB47Fbb3AEF3DB6C80;
    address public managerAddress = 0x603064caAf2e76C414C5f7b6667D118322d311E6;
    address public accountantAddress = 0xF44BD12956a0a87c2C20113DdFe1537A442526B5;
    address public rawDataDecoderAndSanitizer = 0x41b7EeccC3FCc97cd17DF890b4A155d5325a9153;

    function setUp() external { }

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](128);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](4);
        SwapKind[] memory kind = new SwapKind[](4);
        assets[0] = getAddress(sourceChain, "WBTC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "LBTC");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "cbBTC");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "eBTC");
        kind[3] = SwapKind.BuyAndSell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Odos ==========================
        _addOdosSwapLeafs(leafs, assets, kind);

        // ========================== Teller ==========================

        {
            address eBTCTellerLZ = 0x6Ee3aaCcf9f2321E49063C4F8da775DdBd407268;
            ERC20[] memory tellerAssets = new ERC20[](3);
            tellerAssets[0] = getERC20(sourceChain, "WBTC");
            tellerAssets[1] = getERC20(sourceChain, "LBTC");
            tellerAssets[2] = getERC20(sourceChain, "cbBTC");
            _addTellerLeafs(leafs, eBTCTellerLZ, tellerAssets, false, true);
        }

        // ========================== Royco ==========================
        {
            bytes32 wbtcMarketHash = 0xb36f14fd392b9a1d6c3fabedb9a62a63d2067ca0ebeb63bbc2c93b11cc8eb3a2;
            address roycoFrontEndFeeRecipientTemp = 0x303907c6991B9058AB4aBd18B9c57B611FB81103; //this is what is used when there is no fee, I think, but waiting on confirmation from royco team on if they need us to use something specific
            _addRoycoWeirollLeafs(leafs, getERC20(sourceChain, "WBTC"), wbtcMarketHash, roycoFrontEndFeeRecipientTemp);

            bytes32 lbtcMarketHash = 0xabf4b2f17bc32faf4c3295b1347f36d21ec5629128d465b5569e600bf8d46c4f;
            _addRoycoWeirollLeafs(leafs, getERC20(sourceChain, "LBTC"), lbtcMarketHash, roycoFrontEndFeeRecipientTemp);
        }

        // ========================== Fee Claiming ==========================
        {
            ERC20[] memory feeAssets = new ERC20[](4);
            feeAssets[0] = getERC20(sourceChain, "WBTC");
            feeAssets[1] = getERC20(sourceChain, "LBTC");
            feeAssets[2] = getERC20(sourceChain, "cbBTC");
            feeAssets[3] = getERC20(sourceChain, "eBTC");
            _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, true);
        }

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "WBTC"),
            getAddress(sourceChain, "WBTCOFTAdapter"),
            layerZeroBerachainEndpointId,
            getBytes32(sourceChain, "boringVault")
        );
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "LBTC"),
            getAddress(sourceChain, "LBTCOFTAdapter"),
            layerZeroBerachainEndpointId,
            getBytes32(sourceChain, "boringVault")
        );

        // ========================== Crosschain Teller ==========================
        {
            address eBTCTellerLZ = 0x6Ee3aaCcf9f2321E49063C4F8da775DdBd407268;

            address[] memory depositAssets = new address[](3);
            depositAssets[0] = getAddress(sourceChain, "LBTC");
            depositAssets[1] = getAddress(sourceChain, "WBTC");
            depositAssets[2] = getAddress(sourceChain, "cbBTC");

            address[] memory feeAssets = new address[](1);
            feeAssets[0] = getAddress(sourceChain, "ETH"); //pay bridge fee in ETH

            _addCrossChainTellerLeafs(
                leafs, eBTCTellerLZ, depositAssets, feeAssets, abi.encode(layerZeroBerachainEndpointId)
            );
        }

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/LiquidBeraBtcStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
