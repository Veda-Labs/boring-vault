// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {IUniswapV3Router02} from "src/interfaces/IUniswapV3Router02.sol";
import {IAaveV3Pool} from "src/interfaces/IAaveV3Pool.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {ReentrancyGuard} from "@solmate/utils/ReentrancyGuard.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

/**
 * @title PrvlAaveBorrow
 * @author ParavelDAO
 * @notice Adaptor for leveraged Aave V3 positions with Uniswap V3 swaps.
 * @dev Requires vault to approve this contract for baseToken and aToken transfers.
 */

// ========================================= STRUCTS =========================================

/**
 * @param baseToken The base token for the position (e.g., WETH).
 * @param depositToken The token deposited as collateral (e.g., wstETH).
 * @param aToken The Aave aToken received for deposits (e.g., awstETH).
 * @param debtToken The Aave variable debt token (e.g., variableDebtWETH).
 * @param aaveVariableRate The Aave interest rate mode (2 for variable).
 * @param path0 Uniswap V3 path for baseToken -> depositToken swap.
 * @param path1 Uniswap V3 path for depositToken -> baseToken swap.
 */
struct TokenConfig {
    address baseToken;
    address depositToken;
    address aToken;
    address debtToken;
    uint256 aaveVariableRate;
    bytes path0;
    bytes path1;
}

