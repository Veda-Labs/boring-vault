// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Script} from "@forge-std/Script.sol";
import {console2} from "@forge-std/console2.sol";
import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import {BoringSolver} from "src/base/Roles/BoringQueue/BoringSolver.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";

// source .env && forge script script/utils/Mainnet/DebugWithdrawalDeficit.s.sol:DebugWithdrawalDeficit --rpc-url $MAINNET_RPC_URL -vvvv

contract DebugWithdrawalDeficit is Script {
    // From failing withdrawal request - iPrvlClientVaultUSDC
    address constant QUEUE = 0x7D2b993CfC4048b85EC44B95Dc01a4C6B4E47b25;
    address constant BORING_SOLVER = 0x7fF7348e4908654fdF7a465356CB7E4Fa09C4963;
    address constant TELLER = 0x744C20d4F96667a38C4375B16aC88141257169F0;
    address constant ASSET_OUT = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC

    // Withdrawal request details
    uint96 constant NONCE = 11;
    address constant USER = 0xdDEbf1BCC0597415089475c78125E2A6ec481b1C;
    uint128 constant AMOUNT_OF_SHARES = 4584500;
    uint128 constant AMOUNT_OF_ASSETS = 4571246;
    uint40 constant CREATION_TIME = 1763067947;
    uint24 constant SECONDS_TO_MATURITY = 0;
    uint24 constant SECONDS_TO_DEADLINE = 259200;

    function run() external view {
        console2.log("=== Withdrawal Deficit Debugging ===\n");
        console2.log("Queue:", QUEUE);
        console2.log("Teller:", TELLER);
        console2.log("");

        TellerWithMultiAssetSupport teller = TellerWithMultiAssetSupport(TELLER);
        BoringVault vault = BoringVault(payable(address(teller.vault())));
        AccountantWithRateProviders accountant = AccountantWithRateProviders(address(teller.accountant()));
        ERC20 asset = ERC20(ASSET_OUT);

        console2.log("Teller:", address(teller));
        console2.log("Vault:", address(vault));
        console2.log("Accountant:", address(accountant));
        console2.log("Asset:", address(asset));
        console2.log("");

        // Get current share price
        uint256 rate = accountant.getRateInQuoteSafe(asset);
        console2.log("Current rate (share price):", rate);
        console2.log("");

        // Asset decimals for proper calculation
        uint8 assetDecimals = asset.decimals();
        uint8 vaultDecimals = vault.decimals();
        console2.log("Asset decimals:", uint256(assetDecimals));
        console2.log("Vault decimals:", uint256(vaultDecimals));
        console2.log("");

        // Calculate expected assets from shares
        // IMPORTANT: rate is returned in the quote asset's decimals, NOT 1e18!
        // Since both vault and USDC have 6 decimals, we divide by 10^6
        uint256 expectedAssetsFromShares = (uint256(AMOUNT_OF_SHARES) * rate) / (10 ** assetDecimals);
        console2.log("Shares to redeem:", uint256(AMOUNT_OF_SHARES));
        console2.log("Expected assets from shares:", expectedAssetsFromShares);
        console2.log("Required assets (from request):", uint256(AMOUNT_OF_ASSETS));
        console2.log("");

        // Calculate deficit
        if (expectedAssetsFromShares < AMOUNT_OF_ASSETS) {
            uint256 deficit = AMOUNT_OF_ASSETS - expectedAssetsFromShares;
            console2.log("DEFICIT DETECTED!");
            console2.log("Deficit amount:", deficit);
            console2.log("");
            console2.log("This means:");
            console2.log("  - Share price has dropped since request was made");
            console2.log("  - Redeeming shares will return less than requested");
            console2.log("  - Need to cover deficit with solver funds");
        } else if (expectedAssetsFromShares > AMOUNT_OF_ASSETS) {
            uint256 surplus = expectedAssetsFromShares - AMOUNT_OF_ASSETS;
            console2.log("SURPLUS DETECTED!");
            console2.log("Surplus amount:", surplus);
            console2.log("This is good - no deficit expected");
        } else {
            console2.log("EXACT MATCH - no deficit or surplus expected");
        }
        console2.log("");

        // Check vault balances
        console2.log("=== Vault Balances ===");
        uint256 vaultAssetBalance = asset.balanceOf(address(vault));
        console2.log("Vault balance of asset:", vaultAssetBalance);
        console2.log("Vault balance in human readable:", vaultAssetBalance / (10 ** assetDecimals), "USDC");
        console2.log("");

        // Check if vault has enough balance
        if (vaultAssetBalance < AMOUNT_OF_ASSETS) {
            console2.log("WARNING: Vault doesn't have enough asset balance!");
            console2.log("This will cause a deficit during redemption");
        }

        // Check total shares and total supply
        console2.log("=== Share Information ===");
        uint256 totalSupply = vault.totalSupply();
        console2.log("Vault total supply:", totalSupply);
        console2.log("Shares to redeem:", uint256(AMOUNT_OF_SHARES));
        console2.log("Percentage of total:", (uint256(AMOUNT_OF_SHARES) * 10000) / totalSupply, "basis points");
        console2.log("");

        console2.log("=== Recommendation ===");
        if (expectedAssetsFromShares < AMOUNT_OF_ASSETS) {
            uint256 deficit = AMOUNT_OF_ASSETS - expectedAssetsFromShares;
            console2.log("Set coverDeficit=true and ensure solver has", deficit, "of asset");
            console2.log("Deficit in human readable:", deficit / (10 ** assetDecimals), "USDC");
        } else {
            console2.log("No deficit expected - check other factors");
        }

        // Show what the share price was at request time
        console2.log("");
        console2.log("=== Share Price Analysis ===");
        if (AMOUNT_OF_SHARES > 0) {
            // Price when request was created (in asset decimals, same as current rate)
            uint256 priceAtRequest = (uint256(AMOUNT_OF_ASSETS) * (10 ** assetDecimals)) / uint256(AMOUNT_OF_SHARES);
            console2.log("Share price when request was created:", priceAtRequest);
            console2.log("Current share price:", rate);
            if (priceAtRequest > rate) {
                uint256 priceDrop = priceAtRequest - rate;
                console2.log("Price has DROPPED by:", priceDrop);
                console2.log("Percentage drop (bp):", (priceDrop * 10000) / priceAtRequest);
            } else {
                uint256 priceIncrease = rate - priceAtRequest;
                console2.log("Price has INCREASED by:", priceIncrease);
                console2.log("This should not cause a deficit!");
            }
        }
    }
}
