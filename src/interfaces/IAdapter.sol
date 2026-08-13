// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ISwapperTypes} from "src/interfaces/ISwapperTypes.sol";


interface IAdapter {


    //============================== Structs ===============================

    struct OrderInfo {
        //required
        address approvalTarget;
        address cancelTarget;
        address inputToken;
        address outputToken;
        uint256 inputAmount;
        uint256 outputAmount;
        bytes32 protocolHash;
        //optional extension
        address hook;
        bytes hookData;
        bytes context; //for canceling and extra storage (if needed)
    }

    //============================== Errors ===============================
    
    error Adapter__TokenInMismatch(); 
    error Adapter__TokenOutMismatch();
    error Adapter__AmountInMismatch();
    error Adapter__AmountOutMismatch();
    error Adapter__ReceiverMismatch();
    error Adapter__LimitOrdersNotSupported();

    //============================== Functions ===============================

    function version() external pure returns (string memory);
    function verifyLimitOrder(ISwapperTypes.SwapConfig calldata swapConfig, address swapper) external view returns (OrderInfo memory);

    /// @notice Returns the protocol-side cancel target and calldata for an order.
    /// @dev !!! IMPORTANT !!!!
    /// @dev For new integrations, ensure that if the cancel call can REVERT, that this case is handled INSIDE of the adapter.
    /// There may be cases where the order is submitted via the BoringSwapper, and then cannot be posted to the off-chain orderbook
    /// in time, and is expired. In such cases, if the order does not exist on chain, it may revert. 
    /// If the order does not exist on chain, return empty data so the cancel is skipped on the external protocol but still
    /// executed on the Swapper.
    function cancelLimitOrder(ISwapperTypes.SwapConfig calldata swapConfig, address swapper, bytes calldata cancelData, bytes calldata context) external view returns (address target, bytes memory data);

    function filledAmount(ISwapperTypes.SwapConfig calldata swapConfig, address swapper, bytes calldata context) external view returns (uint256);
}
