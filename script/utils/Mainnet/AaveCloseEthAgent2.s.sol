// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

/*
 * source .env && forge script script/utils/Mainnet/AaveCloseEthAgent2.s.sol:AaveCloseEthAgent2 --rpc-url mainnet --broadcast -vv
 */

contract AaveCloseEthAgent2 is Script, MerkleTreeHelper {
    address private constant MANAGER = 0x618c13371DB671AdbCbA93e76f758E307E6A0871;
    address private constant BORING_VAULT = 0x951f36b2F8Fd8B213AE999E53dF1c77749A6cDed;
    address private constant DECODER_AND_SANITIZER = 0xc5c641525Bbf2fD6d163c138101F82c1ca4FBaaE;
    address private constant AAVE_POOL = 0x4e033931ad43597d96D6bcc25c280717730B58B1;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;

    bytes32 private constant REPAY_WETH_LEAF = 0x7400791cd642fd1d1d0505972c4064802e5d5c6dc2cf326b8f1e8134cf980fa2;
    bytes32 private constant WITHDRAW_WSTETH_LEAF = 0x16bebdc8dcf1771fea5315c2d08970332e1dc74c294d6e88349798f89672e38c;

    uint256 private constant VARIABLE_INTEREST_RATE_MODE = 2;

    function run() external {
        uint256 privateKey = vm.envUint("MAINNET_DEPLOYER_KEY");
        string memory json = vm.readFile("leafs/Mainnet/ETHAgent2Prime.json");

        setSourceChainName("mainnet");

        vm.startBroadcast(privateKey);

        bytes32[] memory repayProof = getMerkleProof(json, REPAY_WETH_LEAF);
        bytes32[] memory withdrawProof = getMerkleProof(json, WITHDRAW_WSTETH_LEAF);

        bytes32[][] memory proofs = new bytes32[][](2);
        proofs[0] = repayProof;
        proofs[1] = withdrawProof;

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = DECODER_AND_SANITIZER;
        decodersAndSanitizers[1] = DECODER_AND_SANITIZER;

        address[] memory targets = new address[](2);
        targets[0] = AAVE_POOL;
        targets[1] = AAVE_POOL;

        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "repay(address,uint256,uint256,address)",
            WETH,
            type(uint256).max,
            VARIABLE_INTEREST_RATE_MODE,
            BORING_VAULT
        );

        targetData[1] = abi.encodeWithSignature(
            "withdraw(address,uint256,address)",
            WSTETH,
            type(uint256).max,
            BORING_VAULT
        );

        uint256[] memory values = new uint256[](2);

        ManagerWithMerkleVerification(MANAGER).manageVaultWithMerkleVerification(
            proofs,
            decodersAndSanitizers,
            targets,
            targetData,
            values
        );

        console.log("Closed AAVE position");
        console.log("wstETH balance:", ERC20(WSTETH).balanceOf(BORING_VAULT));

        vm.stopBroadcast();
    }

    function getMerkleProof(string memory json, bytes32 leafDigest) internal view returns (bytes32[] memory) {
        uint256 capacity = vm.parseJsonUint(json, ".metadata.TreeCapacity");
        uint256 height = _calculateTreeHeight(capacity);

        bytes32[] memory leaves = _getLeaves(json, height);
        uint256 leafIndex = _findLeafIndex(leaves, leafDigest);

        return _buildProof(json, height, leafIndex);
    }

    function _calculateTreeHeight(uint256 capacity) private pure returns (uint256) {
        require(capacity > 0, "Invalid capacity");
        uint256 height = 0;
        uint256 temp = capacity;
        while (temp > 1) {
            temp >>= 1;
            height++;
        }
        return height;
    }

    function _getLeaves(string memory json, uint256 height) private view returns (bytes32[] memory) {
        string memory leavesPath = string(abi.encodePacked(".MerkleTree.", vm.toString(height)));
        return vm.parseJsonBytes32Array(json, leavesPath);
    }

    function _findLeafIndex(bytes32[] memory leaves, bytes32 leafDigest) private pure returns (uint256) {
        for (uint256 i = 0; i < leaves.length; i++) {
            if (leaves[i] == leafDigest) {
                return i;
            }
        }
        revert("Leaf not found in merkle tree");
    }

    function _buildProof(
        string memory json,
        uint256 height,
        uint256 leafIndex
    ) private view returns (bytes32[] memory) {
        bytes32[] memory proof = new bytes32[](height);
        uint256 currentIndex = leafIndex;

        for (uint256 level = height; level > 0; level--) {
            string memory levelPath = string(abi.encodePacked(".MerkleTree.", vm.toString(level)));
            bytes32[] memory levelHashes = vm.parseJsonBytes32Array(json, levelPath);
            proof[height - level] = levelHashes[currentIndex ^ 1];
            currentIndex >>= 1;
        }

        return proof;
    }
}
