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
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateEtherFiBTCMerkleRoot.s.sol:CreateEtherFiBTCMerkleRootScript --rpc-url $MAINNET_RPC_URL
 */
contract CreateEtherFiBTCMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x657e8C867D8B37dCC18fA4Caead9C45EB088C642;
    address public managerAddress = 0x382d0106F308864D5462332D9D3bB54a60384B70;
    address public accountantAddress = 0x1b293DC39F94157fA0D1D36d7e0090C8B8B8c13F;
    address public rawDataDecoderAndSanitizer = 0x7712588Aa2a904111A81885B4dCCf895A1DEb700;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
        //generateSniperMerkleRoot();
    }

    function generateSniperMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addSymbioticApproveAndDepositLeaf(leafs, getAddress(sourceChain, "wBTCDefaultCollateral"));
        _addSymbioticApproveAndDepositLeaf(leafs, getAddress(sourceChain, "tBTCDefaultCollateral"));
        _addSymbioticApproveAndDepositLeaf(leafs, getAddress(sourceChain, "LBTCDefaultCollateral"));

        string memory filePath = "./leafs/Mainnet/etherfiBTCSniperLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        // ========================== Symbiotic ==========================
        address[] memory defaultCollaterals = new address[](2);
        defaultCollaterals[0] = getAddress(sourceChain, "wBTCDefaultCollateral");
        defaultCollaterals[1] = getAddress(sourceChain, "LBTCDefaultCollateral");
        _addSymbioticLeafs(leafs, defaultCollaterals);

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](3);
        token0[0] = getAddress(sourceChain, "WBTC");
        token0[1] = getAddress(sourceChain, "WBTC");
        token0[2] = getAddress(sourceChain, "LBTC");

        address[] memory token1 = new address[](3);
        token1[0] = getAddress(sourceChain, "LBTC");
        token1[1] = getAddress(sourceChain, "cbBTC");
        token1[2] = getAddress(sourceChain, "cbBTC");

        _addUniswapV3Leafs(leafs, token0, token1, false);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](3);
        SwapKind[] memory kind = new SwapKind[](3);
        assets[0] = getAddress(sourceChain, "WBTC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "LBTC");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "cbBTC");
        kind[2] = SwapKind.BuyAndSell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Karak ==========================
        _addKarakLeafs(leafs, getAddress(sourceChain, "vaultSupervisor"), getAddress(sourceChain, "kWBTC"));
        _addKarakLeafs(leafs, getAddress(sourceChain, "vaultSupervisor"), getAddress(sourceChain, "kLBTC"));


        // ========================== Symbiotic Vault ==========================
        address[] memory vaults = new address[](1);
        vaults[0] = getAddress(sourceChain, "EtherFi_LBTCSymbioticVault");
        ERC20[] memory vault_assets = new ERC20[](1);
        vault_assets[0] = ERC20(getAddress(sourceChain, "LBTC"));

        // NOTE: No rewards for EtherFi wstETH vault for now.
        address[] memory rewards = new address[](0);
        _addSymbioticVaultLeafs(leafs, vaults, vault_assets, rewards);

        // ========================== LayerZero ==========================
        //_addLayerZeroLeafs(
        //    leafs,
        //    getERC20(sourceChain, "WBTC"),
        //    getAddress(sourceChain, "WBTCOFTAdapter"),
        //    layerZeroScrollEndpointId,
        //    getBytes32(sourceChain, "boringVault")
        //);


        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/EtherFiBtcStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
