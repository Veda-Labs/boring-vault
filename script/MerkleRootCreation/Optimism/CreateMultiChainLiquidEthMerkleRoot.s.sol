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
 *  source .env && forge script script/MerkleRootCreation/Optimism/CreateMultiChainLiquidEthMerkleRoot.s.sol:CreateMultiChainLiquidEthMerkleRootScript --rpc-url $OPTIMISM_RPC_URL
 */
contract CreateMultiChainLiquidEthMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xf0bb20865277aBd641a307eCe5Ee04E79073416C;
    address public rawDataDecoderAndSanitizer = 0x712Dbd2265a194Fe66D7db3F3988A92338bBFAE1;
    address public midasVaultDecoderAndSanitizer = 0x7fc0F133Cb0a3B9C4186121C514E7830092111dC;
    address public managerAddress = 0x227975088C28DBBb4b421c6d96781a53578f19a8;
    address public accountantAddress = 0x0d05D94a5F1E76C18fbeB7A13d17C8a314088198;


    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateMultiChainLiquidEthStrategistMerkleRoot();
    }

    function generateMultiChainLiquidEthStrategistMerkleRoot() public {
        setSourceChainName(optimism);
        setAddress(false, optimism, "boringVault", boringVault);
        setAddress(false, optimism, "managerAddress", managerAddress);
        setAddress(false, optimism, "accountantAddress", accountantAddress);
        setAddress(false, optimism, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);

        // ========================== Native ==========================
        /**
         * wrap, unwrap
         */
        _addNativeLeafs(leafs);


        // ========================== Fee Claiming ==========================
        /**
         * Claim fees in WETH, WEETH
         */
        ERC20[] memory feeAssets = new ERC20[](2);
        feeAssets[0] = getERC20(sourceChain, "WETH");
        feeAssets[1] = getERC20(sourceChain, "WEETH_OFT");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        // ===================== EtherFi ==========================
        _addWeETHLeafs(leafs, getAddress(sourceChain, "ETH"), getAddress(sourceChain, "boringVault"));


        // ========================== Standard Bridge ==========================
        ERC20[] memory localTokens = new ERC20[](1);
        localTokens[0] = getERC20(sourceChain, "USDT");

        ERC20[] memory remoteTokens = new ERC20[](1);
        remoteTokens[0] = getERC20(mainnet, "USDT");

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

        // CCTP Bridge
        _addCCTPBridgeLeafs(leafs, cctpMainnetDomainId);

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "WEETH_OFT"), getAddress(sourceChain, "WEETH_OFT"), layerZeroMainnetEndpointId, getBytes32(sourceChain, "boringVault"));   

        // ===================== Midas Vault ==========================
        setAddress(true, optimism, "rawDataDecoderAndSanitizer", midasVaultDecoderAndSanitizer);
        ERC20[] memory midasVaultTokens = new ERC20[](2);
        midasVaultTokens[0] = getERC20(sourceChain, "USDC");
        midasVaultTokens[1] = getERC20(sourceChain, "USDT");

        ERC20[] memory midasVaultRedeemAssets = new ERC20[](1);
        midasVaultRedeemAssets[0] = getERC20(sourceChain, "USDC");

        _addMidasVaultLeafs(leafs, midasVaultTokens, midasVaultRedeemAssets, getAddress(sourceChain, "liquidRWA"), getAddress(sourceChain, "liquidRWA_DepositAdapter"), getAddress(sourceChain, "liquidRWA_RedemptionVault"));
        setAddress(true, optimism, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Optimism/MultiChainLiquidEthStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

}
