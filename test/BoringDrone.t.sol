// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {BoringDrone} from "src/base/Drones/BoringDrone.sol";
import {DroneLib} from "src/base/Drones/DroneLib.sol";
import {MerkleTreeHelper, ERC20} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract BoringDroneTest is Test, MerkleTreeHelper {
    using Address for address;

    BoringDrone public boringDrone;

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 20083900;

        _startFork(rpcKey, blockNumber);
        setSourceChainName("mainnet");

        boringDrone = new BoringDrone(address(this), 0);
    }

    function testDrone() external {
        // Make the puppet approve this address to spend USDC
        bytes memory callData = abi.encodeWithSelector(
            ERC20.approve.selector, address(this), 777, getAddress(sourceChain, "USDC"), DroneLib.TARGET_FLAG
        );

        address(boringDrone).functionCall(callData);

        assertEq(
            getERC20(sourceChain, "USDC").allowance(address(boringDrone), address(this)), 777, "USDC allowance not set"
        );
    }

    function testSendingETHToDroneWithMinAmountOfGas() external {
        deal(address(this), 1 ether);

        (bool success,) = payable(address(boringDrone)).call{value: 1 ether, gas: 21_000}("");
        assertTrue(success, "Failed to send ETH to drone with min amount of gas.");
        // assertEq(address(this).balance, 1 ether, "Test contract should have received 1 ETH.");
    }

    // ========================================= HELPER FUNCTIONS =========================================

    receive() external payable {}

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
