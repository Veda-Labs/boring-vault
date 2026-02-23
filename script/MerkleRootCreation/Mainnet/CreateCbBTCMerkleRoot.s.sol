// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateCbBTCMerkleRoot.s.sol:CreateCbBTCMerkleRootScript --rpc-url $MAINNET_RPC_URL
 */
contract CreateCbBTCMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x42A03534DBe07077d705311854E3B6933dD6Af85;
    address public managerAddress = 0xcb4647c77688489655F45bB5bac42E14a0b05F85;
    address public accountantAddress = 0x1c217f17d57d3CCD1CB3d8CB16B21e8f0b544156;
    address public rawDataDecoderAndSanitizer = 0x422B5a85Cc4710E3a2E3BaEBE1b11769B29A720f;

    address public odosOwnedDecoderAndSanitizer = 0x6149c711434C54A48D757078EfbE0E2B2FE2cF6a;
    address public oneInchOwnedDecoderAndSanitizer = 0x42842201E199E6328ADBB98e7C2CbE77561FAC88;

    function setUp() external {}

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

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](3);
        token0[0] = getAddress(sourceChain, "WBTC");
        token0[1] = getAddress(sourceChain, "WBTC");
        token0[2] = getAddress(sourceChain, "TBTC");

        address[] memory token1 = new address[](3);
        token1[0] = getAddress(sourceChain, "cbBTC");
        token1[1] = getAddress(sourceChain, "TBTC");
        token1[2] = getAddress(sourceChain, "cbBTC");

        _addUniswapV3Leafs(leafs, token0, token1, false);

        // ========================== 1inch/Odos ==========================
        address[] memory assets = new address[](6);
        SwapKind[] memory kind = new SwapKind[](6);
        assets[0] = getAddress(sourceChain, "WBTC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "cbBTC");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "TBTC");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "PENDLE");
        kind[3] = SwapKind.Sell;
        assets[4] = getAddress(sourceChain, "LBTC");
        kind[4] = SwapKind.BuyAndSell;
        assets[5] = getAddress(sourceChain, "eBTC");
        kind[5] = SwapKind.BuyAndSell;

        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", oneInchOwnedDecoderAndSanitizer);
        _addLeafsFor1InchOwnedGeneralSwapping(leafs, assets, kind);
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", odosOwnedDecoderAndSanitizer);
        _addOdosOwnedSwapLeafs(leafs, assets, kind);
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        // ========================== Pendle ==========================
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_eBTC_market_12_26_24"), true);

        // ========================== eBTC Boring Queue ==========================
        ERC20[] memory withdrawAssets = new ERC20[](3);
        withdrawAssets[0] = getERC20(sourceChain, "WBTC");
        withdrawAssets[1] = getERC20(sourceChain, "cbBTC");
        withdrawAssets[2] = getERC20(sourceChain, "LBTC");
        _addWithdrawQueueLeafs(leafs, 0x74EC75fb641ec17B04007733d9efBE2D1dA5CA2C, getAddress(sourceChain, "eBTC"), withdrawAssets);
        _addWithdrawQueueLeafs(leafs, 0x686696A3e59eE16e8A8533d84B62cfA504827135, getAddress(sourceChain, "eBTC"), withdrawAssets);

        string memory filePath = "./leafs/Mainnet/CbBTCStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
