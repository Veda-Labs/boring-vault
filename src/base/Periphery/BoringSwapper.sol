// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";

contract BoringSwapper is Auth {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    //State Variables
    address internal immutable NATIVE; 

    //Errors
    error SwapFailed();
    error SlippageExceeded();
    error NativeTransferFailed(); 
    
    //Events
    event Swap(
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        address target
    );

    constructor(address _NATIVE, address _owner, Authority _auth) Auth(_owner, _auth) {
        NATIVE = _NATIVE; 
    }

    receive() external payable {}

    function swap(
        address tokenIn,
        address tokenOut, 
        uint256 amountIn,
        uint256 minAmountOut,
        address receiver,
        address target,
        bytes calldata swapData
    ) public payable { //add auth, reentrency protection, and other guards 
        
        //optionally check the target here, or do it directly in the decoder for more flexibility
        //this contract could act as a global list of approved swap targets, or it could be given at the vault level
        
        //_checkTarget(target); 
        
         uint256 outBefore = _balanceOf(tokenOut);

        if (tokenIn == NATIVE) {
            require(msg.value == amountIn, "bad msg.value");
        } else {
            ERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
            ERC20(tokenIn).approve(target, amountIn);
        }
        
        //can potentially preapprove function selectors as well, but may be too limiting        
        (bool success,) = target.call{value: tokenIn == NATIVE ? amountIn : 0}(swapData);
        if (!success) revert SwapFailed();

        uint256 amountOut = _balanceOf(tokenOut) - outBefore; 
        if (amountOut < minAmountOut) revert SlippageExceeded(); 
        
        //clear approvals and send tokens
        if (tokenIn != NATIVE) ERC20(tokenIn).approve(target, 0);

        if (tokenOut != NATIVE) {
            ERC20(tokenOut).safeTransfer(receiver, amountOut); 
        } else {
            (bool sent,) = receiver.call{value: amountOut}("");
            if(!sent) revert NativeTransferFailed(); 
        }
        
        emit Swap(tokenIn, tokenOut, amountIn, amountOut, target); 
    }
    
    //HELPERS

    function _balanceOf(address token) internal view returns (uint256) {
        if (token == NATIVE) return address(this).balance;
        return ERC20(token).balanceOf(address(this));
    }
}

