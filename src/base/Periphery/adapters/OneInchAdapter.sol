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
import {IUniswapV3} from "src/interfaces/IUniswapV3.sol";


contract OneInchAdapter is IAdapter, BaseAdapter {

    address public immutable ROUTER;
    address public immutable FEE_TAKER;

    bytes32 constant ONEINCH_ORDER_TYPE_HASH = keccak256(
        "Order(uint256 salt,address maker,address receiver,address makerAsset,address takerAsset,uint256 makingAmount,uint256 takingAmount,uint256 makerTraits)"
    );

    bytes32 immutable DOMAIN_SEPARATOR;

    constructor(address _router, address _feeTaker) {
        ROUTER = _router;
        FEE_TAKER = _feeTaker;
        DOMAIN_SEPARATOR = keccak256(abi.encode(
            keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
            keccak256("1inch Aggregation Router"),
            keccak256("6"),
            block.chainid,
            _router
        ));
    }

    //============================== V6 swap ===============================

    function swap(
        address executor,
        DecoderCustomTypes.SwapDescription memory desc,
        bytes memory /*data*/
    ) external view returns (address, uint256) {
        if (desc.dstReceiver != payable(msg.sender)) revert("dstReceiver must be swapper");

        BoringSwapper.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(desc.srcToken) != swapConfig.tokenRoute.tokenIn) revert("srcToken mismatch");
        if (ERC20(desc.dstToken) != swapConfig.tokenRoute.tokenOut) revert("dstToken mismatch");

        return (ROUTER, desc.amount);
    }

    //============================== V6 unoswap ===============================

    function unoswap(uint256 token, uint256 amount, uint256 /*minReturn*/, uint256 dex)
        external
        view
        returns (address, uint256)
    {
        BoringSwapper.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(address(uint160(token))) != swapConfig.tokenRoute.tokenIn) revert("token mismatch");
        if (ERC20(_dexTokenOut(dex)) != swapConfig.tokenRoute.tokenOut) revert("tokenOut mismatch");

        return (ROUTER, amount);
    }

    function unoswap2(uint256 token, uint256 amount, uint256 /*minReturn*/, uint256 /*dex*/, uint256 dex2)
        external
        view
        returns (address, uint256)
    {
        BoringSwapper.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(address(uint160(token))) != swapConfig.tokenRoute.tokenIn) revert("token mismatch");
        if (ERC20(_dexTokenOut(dex2)) != swapConfig.tokenRoute.tokenOut) revert("tokenOut mismatch");

        return (ROUTER, amount);
    }

    function unoswap3(uint256 token, uint256 amount, uint256 /*minReturn*/, uint256 /*dex*/, uint256 /*dex2*/, uint256 dex3)
        external
        view
        returns (address, uint256)
    {
        BoringSwapper.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(address(uint160(token))) != swapConfig.tokenRoute.tokenIn) revert("token mismatch");
        if (ERC20(_dexTokenOut(dex3)) != swapConfig.tokenRoute.tokenOut) revert("tokenOut mismatch");

        return (ROUTER, amount);
    }

    function unoswapTo(uint256 to, uint256 token, uint256 amount, uint256 /*minReturn*/, uint256 dex)
        external
        view
        returns (address, uint256)
    {
        if (address(uint160(to)) != msg.sender) revert("to must be swapper");
        BoringSwapper.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(address(uint160(token))) != swapConfig.tokenRoute.tokenIn) revert("token mismatch");
        if (ERC20(_dexTokenOut(dex)) != swapConfig.tokenRoute.tokenOut) revert("tokenOut mismatch");

        return (ROUTER, amount);
    }

    function unoswapTo2(uint256 to, uint256 token, uint256 amount, uint256 /*minReturn*/, uint256 /*dex*/, uint256 dex2)
        external
        view
        returns (address, uint256)
    {
        if (address(uint160(to)) != msg.sender) revert("to must be swapper");
        BoringSwapper.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(address(uint160(token))) != swapConfig.tokenRoute.tokenIn) revert("token mismatch");
        if (ERC20(_dexTokenOut(dex2)) != swapConfig.tokenRoute.tokenOut) revert("tokenOut mismatch");

        return (ROUTER, amount);
    }

    function unoswapTo3(uint256 to, uint256 token, uint256 amount, uint256 /*minReturn*/, uint256 /*dex*/, uint256 /*dex2*/, uint256 dex3)
        external
        view
        returns (address, uint256)
    {
        if (address(uint160(to)) != msg.sender) revert("to must be swapper");
        BoringSwapper.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(address(uint160(token))) != swapConfig.tokenRoute.tokenIn) revert("token mismatch");
        if (ERC20(_dexTokenOut(dex3)) != swapConfig.tokenRoute.tokenOut) revert("tokenOut mismatch");

        return (ROUTER, amount);
    }

    // 1inch V6: fillOrder routes swaps through the limit order protocol.
    // Order fields use Address (uint256) type; strip upper flag bits with uint160 cast.
    function fillOrder(
        DecoderCustomTypes.OneInchV6Order calldata order,
        bytes32 /*r*/,
        bytes32 /*vs*/,
        uint256 amount,
        uint256 /*takerTraits*/
    ) external view returns (address, uint256) {
        BoringSwapper.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(address(uint160(order.takerAsset))) != swapConfig.tokenRoute.tokenIn) revert("takerAsset mismatch");
        if (ERC20(address(uint160(order.makerAsset))) != swapConfig.tokenRoute.tokenOut) revert("makerAsset mismatch");

        return (ROUTER, amount);
    }

    function version() external view returns (uint256) {
        return 1;
    }

    //============================== Limit Orders ===============================

    /// @notice swapData encoding: abi.encode(OneInchLimitOrder order, bytes extension)
    /// The extension contains the FeeTaker postInteraction data where the custom receiver (vault) is embedded.
    function verifyLimitOrder(BoringSwapper.SwapConfig calldata swapConfig, address swapper) external view returns (OrderInfo memory) {
        (DecoderCustomTypes.OneInchLimitOrder memory order, bytes memory extension) =
            abi.decode(swapConfig.swapData, (DecoderCustomTypes.OneInchLimitOrder, bytes));

        if (ERC20(order.makerAsset) != swapConfig.tokenRoute.tokenIn) revert("makerAsset mismatch");
        if (ERC20(order.takerAsset) != swapConfig.tokenRoute.tokenOut) revert("takerAsset mismatch");
        if (order.maker != swapper) revert("maker must be swapper");

        // For orders with a fee extension, the order.receiver is the fee taker contract.
        // The actual receiver (vault) is embedded in the extension's postInteraction data.
        if (extension.length > 0) {
            if (order.receiver != FEE_TAKER) revert("unknown fee taker");
            address customReceiver = _extractCustomReceiver(extension);
            if (customReceiver != address(swapConfig.receiver)) revert("extension receiver mismatch");
        } else {
            if (order.receiver != address(swapConfig.receiver)) revert("receiver mismatch");
        }

        bytes memory orderData = abi.encode(order);
        bytes32 orderHash = _computeOrderHash(orderData);

        return OrderInfo({
            approvalTarget: ROUTER,
            cancelTarget: ROUTER,
            settlementCaller: ROUTER,
            inputToken: order.makerAsset,
            outputToken: order.takerAsset,
            inputAmount: order.makingAmount,
            outputAmount: order.takingAmount,
            protocolHash: orderHash
        });
    }

    function cancelLimitOrder(BoringSwapper.SwapConfig calldata swapConfig, address) external view returns (address, bytes memory) {
        (DecoderCustomTypes.OneInchLimitOrder memory order,) =
            abi.decode(swapConfig.swapData, (DecoderCustomTypes.OneInchLimitOrder, bytes));
        bytes memory orderData = abi.encode(order);
        bytes32 orderHash = _computeOrderHash(orderData);
        return (ROUTER, abi.encodeWithSignature("cancelOrder(uint256,bytes32)", order.makerTraits, orderHash));
    }

    //============================== Internal ===============================

    // 1inch V6 encodes the swap direction in bit 247 of the dex uint256:
    //   bit 247 = 1 (zeroForOne): token0 is input, token1 is output
    //   bit 247 = 0:              token1 is input, token0 is output
    function _dexTokenOut(uint256 dex) internal view returns (address) {
        address pool = address(uint160(dex));
        bool zeroForOne = (dex >> 247) & 0x01 == 1;
        return zeroForOne ? IUniswapV3(pool).token1() : IUniswapV3(pool).token0();
    }

    function _computeOrderHash(bytes memory orderData) internal view returns (bytes32) {
        bytes32 structHash = keccak256(abi.encodePacked(ONEINCH_ORDER_TYPE_HASH, orderData));
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash));
    }

    /// @notice Extracts the custom receiver address from a 1inch FeeTaker extension.
    /// Extension layout:
    ///   [32 bytes] header — 8 packed uint32 offsets
    ///   [variable] data   — concatenated fields
    /// PostInteraction layout (within data):
    ///   [20 bytes] fee taker address
    ///   [ 1 byte ] flags (bit 0 = CUSTOM_RECEIVER_FLAG)
    ///   [20 bytes] integrator fee recipient
    ///   [20 bytes] protocol fee recipient
    ///   [20 bytes] custom receiver (only if flags & 1)
    function _extractCustomReceiver(bytes memory extension) internal pure returns (address) {
        require(extension.length >= 32, "extension too short");

        // Header offset[1] (bytes 4-7) = postInteraction start in data
        uint32 postInteractionStart;
        assembly {
            postInteractionStart := shr(224, mload(add(extension, 36))) // bytes 4-7 of header
        }

        // postInteraction is at: 32 (header) + postInteractionStart
        uint256 piOffset = 32 + uint256(postInteractionStart);
        require(extension.length >= piOffset + 62, "postInteraction too short");

        // Read flags byte at postInteraction + 20 (after fee taker address)
        uint8 flags;
        assembly {
            flags := byte(0, mload(add(add(extension, 32), add(piOffset, 20))))
        }

        require(flags & 1 == 1, "no custom receiver in extension");
        require(extension.length >= piOffset + 81, "custom receiver out of bounds");

        // Custom receiver is at postInteraction + 61 (after: 20 addr + 1 flags + 20 integrator + 20 protocol)
        address customReceiver;
        assembly {
            customReceiver := shr(96, mload(add(add(extension, 32), add(piOffset, 61))))
        }

        return customReceiver;
    }
}
