// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

/**
 * @title FelixDecoderAndSanitizer
 * @notice Decoder and sanitizer for Morpho Blue operations
 * @dev Used by Felix (Morpho Blue fork) for wstHYPE/wHYPE lending markets
 */
contract FelixDecoderAndSanitizer {
    //============================== ERRORS ===============================

    error FelixDecoderAndSanitizer__CallbackNotSupported();
    error FelixDecoderAndSanitizer__InvalidAddress();

    //============================== MORPHO BLUE ===============================

    function supply(
        DecoderCustomTypes.MarketParams calldata params,
        uint256,
        uint256,
        address onBehalf,
        bytes calldata data
    ) external pure returns (bytes memory addressesFound) {
        // Sanitize raw data - reject callbacks
        if (data.length > 0) revert FelixDecoderAndSanitizer__CallbackNotSupported();
        
        // Validate onBehalf address
        if (onBehalf == address(0)) revert FelixDecoderAndSanitizer__InvalidAddress();
        
        // Return addresses found
        addressesFound = abi.encodePacked(
            params.loanToken, 
            params.collateralToken, 
            params.oracle, 
            params.irm, 
            onBehalf
        );
    }

    function withdraw(
        DecoderCustomTypes.MarketParams calldata params,
        uint256,
        uint256,
        address onBehalf,
        address receiver
    ) external pure returns (bytes memory addressesFound) {
        // Validate addresses
        if (onBehalf == address(0) || receiver == address(0)) 
            revert FelixDecoderAndSanitizer__InvalidAddress();
        
        // Return addresses found
        addressesFound = abi.encodePacked(
            params.loanToken, 
            params.collateralToken, 
            params.oracle, 
            params.irm, 
            onBehalf, 
            receiver
        );
    }

    function borrow(
        DecoderCustomTypes.MarketParams calldata params,
        uint256,
        uint256,
        address onBehalf,
        address receiver
    ) external pure returns (bytes memory addressesFound) {
        // Validate addresses
        if (onBehalf == address(0) || receiver == address(0)) 
            revert FelixDecoderAndSanitizer__InvalidAddress();
        
        addressesFound = abi.encodePacked(
            params.loanToken, 
            params.collateralToken, 
            params.oracle, 
            params.irm, 
            onBehalf, 
            receiver
        );
    }

    function repay(
        DecoderCustomTypes.MarketParams calldata params,
        uint256,
        uint256,
        address onBehalf,
        bytes calldata data
    ) external pure returns (bytes memory addressesFound) {
        // Sanitize raw data - reject callbacks
        if (data.length > 0) revert FelixDecoderAndSanitizer__CallbackNotSupported();
        
        // Validate onBehalf address
        if (onBehalf == address(0)) revert FelixDecoderAndSanitizer__InvalidAddress();
        
        addressesFound = abi.encodePacked(
            params.loanToken, 
            params.collateralToken, 
            params.oracle, 
            params.irm, 
            onBehalf
        );
    }

    function supplyCollateral(
        DecoderCustomTypes.MarketParams calldata params,
        uint256,
        address onBehalf,
        bytes calldata data
    ) external pure returns (bytes memory addressesFound) {
        // Sanitize raw data - reject callbacks
        if (data.length > 0) revert FelixDecoderAndSanitizer__CallbackNotSupported();
        
        // Validate onBehalf address
        if (onBehalf == address(0)) revert FelixDecoderAndSanitizer__InvalidAddress();
        
        addressesFound = abi.encodePacked(
            params.loanToken, 
            params.collateralToken, 
            params.oracle, 
            params.irm, 
            onBehalf
        );
    }

    function withdrawCollateral(
        DecoderCustomTypes.MarketParams calldata params,
        uint256,
        address onBehalf,
        address receiver
    ) external pure returns (bytes memory addressesFound) {
        // Validate addresses
        if (onBehalf == address(0) || receiver == address(0)) 
            revert FelixDecoderAndSanitizer__InvalidAddress();
        
        addressesFound = abi.encodePacked(
            params.loanToken, 
            params.collateralToken, 
            params.oracle, 
            params.irm, 
            onBehalf, 
            receiver
        );
    }
}