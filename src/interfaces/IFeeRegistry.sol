// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";

interface IFeeRegistry {

    //active checks
    function atomicFeeActive(address swapper) external view returns (bool);
    function limitFeeActive(address swapper) external view returns (bool);
    
    //get fee for swapper -> token pair
    function getAtomicFee(address swapper, address tokenIn, address tokenOut) external view returns (uint16 feeBps);
    function getLimitFee(address swapper, address tokenIn, address tokenOut) external view returns (uint16 feeBps);
    
    //get fee recipient for swapper -> token pair
    function getFeeRecipientAtomic(address swapper, ERC20 feeToken) external view returns (address feeRecipient);
    function getFeeRecipientLimit(address swapper, ERC20 feeToken) external view returns (address feeRecipient);

    function version() external view returns (string memory);
}
