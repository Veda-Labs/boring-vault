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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateBoostedUSDCMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateBoostedUSDCMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    //standard
    address public boringVault = 0xDbD87325D7b1189Dcc9255c4926076fF4a96A271;
    address public rawDataDecoderAndSanitizer = 0xB44B0976dBE7b958Ef451ab102d47452aB3cB29B;
    address public managerAddress = 0xEd23b12e7700BeB638562A22ED65f74291901c25;
    address public accountantAddress = 0x62A88Bea6fe527b5DEfAA103A3f8b5010205aF92;

    address public odosOwnedDecoderAndSanitizer = 0x6149c711434C54A48D757078EfbE0E2B2FE2cF6a;
    address public oneInchOwnedDecoderAndSanitizer = 0x42842201E199E6328ADBB98e7C2CbE77561FAC88;
    address public itbDecoderAndSanitizer = 0x2D7085602a85aFb417AE1dFcEc09C301FeC8Df36;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateStrategistMerkleRoot();
    }

    function generateStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](512);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](2);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        feeAssets[1] = getERC20(sourceChain, "USDT");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        // ========================== 1inch/Odos ==========================
        address[] memory assets = new address[](11);
        SwapKind[] memory kind = new SwapKind[](11);
        assets[0] = getAddress(sourceChain, "USDC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "USDT");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "SUSDE");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "SUSDS");
        kind[3] = SwapKind.BuyAndSell;
        assets[4] = getAddress(sourceChain, "USDS");
        kind[4] = SwapKind.BuyAndSell;
        assets[5] = getAddress(sourceChain, "USDE");
        kind[5] = SwapKind.BuyAndSell;
        assets[6] = getAddress(sourceChain, "RLUSD");
        kind[6] = SwapKind.BuyAndSell;
        assets[7] = getAddress(sourceChain, "USDG");
        kind[7] = SwapKind.BuyAndSell;
        assets[8] = getAddress(sourceChain, "GHO");
        kind[8] = SwapKind.BuyAndSell;
        assets[9] = getAddress(sourceChain, "stkGHO");
        kind[9] = SwapKind.BuyAndSell;
        assets[10] = getAddress(sourceChain, "PYUSD");
        kind[10] = SwapKind.BuyAndSell;
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", oneInchOwnedDecoderAndSanitizer);
        _addLeafsFor1InchOwnedGeneralSwapping(leafs, assets, kind);
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", odosOwnedDecoderAndSanitizer);
        _addOdosOwnedSwapLeafs(leafs, assets, kind);
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        // ========================== NativeWrapper ==========================
        _addNativeLeafs(leafs);

        // ========================== Aave V3 ==========================
        ERC20[] memory supplyAssets = new ERC20[](7);
        supplyAssets[0] = getERC20(sourceChain, "USDC");
        supplyAssets[1] = getERC20(sourceChain, "USDT");
        supplyAssets[2] = getERC20(sourceChain, "SUSDE");
        supplyAssets[3] = getERC20(sourceChain, "USDE");
        supplyAssets[4] = getERC20(sourceChain, "RLUSD");
        supplyAssets[5] = getERC20(sourceChain, "USDG");
        supplyAssets[6] = getERC20(sourceChain, "PYUSD");
        ERC20[] memory borrowAssets = new ERC20[](0);
        _addAaveV3Leafs(leafs, supplyAssets, borrowAssets);

        // ========================== Merkl Claim ==========================
        _addMerklLeafs(
            leafs, getAddress(sourceChain, "merklDistributor"), 0xe373248E02c5a342d453ecB8eBFC449b8BE70Bc1
        );

        // ========================== Sky Money ==========================
        _addAllSkyMoneyLeafs(leafs);

        // ========================== SUSDS ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "SUSDS")));

        // ========================== Ethena ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "SUSDE")));
        _addEthenaSUSDeWithdrawLeafs(leafs);

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(leafs, getERC20(sourceChain, "USDT"), getAddress(sourceChain, "usdt0OFTAdapter"), layerZeroInkEndpointId, getBytes32(sourceChain, "boringVault"));

        // ========================== CCTP ==========================
        _addCCTPBridgeLeafs(leafs, cctpInkDomainId);
        
        // ========================== SGHO ==========================
        _addSGHOLeafs(leafs);
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "waEthUSDC")));
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "waEthUSDT")));
        _addGHOGSMLeafs(leafs, getAddress(sourceChain, "gsmUsdc"), getERC20(sourceChain, "waEthUSDC"));
        _addGHOGSMLeafs(leafs, getAddress(sourceChain, "gsmUsdt"), getERC20(sourceChain, "waEthUSDT"));

        // ========================== Position Manager ==========================
        // Sentora PRIME main v2 (Morpho) — receipt vault sentoraPRIMEMain, token PYUSD
        {
            address primeMainV2PositionManager = 0x38Ae19114AB80b6EDE8B8fc22C6bc8b9fc6916be;
            ERC20[] memory primeMainV2TokensUsed = new ERC20[](1);
            primeMainV2TokensUsed[0] = getERC20(sourceChain, "PYUSD");
            _addLeafsForITBPositionManagerLocal(leafs, primeMainV2PositionManager, primeMainV2TokensUsed, "Sentora PRIME Main v2 Morpho ITB Position Manager");
        }

        // Sentora PYUSD main v2 (Morpho) — receipt vault sentoraPYUSDMain, token PYUSD
        {
            address pyusdMainV2PositionManager = 0x8B84E1Dd4624e2EF9dc54184B245ab992C74D8d0;
            ERC20[] memory pyusdMainV2TokensUsed = new ERC20[](1);
            pyusdMainV2TokensUsed[0] = getERC20(sourceChain, "PYUSD");
            _addLeafsForITBPositionManagerLocal(leafs, pyusdMainV2PositionManager, pyusdMainV2TokensUsed, "Sentora PYUSD Main v2 Morpho ITB Position Manager");
        }

        // Sentora RLUSD main v2 (Morpho) — receipt vault sentoraRLUSDMain, token RLUSD
        {
            address rlusdMainV2PositionManager = 0x7eD26B1bA3a9db0597Dc0296568e4A1e2770d5e0;
            ERC20[] memory rlusdMainV2TokensUsed = new ERC20[](1);
            rlusdMainV2TokensUsed[0] = getERC20(sourceChain, "RLUSD");
            _addLeafsForITBPositionManagerLocal(leafs, rlusdMainV2PositionManager, rlusdMainV2TokensUsed, "Sentora RLUSD Main v2 Morpho ITB Position Manager");
        }

        // ========================== Verify ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/BoostedUSDCStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function _addLeafsForITBPositionManagerLocal(
        ManageLeaf[] memory leafs,
        address itbPositionManager,
        ERC20[] memory tokensUsed,
        string memory itbContractName
    ) internal {
        // acceptOwnership
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "acceptOwnership()",
            new address[](0),
            string.concat("Accept ownership of the ", itbContractName, " contract"),
            itbDecoderAndSanitizer
        );

        // removeExecutor
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "removeExecutor(address)",
            new address[](0),
            string.concat("Remove executor from the ", itbContractName, " contract"),
            itbDecoderAndSanitizer
        );

        // Withdraw
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "withdraw(address,uint256)",
            new address[](0),
            string.concat("Withdraw from the ", itbContractName, " contract"),
            itbDecoderAndSanitizer
        );
        // WithdrawAll
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "withdrawAll(address)",
            new address[](0),
            string.concat("Withdraw all from the ", itbContractName, " contract"),
            itbDecoderAndSanitizer
        );

        for (uint256 i; i < tokensUsed.length; ++i) {
            // Transfer
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(tokensUsed[i]),
                false,
                "transfer(address,uint256)",
                new address[](1),
                string.concat("Transfer ", tokensUsed[i].symbol(), " to the ", itbContractName, " contract"),
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = itbPositionManager;
        }
    }
}