contract PrvlAaveBorrow is Auth, ReentrancyGuard {

    // ========================================= STATE =========================================

    IUniswapV3Router02 public immutable uniswapV3Router;
    IAaveV3Pool public immutable aave;
    address public immutable vault;

    mapping(uint256 id => TokenConfig) public tokenConfigs;

    // ========================================= EVENTS =========================================
    event TokenConfigSet(uint256 indexed id, TokenConfig config);
    event TokenConfigRemoved(uint256 indexed id);

    event Supplied(
        uint256 indexed configId,
        uint256 swapIn,
        uint256 swapMinOut,
        uint256 borrowAmount
    );

    event PositionReduced(
        uint256 indexed configId,
        uint256 swapMinOut,
        uint256 repayAmount,
        uint256 withdrawAmount
    );

    event Settled(
        uint256 indexed configId,
        uint256 swapMinOut
    );

    // ========================================= ERRORS =========================================

    error PrvlAaveBorrow__minOutCannotBeZero();
    error PrvlAaveBorrow__invalidZeroAddress();
    error PrvlAaveBorrow__configAlreadyExists();
    error PrvlAaveBorrow__invalidConfigId();

    // ========================================= CONSTRUCTOR =========================================

    constructor(
        address _owner,
        address _authority,
        address _uniswapV3Router,
        address _aave,
        address _vault
    ) Auth(_owner, Authority(_authority)) {
        if (_owner == address(0)) revert PrvlAaveBorrow__invalidZeroAddress();
        if (_uniswapV3Router == address(0)) revert PrvlAaveBorrow__invalidZeroAddress();
        if (_aave == address(0)) revert PrvlAaveBorrow__invalidZeroAddress();
        if (_vault == address(0)) revert PrvlAaveBorrow__invalidZeroAddress();
        uniswapV3Router = IUniswapV3Router02(_uniswapV3Router);
        aave = IAaveV3Pool(_aave);
        vault = _vault;
    }

    // ========================================= VAULT FUNCTIONS =========================================

    /**
     * @notice Opens or increases a leveraged position.
     * @dev Swaps baseToken to depositToken, supplies to Aave, borrows baseToken.
     * @dev Access: Vault only (via Auth).
     * @param configId Token configuration identifier.
     * @param swapIn Amount of baseToken to swap.
     * @param swapMinOut Minimum depositToken to receive from swap.
     * @param borrowAmount Amount of baseToken to borrow from Aave.
     */
    function supply(uint256 configId, uint256 swapIn, uint256 swapMinOut, uint256 borrowAmount) external nonReentrant requiresAuth {
        if (swapMinOut == 0) revert PrvlAaveBorrow__minOutCannotBeZero();
        TokenConfig memory config = tokenConfigs[configId];
        if (config.baseToken == address(0)) revert PrvlAaveBorrow__invalidConfigId();

        IUniswapV3Router02.ExactInputParamsRouter02 memory exactInputParams = IUniswapV3Router02.ExactInputParamsRouter02({
            path: config.path0,
            recipient: address(this),
            amountIn: swapIn,
            amountOutMinimum: swapMinOut
        });

        ERC20(config.baseToken).transferFrom(msg.sender, address(this), exactInputParams.amountIn);

        uint256 returnAmount = uniswapV3Router.exactInput(exactInputParams);
        aave.supply(config.depositToken, returnAmount, msg.sender, 0);
        aave.borrow(config.baseToken, borrowAmount, config.aaveVariableRate, 0, msg.sender);
        ERC20(config.baseToken).transfer(msg.sender, borrowAmount);
        emit Supplied(configId, swapIn, swapMinOut, borrowAmount);
    }

    /**
     * @notice Partially reduces a leveraged position.
     * @dev Repays debt, withdraws collateral, swaps back to baseToken.
     * @dev Access: Vault only (via Auth).
     * @param configId Token configuration identifier.
     * @param swapMinOut Minimum baseToken to receive from swap.
     * @param repayAmount Amount of debt to repay.
     * @param withdrawAmount Amount of aTokens to withdraw.
     */
    function reducePosition(uint256 configId, uint256 swapMinOut, uint256 repayAmount, uint256 withdrawAmount) external nonReentrant requiresAuth {
        if (swapMinOut == 0) revert PrvlAaveBorrow__minOutCannotBeZero();

        TokenConfig memory config = tokenConfigs[configId];
        if (config.baseToken == address(0)) revert PrvlAaveBorrow__invalidConfigId();

        ERC20(config.baseToken).transferFrom(msg.sender, address(this), repayAmount);
        aave.repay(config.baseToken, repayAmount, config.aaveVariableRate, msg.sender);

        ERC20(config.aToken).transferFrom(msg.sender, address(this), withdrawAmount);
        uint256 returnAmount = aave.withdraw(config.depositToken, withdrawAmount, address(this));

        IUniswapV3Router02.ExactInputParamsRouter02 memory exactInputParams = IUniswapV3Router02.ExactInputParamsRouter02({
            path: config.path1,
            recipient: msg.sender,
            amountIn: returnAmount,
            amountOutMinimum: swapMinOut
        });
        uniswapV3Router.exactInput(exactInputParams);
        emit PositionReduced(configId, swapMinOut, repayAmount, withdrawAmount);
    }

    /**
     * @notice Closes entire leveraged position.
     * @dev Repays all debt, withdraws all collateral, swaps back to baseToken.
     * @dev Access: Vault only (via Auth).
     * @param configId Token configuration identifier.
     * @param swapMinOut Minimum baseToken to receive from swap.
     */
    function settle(uint256 configId, uint256 swapMinOut) external nonReentrant requiresAuth {
        if (swapMinOut == 0) revert PrvlAaveBorrow__minOutCannotBeZero();

        TokenConfig memory config = tokenConfigs[configId];
        if (config.baseToken == address(0)) revert PrvlAaveBorrow__invalidConfigId();

        uint256 debtBalance = ERC20(config.debtToken).balanceOf(msg.sender);
        ERC20(config.baseToken).transferFrom(msg.sender, address(this), debtBalance);
        aave.repay(config.baseToken, debtBalance, config.aaveVariableRate, msg.sender);

        uint256 aTokenBalance = ERC20(config.aToken).balanceOf(msg.sender);
        ERC20(config.aToken).transferFrom(msg.sender, address(this), aTokenBalance);
        uint256 returnAmount = aave.withdraw(config.depositToken, type(uint256).max, address(this));

        IUniswapV3Router02.ExactInputParamsRouter02 memory exactInputParams = IUniswapV3Router02.ExactInputParamsRouter02({
            path: config.path1,
            recipient: msg.sender,
            amountIn: returnAmount,
            amountOutMinimum: swapMinOut
        });
        uniswapV3Router.exactInput(exactInputParams);
        emit Settled(configId, swapMinOut);
    }

    // ========================================= ADMIN FUNCTIONS =========================================

    /**
     * @notice Registers a new token configuration.
     * @dev Sets max approvals for Uniswap and Aave.
     * @dev Access: Owner only (multisig).
     * @param config Token configuration to register.
     * @return id Configuration identifier (hash of token addresses).
     */
    function setTokenConfig(TokenConfig calldata config) external requiresAuth returns (uint256 id) {
        id = uint256(keccak256(abi.encodePacked(config.baseToken, config.depositToken, config.aToken, config.debtToken)));
        if (tokenConfigs[id].baseToken != address(0)) revert PrvlAaveBorrow__configAlreadyExists();
        if (config.baseToken == address(0)) revert PrvlAaveBorrow__invalidZeroAddress();
        if (config.depositToken == address(0)) revert PrvlAaveBorrow__invalidZeroAddress();
        if (config.aToken == address(0)) revert PrvlAaveBorrow__invalidZeroAddress();
        if (config.debtToken == address(0)) revert PrvlAaveBorrow__invalidZeroAddress();
        tokenConfigs[id] = config;

        ERC20(config.baseToken).approve(address(uniswapV3Router), type(uint256).max);
        ERC20(config.baseToken).approve(address(aave), type(uint256).max);
        ERC20(config.depositToken).approve(address(uniswapV3Router), type(uint256).max);
        ERC20(config.depositToken).approve(address(aave), type(uint256).max);

        emit TokenConfigSet(id, config);
    }

    /**
     * @notice Removes a token configuration.
     * @dev Revokes all approvals for the configuration.
     * @dev Access: Owner only (multisig).
     * @param id Configuration identifier to remove.
     */
    function removeTokenConfig(uint256 id) external requiresAuth {
        TokenConfig memory config = tokenConfigs[id];
        if (config.baseToken == address(0)) revert PrvlAaveBorrow__invalidConfigId();

        ERC20(config.baseToken).approve(address(uniswapV3Router), 0);
        ERC20(config.baseToken).approve(address(aave), 0);
        ERC20(config.depositToken).approve(address(uniswapV3Router), 0);
        ERC20(config.depositToken).approve(address(aave), 0);
        delete tokenConfigs[id];

        emit TokenConfigRemoved(id);
    }

    /**
     * @notice Recovers tokens accidentally sent to this contract.
     * @dev Access: Owner only (multisig).
     * @param token Token address to sweep.
     * @param amount Amount to transfer to vault.
     */
    function sweepERC20(address token, uint256 amount) external requiresAuth {
        ERC20(token).transfer(vault, amount);
    }
}
