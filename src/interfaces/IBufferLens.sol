// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";

interface IBufferLens {
    /**
     * @notice Gets the instantly withdrawable amount for a given asset.
     * @param teller The teller contract.
     * @param asset The asset to get the instantly withdrawable amount for.
     * @return withdrawableAmount The instantly withdrawable amount.
     */
    function getInstantlyWithdrawableAmount(TellerWithMultiAssetSupport teller, ERC20 asset)
        external
        view
        returns (uint256 withdrawableAmount);
}
