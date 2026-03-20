// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringSwapper} from "src/base/Periphery/BoringSwapper.sol";
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
        BoringSwapper.SwapConfig memory swapConfig = _getAppendedSwapConfig();

        // verify path tokens match the approved token route
        // path is abi.encodePacked(tokenIn, fee, ..., tokenOut) — first 20 bytes = tokenIn, last 20 bytes = tokenOut
        bytes memory path = params.path;
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

    function verifyLimitOrder(BoringSwapper.SwapConfig calldata swapConfig, address) external view returns (OrderInfo memory) {
        return OrderInfo({
            approvalTarget: address(0),
            cancelTarget: address(0),
            settlementCaller: address(0),
            inputToken: address(0),
            outputToken: address(0),
            inputAmount: 0,
            outputAmount: 0,
            protocolHash: bytes32(0)
        });
    }

    function cancelLimitOrder(BoringSwapper.SwapConfig calldata, address) external pure returns (address, bytes memory) {
        return (address(0), "");
    }
}
