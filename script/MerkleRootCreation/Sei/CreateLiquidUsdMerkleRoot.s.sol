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
 *  source .env && forge script script/MerkleRootCreation/Sei/CreateLiquidUsdMerkleRoot.s.sol --rpc-url $SEI_RPC_URL --gas-limit 1000000000000000000
 */
contract CreateLiquidUsdSeiMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    // TODO: fill in once deployed
    address public boringVault = 0x08c6F91e2B681FaF5e17227F2a44C307b3C1364C;
    address public rawDataDecoderAndSanitizer = 0x20C6c86861C781F0DB99d5e2704B353Ac2351d5D; // LiquidUSDSeiDecoderAndSanitizer
    address public managerAddress = 0x7b57Ad1A0AA89583130aCfAD024241170D24C13C;
    address public accountantAddress = 0xc315D6e14DDCDC7407784e2Caf815d131Bc1D3E7;

    function setUp() external {}

    function run() external {
        generateLiquidUsdStrategistMerkleRoot();
    }

    function generateLiquidUsdStrategistMerkleRoot() public {
        setSourceChainName(sei);
        setAddress(false, sei, "boringVault", boringVault);
        setAddress(false, sei, "managerAddress", managerAddress);
        setAddress(false, sei, "accountantAddress", accountantAddress);
        setAddress(false, sei, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        // liquidUSD mainnet vault — final destination for PYUSD0 multihop bridge
        setAddress(false, mainnet, "boringVault", 0x08c6F91e2B681FaF5e17227F2a44C307b3C1364C);

        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        // ========================== LayerZero (PYUSD0 -> Mainnet via Arbitrum) ==========================
        // PYUSD0 multihop Sei -> Arbitrum (MultiHopComposer) -> Mainnet
        _addLayerZeroMultiHopLeafs(
            leafs,
            getERC20(sourceChain, "PYUSD0"),
            getAddress(sourceChain, "PYUSDOFTAdapter"),
            layerZeroArbitrumEndpointId,
            getBytes32("arbitrum", "MultiHopComposer"),
            layerZeroMainnetEndpointId,
            getBytes32(mainnet, "boringVault")
        );

        // ========================== Feather pyUSD0 Vault (MetaMorpho) ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "featherPYUSD0Vault")));

        // ========================== Merkl ==========================
        // Claim USDC incentive rewards from Merkl distributor
        _addMerklLeafs(
            leafs,
            getAddress(sourceChain, "merklDistributor"),
            getAddress(sourceChain, "dev1Address")
        );
        _addMerklLeafs(
            leafs,
            getAddress(sourceChain, "merklDistributor"),
            0xe373248E02c5a342d453ecB8eBFC449b8BE70Bc1 // etherfi ops address
        );

        // ========================== CCTP (USDC -> Mainnet) ==========================
        // Bridge USDC rewards back to ETH mainnet via CCTP V2
        _addCCTPBridgeLeafs(leafs, cctpMainnetDomainId);

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Sei/LiquidUsdStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
