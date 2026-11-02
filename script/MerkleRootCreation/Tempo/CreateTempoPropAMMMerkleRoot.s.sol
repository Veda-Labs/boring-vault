// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 * source .env && forge script script/MerkleRootCreation/Tempo/CreateTempoPropAMMMerkleRoot.s.sol --rpc-url $TEMPO_RPC_URL
 *
 * @notice Example root for the DirectPropAMM direct strategist path on one pool.
 *
 * @dev A real vault's root must carry ALL of that vault's permissions in one tree. This script builds
 *      only the four DirectPropAMM leaves, so setting its output on a live vault would revoke
 *      everything else. Copy `_addDirectPropAMMLeafs` into that vault's own root script instead of
 *      shipping this one.
 *
 *      `pool` is intentionally unset. Neither pool live on Tempo implements the reviewed ten-argument
 *      taker ABI, so there is no correct default to hardcode: a root built against a legacy pool
 *      produces leaves that are dead calldata and fail only at strategist execution time. Deploy from
 *      reviewed source, run
 *      `DIRECT_PROP_AMM_POOL=0x... FOUNDRY_PROFILE=tempo forge test --match-test ReviewedTakerAbi`,
 *      then fill in the addresses below. See test/integrations/DirectPropAMM_Safety_Validation.md
 *      for the full deployment gate.
 */
contract CreateTempoPropAMMMerkleRootScript is Script, MerkleTreeHelper {
    address public boringVault = address(0);
    address public managerAddress = address(0);
    address public accountantAddress = address(0);
    address public rawDataDecoderAndSanitizer = address(0); // TempoDirectPropAMMDecoderAndSanitizer
    address public pool = address(0); // DirectPropAMM deployed from reviewed source

    function setUp() external {}

    function run() external {
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        require(boringVault != address(0), "set boringVault");
        require(managerAddress != address(0), "set managerAddress");
        require(accountantAddress != address(0), "set accountantAddress");
        require(rawDataDecoderAndSanitizer != address(0), "set rawDataDecoderAndSanitizer");
        require(pool != address(0), "set pool: no live Tempo pool implements the reviewed taker ABI");

        setSourceChainName(tempo);
        setAddress(false, tempo, "boringVault", boringVault);
        setAddress(false, tempo, "managerAddress", managerAddress);
        setAddress(false, tempo, "accountantAddress", accountantAddress);
        setAddress(false, tempo, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](4);

        // ========================== DirectPropAMM ==========================
        // Base is PRIME and quote is pathUSD, matching the pool's immutable pair. A USDCE/PRIME or
        // USDY/pathUSD pool needs its own deployment, its own decoder, and its own call here.
        _addDirectPropAMMLeafs(leafs, pool, getAddress(sourceChain, "PRIME"), getAddress(sourceChain, "pathUSD"));

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Tempo/TempoPropAMMMerkleRoot.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
