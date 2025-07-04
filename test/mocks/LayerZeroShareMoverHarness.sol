// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {LayerZeroShareMover} from "src/base/Roles/CrossChain/ShareMover/LayerZeroShareMover.sol";
import {MessageLib} from "src/base/Roles/CrossChain/ShareMover/MessageLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Authority} from "@solmate/auth/Auth.sol";

/**
 * @title LayerZeroShareMoverHarness
 * @notice Exposes internal helpers of LayerZeroShareMover for unit testing without touching LayerZero endpoint.
 */
contract LayerZeroShareMoverHarness is LayerZeroShareMover {
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

    // ------------------------------------------------------------------------------------------
    // Stub ShareMover abstract functions (not used in these unit tests)
    // ------------------------------------------------------------------------------------------

    function _sendMessage(
        MessageLib.Message memory,
        uint32,
        bytes calldata,
        ERC20
    ) internal override returns (bytes32) {
        return bytes32("msgid");
    }

    function _previewFee(
        MessageLib.Message memory,
        uint32,
        bytes calldata,
        ERC20
    ) internal view override returns (uint256) {
        return 42;
    }
} 