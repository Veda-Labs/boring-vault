// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BaseDecoderAndSanitizer, DecoderCustomTypes} from "src/base/DecodersAndSanitizers/BaseDecoderAndSanitizer.sol";

contract PrvlAgentVaultDecoderAndSanitizer is BaseDecoderAndSanitizer {
    /* 
     * Note: Approve is implemented in BaseDecoderAndSanitizer.sol
     * 
     * UNISWAP V3
     * // https://etherscan.io/address/0xe592427a0aece92de3edee1f18e0157c05861564#code
     * // https://arbiscan.io/address/0xe592427a0aece92de3edee1f18e0157c05861564
     * - exactInputSingle() - UniswapService.cs:406
     * 
     AAVE
     * // https://arbiscan.io/address/0xa97684ead0e402dC232d5A977953DF7ECBaB3CDb#code pool provider
     * // https://arbiscan.io/address/0xa9022f64f4e86f1c9f4c07b248caa06b0af915d9#code current implementation
     * // https://sepolia.etherscan.io/address/0x6Ae43d3271ff6888e7Fc43Fd7321a503ff738951#code provider
     * // https://sepolia.etherscan.io/address/0x0562453c3dafbb5e625483af58f4e6d668c44e19#code pool
     * - supply() - AaveService.cs:597
     * - borrow() - AaveService.cs:1419  
     * - withdraw() - AaveService.cs:1489
     * - repay() - AaveService.cs:1554
     */
    
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    error PrvlAgentVaultDecoderAndSanitizer__BadPathFormat();


    // ============================== UNISWAP ===============================
    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(
            params.tokenIn,
            params.tokenOut,
            params.recipient
        );
    }

    // SwapRouter02 version (without deadline parameter)
    function exactInput(DecoderCustomTypes.ExactInputParamsRouter02 calldata params)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        // Nothing to sanitize
        // Return addresses found
        // Determine how many addresses are in params.path.
        uint256 chunkSize = 23; // 3 bytes for uint24 fee, and 20 bytes for address token
        uint256 pathLength = params.path.length;
        if (pathLength % chunkSize != 20) revert PrvlAgentVaultDecoderAndSanitizer__BadPathFormat();
        uint256 pathAddressLength = 1 + (pathLength / chunkSize);
        uint256 pathIndex;
        for (uint256 i; i < pathAddressLength; ++i) {
            addressesFound = abi.encodePacked(addressesFound, params.path[pathIndex:pathIndex + 20]);
            pathIndex += chunkSize;
        }
        addressesFound = abi.encodePacked(addressesFound, params.recipient);
    }

    // =============================== AAVE ================================
    function supply(
        address asset,
        uint256,
        /*amount*/ address onBehalfOf,
        uint16 /*referralCode */
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(asset, onBehalfOf);
    }

    function borrow(
        address asset,
        uint256 /*amount*/,
        uint256 /*interestRateMode*/,
        uint16 /*referralCode*/,
        address onBehalfOf
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(asset, onBehalfOf);
    }

    function withdraw(
        address asset,
        uint256,
        /*amount*/ address to
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(asset, to);
    }

    function repay(
        address asset,
        uint256,
        /*amount*/ uint256,
        /*interestRateMode*/ address onBehalfOf
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked(asset, onBehalfOf);
    }

    function setUserEMode(
        uint8 /*categoryId*/
    ) external pure virtual returns (bytes memory addressesFound) {
        addressesFound = abi.encodePacked();
    }

    // =============================== BALANCER ================================

    function flashLoan(address recipient, address[] calldata tokens, uint256[] calldata, bytes calldata)
        external
        pure
        virtual
        returns (bytes memory addressesFound)
    {
        addressesFound = abi.encodePacked(recipient);
        for (uint256 i; i < tokens.length; ++i) {
            addressesFound = abi.encodePacked(addressesFound, tokens[i]);
        }
    }
}
