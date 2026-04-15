// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IRateProvider} from "src/interfaces/IRateProvider.sol";

/**
 * @title MockRateProvider
 * @notice A mock rate provider for testing purposes
 * @dev IMPORTANT: Rate providers must return rates in the QUOTE TOKEN's decimals, not 18 decimals.
 *      This is because getRateInQuote calculates:
 *        rateInQuote = oneQuote * exchangeRateInQuoteDecimals / quoteRate
 *      where oneQuote = 10 ** quoteDecimals
 *      
 *      For the math to work correctly, quoteRate must be in quote decimals.
 *      Example: For a 6-decimal USDC at 1:1 with base, rate should be 1e6, not 1e18.
 */
contract MockRateProvider is IRateProvider {
    uint256 private _rate;
    uint8 public immutable quoteDecimals;
    
    // Bounds are relative to 1.0 in quote decimals
    // MIN_RATE_FACTOR = 0.001 (alt worth 0.1% of base)
    // MAX_RATE_FACTOR = 1000 (alt worth 1000x base)
    uint256 constant MIN_RATE_FACTOR = 1;      // 0.001 as a multiplier (rate / 1000)
    uint256 constant MAX_RATE_FACTOR = 1000000; // 1000 as a multiplier (rate * 1000)

    constructor(uint256 initialRate, uint8 _quoteDecimals) {
        _rate = initialRate;
        quoteDecimals = _quoteDecimals;
    }

    function getRate() external view override returns (uint256) {
        uint256 oneUnit = 10 ** quoteDecimals;
        uint256 minRate = oneUnit / 1000;  // 0.001 in quote decimals
        uint256 maxRate = oneUnit * 1000;  // 1000 in quote decimals
        
        // Apply bounds on read to handle direct fuzzer calls to setRate
        if (_rate < minRate) return minRate;
        if (_rate > maxRate) return maxRate;
        return _rate;
    }

    function setRate(uint256 newRate) external {
        _rate = newRate;  // Store raw value, bounds applied in getRate()
    }
    
    /// @notice Get the one unit value for this rate provider (10 ** quoteDecimals)
    function getOneUnit() external view returns (uint256) {
        return 10 ** quoteDecimals;
    }
}
