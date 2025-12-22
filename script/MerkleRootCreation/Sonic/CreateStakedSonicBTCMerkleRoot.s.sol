// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { FixedPointMathLib } from "@solmate/utils/FixedPointMathLib.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { Strings } from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import { ERC4626 } from "@solmate/tokens/ERC4626.sol";
import { MerkleTreeHelper } from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Sonic/CreateStakedSonicBTCMerkleRoot.s.sol --rpc-url $SONIC_MAINNET_RPC_URL
 */
contract CreateStakedSonicBTCMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xD0851030C94433C261B405fEcbf1DEC5E15948d0;
    address public managerAddress = 0x2531e80FD417F60048BDa5b92B7d0713cAa0c087;
    address public accountantAddress = 0x2b9ad21652e5cCaf52BCcE5375aa32176240D39D;
    address public rawDataDecoderAndSanitizer = 0x3D1b0dF501Ca22A09304c8195bEf9ad266Ad2485;

    function setUp() external { }

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(sonicMainnet);
        setAddress(false, sonicMainnet, "boringVault", boringVault);
        setAddress(false, sonicMainnet, "managerAddress", managerAddress);
        setAddress(false, sonicMainnet, "accountantAddress", accountantAddress);
        setAddress(false, sonicMainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](128);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](2);
        feeAssets[0] = getERC20(sourceChain, "LBTC");
        feeAssets[1] = getERC20(sourceChain, "WBTC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, true);

        // ========================== BoringVaults ==========================
        {
            ERC20[] memory eBTCTellerAssets = new ERC20[](2);
            eBTCTellerAssets[0] = getERC20(sourceChain, "LBTC");
            eBTCTellerAssets[1] = getERC20(sourceChain, "WBTC");
            address eBTCTeller = 0x6Ee3aaCcf9f2321E49063C4F8da775DdBd407268;
            _addTellerLeafs(leafs, eBTCTeller, eBTCTellerAssets, false, false);
            _addWithdrawQueueLeafs(
                leafs,
                getAddress(sourceChain, "eBTCOnChainQueueFast"),
                getAddress(sourceChain, "EBTC"),
                eBTCTellerAssets
            );

            //scBTC
            ERC20[] memory sonicBTCTellerAssets = new ERC20[](2);
            sonicBTCTellerAssets[0] = getERC20(sourceChain, "LBTC");
            sonicBTCTellerAssets[1] = getERC20(sourceChain, "WBTC");
            address sonicBTCTeller = 0xAce7DEFe3b94554f0704d8d00F69F273A0cFf079;
            _addTellerLeafs(leafs, sonicBTCTeller, sonicBTCTellerAssets, false, true);
        }

        // ========================== Balancer/Beets ==========================
        _addBalancerLeafs(
            leafs, getBytes32(sourceChain, "scBTC_LBTC_PoolId"), getAddress(sourceChain, "scBTC_LBTC_gauge")
        );

        // ========================== Silo =========================
        address[] memory incentivesControllers = new address[](2); //no incentives
        _addSiloV2Leafs(leafs, getAddress(sourceChain, "silo_LBTC_scBTC_id32_config"), incentivesControllers);
        _addSiloV2Leafs(leafs, getAddress(sourceChain, "silo_LBTC_WBTC_id31_config"), incentivesControllers);

        // ========================== Verify ==========================

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/Sonic/StakedSonicBTCStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
