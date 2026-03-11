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


contract OneInchAdapter is IAdapter, BaseAdapter {

    address public immutable ROUTER;

    constructor(address _router) {
        ROUTER = _router;
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

    function unoswap(uint256 token, uint256 amount, uint256 /*minReturn*/, uint256 /*dex*/)
        external
        view
        returns (address, uint256)
    {
        BoringSwapper.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(address(uint160(token))) != swapConfig.tokenRoute.tokenIn) revert("token mismatch");

        return (ROUTER, amount);
    }

    function unoswap2(uint256 token, uint256 amount, uint256 /*minReturn*/, uint256 /*dex*/, uint256 /*dex2*/)
        external
        view
        returns (address, uint256)
    {
        BoringSwapper.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(address(uint160(token))) != swapConfig.tokenRoute.tokenIn) revert("token mismatch");

        return (ROUTER, amount);
    }

    function unoswap3(uint256 token, uint256 amount, uint256 /*minReturn*/, uint256 /*dex*/, uint256 /*dex2*/, uint256 /*dex3*/)
        external
        view
        returns (address, uint256)
    {
        BoringSwapper.SwapConfig memory swapConfig = _getAppendedSwapConfig();
        if (ERC20(address(uint160(token))) != swapConfig.tokenRoute.tokenIn) revert("token mismatch");

        return (ROUTER, amount);
    }

    function version() external view returns (uint256) {
        return 1;
    }

    function verifyLimitOrder(BoringSwapper.SwapConfig calldata swapConfig, address) external view returns (address, address, address, uint256, uint256) {
        return (address(0), address(0), address(0), 0, 0);
    }
}
