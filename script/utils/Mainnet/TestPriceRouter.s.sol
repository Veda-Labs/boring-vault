// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";

interface IPriceRouter {
    function getValue(address baseAsset, uint256 amount, address quoteAsset) external view returns (uint256 value);
    function isSupported(address asset) external view returns (bool);
    function getPriceInUSD(address asset) external view returns (uint256);
}

/*
 * source .env && forge script script/utils/Mainnet/TestPriceRouter.s.sol:TestPriceRouter --rpc-url mainnet -vvvv
 */

contract TestPriceRouter is Script {
    address constant PRICE_ROUTER = 0x693799805B502264f9365440B93C113D86a4fFF5;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant SUSDE = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497;

    function run() external view {
        console2.log("=== Testing PriceRouter ===");
        console2.log("PriceRouter:", PRICE_ROUTER);
        console2.log("USDC:", USDC);
        console2.log("sUSDE:", SUSDE);
        console2.log("");

        IPriceRouter priceRouter = IPriceRouter(PRICE_ROUTER);

        // Check if assets are supported
        console2.log("--- Asset Support Check ---");
        bool usdcSupported = priceRouter.isSupported(USDC);
        bool susdeSupported = priceRouter.isSupported(SUSDE);

        console2.log("USDC supported:", usdcSupported);
        console2.log("sUSDE supported:", susdeSupported);
        console2.log("");

        if (!usdcSupported) {
            console2.log("ERROR: USDC is not supported in PriceRouter");
            console2.log("This is why getValue() reverts");
            return;
        }

        if (!susdeSupported) {
            console2.log("ERROR: sUSDE is not supported in PriceRouter");
            console2.log("This is why getValue() reverts");
            return;
        }

        // Try to get prices
        console2.log("--- Price Check ---");
        try priceRouter.getPriceInUSD(USDC) returns (uint256 usdcPrice) {
            console2.log("USDC price (USD, 8 decimals):", usdcPrice);
        } catch {
            console2.log("USDC price query failed");
        }

        try priceRouter.getPriceInUSD(SUSDE) returns (uint256 susdePrice) {
            console2.log("sUSDE price (USD, 8 decimals):", susdePrice);
        } catch {
            console2.log("sUSDE price query failed");
        }

        console2.log("");

        // Try getValue
        console2.log("--- getValue Test ---");
        console2.log("Trying: getValue(USDC, 100000, sUSDE)");
        try priceRouter.getValue(USDC, 100000, SUSDE) returns (uint256 value) {
            console2.log("SUCCESS! Value:", value);
        } catch Error(string memory reason) {
            console2.log("FAILED with reason:", reason);
        } catch (bytes memory lowLevelData) {
            console2.log("FAILED with low level error");
            console2.logBytes(lowLevelData);
        }
    }
}
