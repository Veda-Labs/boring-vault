// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {GenericRateProviderWithDecimalScaling} from "./GenericRateProviderWithDecimalScaling.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {AggregatorV3Interface} from "lib/ccip/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract OracleRateProvider is IRateProvider {
    //============================== STRUCTS ===============================
    struct ChainlinkResponse {
        uint80 roundId;
        int256 answer;
        uint256 timestamp;
        bool success;
        uint8 decimals;
    }

    //============================== ERRORS ===============================
    error OracleRateProvider__BadChainlinkResponse(); 
    error OracleRateProvider__PriceChangeOutOfBounds(); 
    error OracleRateProvider__PriceOutOfBounds(); 
    error OracleRateProvider__PriceIsStale(); 

    //============================== IMMUTABLES ===============================
    AggregatorV3Interface public immutable oracle; // Chainlink PriceAggregatorV3 oracle
    GenericRateProviderWithDecimalScaling public immutable rateProvider; // We use this type to include outputDecimals function
    uint256 public immutable exchangeRateLowerBound;
    uint256 public immutable exchangeRateUpperBound;
    uint32 public immutable heartbeat;
    uint8 public immutable outputDecimals;
    // Maximum deviation allowed between two consecutive Chainlink oracle prices in BPS.
    uint32 public immutable maxDeviationFromPreviousRound;

    constructor(
        address _oracle,
        address _rateProvider,
        uint256 _exchangeRateLowerBound,
        uint256 _exchangeRateUpperBound,
        uint32 _heartbeat,
        uint8 _outputDecimals,
        uint32 _maxDeviation
    ) {
        oracle = AggregatorV3Interface(_oracle);
        rateProvider = GenericRateProviderWithDecimalScaling(_rateProvider);
        exchangeRateLowerBound = _exchangeRateLowerBound;
        exchangeRateUpperBound = _exchangeRateUpperBound;
        heartbeat = _heartbeat;
        outputDecimals = _outputDecimals;
        maxDeviationFromPreviousRound = _maxDeviation;
    }

    // ========================================= RATE FUNCTION =========================================

    /**
     * @notice Get the rate of some asset using Chainlink, and revert if any of the strict requirements are not met.
     */
    function getRate() public override view returns (uint256) {
        ChainlinkResponse memory currentResponse = _getCurrentChainlinkResponse();
        ChainlinkResponse memory prevResponse = _getPrevChainlinkResponse(currentResponse.roundId, currentResponse.decimals);

        if (_chainlinkIsBroken(currentResponse, prevResponse)) revert OracleRateProvider__BadChainlinkResponse();
        if (_chainlinkIsFrozen(currentResponse)) revert OracleRateProvider__PriceIsStale();
        if (_chainlinkPriceChangeAboveMax(currentResponse, prevResponse)) revert OracleRateProvider__PriceChangeOutOfBounds();

        // _chainlinkIsBroken check ensures `currentResponse.answer` is positive
        uint256 rate = uint256(currentResponse.answer);
        rate = _scaleChainlinkPriceByDecimals(rate, currentResponse.decimals);
        if (address(rateProvider) != address(0)) {
            rate = rate * rateProvider.getRate() / 10 ** rateProvider.outputDecimals();
        }
        if (rate < exchangeRateLowerBound || rate > exchangeRateUpperBound) revert OracleRateProvider__PriceOutOfBounds();

        return rate;
    }

    // --- Helper functions ---

    /**
      * @notice Returns true if either current or previous Chainlink response contains invalid data.
      */
    function _chainlinkIsBroken(ChainlinkResponse memory _currentResponse, ChainlinkResponse memory _prevResponse) internal view returns (bool) {
        /* Chainlink is considered broken if its current or previous round data is in any way bad. We check the previous round
        * for two reasons:
        *
        * 1) It is necessary data for the price deviation check,
        * and
        * 2) Chainlink is the preferred primary oracle - having two consecutive valid round responses adds
        * peace of mind when using or returning to Chainlink.
        */
        return _badChainlinkResponse(_currentResponse) || _badChainlinkResponse(_prevResponse);
    }

    /**
      * @notice Checks single response for bad data
      */
    function _badChainlinkResponse(ChainlinkResponse memory _response) internal view returns (bool) {
         // Check for response call reverted
        if (!_response.success) {return true;}
        // Check for an invalid roundId that is 0
        if (_response.roundId == 0) {return true;}
        // Check for an invalid timeStamp that is 0, or in the future
        if (_response.timestamp == 0 || _response.timestamp > block.timestamp) {return true;}
        // Check for non-positive price
        if (_response.answer <= 0) {return true;}

        return false;
    }

    /**
      @notice Returns true if response is older than `heartbeat`
      */
    function _chainlinkIsFrozen(ChainlinkResponse memory _response) internal view returns (bool) {
        return (block.timestamp - _response.timestamp) > heartbeat;
    }

    /**
      @notice Returns true if % change in price from previous round to current is above `maxDeviationFromPreviousRound`.
      If maxDeviationFromPreviousRound is e.g. 5_000 (50%), return true if price has more than doubled, or more than halved.
      */
    function _chainlinkPriceChangeAboveMax(ChainlinkResponse memory _currentResponse, ChainlinkResponse memory _prevResponse) internal view returns (bool) {
        uint currentScaledPrice = _scaleChainlinkPriceByDecimals(uint256(_currentResponse.answer), _currentResponse.decimals);
        uint prevScaledPrice = _scaleChainlinkPriceByDecimals(uint256(_prevResponse.answer), _prevResponse.decimals);

        uint minPrice = Math.min(currentScaledPrice, prevScaledPrice);
        uint maxPrice = Math.max(currentScaledPrice, prevScaledPrice);

        /*
        * Use the larger price as the denominator:
        * - If price decreased, the percentage deviation is in relation to the the previous price.
        * - If price increased, the percentage deviation is in relation to the current price.
        */
        uint percentDeviation = (maxPrice - minPrice) * 10_000 / maxPrice;

        return percentDeviation > maxDeviationFromPreviousRound;
    }

    /**
      @notice Scales `_price` to `outputDecimals`
      @param _price ChainlinkResponse.answer
      @param _answerDecimals ChainlinkResponse.decimals
      */
    function _scaleChainlinkPriceByDecimals(uint _price, uint _answerDecimals) internal view returns (uint) {
        uint price;
        if (_answerDecimals >= outputDecimals) {
            price = _price / (10 ** (_answerDecimals - outputDecimals));
        }
        else if (_answerDecimals < outputDecimals) {
            price = _price * (10 ** (outputDecimals - _answerDecimals));
        }
        return price;
    }

    // --- Oracle response wrapper functions ---

    /**
      @notice Gets latest Chainlink response
      */
    function _getCurrentChainlinkResponse() internal view returns (ChainlinkResponse memory chainlinkResponse) {
        // First, try to get current decimal precision:
        try oracle.decimals() returns (uint8 decimals) {
            // If call to Chainlink succeeds, record the current decimal precision
            chainlinkResponse.decimals = decimals;
        } catch {
            // If call to Chainlink aggregator reverts, return a zero response with success = false
            return chainlinkResponse;
        }

        // Secondly, try to get latest price data:
        try oracle.latestRoundData() returns
        (
            uint80 roundId,
            int256 answer,
            uint256 /* startedAt */,
            uint256 timestamp,
            uint80 /* answeredInRound */
        )
        {
            // If call to Chainlink succeeds, return the response and success = true
            chainlinkResponse.roundId = roundId;
            chainlinkResponse.answer = answer;
            chainlinkResponse.timestamp = timestamp;
            chainlinkResponse.success = true;
            return chainlinkResponse;
        } catch {
            // If call to Chainlink aggregator reverts, return a zero response with success = false
            return chainlinkResponse;
        }
    }

    /**
      @notice Gets historical response from oracle using roundId immediately before latest
      @param _currentRoundId currentResponse.roundId
      @param _currentDecimals currentResponse.decimals
      */
    function _getPrevChainlinkResponse(uint80 _currentRoundId, uint8 _currentDecimals) internal view returns (ChainlinkResponse memory prevChainlinkResponse) {
        /*
        * NOTE: Chainlink only offers a current decimals() value - there is no way to obtain the decimal precision used in a 
        * previous round.  We assume the decimals used in the previous round are the same as the current round.
        */

        // Try to get the price data from the previous round:
        try oracle.getRoundData(_currentRoundId - 1) returns
        (
            uint80 roundId,
            int256 answer,
            uint256 /* startedAt */,
            uint256 timestamp,
            uint80 /* answeredInRound */
        )
        {
            // If call to Chainlink succeeds, return the response and success = true
            prevChainlinkResponse.roundId = roundId;
            prevChainlinkResponse.answer = answer;
            prevChainlinkResponse.timestamp = timestamp;
            prevChainlinkResponse.decimals = _currentDecimals;
            prevChainlinkResponse.success = true;
            return prevChainlinkResponse;
        } catch {
            // If call to Chainlink aggregator reverts, return a zero response with success = false
            return prevChainlinkResponse;
        }
    }
}
