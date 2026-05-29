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

contract LifiAdapter is IAdapter, BaseAdapter {

    //============================== Errors ===============================


    //============================== State ===============================

    // LI.FI Diamond contract — entry point for all swaps.
    address public immutable router;

    //============================== Constructor ===============================

    constructor(address _router) {
        router = _router;
    }

    //============================== Swap functions ===============================

    // ── GenericSwapFacet (V1) ────────────────────────────────────────────────

    /// @notice Validates a swapTokensGeneric call (GenericSwapFacet).
    /// @dev Multi-hop: tokenIn = swapData[0].sendingAssetId, tokenOut = swapData[last].receivingAssetId.
    function swapTokensGeneric(
        bytes32 /*_transactionId*/,
        string calldata /*_integrator*/,
        string calldata /*_referrer*/,
        address payable _receiver,
        uint256 /*_minAmount*/,
        DecoderCustomTypes.LifiSwapData[] calldata _swapData
    ) external view returns (address, uint256) {
        if (_receiver != payable(msg.sender)) revert Adapter__ReceiverMismatch();

        ISwapperTypes.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(_swapData[0].sendingAssetId) != swapConfig.tokenRoute.tokenIn)
            revert Adapter__TokenInMismatch();
        if (ERC20(_swapData[_swapData.length - 1].receivingAssetId) != swapConfig.tokenRoute.tokenOut)
            revert Adapter__TokenOutMismatch();

        return (router, _swapData[0].fromAmount);
    }

    // ── GenericSwapFacetV3 ───────────────────────────────────────────────────
    // Native variants (ERC20ToNative, NativeToERC20) are intentionally omitted —
    // the vault is ERC20-only and cannot receive or send raw ETH.

    /// @notice Validates a swapTokensSingleV3ERC20ToERC20 call (GenericSwapFacetV3).
    function swapTokensSingleV3ERC20ToERC20(
        bytes32 /*_transactionId*/,
        string calldata /*_integrator*/,
        string calldata /*_referrer*/,
        address payable _receiver,
        uint256 /*_minAmountOut*/,
        DecoderCustomTypes.LifiSwapData calldata _swapData
    ) external view returns (address, uint256) {
        if (_receiver != payable(msg.sender)) revert Adapter__ReceiverMismatch();

        ISwapperTypes.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(_swapData.sendingAssetId) != swapConfig.tokenRoute.tokenIn)
            revert Adapter__TokenInMismatch();
        if (ERC20(_swapData.receivingAssetId) != swapConfig.tokenRoute.tokenOut)
            revert Adapter__TokenOutMismatch();

        return (router, _swapData.fromAmount);
    }

    /// @notice Validates a swapTokensMultipleV3ERC20ToERC20 call (GenericSwapFacetV3).
    function swapTokensMultipleV3ERC20ToERC20(
        bytes32 /*_transactionId*/,
        string calldata /*_integrator*/,
        string calldata /*_referrer*/,
        address payable _receiver,
        uint256 /*_minAmountOut*/,
        DecoderCustomTypes.LifiSwapData[] calldata _swapData
    ) external view returns (address, uint256) {
        if (_receiver != payable(msg.sender)) revert Adapter__ReceiverMismatch();

        ISwapperTypes.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(_swapData[0].sendingAssetId) != swapConfig.tokenRoute.tokenIn)
            revert Adapter__TokenInMismatch();
        if (ERC20(_swapData[_swapData.length - 1].receivingAssetId) != swapConfig.tokenRoute.tokenOut)
            revert Adapter__TokenOutMismatch();

        return (router, _swapData[0].fromAmount);
    }

    //============================== Limit Orders (not supported) ===============================

    function verifyLimitOrder(ISwapperTypes.SwapConfig calldata, address)
        external
        pure
        returns (OrderInfo memory)
    {
        revert Adapter__LimitOrdersNotSupported();
    }

    function cancelLimitOrder(ISwapperTypes.SwapConfig calldata, address, bytes calldata /*cancelData*/, bytes calldata /*context*/)
        external
        pure
        returns (address, bytes memory)
    {
        revert Adapter__LimitOrdersNotSupported();
    }

    function filledAmount(ISwapperTypes.SwapConfig calldata, address, bytes calldata /*context*/) external pure returns (uint256) {
        revert Adapter__LimitOrdersNotSupported();
    }

    function version() external pure returns (string memory) {
        return "v1";
    }
}
