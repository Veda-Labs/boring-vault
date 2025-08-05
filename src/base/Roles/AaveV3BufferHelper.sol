// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {IBufferHelper} from "src/interfaces/IBufferHelper.sol";

contract AaveV3BufferHelper is IBufferHelper {
    address[] public depositTargets;
    uint256[] public depositValues;
    address[] public withdrawTargets;
    uint256[] public withdrawValues;

    address public immutable vault;

    constructor(
        address[] memory _depositTargets,
        uint256[] memory _depositValues,
        address[] memory _withdrawTargets,
        uint256[] memory _withdrawValues,
        address _vault
    ) {
        require(
            _depositTargets.length == 2 && _depositValues.length == 2 && _withdrawTargets.length == 1
                && _withdrawValues.length == 1,
            "Invalid lengths"
        );
        depositTargets = _depositTargets;
        depositValues = _depositValues;
        withdrawTargets = _withdrawTargets;
        withdrawValues = _withdrawValues;
        vault = _vault;
    }

    function getDepositManageCall(address asset, uint256 amount)
        public
        view
        returns (address[] memory targets, bytes[] memory data, uint256[] memory values)
    {
        data = new bytes[](2);
        data[0] = abi.encodeWithSignature("approve(address,uint256)", depositTargets[1], amount);
        data[1] = abi.encodeWithSignature("supply(address,uint256,address,uint16)", asset, amount, vault, 0);
        return (depositTargets, data, depositValues);
    }

    function getWithdrawManageCall(address asset, uint256 amount)
        public
        view
        returns (address[] memory targets, bytes[] memory data, uint256[] memory values)
    {
        data = new bytes[](1);
        data[0] = abi.encodeWithSignature("withdraw(address,uint256,address)", asset, amount, vault);
        return (withdrawTargets, data, withdrawValues);
    }
}
