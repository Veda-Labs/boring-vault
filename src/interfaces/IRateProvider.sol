// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.

// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
// Last audited: boring-vault@939c77e25473dff3ed18fa104f004f7afd13452e — file:audit/spearbit-boring-vault-arctic-0.pdf

pragma solidity ^0.8.0;

interface IRateProvider {
    /**
     * @notice Returns the current price of one unit of this provider's asset, expressed in the base asset.
     * @dev The return value uses this provider's asset decimals, not the base asset's decimals.
     *      A USDC (6-decimal) rate provider returns `price * 1e6`; a DAI (18-decimal) provider returns
     *      `price * 1e18`. `AccountantWithRateProviders.claimFees`, `AccountantWithFixedRate.claimYield`,
     *      and `AccountantWithRateProviders.getRateInQuote` rely on this convention.
     */
    function getRate() external view returns (uint256);
}
