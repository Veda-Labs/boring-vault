// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import "forge-std/Script.sol";

contract CreateRoycoJrUsdcMerkleRoot is Script, MerkleTreeHelper {
    // Deployed RoycoJrUsdcCluster architecture (deployments/addresses/Mainnet/RoycoJrUsdcCluster.json).
    address public constant ROYCO_JR_USDC_BORING_VAULT = 0x71861827Aa95cA48148bdA0b40BC740d1c421070;
    address public constant ROYCO_JR_USDC_MANAGER = 0x441973fAe7432a39d13bA4620ebc12Fa43c1C416;
    address public constant ROYCO_JR_USDC_ACCOUNTANT = 0x0142d7E0787498c523c5E21c5BeCe9afDD82C6a3;

    // Decoder address must be set after the RoycoJrUsdc decoder is deployed against this vault.
    address public constant ROYCO_JR_USDC_DECODER_AND_SANITIZER = address(0);

    // Junior tranche of the syrupUSDC market on Royco Dawn. Vault has the LP role on this tranche.
    address public constant ROYCO_JR_SYRUP_USDC = 0x5f340B400F892bBFDed2e5c316369Dcbf05C282A;

    function setUp() external {
        vm.createSelectFork("mainnet");
        setSourceChainName("mainnet");

        setAddress(true, mainnet, "boringVault", ROYCO_JR_USDC_BORING_VAULT);
        setAddress(true, mainnet, "managerAddress", ROYCO_JR_USDC_MANAGER);
        setAddress(true, mainnet, "accountantAddress", ROYCO_JR_USDC_ACCOUNTANT);
        setAddress(true, mainnet, "rawDataDecoderAndSanitizer", ROYCO_JR_USDC_DECODER_AND_SANITIZER);

        setAddress(true, mainnet, "roycoJrSyrupUSDC", ROYCO_JR_SYRUP_USDC);
    }

    function run() external {
        require(ROYCO_JR_USDC_DECODER_AND_SANITIZER != address(0), "Decoder address not set");

        ManageLeaf[] memory leafs = new ManageLeaf[](32);
        _addLeafs(leafs);

        bytes32[][] memory tree = _generateMerkleTree(leafs);
        string memory filePath = "./leafs/Mainnet/RoycoJrUsdcStrategistLeafs.json";
        _generateLeafs(filePath, leafs, tree[tree.length - 1][0], tree);
    }

    function _addLeafs(ManageLeaf[] memory leafs) internal {
        // (0) Accountant fee claiming in USDC.
        ERC20[] memory feeAssets = new ERC20[](1);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, false);

        // (1) USDC ↔ syrupUSDC via Maple's syrupRouter + pool.
        _addAllSyrupLeafs(leafs);

        // (2) Royco Dawn: direct deposit/redeem on the syrupUSDC junior tranche.
        _addRoycoDawnDirectLeafs(leafs, ROYCO_JR_SYRUP_USDC, getAddress(sourceChain, "syrupUSDC"));
    }
}
