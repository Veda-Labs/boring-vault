// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {IBufferHelper} from "src/interfaces/IBufferHelper.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";

/**
 * @title HastraPrimeBufferHelper
 * @notice Deposits USDC or wYLDS into PRIME. Withdrawals are served from idle balance.
 */
contract HastraPrimeBufferHelper is IBufferHelper {
    error HastraPrimeBufferHelper__ZeroAddress();
    error HastraPrimeBufferHelper__UnsupportedAsset(address asset);

    ERC4626 public immutable WYLDS;
    ERC4626 public immutable PRIME;
    address public immutable USDC;
    address public immutable VAULT;

    constructor(address _wylds, address _prime, address _vault) {
        if (_wylds == address(0) || _prime == address(0) || _vault == address(0)) {
            revert HastraPrimeBufferHelper__ZeroAddress();
        }
        WYLDS = ERC4626(_wylds);
        PRIME = ERC4626(_prime);
        USDC = address(ERC4626(_wylds).asset());
        VAULT = _vault;
    }

    function getDepositManageCall(address asset, uint256 amount)
        public
        view
        returns (address[] memory targets, bytes[] memory data, uint256[] memory values)
    {
        address wylds = address(WYLDS);
        address prime = address(PRIME);

        if (asset == USDC) {
            uint256 wyldsAmount = WYLDS.previewDeposit(amount);
            targets = new address[](4);
            data = new bytes[](4);
            targets[0] = USDC;
            data[0] = abi.encodeWithSignature("approve(address,uint256)", wylds, amount);
            targets[1] = wylds;
            data[1] = abi.encodeWithSignature("deposit(uint256,address)", amount, VAULT);
            targets[2] = wylds;
            data[2] = abi.encodeWithSignature("approve(address,uint256)", prime, wyldsAmount);
            targets[3] = prime;
            data[3] = abi.encodeWithSignature("deposit(uint256,address)", wyldsAmount, VAULT);
        } else if (asset == wylds) {
            targets = new address[](2);
            data = new bytes[](2);
            targets[0] = wylds;
            data[0] = abi.encodeWithSignature("approve(address,uint256)", prime, amount);
            targets[1] = prime;
            data[1] = abi.encodeWithSignature("deposit(uint256,address)", amount, VAULT);
        } else {
            revert HastraPrimeBufferHelper__UnsupportedAsset(asset);
        }
        values = new uint256[](targets.length);
    }

    function getWithdrawManageCall(address, uint256)
        public
        pure
        returns (address[] memory targets, bytes[] memory data, uint256[] memory values)
    {
        return (targets, data, values);
    }
}
