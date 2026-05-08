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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateSonicLBTCvMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */
contract CreateSonicLBTCvMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x309f25d839A2fe225E80210e110C99150Db98AAF;
    address public rawDataDecoderAndSanitizer = 0xE9527EA95a383993b41EA7D3b0E50DDA7B13dE94;
    address public managerAddress = 0x9D828035dd3C95452D4124870C110E7866ea6bb7;
    address public accountantAddress = 0x0639e239E417Ab9D1f0f926Fd738a012153930A7;

    address public oneInchOwnedDecoderAndSanitizer = 0x42842201E199E6328ADBB98e7C2CbE77561FAC88;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateSonicLBTCvStrategistMerkleRoot();
    }

    function generateSonicLBTCvStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        leafIndex = type(uint256).max;

        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](2);
        feeAssets[0] = getERC20(sourceChain, "LBTC");
        feeAssets[1] = getERC20(sourceChain, "EBTC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, true);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](3);
        SwapKind[] memory kind = new SwapKind[](3);
        assets[0] = getAddress(sourceChain, "LBTC");
        kind[0] = SwapKind.BuyAndSell;
            assets[1] = getAddress(sourceChain, "EBTC");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "scBTC");
        kind[2] = SwapKind.BuyAndSell;

        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", oneInchOwnedDecoderAndSanitizer);
        _addLeafsFor1InchOwnedGeneralSwapping(leafs, assets, kind);
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        // ========================== BoringVaults ==========================
        // Adding leaf to support bulk withdraw of EBTC for scBTC
        {
            ERC20[] memory eBTCTellerAssets = new ERC20[](1);
            eBTCTellerAssets[0] = getERC20(sourceChain, "LBTC");
            address eBTCTeller = 0x6Ee3aaCcf9f2321E49063C4F8da775DdBd407268;
            _addTellerLeafs(leafs, eBTCTeller, eBTCTellerAssets, false, false);

            address[] memory sonicBTCTellerAssets = new address[](2); 
            sonicBTCTellerAssets[0] = getAddress(sourceChain, "LBTC"); 
            sonicBTCTellerAssets[1] = getAddress(sourceChain, "EBTC");
            address sonicBTCTeller = 0xAce7DEFe3b94554f0704d8d00F69F273A0cFf079;
            address[] memory _feeAssets = new address[](1); 
            _feeAssets[0] = getAddress(sourceChain, "ETH"); //pay bridge fee in ETH\
            _addCrossChainTellerLeafs(leafs, sonicBTCTeller, sonicBTCTellerAssets, _feeAssets, abi.encode(layerZeroSonicMainnetEndpointId));

            // Add scBTC  teller to enable bulkWithdraw for LBTC
            ERC20[] memory scBTCTellerAssets = new ERC20[](2);
            scBTCTellerAssets[0] = getERC20(sourceChain, "LBTC");
            scBTCTellerAssets[1] = getERC20(sourceChain, "EBTC");
            address scBTCTeller = 0xAce7DEFe3b94554f0704d8d00F69F273A0cFf079;
            _addTellerLeafs(leafs, scBTCTeller, scBTCTellerAssets, false, true); // no native deposit, yes bulk operations

            // sonicBTC queue
            address scBTCOnChainQueue = 0x488000E6a0CfC32DCB3f37115e759aF50F55b48B;
            ERC20[] memory scBTCWithdrawQueueAssets = new ERC20[](2);
            scBTCWithdrawQueueAssets[0] = getERC20(sourceChain, "LBTC");
            scBTCWithdrawQueueAssets[1] = getERC20(sourceChain, "EBTC");
            _addWithdrawQueueLeafs(leafs, scBTCOnChainQueue, getAddress(sourceChain, "scBTC"), scBTCWithdrawQueueAssets);

            // eBTC slow queue
            address eBTCOnChainQueueSlow = 0x74EC75fb641ec17B04007733d9efBE2D1dA5CA2C;
            ERC20[] memory eBTCWithdrawQueueAssets = new ERC20[](1);
            eBTCWithdrawQueueAssets[0] = getERC20(sourceChain, "LBTC");
            _addWithdrawQueueLeafs(leafs, eBTCOnChainQueueSlow, getAddress(sourceChain, "EBTC"), eBTCWithdrawQueueAssets);
        }

        // ========================== CCIP ==========================
        bytes32 toChain = 0x0000000000000000000000000000000000000000000000000000000000000092; //sonic
        _addLBTCBridgeLeafs(leafs, toChain);

        console.log("Pre - Verify");
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);
        console.log("Post - Verify");
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        console.log("post - generate merkle tree");
        string memory filePath = "./leafs/Mainnet/SonicLBTCvStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
