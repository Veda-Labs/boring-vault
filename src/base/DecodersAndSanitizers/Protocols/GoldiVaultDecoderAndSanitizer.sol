// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

contract GoldiVaultDecoderAndSanitizer {
    //============================== GoldiVault ===============================

    function deposit(uint256 /*amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function redeemOwnership(uint256 /*amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function redeemYield(uint256 /*amount*/ ) external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    function compound() external pure virtual returns (bytes memory addressesFound) {
        return addressesFound;
    }

    //============================== PointsGoldiVaultStreaming ===============================

    function buyYT(uint256, /*ytAmount*/ uint256, /*dtAmountMax*/ uint256 /*amountOutMin*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }

    function sellYT(uint256, /*ytAmount*/ uint256, /*dtAmountMin*/ uint256 /*amountInMax*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return addressesFound;
    }
}
