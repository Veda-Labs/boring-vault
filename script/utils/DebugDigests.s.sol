// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

contract DebugDigests is Script {
    function run() external {
        address BASEDECODER = 0xFA333c2f8a9439B1083Cae0ef3090A970cC73591;
        address TARGET_AGENT_VAULT = 0x3A29E2a5Ddb20C56D62a9D9Fa29b606833C4bf1d;
        address CLIENT_VAULT = 0x018F1c44D2628e66060382B66EE42c5EE485615f;
        address TARGET_AGENT_TELLER = 0x5915964B4441930F5FfD13EcCA0A7D2f48e1d1A8;
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

        // Compute approve digest
        bytes memory packedApprove = abi.encodePacked(TARGET_AGENT_VAULT);
        bytes32 approveDigest = keccak256(abi.encodePacked(
            BASEDECODER,
            usdc,
            bytes1(0x00), // false
            bytes4(0x095ea7b3), // approve selector
            packedApprove
        ));
        console2.log("Script approve digest:");
        console2.logBytes32(approveDigest);

        // Compute bulkDeposit digest
        bytes memory packedDeposit = abi.encodePacked(usdc, CLIENT_VAULT);
        bytes32 depositDigest = keccak256(abi.encodePacked(
            BASEDECODER,
            TARGET_AGENT_TELLER,
            bytes1(0x00), // false
            bytes4(0x9d574420), // bulkDeposit selector
            packedDeposit
        ));
        console2.log("Script deposit digest:");
        console2.logBytes32(depositDigest);
        
        // Compare with JSON values
        console2.log("JSON approve digest: 0x34ac159423bd7c97edd2defd6fd1a77c00e7bd5952925724e565280af10a4b8f");
        console2.log("JSON deposit digest:  0xf8459b28cfa6497f46be5c9c8c39a41992a655fa8141e2b60094c7ffc461151f");
    }
}