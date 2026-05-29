// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {TellerWithBuffer} from "src/base/Roles/TellerWithBuffer.sol";
import {ERC4626BufferHelper, IBufferHelper} from "src/base/Roles/ERC4626BufferHelper.sol";
import {IBufferLens} from "src/interfaces/IBufferLens.sol";

contract ERC4626BufferLens is IBufferLens {
    function getInstantlyWithdrawableAmount(TellerWithBuffer teller, ERC20 asset)
        external
        view
        returns (uint256 withdrawableAmount)
    {
        (, IBufferHelper withdrawBufferHelper) = teller.currentBufferHelpers(asset);
        address vault = address(teller.vault());
        if (address(withdrawBufferHelper) == address(0)) {
            // If buffer helper is address(0), withdraw buffer is idle ERC20 in the vault
            withdrawableAmount = asset.balanceOf(vault);
        } else {
            // If buffer helper is not address(0), withdraw buffer is ERC4626
            ERC4626 erc4626Vault = ERC4626BufferHelper(address(withdrawBufferHelper)).ERC_4626_VAULT();
            require(erc4626Vault.asset() == asset, "ERC4626BufferLens: Vault asset mismatch");
            // This should work if the vault properly implements it
            withdrawableAmount = erc4626Vault.maxWithdraw(vault);
        }
    }
}
