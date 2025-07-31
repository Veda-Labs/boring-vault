// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {LayerZeroShareMover} from "src/base/Roles/CrossChain/ShareMover/LayerZeroShareMover.sol";
import {MessageLib} from "src/base/Roles/CrossChain/ShareMover/MessageLib.sol";
import {Authority} from "@solmate/auth/Auth.sol";

/**
 * @title LayerZeroShareMoverHarness
 * @notice Exposes internal helpers of LayerZeroShareMover for unit testing without touching LayerZero endpoint.
 */
contract LayerZeroShareMoverHarness is LayerZeroShareMover {
    // Storage helper to expose the last message that was "sent" in tests
    MessageLib.Message public lastMessage;

    constructor(address _vault, address _lzToken, address _endpoint)
        LayerZeroShareMover(
            msg.sender,     // owner
            address(0),     // authority
            _vault,
            _endpoint,
            address(this),  // delegate
            _lzToken
        )
    {}

    // ------------------------------------------------------------------------------------------
    // External wrappers for internal helpers
    // ------------------------------------------------------------------------------------------

    function exposedSanitize(bytes32 recipient, uint32 chainId) external view returns (bytes32) {
        return _sanitizeRecipient(recipient, chainId);
    }

    function exposedDecode(bytes calldata data)
        external
        pure
        returns (uint32 eid, address feeToken, uint256 maxFee)
    {
        BridgeParams memory p = _decodeBridgeParams(data);
        return (p.chainId, p.feeToken, p.maxFee);
    }

    function exposeSetOutboundLimits(RateLimitConfig[] calldata cfg) external {
        _setOutboundRateLimits(cfg);
    }
    function exposeSetInboundLimits(RateLimitConfig[] calldata cfg) external {
        _setInboundRateLimits(cfg);
    }
    function exposeOutboundCheck(uint32 eid, uint256 amt) external {
        _checkAndUpdateOutboundRateLimit(eid, amt);
    }
    function exposeInboundCheck(uint32 eid, uint256 amt) external {
        _checkAndUpdateInboundRateLimit(eid, amt);
    }

    // ------------------------------------------------------------------------------------------
    // Stub ShareMover abstract functions (not used in these unit tests)
    // ------------------------------------------------------------------------------------------

    function _sendMessage(
        uint96 shareAmount,
        bytes32 to,
        bytes calldata bridgeWildCard
    ) internal override returns (bytes32 msgId, uint32 chainId) {
        // Decode chainId from wildcard to mirror real implementation
        BridgeParams memory params = _decodeBridgeParams(bridgeWildCard);
        chainId = params.chainId;

        uint128 amt = uint128(shareAmount);
        uint8 dstDecimals = chains[chainId].targetDecimals;
        if (dstDecimals != 0 && dstDecimals != localDecimals) {
            amt = MessageLib.convertAmountDecimals(amt, localDecimals, dstDecimals);
        }

        lastMessage = MessageLib.Message({recipient: to, amount: amt});

        msgId = bytes32("msgid");
    }

    function _previewFee(
        uint96,
        bytes32,
        bytes calldata
    ) internal pure override returns (uint256) {
        return 42;
    }
} 