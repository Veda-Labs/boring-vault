// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {TellerWithBuffer} from "src/base/Roles/TellerWithBuffer.sol";
import {AaveV3BufferHelper, IBufferHelper} from "src/base/Roles/AaveV3BufferHelper.sol";
import {IPool} from "src/interfaces/IPool.sol";

contract AaveV3BufferLens {
    function getInstantlyWithdrawableAmount(TellerWithBuffer teller, ERC20 asset) public view returns (uint256 withdrawableAmount) {
        (, IBufferHelper withdrawBufferHelper) = teller.currentBufferHelpers(asset);
        address vault = address(teller.vault());
        if (address(withdrawBufferHelper) == address(0)) {
            // If buffer helper is address(0), withdraw buffer is idle ERC20 in the vault
            withdrawableAmount = asset.balanceOf(vault);
        } else {
            // If buffer helper is not address(0), withdraw buffer is Aave V3
            address aaveV3Pool = AaveV3BufferHelper(address(withdrawBufferHelper)).aaveV3Pool();
            ERC20 aToken = ERC20(IPool(aaveV3Pool).getReserveData(address(asset)).aTokenAddress);
            uint256 aTokenBalance = aToken.balanceOf(vault);
            uint256 availableLiquidity = asset.balanceOf(address(aToken));
            withdrawableAmount = aTokenBalance > availableLiquidity ? availableLiquidity : aTokenBalance;
        }
    }
}