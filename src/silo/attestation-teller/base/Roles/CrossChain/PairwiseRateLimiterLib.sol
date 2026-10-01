// SPDX-License-Identifier: SEL-1.0
// Copyright © 2025 Veda Tech Labs
// Derived from Boring Vault Software © 2025 Veda Tech Labs (TEST ONLY – NO COMMERCIAL USE)
// Licensed under Software Evaluation License, Version 1.0
pragma solidity 0.8.21;

/**
 * @title PairwiseRateLimiterLib
 * @dev Library containing the core rate limiting logic, deployed separately to reduce consumer bytecode.
 */
library PairwiseRateLimiterLib {
    struct RateLimit {
        uint256 amountInFlight;
        uint256 lastUpdated;
        uint256 limit;
        uint256 window;
    }

    struct RateLimitConfig {
        uint32 peerEid;
        uint256 limit;
        uint256 window;
    }

    event OutboundRateLimitsChanged(RateLimitConfig[] rateLimitConfigs);
    event InboundRateLimitsChanged(RateLimitConfig[] rateLimitConfigs);

    error OutboundRateLimitExceeded();
    error InboundRateLimitExceeded();

    /**
     * @notice Gets the current amount in flight and amount that can be sent for a given endpoint,
     *         reading directly from the storage mapping.
     */
    function getAmountCanBeSentFromMapping(mapping(uint32 => RateLimit) storage rateLimits, uint32 eid)
        external
        view
        returns (uint256 currentAmountInFlight, uint256 amountCanBeSentValue)
    {
        RateLimit memory rl = rateLimits[eid];
        return _computeAmountCanBeSent(rl.amountInFlight, rl.lastUpdated, rl.limit, rl.window);
    }

    /**
     * @notice Checks and updates the outbound rate limit for a given endpoint.
     */
    function checkAndUpdateOutboundRateLimit(
        mapping(uint32 => RateLimit) storage rateLimits,
        uint32 _dstEid,
        uint256 _amount
    ) external {
        RateLimit storage rl = rateLimits[_dstEid];
        (uint256 currentAmountInFlight, uint256 canBeSent) =
            _computeAmountCanBeSent(rl.amountInFlight, rl.lastUpdated, rl.limit, rl.window);
        if (_amount > canBeSent) revert OutboundRateLimitExceeded();
        rl.amountInFlight = currentAmountInFlight + _amount;
        rl.lastUpdated = block.timestamp;
    }

    /**
     * @notice Checks and updates the inbound rate limit for a given endpoint.
     */
    function checkAndUpdateInboundRateLimit(
        mapping(uint32 => RateLimit) storage rateLimits,
        uint32 _srcEid,
        uint256 _amount
    ) external {
        RateLimit storage rl = rateLimits[_srcEid];
        (uint256 currentAmountInFlight, uint256 canBeSent) =
            _computeAmountCanBeSent(rl.amountInFlight, rl.lastUpdated, rl.limit, rl.window);
        if (_amount > canBeSent) revert InboundRateLimitExceeded();
        rl.amountInFlight = currentAmountInFlight + _amount;
        rl.lastUpdated = block.timestamp;
    }

    /**
     * @notice Sets outbound rate limit configurations.
     */
    function setOutboundRateLimits(
        mapping(uint32 => RateLimit) storage rateLimits,
        RateLimitConfig[] memory _rateLimitConfigs
    ) external {
        unchecked {
            for (uint256 i = 0; i < _rateLimitConfigs.length; i++) {
                RateLimit storage rl = rateLimits[_rateLimitConfigs[i].peerEid];
                // Checkpoint existing rate limit to not retroactively apply new decay rate.
                _checkAndUpdateRateLimit(rateLimits, _rateLimitConfigs[i].peerEid, 0);
                rl.limit = _rateLimitConfigs[i].limit;
                rl.window = _rateLimitConfigs[i].window;
            }
        }
        emit OutboundRateLimitsChanged(_rateLimitConfigs);
    }

    /**
     * @notice Sets inbound rate limit configurations.
     */
    function setInboundRateLimits(
        mapping(uint32 => RateLimit) storage rateLimits,
        RateLimitConfig[] memory _rateLimitConfigs
    ) external {
        unchecked {
            for (uint256 i = 0; i < _rateLimitConfigs.length; i++) {
                RateLimit storage rl = rateLimits[_rateLimitConfigs[i].peerEid];
                // Checkpoint existing rate limit to not retroactively apply new decay rate.
                _checkAndUpdateRateLimit(rateLimits, _rateLimitConfigs[i].peerEid, 0);
                rl.limit = _rateLimitConfigs[i].limit;
                rl.window = _rateLimitConfigs[i].window;
            }
        }
        emit InboundRateLimitsChanged(_rateLimitConfigs);
    }

    // ========================================= INTERNAL =========================================

    function _checkAndUpdateRateLimit(mapping(uint32 => RateLimit) storage rateLimits, uint32 _eid, uint256 _amount)
        private
    {
        RateLimit storage rl = rateLimits[_eid];
        (uint256 currentAmountInFlight,) =
            _computeAmountCanBeSent(rl.amountInFlight, rl.lastUpdated, rl.limit, rl.window);
        rl.amountInFlight = currentAmountInFlight + _amount;
        rl.lastUpdated = block.timestamp;
    }

    function _computeAmountCanBeSent(uint256 _amountInFlight, uint256 _lastUpdated, uint256 _limit, uint256 _window)
        private
        view
        returns (uint256 currentAmountInFlight, uint256 canBeSent)
    {
        uint256 timeSinceLastDeposit = block.timestamp - _lastUpdated;
        if (timeSinceLastDeposit >= _window) {
            currentAmountInFlight = 0;
            canBeSent = _limit;
        } else {
            uint256 decay = (_limit * timeSinceLastDeposit) / _window;
            currentAmountInFlight = _amountInFlight <= decay ? 0 : _amountInFlight - decay;
            canBeSent = _limit <= currentAmountInFlight ? 0 : _limit - currentAmountInFlight;
        }
    }
}
