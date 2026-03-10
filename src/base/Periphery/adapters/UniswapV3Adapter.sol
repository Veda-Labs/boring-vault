// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {IAdapter} from "src/interfaces/IAdapter.sol";

//IAdapter does what exactly? TBD. 
contract UniswapV3Adapter is IAdapter {

    address public immutable UNIV3_ROUTER; 

    constructor(address _router) {
        UNIV3_ROUTER = _router; 
    }

    function exactInput(DecoderCustomTypes.ExactInputParams calldata params)
        external
        view
        virtual
        returns (address, uint256)
    {
        // Nothing to sanitize
        // Return addresses found
        // Determine how many addresses are in params.path.
        uint256 chunkSize = 23; // 3 bytes for uint24 fee, and 20 bytes for address token
        uint256 pathLength = params.path.length;
        if (pathLength % chunkSize != 20) revert("no"); //UniswapV3DecoderAndSanitizer__BadPathFormat();
        uint256 pathAddressLength = 1 + (pathLength / chunkSize);
        uint256 pathIndex;

        //get the size, check the first 20 bytes, check the last 20 bytes, those should be our two addresses
        for (uint256 i; i < pathAddressLength; ++i) {
            pathIndex += chunkSize;
        }

        return (UNIV3_ROUTER, params.amountIn); 
    }

    function version() external view returns (uint256) {
        return 1; 
    }

    function swap(bytes calldata, address swapper) external view returns (bool success, uint256 sellAmount, uint256 buyAmount) {
        return (false, 0, 0);
    }
}
