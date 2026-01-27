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
    function getUserAccountData(address user) external view returns (
        uint256 totalCollateralBase,
        uint256 totalDebtBase,
        uint256 availableBorrowsBase,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    );
}

contract PrvlFlashloanAaveBorrow is UManager {
    using FixedPointMathLib for uint256;

    IUniswapV3Router public uniswapV3Router;
    IQuoter public quoter;
    BalancerVault public balancerVault;
    address public AAVE;
    address public WETH;
    address public USDC;
    address public constant AWETH = 0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8;
    uint24 public uniFeeTier;
    uint256 public aaveVariableRate;

    bytes4 constant EXACT_INPUT_SINGLE_SELECTOR = 0x04e45aaf;
    bytes4 constant SUPPLY_SELECTOR = 0x617ba037;
    bytes4 constant BORROW_SELECTOR = 0xa415bcad;
    bytes4 constant FLASHLOAN_SELECTOR = 0x5c38449e;
    bytes4 constant REPAY_SELECTOR = 0x573ade81;
    bytes4 constant WITHDRAW_SELECTOR = 0x69328dec;

    bytes32[][] private borrowInnerManageProofs;
    address[] private borrowInnerDecodersAndSanitizers;
    bytes32[][] private repayInnerManageProofs;
    address[] private repayInnerDecodersAndSanitizers;
    address[] private outerDecodersAndSanitizers;
    bytes32[][] private outerManageProofs;

    constructor(
        address _owner,
        address _manager,
        address _boringVault,
        address _balancerVault,
        address _uniswapV3Router,
        address _quoter,
        address _aave,
        address _WETH,
        address _USDC,
        uint24 _uniFeeTier,
        uint256 _aaveVariableRate
    ) UManager(_owner, _manager, _boringVault) {
        uniswapV3Router = IUniswapV3Router(_uniswapV3Router);
        quoter = IQuoter(_quoter);
        balancerVault = BalancerVault(_balancerVault);
        AAVE = _aave;
        WETH = _WETH;
        USDC = _USDC;
        uniFeeTier = _uniFeeTier;
        aaveVariableRate = _aaveVariableRate;
    }

    error InsufficientVaultBalance();

    function setBorrowInnerManageProofs(bytes32[][] calldata _borrowInnerManageProofs) external requiresAuth {
        // Manual deep copy to avoid calldata-to-storage issue
        delete borrowInnerManageProofs; // Clear existing
        borrowInnerManageProofs = new bytes32[][](_borrowInnerManageProofs.length);
        for (uint256 i = 0; i < _borrowInnerManageProofs.length; i++) {
            borrowInnerManageProofs[i] = new bytes32[](_borrowInnerManageProofs[i].length);
            for (uint256 j = 0; j < _borrowInnerManageProofs[i].length; j++) {
                borrowInnerManageProofs[i][j] = _borrowInnerManageProofs[i][j];
            }
        }
    }

    function setBorrowInnerDecodersAndSanitizers(address[] calldata _borrowInnerDecodersAndSanitizers)
        external
        requiresAuth
    {
        // Simple array: manual copy
        delete borrowInnerDecodersAndSanitizers;
        borrowInnerDecodersAndSanitizers = new address[](_borrowInnerDecodersAndSanitizers.length);
        for (uint256 i = 0; i < _borrowInnerDecodersAndSanitizers.length; i++) {
            borrowInnerDecodersAndSanitizers[i] = _borrowInnerDecodersAndSanitizers[i];
        }
    }

    function setRepayInnerManageProofs(bytes32[][] calldata _repayInnerManageProofs) external requiresAuth {
        // Manual deep copy to avoid calldata-to-storage issue
        delete repayInnerManageProofs; // Clear existing
        repayInnerManageProofs = new bytes32[][](_repayInnerManageProofs.length);
        for (uint256 i = 0; i < _repayInnerManageProofs.length; i++) {
            repayInnerManageProofs[i] = new bytes32[](_repayInnerManageProofs[i].length);
            for (uint256 j = 0; j < _repayInnerManageProofs[i].length; j++) {
                repayInnerManageProofs[i][j] = _repayInnerManageProofs[i][j];
            }
        }
    }

    function setRepayInnerDecodersAndSanitizers(address[] calldata _repayInnerDecodersAndSanitizers)
        external
        requiresAuth
    {
        // Simple array: manual copy
        delete repayInnerDecodersAndSanitizers;
        repayInnerDecodersAndSanitizers = new address[](_repayInnerDecodersAndSanitizers.length);
        for (uint256 i = 0; i < _repayInnerDecodersAndSanitizers.length; i++) {
            repayInnerDecodersAndSanitizers[i] = _repayInnerDecodersAndSanitizers[i];
        }
    }

    function setOuterDecodersAndSanitizers(address[] calldata _outerDecodersAndSanitizers) external requiresAuth {
        // Simple array: manual copy
        delete outerDecodersAndSanitizers;
        outerDecodersAndSanitizers = new address[](_outerDecodersAndSanitizers.length);
        for (uint256 i = 0; i < _outerDecodersAndSanitizers.length; i++) {
            outerDecodersAndSanitizers[i] = _outerDecodersAndSanitizers[i];
        }
    }

    function setOuterManageProofs(bytes32[][] calldata _outerManageProofs) external requiresAuth {
        // Manual deep copy to avoid calldata-to-storage issue
        delete outerManageProofs; // Clear existing
        outerManageProofs = new bytes32[][](_outerManageProofs.length);
        for (uint256 i = 0; i < _outerManageProofs.length; i++) {
            outerManageProofs[i] = new bytes32[](_outerManageProofs[i].length);
            for (uint256 j = 0; j < _outerManageProofs[i].length; j++) {
                outerManageProofs[i][j] = _outerManageProofs[i][j];
            }
        }
    }

    function borrow(uint256 collateralAmount, uint256 borrowAmount) external requiresAuth {
        uint256 vaultBalance = ERC20(USDC).balanceOf(boringVault);
        if (vaultBalance < collateralAmount) {
            revert InsufficientVaultBalance();
        }

        bytes memory innerUserData = getBorrowUserData(collateralAmount, borrowAmount);

        _executeFlashloan(innerUserData, borrowAmount);
    }

    function repay(uint256 borrowAmount, uint256 supplyAmount) external requiresAuth {
        bytes memory innerUserData = getRepayUserData(borrowAmount, supplyAmount);
        _executeFlashloan(innerUserData, borrowAmount);
    }

    function settle() external requiresAuth {
        // Get total debt in USD (base currency)
        (, uint256 totalDebtBase, , , , ) = IAavePool(AAVE).getUserAccountData(boringVault);
        
        // Convert debt to USDC amount (assuming 8 decimals for base currency, 6 for USDC)
        uint256 debtAmount = totalDebtBase / 100; // Convert from 8 decimals to 6 decimals
        
        bytes memory innerUserData = getRepayUserData(type(uint256).max, type(uint256).max);
        
        // Use actual debt amount for flashloan
        _executeFlashloan(innerUserData, debtAmount);
    }

    function _executeFlashloan(bytes memory innerUserData, uint256 flashloanAmount) internal {
        bytes32[][] memory outerProofs = outerManageProofs;

        address[] memory outerTargets = new address[](1);
        outerTargets[0] = address(manager);

        uint256[] memory outerValues = new uint256[](1);

        bytes[] memory outerTargetData = new bytes[](1);
        address[] memory flashloanTokens = new address[](1);
        flashloanTokens[0] = USDC;
        uint256[] memory flashloanAmounts = new uint256[](1);
        flashloanAmounts[0] = flashloanAmount;
        outerTargetData[0] = abi.encodeWithSelector(
            ManagerWithMerkleVerification.flashLoan.selector,
            address(manager),
            flashloanTokens,
            flashloanAmounts,
            innerUserData
        );

        manager.manageVaultWithMerkleVerification(
            outerProofs, outerDecodersAndSanitizers, outerTargets, outerTargetData, outerValues
        );
    }

    function getBorrowUserData(uint256 collateralAmount, uint256 borrowAmount)
        internal
        returns (bytes memory userData)
    {
        uint256 swapAmount = collateralAmount + borrowAmount;
        uint256 supplyAmount = quoter.quoteExactInputSingle(USDC, WETH, uniFeeTier, swapAmount, uint160(0));

        bytes memory swapData = abi.encodeWithSelector(
            EXACT_INPUT_SINGLE_SELECTOR, USDC, WETH, uniFeeTier, boringVault, swapAmount, 0, uint160(0)
        );
        bytes memory supplyData = abi.encodeWithSelector(SUPPLY_SELECTOR, WETH, supplyAmount, boringVault, 0);
        bytes memory borrowData =
            abi.encodeWithSelector(BORROW_SELECTOR, USDC, borrowAmount, aaveVariableRate, 0, boringVault);

        address[] memory innerTargets = new address[](3);
        innerTargets[0] = address(uniswapV3Router);
        innerTargets[1] = AAVE;
        innerTargets[2] = AAVE;

        bytes[] memory innerTargetData = new bytes[](3);
        innerTargetData[0] = swapData;
        innerTargetData[1] = supplyData;
        innerTargetData[2] = borrowData;

        uint256[] memory innerValues = new uint256[](3);

        userData = abi.encode(
            borrowInnerManageProofs, borrowInnerDecodersAndSanitizers, innerTargets, innerTargetData, innerValues
        );
    }

    function getRepayUserData(uint256 borrowAmount, uint256 supplyAmount) internal returns (bytes memory userData) {
        bytes memory repayData =
            abi.encodeWithSelector(REPAY_SELECTOR, USDC, borrowAmount, aaveVariableRate, boringVault);
        bytes memory withdrawData = abi.encodeWithSelector(WITHDRAW_SELECTOR, WETH, supplyAmount, boringVault);
        
        // For swap, use actual aWETH balance if supplyAmount is max
        uint256 swapAmount = supplyAmount;
        if (supplyAmount == type(uint256).max) {
            swapAmount = ERC20(AWETH).balanceOf(boringVault);
        }
        
        bytes memory swapData = abi.encodeWithSelector(
            EXACT_INPUT_SINGLE_SELECTOR, WETH, USDC, uniFeeTier, boringVault, swapAmount, 0, uint160(0)
        );

        address[] memory innerTargets = new address[](3);
        innerTargets[0] = AAVE;
        innerTargets[1] = AAVE;
        innerTargets[2] = address(uniswapV3Router);

        bytes[] memory innerTargetData = new bytes[](3);
        innerTargetData[0] = repayData;
        innerTargetData[1] = withdrawData;
        innerTargetData[2] = swapData;

        uint256[] memory innerValues = new uint256[](3);

        userData = abi.encode(
            repayInnerManageProofs, repayInnerDecodersAndSanitizers, innerTargets, innerTargetData, innerValues
        );
    }
}
