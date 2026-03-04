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
 *  source .env && forge script script/MerkleRootCreation/plume/CreateLiquidUSDPlumeMerkleRoot.s.sol:CreateLiquidUSDPlumeMerkleRoot --rpc-url $PLUME_RPC_URL
 */
contract CreateLiquidUSDPlumeMerkleRoot is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x08c6F91e2B681FaF5e17227F2a44C307b3C1364C;
    address public managerAddress = 0x7b57Ad1A0AA89583130aCfAD024241170D24C13C;
    address public accountantAddress = 0xc315D6e14DDCDC7407784e2Caf815d131Bc1D3E7;
    address public tellerAddress = 0x4DE413a26fC24c3FC27Cc983be70aA9c5C299387;
    address public rawDataDecoderAndSanitizer = 0x169344808f48C0e09857E16a5f6d126D79506A15;

    function setUp() external {
        vm.createSelectFork("plume");
    }

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateLiquidUSDStrategistMerkleRoot();
    }

    function generateLiquidUSDStrategistMerkleRoot() public {
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

        // ========================== PredicateProxy Deposit ==========================
        _addPredicateProxyDepositLeafs(
            leafs,
            getAddress(sourceChain, "nPredicateProxy"),
            getERC20(sourceChain, "USDC"),
            boringVault,
            getAddress(sourceChain, "nBASISTeller")
        );

        // ========================== AtomicQueue Withdrawal ==========================
        // nBASIS -> nativeUSDC withdrawal
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "nBASIS"),
            getERC20(sourceChain, "USDC")
        );

        // ========================== nAlpha PredicateProxy Deposit ==========================
        _addPredicateProxyDepositLeafs(
            leafs,
            getAddress(sourceChain, "nPredicateProxy"),
            getERC20(sourceChain, "USDC"),
            boringVault,
            getAddress(sourceChain, "nALPHATeller")
        );

        // ========================== nAlpha AtomicQueue Withdrawal ==========================
        // nALPHA -> nativeUSDC withdrawal
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "nALPHA"),
            getERC20(sourceChain, "USDC")
        );

        // ========================== nOpal PredicateProxy Deposit ==========================
        _addPredicateProxyDepositLeafs(
            leafs,
            getAddress(sourceChain, "nPredicateProxy"),
            getERC20(sourceChain, "USDC"),
            boringVault,
            getAddress(sourceChain, "nOPALTeller")
        );

        // ========================== nOpal AtomicQueue Withdrawal ==========================
        // nOPAL -> nativeUSDC withdrawal
        _addAtomicQueueLeafs(
            leafs,
            0x228C44Bb4885C6633F4b6C83f14622f37D5112E5,
            getERC20(sourceChain, "nOPAL"),
            getERC20(sourceChain, "USDC")
        );

        // ========================== CCTP Bridge ==========================
        // Override USDC to Circle's native USDC for CCTP
        _addCCTPBridgeLeafs(leafs, cctpMainnetDomainId);

        // ========================== Verify ==========================
        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Plume/LiquidUSDStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
