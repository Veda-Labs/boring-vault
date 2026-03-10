// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {BoringSwapper} from "src/base/Periphery/BoringSwapper.sol";
import {IAdapter} from "src/interfaces/IAdapter.sol";


contract OneInchAdapter is IAdapter {
    
    address public constant V5_ROUTER = 0x1111111254EEB25477B68fb85Ed929f73A960582;

    ////do we need the context of the vault? idk maybe.  
    //function swap(bytes calldata swapData) external view returns (address, uint256, bytes) {
    //    ISwapper swapper = ISwapper(msg.sender); 

    //    //the swap data should be our raw bytes, function call, etc.  
    //    (
    //        address executor, 
    //        DecoderCustomTypes.SwapDescription calldata desc,
    //        bytes calldata permit,
    //        bytes calldata
    //    ) = abi.decode(swapData(address, DecoderCustomTypes.SwapDescription, bytes, bytes));

    //    //check executor here

    //    //check description here (who is calling this, the swapper, we need to ensure that receiver is the swapper then)
    //    //get a reference to the swapper?

    //    if (desc.srcToken != swapper.approvedTokens(desc.srcToken)) revert("not allowed"); 
    //    if (desc.dstToken != swapper.approvedTokens(desc.dstToken)) revert("not allowed"); 
    //    //if (desc.srcReceiver != msg.sender) revert("no calling"); //who?
    //    if (desc.dstReceiver != msg.sender) revert("no calling"); //called via swapper, so should be msg.sender
    //    
    //    //parse for params/structs
    //    //we can decode this based on function/supported function? do truly want to limit functions that can be called?
    //    //maybe we can be opaque with the function name but parse the data explicitly?
    //    
    //    //if nothing reverted, we allow the swap basically
    //    return(ROUTER, desc.amount, swapData);  
    //}
    
    function version() external view returns (uint256) {
        return 1;
    }

    function swap(BoringSwapper.SwapConfig calldata swapConfig, address) external view returns (address, address, uint256, uint256) {
        return (address(0), address(0), 0, 0);
    }
}
