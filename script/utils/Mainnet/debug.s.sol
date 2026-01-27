// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";


// source .env && forge script script/utils/Mainnet/debug.s.sol:DebugBorrow --rpc-url $MAINNET_RPC_URL -vvvv --broadcast

interface IBorrower {
    function borrow(uint256, uint256) external;
    function repay(uint256, uint256) external;
    function settle() external;
}

contract DebugBorrow is Script {
    function run() external {
        uint256 pk = vm.envUint("MAINNET_DEPLOYER_KEY");
        
        // Mint USDC to BoringVault
        /*
        address usdc = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
        address boringVault = 0x6638968ACBA85A6445D3909F4d0520F7D2501061;
        bytes32 slot = keccak256(abi.encode(boringVault, uint256(9)));
        vm.store(usdc, slot, bytes32(uint256(10000000000))); // 10,000 USDC
       */
       
        vm.startBroadcast(pk);

        IBorrower target = IBorrower(0x7baC3d958369618960d949725479E778cBea8811);
        target.settle();
        //target.borrow(15_000_000, 135_000_000);
        //target.repay(5_000_000, 1_000_000);
        //target.settle();
        vm.stopBroadcast();
    }
}