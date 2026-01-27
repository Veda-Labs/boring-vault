// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

contract TestProofGeneration is Script {
    function run() external {
        string memory json = vm.readFile("leafs/LocalFork/FundMgmtUSDCLocalForkLeafs.json");
        
        // Test finding the deposit digest
        bytes32 depositDigest = 0xf8459b28cfa6497f46be5c9c8c39a41992a655fa8141e2b60094c7ffc461151f;
        
        uint256 capacity = vm.parseJsonUint(json, ".metadata.TreeCapacity");
        uint256 height = log2(capacity);
        console2.log("Tree capacity:", capacity);
        console2.log("Tree height:", height);

        string memory leavesPath = string(abi.encodePacked(".MerkleTree.", vm.toString(height)));
        bytes32[] memory leaves = vm.parseJsonBytes32Array(json, leavesPath);
        console2.log("Number of leaves:", leaves.length);
        
        // Print all leaves
        for (uint256 i = 0; i < leaves.length; i++) {
            console2.log("Leaf", i);
            console2.logBytes32(leaves[i]);
        }
        
        // Try to find our deposit digest
        console2.log("Looking for deposit digest:");
        console2.logBytes32(depositDigest);
        
        uint256 index = type(uint256).max;
        for (uint256 i = 0; i < leaves.length; i++) {
            if (leaves[i] == depositDigest) {
                index = i;
                break;
            }
        }
        
        if (index == type(uint256).max) {
            console2.log("Deposit digest NOT found in leaves!");
        } else {
            console2.log("Deposit digest found at index:", index);
        }
    }
    
    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) {
                value >>= 128;
                result += 128;
            }
            if (value >> 64 > 0) {
                value >>= 64;
                result += 64;
            }
            if (value >> 32 > 0) {
                value >>= 32;
                result += 32;
            }
            if (value >> 16 > 0) {
                value >>= 16;
                result += 16;
            }
            if (value >> 8 > 0) {
                value >>= 8;
                result += 8;
            }
            if (value >> 4 > 0) {
                value >>= 4;
                result += 4;
            }
            if (value >> 2 > 0) {
                value >>= 2;
                result += 2;
            }
            if (value >> 1 > 0) {
                result += 1;
            }
        }
        return result;
    }
}