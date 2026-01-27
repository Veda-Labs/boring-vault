// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {console2} from "forge-std/console2.sol";
import {PrvlAgentVaultDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/Protocols/Paravel/PrvlAgentVaultDecoderAndSanitizer.sol";

/*
 * source .env && forge script script/utils/Mainnet/ApproveTokensETH.s.sol:ApproveTokens --rpc-url mainnet --broadcast -vvvv
 */

contract ApproveTokens is Script, MerkleTreeHelper {
    // Agent vault addresses 
    address constant MANAGER = 0xF93C04915f69e95D9b8777609f07c969Ff24ee48;
    address constant TARGET_AGENT_VAULT = 0x8503B18b279Fd0f1EC35303D8db834619A12250f;
    address constant AGENT_DECODER = 0xc5c641525Bbf2fD6d163c138101F82c1ca4FBaaE;

    function run() external {
        uint256 privateKey = vm.envUint("MAINNET_DEPLOYER_KEY");
        setSourceChainName(mainnet); // Using mainnet chain data for fork
        vm.startBroadcast(privateKey);

        // Read our generated agent merkle tree
        string memory json = vm.readFile("leafs/Mainnet/ETHAgent2Prime.json");
        bytes32 merkleRoot = vm.parseJsonBytes32(json, ".metadata.ManageRoot");
        
        // Find the digests we need from the JSON for all four approvals
        bytes32 approveWETHForSwapDigest = findDigestByDescription(json, "Approve SwapRouter02 to spend WETH");
        bytes32 approveUSDCForSwapDigest = findDigestByDescription(json, "Approve SwapRouter02 to spend wstETH");
        bytes32 approveWETHForAaveDigest = findDigestByDescription(json, "Approve Aave V3 Pool to spend WETH");
        bytes32 approveUSDCForAaveDigest = findDigestByDescription(json, "Approve Aave V3 Pool to spend wstETH");

        // Prepare transaction data - approve all needed tokens
        bytes[] memory targetData = new bytes[](4);
        
        // 1. Approve SwapRouter02 to spend WETH
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45, type(uint256).max);
        
        // 2. Approve SwapRouter02 to spend wstETH
        targetData[1] = abi.encodeWithSignature("approve(address,uint256)", 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45, type(uint256).max);
        
        // 3. Approve AAVE to spend WETH
        targetData[2] = abi.encodeWithSignature("approve(address,uint256)", 0x4e033931ad43597d96D6bcc25c280717730B58B1, type(uint256).max);
        
        // 4. Approve AAVE to spend wstETH
        targetData[3] = abi.encodeWithSignature("approve(address,uint256)", 0x4e033931ad43597d96D6bcc25c280717730B58B1, type(uint256).max);

        setAddress(false, "mainnet", "wstETH", address(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0));
        
        // Set targets
        address[] memory targets = new address[](4);
        targets[0] = getAddress(sourceChain, "WETH");  // WETH for SwapRouter02
        targets[1] = getAddress(sourceChain, "wstETH");  // wstETH for SwapRouter02
        targets[2] = getAddress(sourceChain, "WETH");  // WETH for AAVE
        targets[3] = getAddress(sourceChain, "wstETH");  // wstETH for AAVE

        // Get merkle proofs
        bytes32[][] memory manageProofs = new bytes32[][](4);
        manageProofs[0] = getMerkleProof(json, approveWETHForSwapDigest);
        manageProofs[1] = getMerkleProof(json, approveUSDCForSwapDigest);
        manageProofs[2] = getMerkleProof(json, approveWETHForAaveDigest);
        manageProofs[3] = getMerkleProof(json, approveUSDCForAaveDigest);

        // Set up remaining parameters
        uint256[] memory values = new uint256[](4);
        address[] memory decodersAndSanitizers = new address[](4);
        decodersAndSanitizers[0] = AGENT_DECODER;
        decodersAndSanitizers[1] = AGENT_DECODER;
        decodersAndSanitizers[2] = AGENT_DECODER;
        decodersAndSanitizers[3] = AGENT_DECODER;

        ManagerWithMerkleVerification manager = ManagerWithMerkleVerification(MANAGER);

        // Set the merkle root if not already set
        /*
        address strategist = 0x6f4e539E6B28097F9aF8aFbc7BA78B715F0127fF;
        if (manager.manageRoot(strategist) != merkleRoot) {
            manager.setManageRoot(strategist, merkleRoot);
        }
        */

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);

        vm.stopBroadcast();
    }


    function getMerkleProof(string memory json, bytes32 leafDigest) internal view returns (bytes32[] memory) {
        uint256 leafCount = vm.parseJsonUint(json, ".metadata.LeafCount");
        
        uint256 leafIndex = type(uint256).max;
        for (uint256 i = 0; i < leafCount; i++) {
            string memory leafPath = string(abi.encodePacked(".leafs[", vm.toString(i), "].LeafDigest"));
            bytes32 currentDigest = vm.parseJsonBytes32(json, leafPath);
            if (currentDigest == leafDigest) {
                leafIndex = i;
                break;
            }
        }
        
        require(leafIndex != type(uint256).max, "Leaf digest not found");
        
        uint256 treeCapacity = vm.parseJsonUint(json, ".metadata.TreeCapacity");
        uint256 depth = 0;
        uint256 temp = treeCapacity;
        while (temp > 1) {
            temp = temp >> 1;
            depth++;
        }
        
        bytes32[] memory proof = new bytes32[](depth);
        uint256 currentIndex = leafIndex;
        
        for (uint256 level = 0; level < depth; level++) {
            uint256 siblingIndex = currentIndex ^ 1;
            string memory treeLevelPath = string(abi.encodePacked(".MerkleTree.", vm.toString(depth - level)));
            bytes32[] memory levelHashes = vm.parseJsonBytes32Array(json, treeLevelPath);
            
            if (siblingIndex < levelHashes.length) {
                proof[level] = levelHashes[siblingIndex];
            } else {
                proof[level] = bytes32(0);
            }
            
            currentIndex = currentIndex >> 1;
        }
        
        return proof;
    }

    function findDigestByDescription(string memory json, string memory description) internal view returns (bytes32) {
        uint256 leafCount = vm.parseJsonUint(json, ".metadata.LeafCount");
        
        for (uint256 i = 0; i < leafCount; i++) {
            string memory descPath = string(abi.encodePacked(".leafs[", vm.toString(i), "].Description"));
            string memory leafDescription = vm.parseJsonString(json, descPath);
            
            if (keccak256(bytes(leafDescription)) == keccak256(bytes(description))) {
                string memory digestPath = string(abi.encodePacked(".leafs[", vm.toString(i), "].LeafDigest"));
                return vm.parseJsonBytes32(json, digestPath);
            }
        }
        
        revert(string(abi.encodePacked("Description not found: ", description)));
    }
}