// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract SonicGatewayDecoderAndSanitizer {
    ////////////////// Sonic Gateway //////////////////

    //bridges mainnet -> sonic
    function deposit(uint96, /*uid*/ address token, uint256 /*amount*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(token);
    }

    //bridges sonic -> mainnet
    function withdraw(uint96, /*uid*/ address token, uint256 /*amount*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(token);
    }

    function claim(uint256, /*id*/ address token, uint256, /*amount*/ bytes calldata /*proof*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(token);
    }

    //if the bridge is "dead", we can cancel our deposit if needed
    function cancelDepositWhileDead(uint256, /*id*/ address token, uint256, /*amount*/ bytes calldata /*proof*/ )
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        return abi.encodePacked(token);
    }
}
