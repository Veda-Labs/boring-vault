// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract OogaBoogaDecoderAndSanitizer {
    function swap(
        DecoderCustomTypes.swapTokenInfoOogaBooga memory tokenInfo,
        bytes calldata, /*pathDefinition*/
        address executor,
        uint32 /*referralCode*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound =
            abi.encodePacked(tokenInfo.inputToken, tokenInfo.outputToken, tokenInfo.outputReceiver, executor);
    }
}
