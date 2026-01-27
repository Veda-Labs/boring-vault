// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {PrvlFlashloanAaveBorrowV5} from "../../../src/micro-managers/PrvlFlashloanAaveBorrowV5.sol";
import {BoringVault} from "../../../src/base/BoringVault.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

// source .env && forge script script/utils/Mainnet/debugV5.s.sol:DebugBorrow --rpc-url $MAINNET_RPC_URL -vvvv --broadcast


contract DebugBorrow is Script {

    address constant agent1VaultUSDC = 0x7e68c279EA86FA49A49Eef2Cbb79B9cBfBc48025;
    address constant agentVault2USDC = 0x6638968ACBA85A6445D3909F4d0520F7D2501061;
    uint256 constant minOut = 0;
    
    
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant aEthsUSDe = 0xc2015641564a5914A17CB9A92eC8d8feCfa8f2D0;

    

    
    function run() external {
        uint256 pk = vm.envUint("MAINNET_DEPLOYER_KEY");

    //settle 
    uint256 _balance = ERC20(aEthsUSDe).balanceOf(agentVault2USDC);
    console.log("aEthsUSDe in vault:", _balance);

    DecoderCustomTypes.ExactInputParamsRouter02 memory settleParams = DecoderCustomTypes.ExactInputParamsRouter02({
        path: hex"9d39a5de30e57443bff2a8307a4256c8797a3497000064dac17f958d2ee523a2206206994597c13d831ec70000646b175474e89094c44da98b954eedeac495271d0f000064a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48",
        recipient: agentVault2USDC,
        amountIn: _balance,
        amountOutMinimum: 95721208
    });

    DecoderCustomTypes.ExactInputParamsRouter02 memory borrowParams = DecoderCustomTypes.ExactInputParamsRouter02({
        path: hex"c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000647f39c581f595b53c5cb19bd0b3f8da6c935e2ca0",
        recipient: agentVault2USDC,
        amountIn: 100_000_000,
        amountOutMinimum: 82112353376020554268
    });

 
        vm.startBroadcast(pk);

        PrvlFlashloanAaveBorrowV5 target = PrvlFlashloanAaveBorrowV5(0xB8461be4483850D49503840110ec43d56702e13F);
        target.settle(settleParams);
        //target.borrow(10_000_000, 90_000_000, borrowParams);
        //target.repay(3_000_000, 2.7e18, settleParams);
        //target.settle();
        vm.stopBroadcast();
    }
}