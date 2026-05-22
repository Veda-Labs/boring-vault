// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ISwapperTypes} from "src/interfaces/ISwapperTypes.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IAdapter} from "src/interfaces/IAdapter.sol";
import {BaseAdapter} from "src/base/Periphery/adapters/BaseAdapter.sol";

contract UniswapV3Adapter is IAdapter, BaseAdapter {

    address public immutable UNIV3_ROUTER;

    constructor(address _router) {
        UNIV3_ROUTER = _router;
    }

    function exactInput(DecoderCustomTypes.ExactInputParams memory params)
        external
        view
        virtual
        returns (address, uint256)
    {
        if (params.recipient != msg.sender) revert("recipient must be swapper");

        // extract appended SwapConfig for additional validation
        ISwapperTypes.SwapConfig memory swapConfig = _getAppendedSwapConfig();

        // verify path tokens match the approved token route
        // canonical V3 path: abi.encodePacked(token, fee, token, fee, ..., token) — 20-byte tokens, 3-byte fees
        // length must be 20 + n*23 for n >= 1 hop, else Uniswap may interpret the path differently than this adapter reads it
        bytes memory path = params.path;
        if (path.length < 43 || (path.length - 20) % 23 != 0) revert("invalid path length");
        address pathTokenIn;
        address pathTokenOut;
        assembly {
            pathTokenIn := shr(96, mload(add(path, 0x20)))
            pathTokenOut := shr(96, mload(add(add(path, 0x20), sub(mload(path), 20))))
        }
        if (ERC20(pathTokenIn) != swapConfig.tokenRoute.tokenIn) revert("path tokenIn mismatch");
        if (ERC20(pathTokenOut) != swapConfig.tokenRoute.tokenOut) revert("path tokenOut mismatch");

        return (UNIV3_ROUTER, params.amountIn);
    }

    function version() external view returns (uint256) {
        return 1; 
    }

    error UniswapV3Adapter__LimitOrdersNotSupported();

    function verifyLimitOrder(ISwapperTypes.SwapConfig calldata, address) external pure returns (OrderInfo memory) {
        revert UniswapV3Adapter__LimitOrdersNotSupported();
    }

    function cancelLimitOrder(ISwapperTypes.SwapConfig calldata, address) external pure returns (address, bytes memory) {
        revert UniswapV3Adapter__LimitOrdersNotSupported();
    }

    function filledAmount(ISwapperTypes.SwapConfig calldata, address) external pure returns (uint256) {
        revert UniswapV3Adapter__LimitOrdersNotSupported();
    }
}
