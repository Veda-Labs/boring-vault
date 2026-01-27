// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

/*
 * source .env && forge script script/utils/Mainnet/EnableEmodeAgent2ETH.s.sol:EnableEmodeAgent2ETH --rpc-url mainnet --broadcast -vv
 */

contract EnableEmodeAgent2ETH is Script, MerkleTreeHelper {
    uint256 public privateKey;
    
    address constant MANAGER = 0x618c13371DB671AdbCbA93e76f758E307E6A0871;
    address constant AAVE_POOL = 0x4e033931ad43597d96D6bcc25c280717730B58B1; // prime v3 pool
    
    function setUp() external {
        privateKey = vm.envUint("MAINNET_DEPLOYER_KEY");
    }

    function run() external {
        vm.startBroadcast(privateKey);
        
        // Parse the Merkle root and get proof for setUserEMode
        string memory json = vm.readFile("leafs/Mainnet/ETHAgent2Prime.json");
        bytes32 merkleRoot = vm.parseJsonBytes32(json, ".metadata.ManageRoot");
        
        // Get the proof for setUserEMode leaf (0x17314b54f90d3225eb2607cbb7dfb4b17050c379bb821c8c39a0969fd0809fad)
        setSourceChainName("mainnet");
        bytes32[] memory proof = getMerkleProof(json, 0x9bce461075ee43483459218aec201cebef3869c006b8c2f3ce6903d489ea33fd);
        
        // Prepare the target data for enabling eMode
        // setUserEMode(uint8) where uint8 = 1 for ETH correlated assets eMode
        bytes memory targetData = abi.encodeWithSignature("setUserEMode(uint8)", 1);
        
        // Setup arrays for the manager call
        address[] memory targets = new address[](1);
        targets[0] = AAVE_POOL;
        
        bytes[] memory targetDatas = new bytes[](1);
        targetDatas[0] = targetData;
        
        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = 0xc5c641525Bbf2fD6d163c138101F82c1ca4FBaaE; // Base decoder
        
        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = proof;
        
        // Call manageWithMerkleTree on the manager contract
        ManagerWithMerkleVerification managerContract = ManagerWithMerkleVerification(MANAGER);
        managerContract.manageVaultWithMerkleVerification(
            proofs,
            decodersAndSanitizers,
            targets,
            targetDatas,
            values
        );
        
        console.log("Successfully enabled eMode on Aave V3 Core for agent2ETH manager");
        
        vm.stopBroadcast();
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