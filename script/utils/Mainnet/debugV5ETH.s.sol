// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import {PrvlFlashloanAaveBorrowV5} from "../../../src/micro-managers/PrvlFlashloanAaveBorrowV5.sol";
import {BoringVault} from "../../../src/base/BoringVault.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";

// source .env && forge script script/utils/Mainnet/debugV5ETH.s.sol:DebugBorrow --rpc-url $MAINNET_RPC_URL -vvvv --broadcast


contract DebugBorrow is Script {

    address constant agent = 0x8503B18b279Fd0f1EC35303D8db834619A12250f;
    uint256 constant minOut = 0;
    
    //address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
     address constant aEthwstETH = 0x0B925eD163218f6662a35e0f0371Ac234f9E9371;

    

    
    function run() external {
        uint256 pk = vm.envUint("MAINNET_DEPLOYER_KEY");

    //settle 
    uint256 _balance = ERC20(aEthwstETH).balanceOf(agent);
    //console.log("aEthwstETH in vault:", _balance);

    DecoderCustomTypes.ExactInputParamsRouter02 memory settleParams = DecoderCustomTypes.ExactInputParamsRouter02({
        path: hex"7f39c581f595b53c5cb19bd0b3f8da6c935e2ca0000064c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2",
        recipient: agent,
        amountIn: _balance,    
        amountOutMinimum: 0
    });

    DecoderCustomTypes.ExactInputParamsRouter02 memory borrowParams = DecoderCustomTypes.ExactInputParamsRouter02({
        path: hex"c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000647f39c581f595b53c5cb19bd0b3f8da6c935e2ca0",
        recipient: agent,
        amountIn: 3e15,
        amountOutMinimum: 2435511028394096
    });

 
        vm.startBroadcast(pk);

        PrvlFlashloanAaveBorrowV5 target = PrvlFlashloanAaveBorrowV5(0x73AD623b9b857F635BB3D34b970C126b4aEe0c6b);
       
        //target.borrow(1e15, 2e15, borrowParams);
        //target.repay(1e14, 1e13, settleParams);
        target.settle(settleParams);
        //target.settle();
        vm.stopBroadcast();
    }
}