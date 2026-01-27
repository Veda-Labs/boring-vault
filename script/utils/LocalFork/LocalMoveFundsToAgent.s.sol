// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {console2} from "forge-std/console2.sol";

/*
 * source .env && forge script script/utils/LocalFork/LocalMoveFundsToAgent.s.sol:MoveFunds --fork-url local --broadcast -vvvvv
 */
contract MoveFunds is Script, MerkleTreeHelper {

    address constant MANAGER = 0x5d6C866f873fCcFAe13aD75479cFbD606fE27b29;
    address constant CLIENT_VAULT = 0x018F1c44D2628e66060382B66EE42c5EE485615f;
    address constant TARGET_AGENT_VAULT = 0x3A29E2a5Ddb20C56D62a9D9Fa29b606833C4bf1d;
    address constant TARGET_AGENT_TELLER = 0x5915964B4441930F5FfD13EcCA0A7D2f48e1d1A8;
    address constant BASEDECODER = 0xFA333c2f8a9439B1083Cae0ef3090A970cC73591;

    function run() external {
        uint256 privateKey = vm.envUint("LOCAL_DEPLOYER_PRIVATE_KEY");
        setSourceChainName("local");
        vm.startBroadcast(privateKey);

        string memory json = vm.readFile("leafs/LocalFork/FundMgmtUSDCLocalForkLeafs.json");
        bytes32 merkleRoot = vm.parseJsonBytes32(json, ".metadata.ManageRoot");

        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature("approve(address,uint256)", TARGET_AGENT_VAULT, type(uint256).max);
        targetData[1] = abi.encodeWithSignature(
            "bulkDeposit(address,uint256,uint256,address)",
            usdc,
            10_000e6, // 10k USDC
            0,
            CLIENT_VAULT
        );

        address[] memory targets = new address[](2);
        targets[0] = usdc;
        targets[1] = TARGET_AGENT_TELLER;

        bytes memory packedApprove = abi.encodePacked(TARGET_AGENT_VAULT);
        bytes32 approveDigest = computeLeafDigest(BASEDECODER, targets[0], false, 0x095ea7b3, packedApprove);

        bytes memory packedDeposit = abi.encodePacked(usdc, CLIENT_VAULT);
        bytes32 depositDigest = computeLeafDigest(BASEDECODER, targets[1], false, 0x9d574420, packedDeposit);

        bytes32[][] memory manageProofs = new bytes32[][](2);
        manageProofs[0] = getMerkleProof(json, approveDigest);
        manageProofs[1] = getMerkleProof(json, depositDigest);

        uint256[] memory values = new uint256[](2);
        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = BASEDECODER;
        decodersAndSanitizers[1] = BASEDECODER;

        ManagerWithMerkleVerification manager = ManagerWithMerkleVerification(MANAGER);
        manager.setManageRoot(vm.envAddress("LOCAL_DEPLOYER_ADDRESS"), merkleRoot);

        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, values
        );

        ERC20 _usdc = ERC20(usdc);
        uint256 AgentVaultBalance = _usdc.balanceOf(TARGET_AGENT_VAULT);
        console2.log("Agent Vault USDC Balance: ", AgentVaultBalance / 1e6);

        ERC20 agentVault = ERC20(TARGET_AGENT_VAULT);
        uint256 clientVaultBalance = agentVault.balanceOf(CLIENT_VAULT);
        console2.log("CLIENT Shares Balance: ", clientVaultBalance / 1e6);

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