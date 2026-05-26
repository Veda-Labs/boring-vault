// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ISwapperTypes} from "src/interfaces/ISwapperTypes.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {IAdapter} from "src/interfaces/IAdapter.sol";
import {ISwapper} from "src/interfaces/ISwapper.sol";

interface IGPv2Settlement {
    function domainSeparator() external view returns (bytes32);
    function filledAmount(bytes calldata orderUid) external view returns (uint256);
}

contract CowswapAdapter is IAdapter {

    //============================== Errors ===============================

    error CowswapAdapter__OnlySellOrdersSupported();
    error CowswapAdapter__SellTokenMismatch();
    error CowswapAdapter__BuyTokenMismatch();
    error CowswapAdapter__ReceiverMismatch();
    error CowswapAdapter__NonZeroFeeAmount();
    error CowswapAdapter__InvalidSellTokenBalance();
    error CowswapAdapter__InvalidBuyTokenBalance();

    //============================== Immutables ===============================
    
    address immutable cowSettlement;
    address immutable vaultRelayer;

    //============================== Constants ===============================

    bytes32 constant GPV2_ORDER_TYPE_HASH = keccak256(
        "Order(address sellToken,address buyToken,address receiver,uint256 sellAmount,uint256 buyAmount,uint32 validTo,bytes32 appData,uint256 feeAmount,string kind,bool partiallyFillable,string sellTokenBalance,string buyTokenBalance)"
    );

    //============================== Constructor ===============================
    
    constructor(address _cowSettlement, address _vaultRelayer) {
        cowSettlement = _cowSettlement;
        vaultRelayer = _vaultRelayer;
    }

    //============================== Limit Orders ===============================

    function verifyLimitOrder(ISwapperTypes.SwapConfig calldata swapConfig, address)
        external
        view
        returns (OrderInfo memory)
    {
        DecoderCustomTypes.GPv2OrderData memory order =
            abi.decode(swapConfig.swapData, (DecoderCustomTypes.GPv2OrderData));

        if (order.kind != keccak256("sell")) revert CowswapAdapter__OnlySellOrdersSupported();
        if (order.feeAmount != 0) revert CowswapAdapter__NonZeroFeeAmount();
        if (order.sellTokenBalance != keccak256("erc20")) revert CowswapAdapter__InvalidSellTokenBalance();
        if (order.buyTokenBalance != keccak256("erc20")) revert CowswapAdapter__InvalidBuyTokenBalance();
        if (ERC20(order.sellToken) != swapConfig.tokenRoute.tokenIn) revert CowswapAdapter__SellTokenMismatch();
        if (ERC20(order.buyToken) != swapConfig.tokenRoute.tokenOut) revert CowswapAdapter__BuyTokenMismatch();
        if (order.receiver != (address(swapConfig.receiver))) revert CowswapAdapter__ReceiverMismatch();

        bytes32 orderHash = _computeOrderHash(swapConfig.swapData);

        return OrderInfo({
            approvalTarget: vaultRelayer,
            cancelTarget: cowSettlement,
            inputToken: order.sellToken,
            outputToken: order.buyToken,
            inputAmount: order.sellAmount,
            outputAmount: order.buyAmount,
            protocolHash: orderHash,
            hook: address(0),
            hookData: ""
        });
    }

    function cancelLimitOrder(ISwapperTypes.SwapConfig calldata swapConfig, address swapper)
        external
        view
        returns (address, bytes memory)
    {
        DecoderCustomTypes.GPv2OrderData memory order =
            abi.decode(swapConfig.swapData, (DecoderCustomTypes.GPv2OrderData));
        bytes32 orderHash = _computeOrderHash(swapConfig.swapData);
        bytes memory orderUid = abi.encodePacked(orderHash, swapper, order.validTo);
        return (cowSettlement, abi.encodeWithSignature("invalidateOrder(bytes)", orderUid));
    }

    /// @dev `filledAmount` is also set to `type(uint256).max` by `invalidateOrder`. The swapper only
    ///      invalidates from inside `_cancelOrder` and queries `isFilled` BEFORE that call, so any
    ///      non-zero reading at this site must be a genuine fill. Partial fills are rejected upstream
    ///      in `verifyLimitOrder`.
    function filledAmount(ISwapperTypes.SwapConfig calldata swapConfig, address swapper)
        external
        view
        returns (uint256)
    {
        DecoderCustomTypes.GPv2OrderData memory order =
            abi.decode(swapConfig.swapData, (DecoderCustomTypes.GPv2OrderData));
        bytes32 orderHash = _computeOrderHash(swapConfig.swapData);
        bytes memory orderUid = abi.encodePacked(orderHash, swapper, order.validTo);
        return IGPv2Settlement(cowSettlement).filledAmount(orderUid);
    }

    function version() external view returns (uint256) {
        return 1;
    }

    //============================== Internal ===============================

    function _computeOrderHash(bytes memory swapData) internal view returns (bytes32) {
        bytes32 domainSeparator = IGPv2Settlement(cowSettlement).domainSeparator();
        bytes32 structHash = keccak256(abi.encodePacked(GPV2_ORDER_TYPE_HASH, swapData));
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }
}
