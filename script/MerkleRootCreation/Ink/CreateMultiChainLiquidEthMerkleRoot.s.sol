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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateMultiChainLiquidEthMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL --gas-limit 100000000000000000
 */
contract CreateMultiChainLiquidEthMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xf0bb20865277aBd641a307eCe5Ee04E79073416C;
    address public rawDataDecoderAndSanitizer = 0x8fB043d30BAf4Eba2C8f7158aCBc07ec9A53Fe85;
    address public managerAddress = 0xf9f7969C357ce6dfd7973098Ea0D57173592bCCa;
    address public accountantAddress = 0x0d05D94a5F1E76C18fbeB7A13d17C8a314088198;
    address public pancakeSwapDataDecoderAndSanitizer = 0xfdC73Fc6B60e4959b71969165876213918A443Cd;
    //address public scrollBridgeDecoderAndSanitizer = 0xA66a6B289FB5559b7e4ebf598B8e0A97C776c200;
    //address public itbDecoderAndSanitizer = 0xEEb53299Cb894968109dfa420D69f0C97c835211;
    //address public itbAaveDecoderAndSanitizer = 0x7fA5dbDB1A76d2990Ea0f3c74e520E3fcE94748B;
    //address public itbReserveProtocolPositionManager = 0x778aC5d0EE062502fADaa2d300a51dE0869f7995;
    //address public itbAaveLidoPositionManager = 0xC4F5Ee078a1C4DA280330546C29840d45ab32753;
    //address public itbAaveLidoPositionManager2 = 0x572F323Aa330B467C356c5a30Bf9A20480F4fD52;
    //address public hyperlaneDecoderAndSanitizer = 0xfC823909C7D2Cb8701FE7d6EE74508C57Df1D6dE;
    //address public termFinanceDecoderAndSanitizer = 0xF8e9517e7e98D7134E306aD3747A50AC8dC1dbc9;
    //address public kingClaimingDecoderAndSanitizer = 0xd4067b594C6D48990BE42a559C8CfDddad4e8D6F;

    //address public itbCorkDecoderAndSanitizer = 0x457Cce6Ec3fEb282952a7e50a1Bc727Ca235Eb0a;

    //address public drone = 0x0a42b2F3a0D54157Dbd7CC346335A4F1909fc02c;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateLiquidEthStrategistMerkleRoot();
    }

    function generateLiquidEthStrategistMerkleRoot() public {
        setSourceChainName(ink);
        setAddress(false, ink, "boringVault", boringVault);
        setAddress(false, ink, "managerAddress", managerAddress);
        setAddress(false, ink, "accountantAddress", accountantAddress);
        setAddress(false, ink, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](4096);

        // ========================== Aave V3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](2);
        supplyAssets[0] = getERC20(sourceChain, "WETH");
        supplyAssets[1] = getERC20(sourceChain, "WEETH");
        ERC20[] memory borrowAssets = new ERC20[](2);
        borrowAssets[0] = getERC20(sourceChain, "WETH");
        borrowAssets[1] = getERC20(sourceChain, "WEETH");
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

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

        // ========================== Standard Bridge ==========================
        ERC20[] memory localTokens = new ERC20[](0);
        ERC20[] memory remoteTokens = new ERC20[](0);
        //localTokens[0] = getERC20(sourceChain, "WETH");
        //remoteTokens[0] = getERC20(mainnet, "WETH");
        _addStandardBridgeLeafs(
            leafs,
            mainnet,
            address(0),
            address(0),
            getAddress(sourceChain, "standardBridge"),
            address(0),
            localTokens,
            remoteTokens
        );


        // ========================== LayerZero ==========================
        {
            _addLayerZeroLeafs(
                leafs,
                getERC20(sourceChain, "WEETH"),
                getAddress(sourceChain, "WEETH"),
                layerZeroMainnetEndpointId,
                getBytes32(sourceChain, "boringVault")
            );

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Ink/MainnetMultiChainLiquidEthStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
