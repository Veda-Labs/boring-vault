// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {console2} from "forge-std/console2.sol";

/*
 * source .env && forge script script/utils/Mainnet/ClaimFeesUSDC.s.sol:ClaimFees --fork-url mainnet --broadcast -vvvvv
 */
contract ClaimFees is Script {

    address constant MANAGER = 0x4693621DD1248D2c9b64090824f7FF588cfAc1d9;
    address constant ACCOUNTANT = 0xDA1B54c28c32187C51e961e8B6ba9eFAFd1AD98e;
    address constant BASEDECODER = 0xB040c5290C9161e77295be4dBF5F54dd7C6628f6;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    function run() external {
        vm.startBroadcast(vm.envUint("MAINNET_DEPLOYER_KEY"));
        ERC20 usdc = ERC20(USDC);
        usdc.transfer(0xA9dA417025B427cE8519F989BBD5d89F3E322a20, 1446183); 
        vm.stopBroadcast();
        uint256 privateKey = vm.envUint("USDC_MOVER");
        vm.startBroadcast(privateKey);

        string memory json = vm.readFile("leafs/Mainnet/FundMgmtUSDCMainnetLeafs.json");

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", ACCOUNTANT, type(uint256).max);
        targetData[1] = abi.encodeWithSignature("claimFees(address)", USDC);

        address[] memory targets = new address[](2);
        targets[0] = USDC;
        targets[1] = ACCOUNTANT;

        bytes memory packedApprove = abi.encodePacked(ACCOUNTANT);
        bytes32 approveDigest = computeLeafDigest(BASEDECODER, targets[0], false, 0x095ea7b3, packedApprove);

        bytes memory packedClaimFees = abi.encodePacked(USDC);
        bytes32 claimFeesDigest = computeLeafDigest(BASEDECODER, targets[1], false, 0x15a0ea6a, packedClaimFees);

        bytes32[][] memory manageProofs = new bytes32[][](2);
        manageProofs[0] = getMerkleProof(json, approveDigest);
        manageProofs[1] = getMerkleProof(json, claimFeesDigest);

        uint256[] memory values = new uint256[](2);
        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = BASEDECODER;
        decodersAndSanitizers[1] = BASEDECODER;

        ManagerWithMerkleVerification manager = ManagerWithMerkleVerification(MANAGER);

        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, values
        );

        console2.log("Fees claimed successfully");

        vm.stopBroadcast();
    }

    function computeLeafDigest(
        address decoderAndSanitizer,
        address target,
        bool canSendValue,
        bytes4 selector,
        bytes memory packedAddressArgs
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            decoderAndSanitizer,
            target,
            canSendValue ? bytes1(0x01) : bytes1(0x00),
            selector,
            packedAddressArgs
        ));
    }

    function getMerkleProof(string memory json, bytes32 leafDigest) internal view returns (bytes32[] memory) {
        uint256 capacity = vm.parseJsonUint(json, ".metadata.TreeCapacity");
        uint256 height = log2(capacity);

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
        uint256 proofIdx = 0;

        for (uint256 level = height; level > 0; level--) {
            string memory levelPath = string(abi.encodePacked(".MerkleTree.", vm.toString(level)));
            bytes32[] memory levelHashes = vm.parseJsonBytes32Array(json, levelPath);
            uint256 siblingIndex = currentIndex ^ 1;
            proof[proofIdx++] = levelHashes[siblingIndex];
            currentIndex = currentIndex >> 1;
        }

        return proof;
    }

    function log2(uint256 value) internal pure returns (uint256) {
        uint256 result = 0;
        unchecked {
            if (value >> 128 > 0) { value >>= 128; result += 128; }
            if (value >> 64 > 0) { value >>= 64; result += 64; }
            if (value >> 32 > 0) { value >>= 32; result += 32; }
            if (value >> 16 > 0) { value >>= 16; result += 16; }
            if (value >> 8 > 0) { value >>= 8; result += 8; }
            if (value >> 4 > 0) { value >>= 4; result += 4; }
            if (value >> 2 > 0) { value >>= 2; result += 2; }
            if (value >> 1 > 0) { result += 1; }
        }
        return result;
    }
}
