// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";
import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {PrvlFlashloanAaveBorrowV5, TokenConfig} from "src/micro-managers/PrvlFlashloanAaveBorrowV5.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {RolesAuthority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {DeployPrvlFlashloanAaveBorrow} from "script/utils/Mainnet/DeployMicroUSDCsUSDCePRIME.s.sol";

// forge test --match-path test/micro-managers/PrvlFlashloanAaveBorrowV5MainnetUSDCPrime.t.sol --fork-url $MAINNET_RPC_URL -vvvv
contract PrvlFlashloanAaveBorrowV5MainnetUSDCPrimeTest is Test, MainnetAddresses, MerkleTreeHelper {

    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    PrvlFlashloanAaveBorrowV5 public flashloanManager;
    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    RolesAuthority public rolesAuthority;
    DeployPrvlFlashloanAaveBorrow public deployScript;

    address constant OWNER = 0xA45A9b2bC0230Fa78aF0C92031a2E4016aFA9B40;
    address constant MANAGER = 0x8f15C3f376f53b3406c1640135204944baA9c00D;
    address constant BORING_VAULT = 0x6638968ACBA85A6445D3909F4d0520F7D2501061;
    address constant BASE_TOKEN = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
    address constant DEPOSIT_TOKEN = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497; // sUSDe
    address constant A_TOKEN = 0xc2015641564a5914A17CB9A92eC8d8feCfa8f2D0;
    address constant DEBT_TOKEN = 0xeD90dE2D824Ee766c6Fd22E90b12e598f681dc9F;
    address constant AGENT_MANAGER = 0x02B5f0fafA419C5227A1de9777585ACA048a309d;
    uint8 public constant STRATEGIST_ROLE = 7;
    address public admin = 0xA45A9b2bC0230Fa78aF0C92031a2E4016aFA9B40;

    function setUp() external {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));

        deployScript = new DeployPrvlFlashloanAaveBorrow();
        deployScript.setUp();
        manager = deployScript.run();
        flashloanManager =  PrvlFlashloanAaveBorrowV5(0x02B5f0fafA419C5227A1de9777585ACA048a309d); //deployScript.flashloanManager();

        boringVault = BoringVault(payable(BORING_VAULT));
        rolesAuthority = RolesAuthority(0xf84B1eF921D7aA21609C5f09E65C8067a048793C);

        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", address(boringVault));
        setAddress(false, mainnet, "manager", MANAGER);
        setAddress(false, mainnet, "flashloanManager", address(flashloanManager));
    }

    function testDeploymentSuccessful() external view {
        assertNotEq(address(flashloanManager), address(0));
        assertEq(flashloanManager.baseToken(), BASE_TOKEN);
        assertEq(flashloanManager.depositToken(), DEPOSIT_TOKEN);
        assertEq(flashloanManager.aToken(), A_TOKEN);
        assertEq(flashloanManager.debtToken(), DEBT_TOKEN);
    }

    function testRolePermissionsSet() external view {
        assertTrue(rolesAuthority.doesUserHaveRole(address(flashloanManager), STRATEGIST_ROLE));
        assertTrue(rolesAuthority.doesUserHaveRole(AGENT_MANAGER, STRATEGIST_ROLE));
    }

    function testAgentManagerCanCallAllFunctions() external {
        uint256 collateralAmount = 1000e6; // 1000 USDC
        uint256 borrowAmount = 500e6; // 500 USDC

        vm.startPrank(admin);
        deal(BASE_TOKEN, BORING_VAULT, collateralAmount);
        vm.stopPrank();

        // Multi-hop path: USDC -> DAI -> USDT -> sUSDe
        bytes memory borrowPath = hex"a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000646b175474e89094c44da98b954eedeac495271d0f000064dac17f958d2ee523a2206206994597c13d831ec70000649d39a5de30e57443bff2a8307a4256c8797a3497";

        DecoderCustomTypes.ExactInputParamsRouter02 memory borrowParams = DecoderCustomTypes.ExactInputParamsRouter02({
            path: borrowPath,
            recipient: BORING_VAULT,
            amountIn: collateralAmount + borrowAmount,
            amountOutMinimum: 0
        });

        vm.startPrank(AGENT_MANAGER);

        // Test borrow
        flashloanManager.borrow(collateralAmount, borrowAmount, borrowParams);

        uint256 postBorrowDebtBalance = ERC20(DEBT_TOKEN).balanceOf(BORING_VAULT);
        assertGt(postBorrowDebtBalance, 0, "Should have debt after borrow");

        // Test repay
        uint256 withdrawAmount = ERC20(A_TOKEN).balanceOf(BORING_VAULT) / 4;
        uint256 repayAmount = borrowAmount / 4;

        // Reverse path: sUSDe -> USDT -> DAI -> USDC
        bytes memory repayPath = hex"9d39a5de30e57443bff2a8307a4256c8797a3497000064dac17f958d2ee523a2206206994597c13d831ec70000646b175474e89094c44da98b954eedeac495271d0f000064a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";

        DecoderCustomTypes.ExactInputParamsRouter02 memory repayParams = DecoderCustomTypes.ExactInputParamsRouter02({
            path: repayPath,
            recipient: BORING_VAULT,
            amountIn: withdrawAmount,
            amountOutMinimum: 0
        });

        flashloanManager.repay(repayAmount, withdrawAmount, repayParams);

        uint256 postRepayDebtBalance = ERC20(DEBT_TOKEN).balanceOf(BORING_VAULT);
        assertLt(postRepayDebtBalance, postBorrowDebtBalance, "Debt should decrease after repay");

        // Test settle
        DecoderCustomTypes.ExactInputParamsRouter02 memory settleParams = DecoderCustomTypes.ExactInputParamsRouter02({
            path: repayPath,
            recipient: BORING_VAULT,
            amountIn: ERC20(A_TOKEN).balanceOf(BORING_VAULT),
            amountOutMinimum: 0
        });

        flashloanManager.settle(settleParams);

        assertEq(ERC20(DEBT_TOKEN).balanceOf(BORING_VAULT), 0, "Debt should be zero after settle");
        assertEq(ERC20(A_TOKEN).balanceOf(BORING_VAULT), 0, "aToken should be zero after settle");

        vm.stopPrank();
    }

    function testBorrowAndSettle(uint256 borrowAmount, uint256 collateralAmount) external {
        collateralAmount = bound(collateralAmount, 100e6, 10000e6); // 100-10,000 USDC
        borrowAmount = bound(borrowAmount, 10e6, collateralAmount * 2);

        vm.startPrank(admin);
        deal(BASE_TOKEN, BORING_VAULT, collateralAmount);
        uint256 preBaseBalance = ERC20(BASE_TOKEN).balanceOf(BORING_VAULT);
        uint256 preDebtBalance = ERC20(DEBT_TOKEN).balanceOf(BORING_VAULT);

        bytes memory borrowPath = hex"a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000646b175474e89094c44da98b954eedeac495271d0f000064dac17f958d2ee523a2206206994597c13d831ec70000649d39a5de30e57443bff2a8307a4256c8797a3497";

        DecoderCustomTypes.ExactInputParamsRouter02 memory borrowParams = DecoderCustomTypes.ExactInputParamsRouter02({
            path: borrowPath,
            recipient: BORING_VAULT,
            amountIn: collateralAmount + borrowAmount,
            amountOutMinimum: 0
        });

        flashloanManager.borrow(collateralAmount, borrowAmount, borrowParams);

        uint256 postBaseBalance = ERC20(BASE_TOKEN).balanceOf(BORING_VAULT);
        uint256 postDebtBalance = ERC20(DEBT_TOKEN).balanceOf(BORING_VAULT);

        assertEq(postBaseBalance + collateralAmount, preBaseBalance);
        assertApproxEqRel(postDebtBalance - preDebtBalance, borrowAmount, 0.01e18);

        vm.warp(block.timestamp + 20 days);

        bytes memory settlePath = hex"9d39a5de30e57443bff2a8307a4256c8797a3497000064dac17f958d2ee523a2206206994597c13d831ec70000646b175474e89094c44da98b954eedeac495271d0f000064a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48";

        DecoderCustomTypes.ExactInputParamsRouter02 memory settleParams = DecoderCustomTypes.ExactInputParamsRouter02({
            path: settlePath,
            recipient: BORING_VAULT,
            amountIn: ERC20(A_TOKEN).balanceOf(BORING_VAULT),
            amountOutMinimum: 0
        });

        flashloanManager.settle(settleParams);

        assertEq(ERC20(DEBT_TOKEN).balanceOf(BORING_VAULT), 0);
        assertEq(ERC20(A_TOKEN).balanceOf(BORING_VAULT), 0);
        assertApproxEqRel(ERC20(BASE_TOKEN).balanceOf(BORING_VAULT), preBaseBalance, 0.05e18);

        vm.stopPrank();
    }
}
