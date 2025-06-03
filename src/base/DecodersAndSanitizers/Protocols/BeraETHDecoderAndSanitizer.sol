// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract BeraETHDecoderAndSanitizer {
    //============================== rberaETH ===============================

    function depositAndWrap(address WETH, uint256, /*amount*/ uint256 /*minAmountOut*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(WETH);
    }

    // TODO idk if we need this
    //function withdraw(address receiver, uint256 /*unwrappedAmount*/, bytes memory options) external pure virtual returns (bytes memory addressesFound) {
    //    addressesFound = abi.encodePacked(receiver, options);
    //}

    //============================== beraETH ===============================

    function unwrap(uint256 /*amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }
}
