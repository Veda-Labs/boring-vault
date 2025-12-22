// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import { FixedPointMathLib } from "@solmate/utils/FixedPointMathLib.sol";
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { Strings } from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import { ERC4626 } from "@solmate/tokens/ERC4626.sol";
import { ManagerWithMerkleVerification } from "src/base/Roles/ManagerWithMerkleVerification.sol";
import { MerkleTreeHelper } from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/plume/CreateRoycoUSDPlumeMerkleRoot.s.sol:CreateRoycoUSDPlumeMerkleRoot --rpc-url $PLUME_RPC_URL
 */
contract CreateRoycoUSDPlumeMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x83A6F6034ee44De6648B1885e24D837D8D98698f;
    address public managerAddress = 0xe942A366Ccb629939921b35e1382D2c9634146cE;
    address public accountantAddress = 0xfFfBF5B884AdF7297B94e62535D1b031387041Bd;
    address public tellerAddress = 0x4Fc294112fD0b7226ecA095FEE9909E30882Cb11;
    address public rawDataDecoderAndSanitizer = 0x3820D474cc9b1Aed0A0D78C86b644c5C709E98Ce;

    function setUp() external {
        vm.createSelectFork("plume");
    }

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateRoycoStrategistMerkleRoot();
    }

    function generateRoycoStrategistMerkleRoot() public {
        setSourceChainName(plume);
        setAddress(false, plume, "boringVault", boringVault);
        setAddress(false, plume, "managerAddress", managerAddress);
        setAddress(false, plume, "accountantAddress", accountantAddress);
        setAddress(false, plume, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, plume, "tellerAddress", tellerAddress);

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // ========================== Fee Claiming ==========================
        ERC20[] memory feeAssets = new ERC20[](1);
        feeAssets[0] = getERC20(sourceChain, "USDC");
        _addLeafsForFeeClaiming(leafs, getAddress(sourceChain, "accountantAddress"), feeAssets, true);

        // ========================== Deposits into Other Vault Tellers ==========================
        // pUSD Vault Teller
        ERC20[] memory pUSDTellerAssets = new ERC20[](1);
        pUSDTellerAssets[0] = getERC20(sourceChain, "USDC");
        _addTellerLeafs(leafs, getAddress(sourceChain, "pUSDTeller"), pUSDTellerAssets, false, true);

        ERC20[] memory nucleusTellerAssets = new ERC20[](6);
        nucleusTellerAssets[0] = getERC20(sourceChain, "pUSD");
        nucleusTellerAssets[1] = getERC20(sourceChain, "USDC");
        nucleusTellerAssets[2] = getERC20(sourceChain, "nCREDIT");
        nucleusTellerAssets[3] = getERC20(sourceChain, "nBASIS");
        nucleusTellerAssets[4] = getERC20(sourceChain, "nALPHA");
        nucleusTellerAssets[5] = getERC20(sourceChain, "nINSTO");

        // nINSTO Vault Teller
        _addTellerLeafs(leafs, getAddress(sourceChain, "nINSTOTeller"), nucleusTellerAssets, false, true);

        // nCREDIT Vault Teller
        _addTellerLeafs(leafs, getAddress(sourceChain, "nCREDITTeller"), nucleusTellerAssets, false, true);

        // nBASIS Vault Teller
        _addTellerLeafs(leafs, getAddress(sourceChain, "nBASISTeller"), nucleusTellerAssets, false, true);

        // nAlpha Vault Teller
        _addTellerLeafs(leafs, getAddress(sourceChain, "nALPHATeller"), nucleusTellerAssets, false, true);

        // ========================== Royco Markets ==========================
        // Based on Royco Requirements spreadsheet - all markets use $PLUME as incentive token
        // Market hashes extracted from Royco URLs (example: market ID 98866 -> hash 0x85c3ab928fdf01f9f53d4a776a9cdd9ab34d6e48a4ac2a111471f4425d5ce04c)
        bytes32[] memory marketHashes = new bytes32[](5);
        marketHashes[0] = 0x85c3ab928fdf01f9f53d4a776a9cdd9ab34d6e48a4ac2a111471f4425d5ce04c; // Nest nINSTO market
        marketHashes[1] = 0xd7b4af5225fb14fc0f0f7e068faaa03c3d1530f695b60187f74ed7a0e259fa10; // nCredit
        marketHashes[2] = 0x4d2ae1e85a4f4c2314e23833445c0a4cb6c434a1aa382bf5939fb18140bcb709; // nBasis
        marketHashes[3] = 0xc41a78d629855b99788af7449020a88eec807be5f26ab050908dd7e633735897; // nAlpha
        marketHashes[4] = 0x579faf40ca0f509b535552cf032c6b24030fa2c4b3e69f269f6c9520a7fffb1b; // Solera lending market (10% allocation, 8% APY)

        ERC20[] memory marketAsset = new ERC20[](5);
        marketAsset[0] = getERC20(sourceChain, "nINSTO");
        marketAsset[1] = getERC20(sourceChain, "nCREDIT");
        marketAsset[2] = getERC20(sourceChain, "nBASIS");
        marketAsset[3] = getERC20(sourceChain, "nALPHA");
        marketAsset[4] = getERC20(sourceChain, "pUSD");

        address[] memory incentivesRequested = new address[](1);
        incentivesRequested[0] = getAddress(sourceChain, "plumeToken");

        address frontendFeeRecipient = 0x169C8c63aaC6433be8fdFE4AA116286329226E0a;

        // Add Royco market support for each market
        for (uint256 i = 0; i < marketHashes.length; i++) {
            _addRoycoRecipeAPOfferLeafs(
                leafs, address(marketAsset[i]), marketHashes[i], address(0), incentivesRequested
            );
            _addRoycoWeirollLeafs(leafs, marketAsset[i], marketHashes[i], frontendFeeRecipient);
        }

        // ========================== Royco Vault Markets (if any) ==========================
        // If any of these tokens have vault markets, add support here
        // Example:
        // address pUSDVault = address(0); // Update with actual vault address
        // if (pUSDVault != address(0)) {
        //     _addRoycoVaultMarketLeafs(leafs, pUSD, pUSDVault, address(0), incentivesRequested[0]);
        //     _addRoyco4626VaultLeafs(leafs, ERC4626(pUSDVault));
        // }

        // ========================== BoringChef Rewards Distribution ==========================
        // Add support for distributeRewards functionality
        {
            address[] memory allRewardsTokens = new address[](1);
            allRewardsTokens[0] = getAddress(sourceChain, "plumeToken");

            _addBoringChefApproveRewardsLeafs(leafs, boringVault, allRewardsTokens);

            _addBoringChefDistributeRewardsLeaf(leafs, boringVault, allRewardsTokens);

            _addBoringChefClaimLeaf(leafs, boringVault);
        }

        // nAlpha Offer
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "nALPHA"),
            getERC20(sourceChain, "nCREDIT")
        );
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "nALPHA"),
            getERC20(sourceChain, "nBASIS")
        );
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "nALPHA"),
            getERC20(sourceChain, "pUSD")
        );
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "nALPHA"),
            getERC20(sourceChain, "opNALPHA")
        );
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "nALPHA"),
            getERC20(sourceChain, "USDC")
        );

        // nCredit Offer
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "nCREDIT"),
            getERC20(sourceChain, "nALPHA")
        );
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "nCREDIT"),
            getERC20(sourceChain, "nBASIS")
        );
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "nCREDIT"),
            getERC20(sourceChain, "pUSD")
        );
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "nCREDIT"),
            getERC20(sourceChain, "opNALPHA")
        );
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "nCREDIT"),
            getERC20(sourceChain, "USDC")
        );

        // nBasis Offer
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "nBASIS"),
            getERC20(sourceChain, "nALPHA")
        );
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "nBASIS"),
            getERC20(sourceChain, "nCREDIT")
        );
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "nBASIS"),
            getERC20(sourceChain, "pUSD")
        );
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "nBASIS"),
            getERC20(sourceChain, "opNALPHA")
        );
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "nBASIS"),
            getERC20(sourceChain, "USDC")
        );

        // pUSD Offer
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "pUSD"),
            getERC20(sourceChain, "nALPHA")
        );
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "pUSD"),
            getERC20(sourceChain, "nCREDIT")
        );
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "pUSD"),
            getERC20(sourceChain, "nBASIS")
        );
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "pUSD"),
            getERC20(sourceChain, "opNALPHA")
        );
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "pUSD"),
            getERC20(sourceChain, "USDC")
        );

        // opNAlpha Offer
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "opNALPHA"),
            getERC20(sourceChain, "nALPHA")
        );
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "opNALPHA"),
            getERC20(sourceChain, "nCREDIT")
        );
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "opNALPHA"),
            getERC20(sourceChain, "nBASIS")
        );
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "opNALPHA"),
            getERC20(sourceChain, "pUSD")
        );
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "opNALPHA"),
            getERC20(sourceChain, "USDC")
        );

        // nNSTO Offer
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "nINSTO"),
            getERC20(sourceChain, "nALPHA")
        );
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "nINSTO"),
            getERC20(sourceChain, "nCREDIT")
        );
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "nINSTO"),
            getERC20(sourceChain, "nBASIS")
        );
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "nINSTO"),
            getERC20(sourceChain, "pUSD")
        );
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "nINSTO"),
            getERC20(sourceChain, "opNALPHA")
        );
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "nINSTO"),
            getERC20(sourceChain, "USDC")
        );

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/plume/RoycoPlumeMerkleRoot.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
