// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

abstract contract CoreWriterDecoderAndSanitizer is BaseDecoderAndSanitizer {
    uint64 constant G = 10;

    error CoreWriterDecoderAndSanitizer__InvalidEncodingVersion();
    error CoreWriterDecoderAndSanitizer__InvalidActionID();

    function sendRawAction(bytes calldata data) external view virtual returns (bytes memory addressesFound) {
        if (data[0] != 0x01) {
            revert CoreWriterDecoderAndSanitizer__InvalidEncodingVersion();
        }
        bytes1 actionID = data[3];

        if (actionID == 0x01) {
            // limit order
            (uint32 asset, bool isBuy, uint64 limitPx, uint64 sz, bool reduceOnly, uint8 encodedTif, uint128 cloid) =
                abi.decode(data[4:], (uint32, bool, uint64, uint64, bool, uint8, uint128));
            return abi.encodePacked(
                address(uint160(asset)),
                address(uint160(isBuy ? 1 : 0)),
                address(uint160(limitPx / G)),
                address(uint160(limitPx % G == 0 ? 1 : 0))
            );
        } else if (actionID == 0x06) {
            // spot send
            (address destination, uint64 token, uint64 _wei) = abi.decode(data[4:], (address, uint64, uint64));
            return abi.encodePacked(destination);
        } else if (actionID == 0x0a) {
            // cancel limit order by OID
            (uint32 asset, uint64 oid) = abi.decode(data[4:], (uint32, uint64));
            return abi.encodePacked(address(uint160(asset)));
        } else if (actionID == 0x0b) {
            // cancel limit order by CLOID
            (uint32 asset, uint128 cloid) = abi.decode(data[4:], (uint32, uint128));
            return abi.encodePacked(address(uint160(asset)));
        } else {
            revert CoreWriterDecoderAndSanitizer__InvalidActionID();
        }
    }
}
