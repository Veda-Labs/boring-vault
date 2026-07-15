// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 * liquidMonadETH — Monad strategy root.
 *
 *  source .env && forge script script/MerkleRootCreation/Monad/CreateLiquidMonadETHMerkleRoot.s.sol --rpc-url $MONAD_RPC_URL
 *
 * Strategy leaves:
 *   - Steakhouse Prime ETH Morpho vault (ERC4626, asset = WETH)
 *   - Morpho Blue wstETH/WETH market (supply, withdraw, collateral, borrow, repay)
 *   - Merkl claim (WMON)
 *   - WMON wrap / unwrap
 *   - Uniswap V4 MON/WETH swap
 *
 * Reverse-bridge leaves (Monad → Mainnet):
 *   - WETH via Wormhole NTT MultiToken Executor
 *   - wstETH via Chainlink CCIP (fee tokens: LINK or WMON)
 */
contract CreateLiquidMonadETHMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xA024063B630D554078bbF985718B22F3c6870EE0;
    address public managerAddress = 0xA4F58CCE8c5C42a313e12d3c8FBb983D5B8A09Ef;
    address public accountantAddress = 0x5ce04a3d8D5297A24bF752d0172064941D8d853b;
    address public rawDataDecoderAndSanitizer = 0x838fAc7f33231558185DA06d2F1F8dc3fcd5d7C7;
    address public morphoBlueDecoderAndSanitizer = 0x328277D7499709225434793E6c23ef47Aa5b76b3;

    function setUp() external {}

    function run() external {
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(monad);
        setAddress(false, monad, "boringVault", boringVault);
        setAddress(false, monad, "managerAddress", managerAddress);
        setAddress(false, monad, "accountantAddress", accountantAddress);
        setAddress(false, monad, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        // ========================== Steakhouse Prime ETH (ERC4626) ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "steakhousePrimeETHVault")));

        // ========================== Morpho Blue wstETH/WETH market ==========================
        // Morpho Blue leaves use a dedicated Morpho-only decoder & sanitizer.
        setAddress(true, monad, "rawDataDecoderAndSanitizer", morphoBlueDecoderAndSanitizer);
        bytes32 wstethWethMarketId = getBytes32(sourceChain, "morphoBlue_wstETH_WETH_marketId");
        _addMorphoBlueSupplyLeafs(leafs, wstethWethMarketId);
        _addMorphoBlueCollateralLeafs(leafs, wstethWethMarketId);
        _addMorphoBlueRepayLeafs(leafs, wstethWethMarketId);
        setAddress(true, monad, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        // ========================== Merkl rewards ==========================
        _addMerklClaimLeaf(leafs, getAddress(sourceChain, "merklDistributor"));

        // ========================== WMON wrap / unwrap ==========================
        _addNativeLeafs(leafs, getAddress(sourceChain, "WMON"));

        // ========================== Uniswap V4 — MON / WETH ==========================
        // Native MON on Uniswap V4 is address(0); the helper handles the sentinel conversion.
        // Pool key (fee 500, tickSpacing 1) is pinned to match uniV4_MON_WETH_poolId.
        {
            address[] memory v4Token0 = new address[](1);
            address[] memory v4Token1 = new address[](1);
            address[] memory v4Hooks = new address[](1);
            uint256[] memory v4Fees = new uint256[](1);
            uint256[] memory v4TickSpacings = new uint256[](1);
            v4Token0[0] = address(0);
            v4Token1[0] = getAddress(sourceChain, "WETH");
            v4Hooks[0] = address(0);
            v4Fees[0] = 500;
            v4TickSpacings[0] = 1;
            _addUniswapV4Leafs(leafs, v4Token0, v4Token1, v4Hooks, v4Fees, v4TickSpacings);
        }

        // ========================== Wormhole NTT — WETH → Mainnet ==========================
        _addWormholeNTTExecutorMultiTokenBridgeLeafs(
            leafs,
            getAddress(sourceChain, "wormholeMultiTokenExecutor"),
            getAddress(sourceChain, "wormholeMultiTokenNtt"),
            getERC20(sourceChain, "WETH"),
            uint16(wormholeMainnetChainId)
        );

        // ========================== CCIP — wstETH → Mainnet ==========================
        // The live Monad CCIP FeeQuoter accepts fees in LINK or the wrapped-native WMON
        // (router.getWrappedNative()), both of which the vault can hold.
        ERC20[] memory ccipBridgeAssets = new ERC20[](1);
        ccipBridgeAssets[0] = getERC20(sourceChain, "WSTETH");
        ERC20[] memory ccipFeeTokens = new ERC20[](2);
        ccipFeeTokens[0] = getERC20(sourceChain, "LINK");
        ccipFeeTokens[1] = getERC20(sourceChain, "WMON");
        _addCcipBridgeLeafs(leafs, ccipMainnetChainSelector, ccipBridgeAssets, ccipFeeTokens);

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Monad/LiquidMonadETHStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
