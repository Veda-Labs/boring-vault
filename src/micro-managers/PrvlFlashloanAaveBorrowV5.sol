// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {UManager, FixedPointMathLib, ManagerWithMerkleVerification, ERC20} from "src/micro-managers/UManager.sol";
import {IUniswapV3Router} from "src/interfaces/IUniswapV3Router.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";

struct TokenConfig {
    address baseToken; // eg WETH
    address depositToken; // eg wstETH
    address aToken; // eg awstETH
    address debtToken; // eg variableDebtEthWETH
}

contract PrvlFlashloanAaveBorrowV5 is UManager {
    using FixedPointMathLib for uint256;

    IUniswapV3Router public immutable uniswapV3Router;
    BalancerVault public immutable balancerVault;
    address public immutable AAVE;
    address public immutable baseToken; // eg depositToken
    address public immutable depositToken; // eg wstdepositToken
    address public immutable aToken; // eg awstETH
    address public immutable debtToken; // eg variableDebtEthWETH;
    uint256 public immutable aaveVariableRate;

    bytes4 constant EXACT_INPUT_SELECTOR = 0xb858183f; 
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
        address _aave,
        TokenConfig memory _tokens,
        uint256 _aaveVariableRate
    ) UManager(_owner, _manager, _boringVault) {
        uniswapV3Router = IUniswapV3Router(_uniswapV3Router);
        balancerVault = BalancerVault(_balancerVault);
        AAVE = _aave;
        baseToken = _tokens.baseToken;
        depositToken = _tokens.depositToken;
        aToken = _tokens.aToken;
        debtToken = _tokens.debtToken;
        aaveVariableRate = _aaveVariableRate;
    }

    error PrvlFlashloanAaveBorrowV5__Slippage();

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

    function borrow(uint256 collateralAmount, uint256 borrowAmount, DecoderCustomTypes.ExactInputParamsRouter02 calldata exactInputParams) external requiresAuth {
        bytes memory innerUserData = getBorrowUserData(collateralAmount, borrowAmount , exactInputParams);
        _executeFlashloan(innerUserData, borrowAmount);
    }

    function repay(uint256 borrowAmount, uint256 supplyAmount, DecoderCustomTypes.ExactInputParamsRouter02 calldata exactInputParams) external requiresAuth {
        bytes memory innerUserData = getRepayUserData(borrowAmount, supplyAmount, exactInputParams);
        _executeFlashloan(innerUserData, borrowAmount);
    }

    function settle(DecoderCustomTypes.ExactInputParamsRouter02 calldata exactInputParams) external requiresAuth {
        uint256 debtAmount = ERC20(debtToken).balanceOf(boringVault);
        bytes memory innerUserData = getRepayUserData(type(uint256).max, type(uint256).max, exactInputParams);
        _executeFlashloan(innerUserData, debtAmount);
    }

    function _executeFlashloan(bytes memory innerUserData, uint256 flashloanAmount) internal {
        bytes32[][] memory outerProofs = outerManageProofs;

        address[] memory outerTargets = new address[](1);
        outerTargets[0] = address(manager);

        uint256[] memory outerValues = new uint256[](1);

        bytes[] memory outerTargetData = new bytes[](1);
        address[] memory flashloanTokens = new address[](1);
        flashloanTokens[0] = baseToken;
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

    function getBorrowUserData(uint256 collateralAmount, uint256 borrowAmount, DecoderCustomTypes.ExactInputParamsRouter02 calldata exactInputParams)
        internal
        view
        returns (bytes memory userData)
    {
        bytes memory swapData = abi.encodeWithSelector(
            EXACT_INPUT_SELECTOR,
            exactInputParams
        );

        bytes memory supplyData = abi.encodeWithSelector(SUPPLY_SELECTOR, depositToken, type(uint256).max, boringVault, 0);
        bytes memory borrowData =
            abi.encodeWithSelector(BORROW_SELECTOR, baseToken, borrowAmount, aaveVariableRate, 0, boringVault);

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

    function getRepayUserData(uint256 borrowAmount, uint256 supplyAmount, DecoderCustomTypes.ExactInputParamsRouter02 calldata exactInputParams) internal returns (bytes memory userData) {
        bytes memory repayData =
            abi.encodeWithSelector(REPAY_SELECTOR, baseToken, borrowAmount, aaveVariableRate, boringVault);
        bytes memory withdrawData = abi.encodeWithSelector(WITHDRAW_SELECTOR, depositToken, supplyAmount, boringVault);
        
        // For swap, use actual adepositToken balance if supplyAmount is max
        uint256 swapAmount = supplyAmount;
        if (supplyAmount == type(uint256).max) {
            swapAmount = ERC20(aToken).balanceOf(boringVault);
        }
        
        bytes memory swapData = abi.encodeWithSelector(
            EXACT_INPUT_SELECTOR,
            exactInputParams
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
