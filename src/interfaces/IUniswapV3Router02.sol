// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

interface IUniswapV3Router02  {
       struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    struct ExactInputParamsRouter02 {
        bytes path;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
    function exactInput(ExactInputParamsRouter02 calldata params) external payable returns (uint256 amountOut);
    function exactInputRouter02(ExactInputParamsRouter02 calldata params) external payable returns (uint256 amountOut);

}
