
// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {UManager, FixedPointMathLib, ManagerWithMerkleVerification, ERC20} from "src/micro-managers/UManager.sol";
import {IUniswapV3Router} from "src/interfaces/IUniswapV3Router.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";

interface IQuoter {
    function quoteExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
    ) external returns (uint256 amountOut);

    function quoteExactOutputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountOut,
        uint160 sqrtPriceLimitX96
    ) external returns (uint256 amountIn);
}

interface IAavePool {
    function getUserAccountData(address user)
        external
        view
        returns (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        );

    function getReserveData(address asset)
        external
        view
        returns (
            uint256 configuration,
            uint128 liquidityIndex,
            uint128 currentLiquidityRate,
            uint128 variableBorrowIndex,
            uint128 currentVariableBorrowRate,
            uint128 currentStableBorrowRate,
            uint40 lastUpdateTimestamp,
            uint16 id,
            address aTokenAddress,
            address stableDebtTokenAddress,
            address variableDebtTokenAddress,
            address interestRateStrategyAddress,
            uint128 accruedToTreasury,
            uint128 unbacked,
            uint128 isolationModeTotalDebt
        );
}

contract PrvlFlashloanAaveBorrowV2 is UManager {
    using FixedPointMathLib for uint256;

    IUniswapV3Router public uniswapV3Router;
    IQuoter public quoter;
    BalancerVault public balancerVault;

    address public AAVE = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2; // Aave V3 Pool

    bytes4 constant EXACT_INPUT_SINGLE_SELECTOR = 0x04e45aaf;
    bytes4 constant SUPPLY_SELECTOR = 0x617ba037;
    bytes4 constant BORROW_SELECTOR = 0xa415bcad;
    bytes4 constant REPAY_SELECTOR = 0x573ade81;
    bytes4 constant WITHDRAW_SELECTOR = 0x69328dec;

    struct PositionUpdate {
        bytes32[][] innerManageProofs;
        address[] innerDecodersAndSanitizers;
        bytes32[][] outerManageProofs;
        address[] outerDecodersAndSanitizers;
        uint256 collateralAmount;
        address collateralToken;
        uint256 borrowAmount;
        address borrowToken;
        uint24 uniFeeTier;
        uint256 aaveVariableRate;
        address aToken; // Aave aToken for collateralToken
    }

    constructor(
        address _owner,
        address _manager,
        address _boringVault,
        address _balancerVault,
        address _uniswapV3Router,
        address _quoter
    ) UManager(_owner, _manager, _boringVault) {
        uniswapV3Router = IUniswapV3Router(_uniswapV3Router);
        quoter = IQuoter(_quoter);
        balancerVault = BalancerVault(_balancerVault);
    }

    error InsufficientVaultBalance();

    function borrow(PositionUpdate memory positionUpdate) external requiresAuth {
        uint256 vaultBalance = ERC20(positionUpdate.borrowToken).balanceOf(boringVault);
        if (vaultBalance < positionUpdate.borrowAmount) {
            revert InsufficientVaultBalance();
        }
        bytes memory innerUserData = getBorrowUserData(positionUpdate);
        _executeFlashloan(positionUpdate, innerUserData, positionUpdate.borrowAmount);
    }

    function repay(PositionUpdate memory positionUpdate) external requiresAuth {
        bytes memory innerUserData = getRepayUserData(positionUpdate, positionUpdate.borrowAmount, positionUpdate.collateralAmount);
        _executeFlashloan(positionUpdate, innerUserData, positionUpdate.borrowAmount);
    }

    function settle(PositionUpdate memory positionUpdate) external requiresAuth {
        address variableDebtToken = _getVariableDebtToken(positionUpdate.borrowToken);
        uint256 debtAmount = ERC20(variableDebtToken).balanceOf(boringVault);
        bytes memory innerUserData = getRepayUserData(positionUpdate, type(uint256).max, type(uint256).max);
        _executeFlashloan(positionUpdate, innerUserData, debtAmount);
    }

    function _executeFlashloan(
        PositionUpdate memory positionUpdate,
        bytes memory innerUserData,
        uint256 flashloanAmount
    ) internal {
        address[] memory outerTargets = new address[](1);
        outerTargets[0] = address(manager);
        bytes[] memory outerTargetData = new bytes[](1);
        address[] memory flashloanTokens = new address[](1);
        flashloanTokens[0] = positionUpdate.borrowToken;
        uint256[] memory flashloanAmounts = new uint256[](1);
        flashloanAmounts[0] = flashloanAmount;
        outerTargetData[0] = _encodeFlashloanData(address(manager), flashloanTokens, flashloanAmounts, innerUserData);
        manager.manageVaultWithMerkleVerification(
            positionUpdate.outerManageProofs,
            positionUpdate.outerDecodersAndSanitizers,
            outerTargets,
            outerTargetData,
            new uint256[](1)
        );
    }

    function _encodeFlashloanData(
        address manager,
        address[] memory flashloanTokens,
        uint256[] memory flashloanAmounts,
        bytes memory innerUserData
    ) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            ManagerWithMerkleVerification.flashLoan.selector,
            manager,
            flashloanTokens,
            flashloanAmounts,
            innerUserData
        );
    }

    function getBorrowUserData(
        PositionUpdate memory positionUpdate
    ) internal returns (bytes memory userData) {
        uint256 swapAmount = positionUpdate.collateralAmount + positionUpdate.borrowAmount;
        uint256 supplyAmount = _getQuote(
            positionUpdate.borrowToken,
            positionUpdate.collateralToken,
            positionUpdate.uniFeeTier,
            swapAmount
        );
        
        (bytes[] memory innerTargetData, address[] memory innerTargets) = _prepareBorrowTargetData(
            positionUpdate,
            swapAmount,
            supplyAmount
        );
        
        userData = _encodeUserData(
            positionUpdate.innerManageProofs,
            positionUpdate.innerDecodersAndSanitizers,
            innerTargets,
            innerTargetData
        );
    }

    function _getQuote(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn
    ) internal returns (uint256 amountOut) {
        return quoter.quoteExactInputSingle(tokenIn, tokenOut, fee, amountIn, 0);
    }

    function _prepareBorrowTargetData(
        PositionUpdate memory positionUpdate,
        uint256 swapAmount,
        uint256 supplyAmount
    ) internal returns (bytes[] memory innerTargetData, address[] memory innerTargets) {
        innerTargetData = new bytes[](3);
        innerTargets = new address[](3);

        innerTargetData[0] = _encodeSwapDataBorrow(
            positionUpdate.borrowToken,
            positionUpdate.collateralToken,
            positionUpdate.uniFeeTier,
            swapAmount
        );
        innerTargetData[1] = _encodeSupplyData(positionUpdate.collateralToken, supplyAmount);
        innerTargetData[2] = _encodeBorrowData(
            positionUpdate.borrowToken,
            positionUpdate.borrowAmount,
            positionUpdate.aaveVariableRate
        );

        innerTargets[0] = address(uniswapV3Router);
        innerTargets[1] = AAVE;
        innerTargets[2] = AAVE;
    }

    function _encodeSwapDataBorrow(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn
    ) internal view returns (bytes memory) {
        return abi.encodeWithSelector(
            EXACT_INPUT_SINGLE_SELECTOR,
            tokenIn,
            tokenOut,
            fee,
            boringVault,
            amountIn,
            0,
            0
        );
    }

    function _encodeSupplyData(
        address token,
        uint256 amount
    ) internal view returns (bytes memory) {
        return abi.encodeWithSelector(
            SUPPLY_SELECTOR,
            token,
            amount,
            boringVault,
            0
        );
    }

    function _encodeBorrowData(
        address token,
        uint256 amount,
        uint256 rateMode
    ) internal view returns (bytes memory) {
        return abi.encodeWithSelector(
            BORROW_SELECTOR,
            token,
            amount,
            rateMode,
            0,
            boringVault
        );
    }

    function getRepayUserData(
        PositionUpdate memory positionUpdate,
        uint256 borrowAmount,
        uint256 supplyAmount
    ) internal returns (bytes memory userData) {
        uint256 swapAmount = supplyAmount;
        if (supplyAmount == type(uint256).max) {
            swapAmount = ERC20(positionUpdate.aToken).balanceOf(boringVault);
        }

        (bytes[] memory innerTargetData, address[] memory innerTargets) = _prepareRepayTargetData(
            positionUpdate,
            borrowAmount,
            supplyAmount,
            swapAmount
        );

        userData = _encodeUserData(
            positionUpdate.innerManageProofs,
            positionUpdate.innerDecodersAndSanitizers,
            innerTargets,
            innerTargetData
        );
    }

    function _prepareRepayTargetData(
        PositionUpdate memory positionUpdate,
        uint256 borrowAmount,
        uint256 supplyAmount,
        uint256 swapAmount
    ) internal returns (bytes[] memory innerTargetData, address[] memory innerTargets) {
        innerTargetData = new bytes[](3);
        innerTargets = new address[](3);

        innerTargetData[0] = _encodeRepayData(
            positionUpdate.borrowToken,
            borrowAmount,
            positionUpdate.aaveVariableRate
        );
        innerTargetData[1] = _encodeWithdrawData(positionUpdate.collateralToken, supplyAmount);
        innerTargetData[2] = _encodeSwapDataRepay(
            positionUpdate.collateralToken,
            positionUpdate.borrowToken,
            positionUpdate.uniFeeTier,
            swapAmount
        );

        innerTargets[0] = AAVE;
        innerTargets[1] = AAVE;
        innerTargets[2] = address(uniswapV3Router);
    }

    function _encodeRepayData(
        address token,
        uint256 amount,
        uint256 rateMode
    ) internal view returns (bytes memory) {
        return abi.encodeWithSelector(
            REPAY_SELECTOR,
            token,
            amount,
            rateMode,
            boringVault
        );
    }

    function _encodeWithdrawData(
        address token,
        uint256 amount
    ) internal view returns (bytes memory) {
        return abi.encodeWithSelector(
            WITHDRAW_SELECTOR,
            token,
            amount,
            boringVault
        );
    }

    function _encodeSwapDataRepay(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn
    ) internal view returns (bytes memory) {
        return abi.encodeWithSelector(
            EXACT_INPUT_SINGLE_SELECTOR,
            tokenIn,
            tokenOut,
            fee,
            boringVault,
            amountIn,
            0,
            0
        );
    }

    function _encodeUserData(
        bytes32[][] memory innerManageProofs,
        address[] memory innerDecodersAndSanitizers,
        address[] memory innerTargets,
        bytes[] memory innerTargetData
    ) internal pure returns (bytes memory userData) {
        uint256[] memory innerValues = new uint256[](3);
        userData = abi.encode(
            innerManageProofs,
            innerDecodersAndSanitizers,
            innerTargets,
            innerTargetData,
            innerValues
        );
    }

    function _getVariableDebtToken(address asset) internal view returns (address vDebt) {
        // Extract variableDebtTokenAddress (11th field, 10th after config) at offset 10 * 32 = 320 bytes
        assembly {
            let success := staticcall(gas(), sload(AAVE.slot), add(asset, 0x20), 0x20, 0, 0)
            if iszero(success) { revert(0, 0) }
            returndatacopy(0, 320, 32) // variableDebtTokenAddress at 320 bytes
            vDebt := mload(0)
        }
    }
}
