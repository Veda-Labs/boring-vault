// SPDX-License-Identifier: SEL-1.0
pragma solidity 0.8.21;

import {Test} from "@forge-std/Test.sol";
import {OFTDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/Protocols/OFTDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract OFTDecoderAndSanitizerTest is Test {
    function testSolanaVaultPdaSurvivesSanitizedAddressHalves() external {
        OFTDecoderAndSanitizer decoder = new OFTDecoderAndSanitizer();
        bytes32 vaultPda =
            hex"0a0ec301764a27c80560b1001676dad0960e95a8be674f17c10fe0337fb5653d";
        address refundAddress = address(0xB0B);

        DecoderCustomTypes.SendParam memory sendParam;
        sendParam.dstEid = 30168;
        sendParam.to = vaultPda;
        sendParam.amountLD = 1;
        sendParam.minAmountLD = 1;

        DecoderCustomTypes.MessagingFee memory fee;
        bytes memory sanitized = decoder.send(sendParam, fee, refundAddress);

        bytes20 highAddress;
        bytes20 lowAddress;
        assembly {
            highAddress := mload(add(sanitized, 52))
            lowAddress := mload(add(sanitized, 72))
        }
        bytes32 reconstructed =
            bytes32(bytes16(highAddress)) | bytes32(uint256(uint128(bytes16(lowAddress))));

        assertEq(reconstructed, vaultPda);
        assertEq(
            sanitized,
            abi.encodePacked(
                address(uint160(30168)),
                address(bytes20(bytes16(vaultPda))),
                address(bytes20(bytes16(vaultPda << 128))),
                refundAddress
            )
        );
    }
}
