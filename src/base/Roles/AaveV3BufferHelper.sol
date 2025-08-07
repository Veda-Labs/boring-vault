// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {IBufferHelper} from "src/interfaces/IBufferHelper.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

contract AaveV3BufferHelper is IBufferHelper {
    address public immutable aaveV3Pool;
    address public immutable vault;

    constructor(
        address _aaveV3Pool,
        address _vault
    ) {
        aaveV3Pool = _aaveV3Pool;
        vault = _vault;
    }

    function getDepositManageCall(address asset, uint256 amount)
        public
        view
        returns (address[] memory targets, bytes[] memory data, uint256[] memory values)
    {
        uint256 currentAllowance = ERC20(asset).allowance(vault, aaveV3Pool);
        if (currentAllowance >= amount) {
            targets = new address[](1);
            targets[0] = aaveV3Pool;
            data = new bytes[](1);
            data[0] = abi.encodeWithSignature("supply(address,uint256,address,uint16)", asset, amount, vault, 0);
            values = new uint256[](1);
            values[0] = 0;
        } else if (currentAllowance == 0) {
            targets = new address[](2);
            targets[0] = asset;
            targets[1] = aaveV3Pool;
            data = new bytes[](2);
            data[0] = abi.encodeWithSignature("approve(address,uint256)", aaveV3Pool, amount);
            data[1] = abi.encodeWithSignature("supply(address,uint256,address,uint16)", asset, amount, vault, 0);
            values = new uint256[](2);
        } else {
            targets = new address[](3);
            targets[0] = asset;
            targets[1] = asset;
            targets[2] = aaveV3Pool;
            data = new bytes[](3);
            data[0] = abi.encodeWithSignature("approve(address,uint256)", aaveV3Pool, 0);
            data[1] = abi.encodeWithSignature("approve(address,uint256)", aaveV3Pool, amount);
            data[2] = abi.encodeWithSignature("supply(address,uint256,address,uint16)", asset, amount, vault, 0);
            values = new uint256[](3);
        }
    }

    function getWithdrawManageCall(address asset, uint256 amount)
        public
        view
        returns (address[] memory targets, bytes[] memory data, uint256[] memory values)
    {
        targets = new address[](1);
        targets[0] = aaveV3Pool;
        data = new bytes[](1);
        data[0] = abi.encodeWithSignature("withdraw(address,uint256,address)", asset, amount, vault);
        values = new uint256[](1);
        return (targets, data, values);
    }
}
