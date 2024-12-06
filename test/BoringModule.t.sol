// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {BoringModule, BoringDrone} from "src/base/Gnosis/BoringModule.sol";
import {DroneLib} from "src/base/Drones/DroneLib.sol";
import {MerkleTreeHelper, ERC20} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {ISafe} from "src/interfaces/ISafe.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract BoringModuleTest is Test, MerkleTreeHelper {
    using Address for address;

    BoringModule public boringModule = BoringModule(payable(0xF5Ad9688D79b02508e8f0b1a698415746AEee81D));
    address public moduleOwner;
    address public gnosisSafe = 0x5061F6517591804391b38937c99057014B1EDb78;

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "ARBITRUM_RPC_URL";
        uint256 blockNumber = 282002133;

        _startFork(rpcKey, blockNumber);
        setSourceChainName("arbitrum");

        moduleOwner = getAddress(sourceChain, "dev0Address");

        // Module is already enabled on the safe.
    }

    function testModule() external {
        // Give gnosis safe WETH, and native ETH.
        deal(getAddress(sourceChain, "WETH"), gnosisSafe, 1_000e18);
        deal(gnosisSafe, 1 ether);

        // Make the module transfer WETH to moduleOwner
        bytes memory callData = abi.encodeWithSelector(
            ERC20.transfer.selector, moduleOwner, 1e18, getAddress(sourceChain, "WETH"), DroneLib.TARGET_FLAG
        );

        uint256 ownerWethDelta = getERC20(sourceChain, "WETH").balanceOf(moduleOwner);
        vm.prank(moduleOwner);
        address(boringModule).functionCall(callData);
        ownerWethDelta = getERC20(sourceChain, "WETH").balanceOf(moduleOwner) - ownerWethDelta;

        assertEq(ownerWethDelta, 1 ether, "Module did not transfer correct amount of WETH to moduleOwner");

        // Now have the gnosis safe transfer ETH to the module owner.

        uint256 ownerEthDelta = moduleOwner.balance;
        vm.prank(moduleOwner);
        boringModule.withdrawNativeFromSafe();
        ownerEthDelta = moduleOwner.balance - ownerEthDelta;

        assertEq(ownerEthDelta, 1 ether, "Module did not transfer correct amount of ETH to moduleOwner");
    }

    function testOnlyBoringVaultRevert() external {
        bytes memory callData = abi.encodeWithSelector(
            ERC20.transfer.selector, moduleOwner, 1e18, getAddress(sourceChain, "WETH"), DroneLib.TARGET_FLAG
        );

        vm.expectRevert(abi.encodeWithSelector(BoringDrone.BoringDrone__OnlyBoringVault.selector));
        address(boringModule).functionCall(callData);

        vm.expectRevert(abi.encodeWithSelector(BoringDrone.BoringDrone__OnlyBoringVault.selector));
        boringModule.withdrawNativeFromSafe();
    }

    // ========================================= HELPER FUNCTIONS =========================================

    receive() external payable {}

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
