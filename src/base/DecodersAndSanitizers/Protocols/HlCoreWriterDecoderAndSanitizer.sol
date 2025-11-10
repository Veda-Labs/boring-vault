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
            (uint32 asset, bool isBuy, uint64 limitPx, uint64 sz, bool reduceOnly, uint8 encodedTif, uint128 cloid) =
                abi.decode(data[4:], (uint32, bool, uint64, uint64, bool, uint8, uint128));
            return abi.encodePacked(asset, isBuy, limitPx / G, limitPx % G == 0);
        } else if (actionID == 0x06) {
            (address destination, uint64 token, uint64 _wei) = abi.decode(data[4:], (address, uint64, uint64));
            return abi.encodePacked(destination);
        } else if(actionID == 0x02) {
            (address vault,bool isDeposit, uint64 usd) = abi.decode(data[4:], (address, bool, uint64));
            return abi.encodePacked(vault);
        } else if(actionID == 0x07) {
            (uint64 ntl,bool toPerp) = abi.decode(data[4:], (uint64,bool));
            return abi.encodePacked(ntl,toPerp);
        }
    }
}
