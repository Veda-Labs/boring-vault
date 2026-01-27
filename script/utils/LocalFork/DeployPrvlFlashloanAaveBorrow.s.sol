// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {PrvlFlashloanAaveBorrow} from "src/micro-managers/PrvlFlashloanAaveBorrow.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";

/*
 * source .env && forge script script/utils/LocalFork/DeployPrvlFlashloanAaveBorrow.s.sol:DeployPrvlFlashloanAaveBorrow --fork-url local --broadcast -vv
 */

contract DeployPrvlFlashloanAaveBorrow is Script, MerkleTreeHelper {
    uint256 public privateKey;
    
    address constant OWNER = 0x6f4e539E6B28097F9aF8aFbc7BA78B715F0127fF;
    address constant MANAGER = 0x54a352BE658a9CDe86409b7281BFBCE0cA94dd81;
    address constant BORING_VAULT = 0x3A29E2a5Ddb20C56D62a9D9Fa29b606833C4bf1d;
    address constant BALANCER_VAULT = 0xBA12222222228d8Ba445958a75a0704d566BF2C8;
    address constant UNI_V3_ROUTER = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address constant UNI_V3_QUOTER = 0xb27308f9F90D607463bb33eA1BeBb41C27CE5AB6;
    address constant AAVE_POOL = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant BASEDECODER = 0x078AF49028bDfC2a2247B76d170022a9C98308D0;
    
    uint24 constant UNI_FEE_TIER = 3000;
    uint256 constant AAVE_VARIABLE_RATE = 2;
    
    RolesAuthority public rolesAuthority = RolesAuthority(0x85aa8590E3f076aF23AF2cc29a743c481354A8cf);
    PrvlFlashloanAaveBorrow public flashloanManager;

    function setUp() external {
        privateKey = vm.envUint("LOCAL_DEPLOYER_PRIVATE_KEY");
    }

    function run() external {
        vm.startBroadcast(privateKey);

        // Deploy the micro-manager
        flashloanManager = new PrvlFlashloanAaveBorrow(
            OWNER,
            MANAGER,
            BORING_VAULT,
            BALANCER_VAULT,
            UNI_V3_ROUTER,
            UNI_V3_QUOTER,
            AAVE_POOL,
            WETH,
            USDC,
            UNI_FEE_TIER,
            AAVE_VARIABLE_RATE
        );

        console.log("PrvlFlashloanAaveBorrow deployed at:", address(flashloanManager));

        // Give micro-manager permission to manage the vault (role 7)
        if (!rolesAuthority.doesUserHaveRole(address(flashloanManager), 7)) {
            rolesAuthority.setUserRole(address(flashloanManager), 7, true);
            console.log("Granted role 7 to micro-manager");
        }

        flashloanManager.setAuthority(rolesAuthority);

        // Parse the Merkle root from JSON
        string memory json = vm.readFile("leafs/LocalFork/FundMgmtUSDCAgentMainnetForkLeafs.json");
        bytes32 merkleRoot = vm.parseJsonBytes32(json, ".metadata.ManageRoot");

        // Set the Merkle root for the micro-manager address
        ManagerWithMerkleVerification managerContract = ManagerWithMerkleVerification(MANAGER);
        managerContract.setManageRoot(address(flashloanManager), merkleRoot);
        managerContract.setManageRoot(MANAGER, merkleRoot);

        // Set up proofs for the micro-manager
        _setupMicroManagerProofs(flashloanManager);

        vm.stopBroadcast();
    }

    function _setupMicroManagerProofs(PrvlFlashloanAaveBorrow microManager) internal {
        setSourceChainName("mainnet");
        string memory json = vm.readFile("leafs/LocalFork/FundMgmtUSDCAgentMainnetForkLeafs.json");
        
        // Set up borrow inner operations proofs (3 operations: swap, supply, borrow)
        bytes32[][] memory borrowInnerManageProofs = new bytes32[][](3);
        borrowInnerManageProofs[0] = getMerkleProof(json, 0x5d74981162e16fcc0a27ef26a25f75d14f92dab54a218cefadf61f0d7ce87fff); // USDC->WETH swap
        borrowInnerManageProofs[1] = getMerkleProof(json, 0x3be8fa59f72de7230cb781231e183e937feabbcab6ec516d621cfa7033c3663b); // AAVE WETH supply
        borrowInnerManageProofs[2] = getMerkleProof(json, 0x04bf67c02da44dec7fdd56251cd0be0c7ecea9b9927f5939b10f85e38e0f9a72); // AAVE USDC borrow
        
        address[] memory borrowInnerDecodersAndSanitizers = new address[](3);
        borrowInnerDecodersAndSanitizers[0] = BASEDECODER;
        borrowInnerDecodersAndSanitizers[1] = BASEDECODER;
        borrowInnerDecodersAndSanitizers[2] = BASEDECODER;
        
        // Set up repay inner operations proofs (3 operations: repay, withdraw, swap)
        bytes32[][] memory repayInnerManageProofs = new bytes32[][](3);
        repayInnerManageProofs[0] = getMerkleProof(json, 0xda35826a8a1013fe5cf9b4c1005d856050d7edf0e4cb69f1baaf16059b3f318b); // AAVE USDC repay
        repayInnerManageProofs[1] = getMerkleProof(json, 0x539b50ed42eb794ee242cf23ea2b8e0840cd40c8e533b36b93d25121ae4a2af0); // AAVE WETH withdraw
        repayInnerManageProofs[2] = getMerkleProof(json, 0x94a4799f727108873b3c1d4347a2798a7ae5417955389c0320deac3245385fec); // WETH->USDC swap
        
        address[] memory repayInnerDecodersAndSanitizers = new address[](3);
        repayInnerDecodersAndSanitizers[0] = BASEDECODER;
        repayInnerDecodersAndSanitizers[1] = BASEDECODER;
        repayInnerDecodersAndSanitizers[2] = BASEDECODER;
        
        // Set up outer flashloan proof
        address[] memory outerDecodersAndSanitizers = new address[](1);
        outerDecodersAndSanitizers[0] = BASEDECODER;
        
        bytes32[][] memory outerManageProofs = new bytes32[][](1);
        outerManageProofs[0] = getMerkleProof(json, 0xa50c6593a1f7b746bf2006dba902573c35f62005b0510921070ae8f234cad304); // Flashloan USDC
        
        // Set all proofs and decoders
        microManager.setBorrowInnerManageProofs(borrowInnerManageProofs);
        microManager.setBorrowInnerDecodersAndSanitizers(borrowInnerDecodersAndSanitizers);
        microManager.setRepayInnerManageProofs(repayInnerManageProofs);
        microManager.setRepayInnerDecodersAndSanitizers(repayInnerDecodersAndSanitizers);
        microManager.setOuterDecodersAndSanitizers(outerDecodersAndSanitizers);
        microManager.setOuterManageProofs(outerManageProofs);
        
        console.log("Micro-manager proofs configured");
    }

    function getMerkleProof(string memory json, bytes32 leafDigest) internal view returns (bytes32[] memory) {
        uint256 capacity = vm.parseJsonUint(json, ".metadata.TreeCapacity");
        uint256 height = 0;
        uint256 temp = capacity;
        if (temp == 0) revert("Invalid capacity");
        while (temp > 1) {
            temp >>= 1;
            height++;
        }

        string memory leavesPath = string(abi.encodePacked(".MerkleTree.", vm.toString(height)));
        bytes32[] memory leaves = vm.parseJsonBytes32Array(json, leavesPath);

        uint256 index = type(uint256).max;
        for (uint256 i = 0; i < leaves.length; i++) {
            if (leaves[i] == leafDigest) {
                index = i;
                break;
            }
        }
        if (index == type(uint256).max) revert("Leaf not found");

        bytes32[] memory proof = new bytes32[](height);
        uint256 currentIndex = index;

        for (uint256 level = height; level > 0; level--) {
            string memory levelPath = string(abi.encodePacked(".MerkleTree.", vm.toString(level)));
            bytes32[] memory levelHashes = vm.parseJsonBytes32Array(json, levelPath);
            proof[height - level] = levelHashes[currentIndex ^ 1];
            currentIndex >>= 1;
        }

        return proof;
    }
}